open! Core
open! Async

let cycle_enum ~all ~equal t =
  let all = Array.of_list all in
  let i = Array.findi_exn all ~f:(fun _ x -> equal x t) |> fst in
  all.((i + 1) mod Array.length all)
;;

let cycle_enum_back ~all ~equal t =
  let all = Array.of_list all in
  let i = Array.findi_exn all ~f:(fun _ x -> equal x t) |> fst in
  all.((i - 1 + Array.length all) mod Array.length all)
;;

module Timestamp_mode = struct
  type t =
    | Time_only (* "11:20:27.161365" *)
    | Relative (* "MM:SS.mmmuuu" relative to process start *)
    | Delta (* "+SS.mmmuuu" relative to previous message *)
  [@@deriving sexp, equal, enumerate]

  let default = List.hd_exn all
  let cycle t = cycle_enum ~all ~equal:[%equal: t] t
  let cycle_back t = cycle_enum_back ~all ~equal:[%equal: t] t
end

module Message_mode = struct
  type t =
    | Normal
    | Pretty
    | Expectree
    | Expectable
  [@@deriving sexp, equal, enumerate]

  let default = List.hd_exn all
  let cycle t = cycle_enum ~all ~equal:[%equal: t] t
  let cycle_back t = cycle_enum_back ~all ~equal:[%equal: t] t
end

(** A structured message parsed from a sexp of the form (message (key1 val1) (key2 val2)
    ...) *)
module Structured_message = struct
  type t =
    { message : string
    ; attributes : (string * Sexp.t) list
    }
  [@@deriving sexp_of]

  (** Try to parse a sexp as a structured message. Returns [Some t] if the sexp is an
      atom, or a list whose first element is an atom and whose subsequent elements are
      pairs. *)
  let of_sexp sexp =
    match (sexp : Sexp.t) with
    | Atom message -> Some { message; attributes = [] }
    | List (Atom message :: rest) ->
      let attributes =
        List.filter_map rest ~f:(fun attr ->
          match attr with
          | Sexp.List [ Atom key; value ] -> Some (key, value)
          | _ -> None)
      in
      (* Only treat as structured if all remaining elements were valid pairs *)
      if List.length attributes = List.length rest
      then Some { message; attributes }
      else None
    | _ -> None
  ;;

  (** Pretty-print a structured message *)
  let to_string_pretty { message; attributes } =
    if List.is_empty attributes
    then message
    else (
      let attr_strs =
        List.map attributes ~f:(fun (key, value) ->
          Sexp.to_string_hum ~max_width:Int.max_value (Sexp.List [ Sexp.Atom key; value ]))
      in
      [%string "%{message} %{String.concat attr_strs ~sep:\" \"}"])
  ;;
end

type t =
  { timestamp : Time_ns.t
  ; level : Log.Level.t option
  ; message : string
  }
[@@deriving sexp_of]

let with_parsed_sexp message ~if_not_sexp ~if_unstructured_sexp ~if_structured =
  match Option.try_with (fun () -> Sexp.of_string message) with
  | None -> if_not_sexp message
  | Some sexp ->
    (match Structured_message.of_sexp sexp with
     | None -> if_unstructured_sexp message sexp
     | Some structured -> if_structured structured)
;;

let format_attrs_sexp attributes =
  Sexp.List
    (List.map attributes ~f:(fun (key, value) -> Sexp.List [ Sexp.Atom key; value ]))
;;

(** Format a message, optionally pretty-printing if it's a structured sexp *)
let format_message ~message_mode message =
  let passthrough message _sexp = message in
  match (message_mode : Message_mode.t) with
  | Normal ->
    with_parsed_sexp
      message
      ~if_not_sexp:Fn.id
      ~if_unstructured_sexp:passthrough
      ~if_structured:Structured_message.to_string_pretty
  | Pretty ->
    with_parsed_sexp
      message
      ~if_not_sexp:Fn.id
      ~if_unstructured_sexp:passthrough
      ~if_structured:(fun { message; attributes } ->
        match attributes with
        | [] -> message
        | [ (key, value) ] ->
          let attr_sexp = Sexp.List [ Sexp.Atom key; value ] in
          [%string "%{message}\n%{Sexp_pretty.sexp_to_string attr_sexp}"]
        | _ ->
          [%string
            "%{message}\n%{Sexp_pretty.sexp_to_string (format_attrs_sexp attributes)}"])
  | Expectree ->
    with_parsed_sexp
      message
      ~if_not_sexp:Fn.id
      ~if_unstructured_sexp:(fun _message sexp -> Expectree.sexp_to_string sexp)
      ~if_structured:(fun { message; attributes } ->
        Expectree.sexp_to_string
          [%sexp ((message, attributes) : string * (string * Sexp.t) list)])
  | Expectable ->
    with_parsed_sexp
      message
      ~if_not_sexp:Fn.id
      ~if_unstructured_sexp:passthrough
      ~if_structured:(fun { message; attributes } ->
        if List.is_empty attributes
        then message
        else (
          let table = Expectable.Format.print [ format_attrs_sexp attributes ] in
          [%string "%{message}\n%{table}"]))
;;

(* The timestamp format "2026-01-28 11:20:27.161365-05:00" is always 32 characters *)
let timestamp_width = 32

(** Format a timestamp as time only (no date). Output format: "11:20:27.161365" *)
let format_timestamp_time_only timestamp ~zone =
  let _date, ofday = Time_ns.to_date_ofday ~zone timestamp in
  let parts = Time_ns.Ofday.to_parts ofday in
  sprintf "%02d:%02d:%02d.%03d%03d" parts.hr parts.min parts.sec parts.ms parts.us
;;

(** Format a timestamp as relative to a start time. Output format: "MM:SS.mmmuuu" or
    "HH:MM:SS.mmmuuu" if >= 1 hour. Always shows minutes. *)
let format_timestamp_relative ~start_time timestamp =
  let span = Time_ns.Span.max Time_ns.Span.zero (Time_ns.diff timestamp start_time) in
  let { Time_ns.Span.Parts.sign = _; hr; min; sec; ms; us; ns = _ } =
    Time_ns.Span.to_parts span
  in
  if hr > 0
  then sprintf "%02d:%02d:%02d.%03d%03d" hr min sec ms us
  else sprintf "%02d:%02d.%03d%03d" min sec ms us
;;

(** Format a timestamp as delta from previous time. Output format: "+SS.mmmuuu",
    "+MM:SS.mmmuuu", or "+HH:MM:SS.mmmuuu". Only shows larger units if nonzero. *)
let format_timestamp_delta ~previous_time timestamp =
  let span = Time_ns.Span.max Time_ns.Span.zero (Time_ns.diff timestamp previous_time) in
  let { Time_ns.Span.Parts.sign = _; hr; min; sec; ms; us; ns = _ } =
    Time_ns.Span.to_parts span
  in
  if hr > 0
  then sprintf "+%d:%02d:%02d.%03d%03d" hr min sec ms us
  else if min > 0
  then sprintf "+%d:%02d.%03d%03d" min sec ms us
  else sprintf "+%d.%03d%03d" sec ms us
;;

let format_timestamp ~mode ~start_time ~previous_time ~zone timestamp =
  match (mode : Timestamp_mode.t) with
  | Time_only -> format_timestamp_time_only timestamp ~zone
  | Relative ->
    (match start_time with
     | Some start -> format_timestamp_relative ~start_time:start timestamp
     | None -> format_timestamp_time_only timestamp ~zone)
  | Delta ->
    (match previous_time with
     | Some prev -> format_timestamp_delta ~previous_time:prev timestamp
     | None ->
       (match start_time with
        | Some start -> format_timestamp_delta ~previous_time:start timestamp
        | None -> format_timestamp_time_only timestamp ~zone))
;;

(** Parse a log line in the standard OCaml text format: "2026-01-28 11:20:27.161365-05:00
    Info Server ready in instance local"

    Returns [Some t] if the line matches the format, [None] otherwise. *)
let parse_text_format line =
  let open Option.Let_syntax in
  (* Need at least timestamp + space + something *)
  let%bind () = Option.some_if (String.length line > timestamp_width + 1) () in
  let%bind timestamp =
    Option.try_with (fun () -> Time_ns.of_string (String.prefix line timestamp_width))
  in
  (* Try to parse level - it's optional *)
  let level, message =
    (* Find the space after the potential level *)
    match
      String.lfindi line ~pos:(timestamp_width + 1) ~f:(fun _ c -> Char.equal c ' ')
    with
    | None ->
      (* No space found - everything after timestamp is the message, no level *)
      let message = String.subo line ~pos:(timestamp_width + 1) in
      None, message
    | Some level_end ->
      let level_str =
        String.sub line ~pos:(timestamp_width + 1) ~len:(level_end - timestamp_width - 1)
      in
      (match Option.try_with (fun () -> Log.Level.of_string level_str) with
       | Some level ->
         let message = String.subo line ~pos:(level_end + 1) in
         Some level, message
       | None ->
         (* Not a valid level - treat everything after timestamp as message *)
         let message = String.subo line ~pos:(timestamp_width + 1) in
         None, message)
  in
  Some { timestamp; level; message }
;;

(** Parse a log line in the async_log sexp format using [Log.Message.Stable.V3.t_of_sexp],
    which handles the versioned [(V2 ...)] wrapper:
    [(V2((time(2026-02-18 10:57:33.205472Z))(level(Info))(message(String"Starting up"))(tags())))]

    Returns [Some t] if the line matches the format, [None] otherwise. *)
let parse_sexp_format line =
  let open Option.Let_syntax in
  let%bind () = Option.some_if (String.is_prefix line ~prefix:"(") () in
  let%bind sexp = Option.try_with (fun () -> Sexp.of_string line) in
  let%bind msg = Option.try_with (fun () -> Log.Message.Stable.V3.t_of_sexp sexp) in
  let timestamp = Log.Message.time msg |> Time_ns.of_time_float_round_nearest in
  let level = Log.Message.level msg in
  (* Produce the same message+tags string that [Log.Message.to_write_only_text] would, so
     that sexp-format and text-format logs look the same after parsing. *)
  let message =
    String.concat
      (Log.Message.message msg
       ::
       (match Log.Message.tags msg with
        | [] -> []
        | tags ->
          " --"
          :: List.concat_map tags ~f:(fun (key, value) -> [ " ["; key; ": "; value; "]" ]))
      )
  in
  Some { timestamp; level; message }
;;

(** Parse a log line in either text format or sexp format.

    Returns [Some t] if the line matches either format, [None] otherwise. *)
let parse line =
  match parse_sexp_format line with
  | Some _ as result -> result
  | None -> parse_text_format line
;;

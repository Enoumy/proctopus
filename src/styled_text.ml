open! Core
open Bonsai_term

(** A flat representation of styled text as a list of fragments. Each fragment has text
    and optional attributes. This can be rendered as a single line or wrapped to multiple
    lines while preserving styling. *)

(** Calculate the display width of a string using proper UTF-8 decoding *)
let display_width_utf8 s =
  let decoder = Uutf.decoder ~encoding:`UTF_8 (`String s) in
  let rec loop acc =
    match Uutf.decode decoder with
    | `Uchar u -> loop (acc + View.uchar_tty_width u)
    | `End -> acc
    | `Malformed _ -> loop (acc + 1)
    | `Await -> acc
  in
  loop 0
;;

(** Split a UTF-8 string at a given display width, returning (before, after,
    ~split_width). The [~split_width] avoids the caller needing to re-decode [before] to
    measure it. Short-circuits without decoding when the byte length of [s] is less than
    [target_width], since every UTF-8 character occupies at least one byte. *)
let split_at_display_width s target_width =
  if String.length s < target_width
  then s, "", ~split_width:(display_width_utf8 s)
  else (
    let decoder = Uutf.decoder ~encoding:`UTF_8 (`String s) in
    let buf_before = Buffer.create (String.length s) in
    let rec loop current_width =
      if current_width >= target_width
      then (
        (* We've reached the target width, rest goes to 'after' *)
        let pos = Uutf.decoder_byte_count decoder in
        let before = Buffer.contents buf_before in
        let after = String.subo s ~pos in
        before, after, ~split_width:current_width)
      else (
        match Uutf.decode decoder with
        | `Uchar u ->
          let char_width = View.uchar_tty_width u in
          if current_width + char_width > target_width
          then (
            (* This character would exceed target, stop here *)
            let before = Buffer.contents buf_before in
            let byte_len = Uchar.Utf8.byte_length u in
            let pos = Uutf.decoder_byte_count decoder - byte_len in
            let after = String.subo s ~pos in
            before, after, ~split_width:current_width)
          else (
            (* Add this character to before *)
            Uutf.Buffer.add_utf_8 buf_before u;
            loop (current_width + char_width))
        | `End -> Buffer.contents buf_before, "", ~split_width:current_width
        | `Malformed bytes ->
          Buffer.add_string buf_before bytes;
          loop (current_width + 1)
        | `Await -> Buffer.contents buf_before, "", ~split_width:current_width)
    in
    loop 0)
;;

module Fragment = struct
  type t =
    { text : string
    ; attrs : Attr.t list
    }

  let create ?(attrs = []) text = { text; attrs }

  (** Split fragment at a given display width. Returns (before, after,
      before_display_width) so callers can track widths without re-decoding. *)
  let split_at_width t target_width =
    let before, after, ~split_width = split_at_display_width t.text target_width in
    { t with text = before }, { t with text = after }, ~split_width
  ;;
end

type t = Fragment.t list

let of_string ?attrs s = [ Fragment.create ?attrs s ]
let concat (ts : t list) : t = List.concat ts
let to_string t = List.map t ~f:(fun f -> f.Fragment.text) |> String.concat

let to_view t =
  List.map t ~f:(fun { Fragment.text; attrs } -> View.text ~attrs text) |> View.hcat
;;

(** Wrap styled text to fit within the given width (in display columns). Returns a list of
    styled text lines. Wrapping splits fragments as needed to fill each line, respecting
    Unicode character display widths. *)
let wrap ~width t =
  if width <= 0
  then [ t ]
  else (
    let rec loop current_line current_width remaining_fragments lines =
      match remaining_fragments with
      | [] ->
        (* Finish the last line *)
        let final_lines =
          if List.is_empty current_line then lines else current_line :: lines
        in
        List.rev final_lines
      | fragment :: rest ->
        let space_left = width - current_width in
        if space_left <= 0
        then
          (* Line is full, start a new line with this fragment *)
          loop [] 0 (fragment :: rest) (current_line :: lines)
        else (
          (* Try to split the fragment at the remaining space. This is O(space_left)
             rather than O(fragment length), avoiding an O(N^2/W) worst case for very long
             lines. [split_at_width] also returns the display width of [before] so we
             don't need to re-decode it. *)
          let before, after, ~split_width = Fragment.split_at_width fragment space_left in
          if String.is_empty after.text
          then
            (* Entire fragment fit on the current line *)
            loop (current_line @ [ before ]) (current_width + split_width) rest lines
          else (
            (* Fragment was split - before fills the line, after continues *)
            let line = current_line @ [ before ] in
            loop [] 0 (after :: rest) (line :: lines)))
    in
    match loop [] 0 t [] with
    | [] -> [ [] ]
    | lines -> lines)
;;

let to_view_wrapped ~width t = List.map (wrap ~width t) ~f:to_view |> View.vcat

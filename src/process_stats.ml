open! Core

module Sample = struct
  module State = struct
    type t =
      | Running
      | Sleeping
      | Stopped
      | Zombie
      | Other
    [@@deriving bin_io, sexp]
  end

  type t =
    { timestamp : Time_ns.t
    ; cpu_percent : float
    ; memory_rss_bytes : Int64.t
    ; memory_virt_bytes : Int64.t
    ; num_threads : int
    ; state : State.t
    }
  [@@deriving bin_io, sexp]
end

module Tree_sample = struct
  type process_info =
    { pid : Pid.t
    ; command : string
    ; sample : Sample.t
    }
  [@@deriving bin_io, sexp]

  type t =
    { root : process_info
    ; children : process_info list
    ; total_cpu_percent : float
    ; total_memory_rss_bytes : Int64.t
    }
  [@@deriving bin_io, sexp]
end

module History = struct
  type t = Tree_sample.t Circular_buffer.t [@@deriving sexp_of]

  let create ~max_samples = Circular_buffer.create ~capacity:max_samples
  let add t sample = Circular_buffer.push t sample
  let to_list t = Circular_buffer.to_list t
  let is_empty t = Circular_buffer.length t = 0
  let latest t = Circular_buffer.last t

  let cpu_percents t =
    Circular_buffer.to_list_map t ~f:(fun (s : Tree_sample.t) -> s.total_cpu_percent)
  ;;

  let memory_rss_bytes t =
    Circular_buffer.to_list_map t ~f:(fun (s : Tree_sample.t) -> s.total_memory_rss_bytes)
  ;;

  let max_memory_rss_bytes t =
    Circular_buffer.fold t ~init:0L ~f:(fun acc (s : Tree_sample.t) ->
      if Int64.( > ) s.total_memory_rss_bytes acc then s.total_memory_rss_bytes else acc)
  ;;
end

let sparkline_chars =
  [| "\xe2\x96\x81" (* ▁ *)
   ; "\xe2\x96\x82" (* ▂ *)
   ; "\xe2\x96\x83" (* ▃ *)
   ; "\xe2\x96\x84" (* ▄ *)
   ; "\xe2\x96\x85" (* ▅ *)
   ; "\xe2\x96\x86" (* ▆ *)
   ; "\xe2\x96\x87" (* ▇ *)
   ; "\xe2\x96\x88" (* █ *)
  |]
;;

let render_sparkline values ~max_width ?min_bound ?max_bound ?(right_align = false) () =
  if List.is_empty values
  then if right_align then String.make max_width ' ' else ""
  else (
    let values = List.take (List.rev values) max_width |> List.rev in
    let min_val =
      match min_bound with
      | Some m -> m
      | None -> List.fold values ~init:Float.infinity ~f:Float.min
    in
    let max_val =
      match max_bound with
      | Some m -> m
      | None -> List.fold values ~init:Float.neg_infinity ~f:Float.max
    in
    let range = max_val -. min_val in
    let strs =
      List.map values ~f:(fun v ->
        let normalized = if Float.( > ) range 0.0 then (v -. min_val) /. range else 0.5 in
        let idx =
          Float.to_int (normalized *. Float.of_int (Array.length sparkline_chars - 1))
        in
        let idx = Int.max 0 (Int.min idx (Array.length sparkline_chars - 1)) in
        sparkline_chars.(idx))
    in
    let sparkline = String.concat strs in
    if right_align
    then (
      (* Each sparkline char is 3 bytes in UTF-8, so we count actual chars *)
      let num_chars = List.length strs in
      let padding = max_width - num_chars in
      if padding > 0 then String.make padding ' ' ^ sparkline else sparkline)
    else sparkline)
;;

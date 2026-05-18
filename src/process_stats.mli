open! Core

(** Stats for a single process at a point in time *)
module Sample : sig
  module State : sig
    type t =
      | Running
      | Sleeping
      | Stopped
      | Zombie
      | Other
    [@@deriving sexp, bin_io]
  end

  type t =
    { timestamp : Time_ns.t
    ; cpu_percent : float (** CPU usage as percentage (0-100 per core) *)
    ; memory_rss_bytes : Int64.t (** Resident set size in bytes *)
    ; memory_virt_bytes : Int64.t (** Virtual memory size in bytes *)
    ; num_threads : int
    ; state : State.t
    }
  [@@deriving sexp, bin_io]
end

(** Stats for a process tree (main process + children) *)
module Tree_sample : sig
  type process_info =
    { pid : Pid.t
    ; command : string
    ; sample : Sample.t
    }
  [@@deriving sexp, bin_io]

  type t =
    { root : process_info
    ; children : process_info list
    ; total_cpu_percent : float
    ; total_memory_rss_bytes : Int64.t
    }
  [@@deriving sexp, bin_io]
end

(** History of samples for sparkline rendering *)
module History : sig
  type t [@@deriving sexp_of]

  val create : max_samples:int -> t
  val add : t -> Tree_sample.t -> t
  val to_list : t -> Tree_sample.t list
  val cpu_percents : t -> float list
  val memory_rss_bytes : t -> Int64.t list
  val max_memory_rss_bytes : t -> Int64.t
  val is_empty : t -> bool
  val latest : t -> Tree_sample.t option
end

(** Render a sparkline from a list of values. Optional [min_bound] and [max_bound] specify
    the range for scaling (defaults to min/max of values). If [right_align] is true, pads
    with spaces on the left to fill [max_width]. *)
val render_sparkline
  :  float list
  -> max_width:int
  -> ?min_bound:float
  -> ?max_bound:float
  -> ?right_align:bool
  -> unit
  -> string

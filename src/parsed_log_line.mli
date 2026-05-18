open! Core
open! Async

module Timestamp_mode : sig
  type t =
    | Time_only
    | Relative
    | Delta
  [@@deriving sexp, equal, enumerate]

  val default : t
  val cycle : t -> t
  val cycle_back : t -> t
end

module Message_mode : sig
  type t =
    | Normal
    | Pretty
    | Expectree
    | Expectable
  [@@deriving sexp, equal, enumerate]

  val default : t
  val cycle : t -> t
  val cycle_back : t -> t
end

module Structured_message : sig
  type t =
    { message : string
    ; attributes : (string * Sexp.t) list
    }
  [@@deriving sexp_of]

  val of_sexp : Sexp.t -> t option
  val to_string_pretty : t -> string
end

type t =
  { timestamp : Time_ns.t
  ; level : Log.Level.t option
  ; message : string
  }
[@@deriving sexp_of]

val format_message : message_mode:Message_mode.t -> string -> string

val format_timestamp
  :  mode:Timestamp_mode.t
  -> start_time:Time_ns.t option
  -> previous_time:Time_ns.t option
  -> zone:Time_ns.Zone.t
  -> Time_ns.t
  -> string

val parse : string -> t option

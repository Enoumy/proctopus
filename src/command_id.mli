(** An identifier for a given command in the tree, e.g. "foo/bar:command" has the id
    ["foo"; "bar"] *)

open! Core

type t = string list [@@deriving sexp, compare, equal, hash, bin_io]

include Comparable.S with type t := t
include Hashable.S with type t := t

(** Parse a string like "foo/bar" into ["foo"; "bar"] *)
val of_string : string -> t

(** Convert back to string form "foo/bar" *)
val to_string : t -> string

(** Concatenate two command ids *)
val concat : t -> t -> t

(** Get just the last segment for display (empty string if empty) *)
val display_name : t -> string

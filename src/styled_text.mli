open! Core
open Bonsai_term

(** A flat representation of styled text as a list of fragments. Each fragment has text
    and optional attributes. This can be rendered as a single line or wrapped to multiple
    lines while preserving styling. *)

type t

val of_string : ?attrs:Attr.t list -> string -> t
val concat : t list -> t
val to_string : t -> string

(** Render as a single-line view. *)
val to_view : t -> View.t

(** Wrap to fit within the given width, returning a list of styled text lines. *)
val wrap : width:int -> t -> t list

(** Wrap to fit within the given width and combine into a single view with line breaks. *)
val to_view_wrapped : width:int -> t -> View.t

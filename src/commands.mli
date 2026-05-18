open! Core

(** Build tree from items with paths, preserving original order. *)
val of_items
  :  root:string
  -> (Command_id.t * Tree_item.t) list
  -> Tree_item.t Navigable_tree.t

(** Test helper to create a command item from a label string. Parses "name:command"
    format, with [run_on_start] defaulting to false. *)
val entry : ?run_on_start:bool -> string -> Command_id.t * Tree_item.t

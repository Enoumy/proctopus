(** A trie that remembers the insertion order of its values within each prefix. This is
    useful for building trees where sibling order should match insertion order rather than
    alphabetical order. *)

type 'a t

val create : unit -> 'a t

(** Add a value at the given path. The path is a list of string segments. *)
val add : 'a t -> data:'a -> string list -> unit

(** Convert the trie to a list of tree nodes at the top level, preserving insertion order.
    [branch name children] creates a branch node with the given name and children.
    [leaf data] creates a leaf node from the stored data. *)
val to_tree_nodes
  :  'a t
  -> branch:(string -> 'node list -> 'node)
  -> leaf:('a -> 'node)
  -> 'node list

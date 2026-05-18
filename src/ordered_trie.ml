open! Core

(** This is a trie that remembers the insertion order of its values, but only within a
    single prefix. Unlike the version in [Expectable], this one stores associated data
    with each leaf. *)
type 'a t =
  { children : 'a t String.Table.t
  ; mutable insertion_order : string list (* latest first *)
  ; mutable leaf_data : 'a option
  }
[@@deriving sexp_of]

let create () =
  { children = String.Table.create (); insertion_order = []; leaf_data = None }
;;

let get_or_add_one t =
  Hashtbl.find_and_call t.children ~if_found:Fn.id ~if_not_found:(fun key ->
    let data = create () in
    Hashtbl.set t.children ~key ~data;
    t.insertion_order <- key :: t.insertion_order;
    data)
;;

let rec add t ~data path =
  match path with
  | [] -> t.leaf_data <- Some data
  | key :: rest -> add (get_or_add_one t key) ~data rest
;;

(** Convert the trie to a list of tree nodes at the top level, preserving insertion order.
    This is the main function for building navigable trees. *)
let to_tree_nodes t ~branch ~leaf =
  let rec build_node key subtrie =
    let children =
      List.map (List.rev subtrie.insertion_order) ~f:(fun child_key ->
        let child = Hashtbl.find_exn subtrie.children child_key in
        build_node child_key child)
    in
    match subtrie.leaf_data, children with
    | Some data, [] -> leaf data
    | None, children -> branch key children
    | Some data, children ->
      (* Unusual case: both a leaf and children at the same path *)
      branch key (leaf data :: children)
  in
  List.map (List.rev t.insertion_order) ~f:(fun key ->
    let child = Hashtbl.find_exn t.children key in
    build_node key child)
;;

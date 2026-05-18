open! Core

(* Build tree from items with paths, preserving original order. Uses Ordered_trie to
   remember the insertion order of sections/items at each level. *)
let of_items ~root (items : (Command_id.t * Tree_item.t) list)
  : Tree_item.t Navigable_tree.t
  =
  let trie = Ordered_trie.create () in
  List.iter items ~f:(fun (path, item) -> Ordered_trie.add trie ~data:item path);
  let children =
    Ordered_trie.to_tree_nodes
      trie
      ~branch:(fun name children ->
        Navigable_tree.Node.Branch
          { value = Tree_item.Section name; children; expanded = true })
      ~leaf:(fun item -> Navigable_tree.Node.Leaf item)
  in
  Navigable_tree.Node.Branch { value = Tree_item.Section root; children; expanded = true }
;;

(* Test helper to create a command item from a label string. *)
let entry ?(run_on_start = false) label =
  let id, bash_code =
    match String.lsplit2 label ~on:':' with
    | Some (id, bash_code) -> Command_id.of_string id, bash_code
    | None -> Command_id.of_string label, label
  in
  id, Tree_item.Command { id; bash_code; run_on_start; is_interactive = false }
;;

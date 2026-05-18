open! Core

type t = string list [@@deriving sexp, compare, equal, hash, bin_io]

include functor Comparable.Make
include functor Hashable.Make

let of_string s =
  match s with
  | "" -> []
  | _ -> String.split s ~on:'/'
;;

let to_string t = String.concat t ~sep:"/"
let concat t1 t2 = t1 @ t2

let display_name t =
  match List.last t with
  | Some name -> name
  | None -> ""
;;

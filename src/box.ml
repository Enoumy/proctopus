open! Core

(** A box that wraps a mutable value, creating a new box on each mutation to defeat
    Bonsai's phys_equal cutoff. Mutating the inner value and then re-boxing ensures Bonsai
    sees a new allocation and triggers re-computation. *)

type 'a t = { mutable value : 'a } [@@deriving sexp_of]

let create value = { value }
let get t = t.value

let mutate t ~f =
  f t.value;
  { value = t.value }
;;

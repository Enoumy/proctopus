(** A box that wraps a mutable value, creating a new box on each mutation to defeat
    Bonsai's phys_equal cutoff.

    When used as part of a Bonsai model, mutations to the inner value are invisible to
    Bonsai's change detection (which uses [phys_equal]). Calling [mutate] returns a fresh
    allocation wrapping the same (now-mutated) inner value, which Bonsai will see as a
    change. The caller must not hold on to the old box after calling [mutate]. *)

open! Core

type 'a t [@@deriving sexp_of]

val create : 'a -> 'a t
val get : 'a t -> 'a

(** Mutate the inner value and return a fresh box wrapping the same (now mutated) value.
    The caller must not hold on to the old box. *)
val mutate : 'a t -> f:('a -> unit) -> 'a t

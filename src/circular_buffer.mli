(** A fixed-capacity circular buffer backed by a [Box] for Bonsai compatibility.

    Memory is bounded: the buffer pre-allocates a [Uniform_array] of [capacity] slots
    (using [or_null] for empty slots) and overwrites the oldest element when full. [push]
    returns a fresh [Box] wrapper to defeat Bonsai's phys_equal cutoff.

    Elements are stored in insertion order (oldest to newest). *)

open! Core

type 'a t [@@deriving sexp_of]

val create : capacity:int -> 'a t

(** Add an element. If the buffer is full, the oldest element is overwritten. Returns a
    new box wrapping the (mutated) buffer. *)
val push : 'a t -> 'a -> 'a t

(** Number of elements currently in the buffer. *)
val length : 'a t -> int

(** Iterate from oldest to newest. *)
val iter : 'a t -> f:('a -> unit) -> unit

(** Iterate from newest to oldest. *)
val iter_rev : 'a t -> f:('a -> unit) -> unit

(** Fold from oldest to newest. *)
val fold : 'a t -> init:'acc -> f:('acc -> 'a -> 'acc) -> 'acc

(** Return elements oldest to newest. *)
val to_list : 'a t -> 'a list

(** Map each element and return the results oldest to newest. *)
val to_list_map : 'a t -> f:('a -> 'b) -> 'b list

(** The most recently added element, or [None] if empty. *)
val last : 'a t -> 'a option

(** Reset the buffer to empty. The underlying array is reused. *)
val clear : 'a t -> 'a t

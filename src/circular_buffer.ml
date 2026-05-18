open! Core

type 'a inner =
  { arr : 'a or_null Uniform_array.t
  ; capacity : int
  ; mutable write_pos : int (* next slot to write, mod capacity *)
  ; mutable len : int (* number of live elements, <= capacity *)
  }
[@@deriving sexp_of]

type 'a t = 'a inner Box.t [@@deriving sexp_of]

let create ~capacity =
  Box.create
    { arr = Uniform_array.create ~len:capacity Null; capacity; write_pos = 0; len = 0 }
;;

let push t elem =
  Box.mutate t ~f:(fun inner ->
    Uniform_array.set inner.arr inner.write_pos (This elem);
    inner.write_pos <- (inner.write_pos + 1) mod inner.capacity;
    if inner.len < inner.capacity then inner.len <- inner.len + 1)
;;

let length t = (Box.get t).len

(** Index of the oldest element *)
let oldest_index inner = (inner.write_pos - inner.len + inner.capacity) mod inner.capacity

(** Get element at logical index [i] (0 = oldest, len-1 = newest). *)
let get_exn inner i =
  let physical = (oldest_index inner + i) mod inner.capacity in
  match Uniform_array.get inner.arr physical with
  | This x -> x
  | Null ->
    raise_s
      [%message "Circular_buffer.get_exn: unexpected Null" (i : int) (physical : int)]
;;

let iter t ~f =
  let inner = Box.get t in
  for i = 0 to inner.len - 1 do
    f (get_exn inner i)
  done
;;

let iter_rev t ~f =
  let inner = Box.get t in
  for i = inner.len - 1 downto 0 do
    f (get_exn inner i)
  done
;;

let fold t ~init ~f =
  let inner = Box.get t in
  let acc = ref init in
  for i = 0 to inner.len - 1 do
    acc := f !acc (get_exn inner i)
  done;
  !acc
;;

let to_list t =
  let acc = ref [] in
  iter_rev t ~f:(fun x -> acc := x :: !acc);
  !acc
;;

let to_list_map t ~f =
  let acc = ref [] in
  iter_rev t ~f:(fun x -> acc := f x :: !acc);
  !acc
;;

let last t =
  let inner = Box.get t in
  if inner.len = 0 then None else Some (get_exn inner (inner.len - 1))
;;

let clear t =
  Box.mutate t ~f:(fun inner ->
    for i = 0 to inner.capacity - 1 do
      Uniform_array.set inner.arr i Null
    done;
    inner.write_pos <- 0;
    inner.len <- 0)
;;

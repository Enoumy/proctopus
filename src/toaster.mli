(** A simple toast notification component that displays a short-lived message. *)

open! Core
open Bonsai_term

type t =
  { view : View.t Bonsai.t
  (** The toast view. Returns [View.none] when no toast is visible. The caller is
      responsible for positioning this view. *)
  ; show : (bg:Attr.Color.t -> string -> unit Effect.t) Bonsai.t
  (** Effect to show a toast with the given background color and text. The toast will be
      visible for 1 second. Calling [show] again before the previous toast expires will
      replace it. *)
  }

val create : Bonsai.graph @ local -> t

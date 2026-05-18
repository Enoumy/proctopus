open! Core
open Async

module Register_commands : sig
  (* Command ids here are specified relative to the provided [prefix] *)

  module Entry : sig
    type command =
      { id : Command_id.t
      ; bash_code : string
      ; run_on_start : bool
      ; is_interactive : bool
      }
    [@@deriving sexp]

    type group =
      { id : Command_id.t
      ; bash_code : string
      }
    [@@deriving sexp]

    type t =
      | Command of command
      | Group of group
    [@@deriving sexp]
  end

  module Query : sig
    type t =
      { entries : Entry.t list
      ; prefix : Command_id.t
      }
    [@@deriving sexp, bin_io]
  end

  module Response : sig
    type t = unit Or_error.t [@@deriving sexp, bin_io]
  end

  val implement
    :  ('state -> Query.t -> Response.t Deferred.t)
    -> 'state Rpc.Implementation.t list

  val dispatch : Rpc.Connection.t -> Query.t -> Response.t Or_error.t Deferred.t
end

module Start_process : sig
  module Query : sig
    type t =
      { id : Command_id.t
      ; output_fifo : string
      (** To avoid streaming all process stdout/stderr through RPC where you can't apply
          pushback, the channel instead opens a FIFO and hands it to the instance which
          writes output. The channel then can read lazily from the FIFO, and the instance
          will naturally receive pushback when the pipe is too full. *)
      }
    [@@deriving sexp, bin_io]
  end

  module Response : sig
    type t = unit [@@deriving sexp, bin_io]
  end

  val implement
    :  ('state -> Query.t -> Response.t Or_error.t Deferred.t)
    -> 'state Rpc.Implementation.t list

  val dispatch
    :  Rpc.Connection.t
    -> Query.t
    -> Response.t Or_error.t Or_error.t Deferred.t
end

module Signal_process : sig
  module Signal_kind : sig
    type t =
      | Term
      | Stop
      | Cont
    [@@deriving sexp]
  end

  module Query : sig
    type t =
      { id : Command_id.t
      ; signal : Signal_kind.t
      }
    [@@deriving sexp, bin_io]
  end

  module Response : sig
    type t = unit Or_error.t [@@deriving sexp, bin_io]
  end

  val implement
    :  ('state -> Query.t -> Response.t Deferred.t)
    -> 'state Rpc.Implementation.t list

  val dispatch : Rpc.Connection.t -> Query.t -> Response.t Or_error.t Deferred.t
end

module Status_update : sig
  module Update : sig
    (** See where we dispatch [Started] updates to read why this is not part of
        [Start_process.Repsonse] *)
    type t =
      | Started of { pid : Pid.t }
      | Stats of { stats : Process_stats.Tree_sample.t }
      | Exited of
          { code : int option
          ; signal : string option
          }
    [@@deriving sexp]
  end

  module Msg : sig
    type t =
      { id : Command_id.t
      ; update : Update.t
      }
    [@@deriving sexp, bin_io]
  end

  val implement : ('state -> Msg.t -> unit) -> 'state Rpc.Implementation.t list
  val dispatch : Rpc.Connection.t -> Msg.t -> unit Or_error.t
end

module Client_log : sig
  module Level : sig
    type t =
      | Debug
      | Error
    [@@deriving sexp]
  end

  module Msg : sig
    type t =
      { level : Level.t
      ; id : Command_id.t option
      ; message : string
      }
    [@@deriving sexp, bin_io]
  end

  val implement : ('state -> Msg.t -> unit) -> 'state Rpc.Implementation.t list
  val dispatch : Rpc.Connection.t -> Msg.t -> unit Or_error.t
end

module Group_status : sig
  module Update : sig
    type t =
      | Output of string
      | Exited_ok
      | Exited_error of string
    [@@deriving sexp]
  end

  module Msg : sig
    type t =
      { id : Command_id.t
      ; update : Update.t
      }
    [@@deriving sexp, bin_io]
  end

  val implement : ('state -> Msg.t -> unit) -> 'state Rpc.Implementation.t list
  val dispatch : Rpc.Connection.t -> Msg.t -> unit Or_error.t
end

module Interactive_session : sig
  module Msg : sig
    type t =
      { id : Command_id.t
      ; session_id_sexp : string
      }
    [@@deriving sexp, bin_io]
  end

  val implement : ('state -> Msg.t -> unit) -> 'state Rpc.Implementation.t list
  val dispatch : Rpc.Connection.t -> Msg.t -> unit Or_error.t
end

(** A [Channel.t] is a point of communication for one or multiple instances of proctopus
    via a unix socket that it creates. It sends requests to the instances on behalf of the
    UI to manage processes and exposes pipes for status updates to be fed into the UI. *)

open! Core
open Async

(** An update for a single (non-group) command, combining status updates, output lines,
    and (for interactive commands) tmux session IDs into a single ordered stream. *)
module Command_update : sig
  type t =
    | Status of Protocol.Status_update.Update.t
    | Output of string list
    | Session of Tmux.Session_id.t
end

(** An entry registered via [entries_ready], paired with a pipe that will carry all
    subsequent updates for that entry. *)
module Entry : sig
  type t =
    | Command of
        { entry : Protocol.Register_commands.Entry.command
        ; updates : Command_update.t Pipe.Reader.t
        }
    | Group of
        { entry : Protocol.Register_commands.Entry.group
        ; updates : Protocol.Group_status.Update.t Pipe.Reader.t
        }
end

type t

(** Start an RPC server that listens for proctopus requests. Creates a Unix socket at a
    path based on XDG_RUNTIME_DIR and current PID. Tracks registered commands and notifies
    via [entries_ready] when new commands are registered. *)
val start : unit -> t Deferred.t

(** Returns the socket path for this channel *)
val socket_path : t -> string

(** Pipe that emits registered entries with their prefix and per-entry update pipes. Each
    command entry carries a [Command_update.t] pipe for status and output; each group
    entry carries a [Group_status.Update.t] pipe. The caller should begin consuming these
    pipes when the entry is announced. *)
val entries_ready : t -> (prefix:Command_id.t * entries:Entry.t list) Pipe.Reader.t

(** Pipe that emits log messages from clients and from the channel itself. *)
val logs : t -> Protocol.Client_log.Msg.t Pipe.Reader.t

(** Dispatch start_process to the client that owns the given id. Creates a FIFO for output
    streaming. All updates (started, output lines, stats, and exit) arrive via the
    per-command pipe provided in [entries_ready].

    The channel internally ensures that the output FIFO is fully drained before surfacing
    the corresponding [Exited] status update, so that trailing output is not reordered
    with respect to the exit event. *)
val dispatch_start_process : t -> id:Command_id.t -> unit Or_error.t Deferred.t

(** Dispatch a signal to the process owned by the client for the given id *)
val dispatch_signal_process
  :  t
  -> id:Command_id.t
  -> signal:Protocol.Signal_process.Signal_kind.t
  -> Protocol.Signal_process.Response.t Deferred.t

(** Clean up the socket file and close server *)
val close : t -> unit Deferred.t

open! Core
open Async

type t

(** Create a new process manager *)
val create : unit -> t

(** Start a process running the given bash code. Returns the pid, separate stdout and
    stderr line pipes, and a deferred for when the process exits. Returns an error if the
    process manager is closed or the process fails to spawn. *)
val start_process
  :  t
  -> env:Core_unix.env
  -> bash_code:string
  -> (Pid.t
     * stdout:string Pipe.Reader.t
     * stderr:string Pipe.Reader.t
     * Unix.Exit_or_signal.t Deferred.t)
       Deferred.Or_error.t

(** Kill a process by PID *)
val kill_process : t -> Pid.t -> unit

(** Pause a process group by sending SIGSTOP *)
val pause_process : t -> Pid.t -> unit

(** Resume a paused process group by sending SIGCONT *)
val resume_process : t -> Pid.t -> unit

(** Sample stats for a process group. Returns None if the process doesn't exist. *)
val sample_process_group : t -> Pid.t -> Process_stats.Tree_sample.t option Deferred.t

(** Shutdown all processes and prevent new ones from spawning *)
val close : t -> unit Deferred.t

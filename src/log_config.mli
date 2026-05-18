(** Configuration for teeing process output to log files on disk.

    When [log_dir] is set, each process's output is written to a file under that directory
    mirroring the command tree structure. For example, a command with id
    ["servers"; "web"] writes to [<log_dir>/servers/web].

    [append] controls whether log files are appended to or truncated when a process
    starts. [split] controls whether stdout and stderr are written to separate files
    ([<path>.stdout] and [<path>.stderr]) or combined into one. *)

open! Core

type t =
  { log_dir : string
  ; append : bool
  ; split : bool
  }
[@@deriving sexp_of]

(** Returns the log file path(s) for a given command id. In split mode, returns separate
    stdout and stderr paths. In combined mode, returns a single path for both. *)
val log_paths
  :  t
  -> Command_id.t
  -> [ `Combined of string | `Split of stdout:string * stderr:string ]

(** Serialize log config to environment variable key-value pairs for passing to child
    processes. *)
val to_env_vars : t -> (string * string) list

(** Deserialize log config from environment variables. Returns [None] if
    [PROCTOPUS_LOG_DIR] is not set. *)
val of_env : unit -> t option

(** Forward stdout and stderr pipes into a single interleaved output pipe, optionally
    teeing each line to log files on disk. Returns the interleaved output pipe and a
    cleanup function that closes any open log writers. *)
val forward_output
  :  t option
  -> id:Command_id.t
  -> stdout:string Async.Pipe.Reader.t
  -> stderr:string Async.Pipe.Reader.t
  -> string Async.Pipe.Reader.t * (unit -> unit Async.Deferred.t)

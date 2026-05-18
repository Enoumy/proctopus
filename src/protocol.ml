open! Core
open Async

(* RPC for child to register commands with parent *)
module Register_commands = struct
  module Entry = struct
    module V1 = struct
      type command =
        { id : Command_id.t
        ; bash_code : string
        ; run_on_start : bool
        ; is_interactive : bool
        }
      [@@deriving bin_io, sexp]

      type group =
        { id : Command_id.t
        ; bash_code : string
        }
      [@@deriving bin_io, sexp]

      type t =
        | Command of command
        | Group of group
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Query = struct
    module V1 = struct
      type t =
        { entries : Entry.V1.t list
        ; prefix : Command_id.t
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Response = struct
    module V1 = struct
      type t = unit Or_error.t [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 =
    Rpc.Rpc.create
      ~name:"proctopus-register-commands"
      ~version:1
      ~bin_query:Query.V1.bin_t
      ~bin_response:Response.V1.bin_t
      ~include_in_error_count:Only_on_exn
  ;;

  let callee = Babel.Callee.Rpc.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr query -> f state query)
  ;;

  let dispatch = Rpc.Rpc.dispatch v1
end

(* RPC to start a process - returns pid on success *)
module Start_process = struct
  module Query = struct
    module V1 = struct
      type t =
        { id : Command_id.t
        ; output_fifo : string
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Response = struct
    module V1 = struct
      type t = unit [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 =
    Rpc.Rpc.create
      ~name:"proctopus-start-process"
      ~version:3
      ~bin_query:Query.V1.bin_t
      ~bin_response:[%bin_type_class: Response.t Or_error.t]
      ~include_in_error_count:Only_on_exn
  ;;

  let callee = Babel.Callee.Rpc.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr query -> f state query)
  ;;

  let dispatch = Rpc.Rpc.dispatch v1
end

(* RPC to send a signal to a process by id *)
module Signal_process = struct
  module Signal_kind = struct
    module V1 = struct
      type t =
        | Term
        | Stop
        | Cont
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Query = struct
    module V1 = struct
      type t =
        { id : Command_id.t
        ; signal : Signal_kind.t
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Response = struct
    module V1 = struct
      type t = unit Or_error.t [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 =
    Rpc.Rpc.create
      ~name:"proctopus-signal-process"
      ~version:1
      ~bin_query:Query.V1.bin_t
      ~bin_response:Response.V1.bin_t
      ~include_in_error_count:Only_on_exn
  ;;

  let callee = Babel.Callee.Rpc.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr query -> f state query)
  ;;

  let dispatch = Rpc.Rpc.dispatch v1
end

(* One-way RPC for clients to send process status updates (stats or exit) *)
module Status_update = struct
  module Update = struct
    module V1 = struct
      type t =
        | Started of { pid : Pid.t }
        | Stats of { stats : Process_stats.Tree_sample.t }
        | Exited of
            { code : int option
            ; signal : string option
            }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Msg = struct
    module V1 = struct
      type t =
        { id : Command_id.t
        ; update : Update.t
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 =
    Rpc.One_way.create ~name:"proctopus-status-update" ~version:1 ~bin_msg:Msg.bin_t
  ;;

  let callee = Babel.Callee.One_way.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr msg -> f state msg)
  ;;

  let dispatch = Rpc.One_way.dispatch v1
end

(* One-way RPC for clients to send log messages with severity levels *)
module Client_log = struct
  module Level = struct
    module V1 = struct
      type t =
        | Debug
        | Error
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Msg = struct
    module V1 = struct
      type t =
        { level : Level.t
        ; id : Command_id.t option
        ; message : string
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 = Rpc.One_way.create ~name:"proctopus-client-log" ~version:1 ~bin_msg:Msg.bin_t
  let callee = Babel.Callee.One_way.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr msg -> f state msg)
  ;;

  let dispatch = Rpc.One_way.dispatch v1
end

(* One-way RPC for reporting group initialization status *)
module Group_status = struct
  module Update = struct
    module V1 = struct
      type t =
        | Output of string
        | Exited_ok
        | Exited_error of string
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  module Msg = struct
    module V1 = struct
      type t =
        { id : Command_id.t
        ; update : Update.t
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 = Rpc.One_way.create ~name:"proctopus-group-status" ~version:1 ~bin_msg:Msg.bin_t
  let callee = Babel.Callee.One_way.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr msg -> f state msg)
  ;;

  let dispatch = Rpc.One_way.dispatch v1
end

(* One-way RPC for clients to report tmux session IDs for interactive commands. The
   session_id is serialized as a sexp string because Tmux.Session_id.t is abstract. *)
module Interactive_session = struct
  module Msg = struct
    module V1 = struct
      type t =
        { id : Command_id.t
        ; session_id_sexp : string
        }
      [@@deriving bin_io, sexp]
    end

    include V1
  end

  let v1 =
    Rpc.One_way.create ~name:"proctopus-interactive-session" ~version:1 ~bin_msg:Msg.bin_t
  ;;

  let callee = Babel.Callee.One_way.singleton v1

  let implement f =
    Babel.Callee.implement_multi_exn callee ~f:(fun state _descr msg -> f state msg)
  ;;

  let dispatch = Rpc.One_way.dispatch v1
end

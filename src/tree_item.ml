open! Core

(* Tree node value - either a section header, a command, or an initializing group *)
type t =
  | Section of string
  | Command of
      { id : Command_id.t
      ; bash_code : string
      ; run_on_start : bool
      ; is_interactive : bool
      }
  | Initializing_group of
      { id : Command_id.t
      ; bash_code : string
      }
[@@deriving sexp, equal]

let name = function
  | Section name -> name
  | Command { id; _ } -> Command_id.display_name id
  | Initializing_group { id; _ } -> Command_id.display_name id
;;

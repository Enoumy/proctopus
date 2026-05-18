open! Core

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

val name : t -> string

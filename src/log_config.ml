open! Core

type t =
  { log_dir : string
  ; append : bool
  ; split : bool
  }
[@@deriving sexp_of]

let log_paths t id =
  let path = t.log_dir ^/ Command_id.to_string id in
  if t.split
  then `Split (~stdout:(path ^ ".stdout"), ~stderr:(path ^ ".stderr"))
  else `Combined path
;;

let env_var_dir = "PROCTOPUS_LOG_DIR"
let env_var_append = "PROCTOPUS_LOG_APPEND"
let env_var_split = "PROCTOPUS_LOG_SPLIT"
let bool_to_env b = if b then "1" else "0"

let bool_of_env var =
  Option.value_map (Sys.getenv var) ~default:false ~f:(fun v -> String.equal v "1")
;;

let to_env_vars t =
  [ env_var_dir, t.log_dir
  ; env_var_append, bool_to_env t.append
  ; env_var_split, bool_to_env t.split
  ]
;;

let of_env () =
  match Sys.getenv env_var_dir with
  | None -> None
  | Some log_dir ->
    let append = bool_of_env env_var_append in
    let split = bool_of_env env_var_split in
    Some { log_dir; append; split }
;;

let open_log_writer ~path ~append =
  Core_unix.mkdir_p (Filename.dirname path);
  Async.Writer.open_file path ~append
;;

(** Forward a pipe into [output_write], optionally also writing each line to [log_writer].
    Returns a deferred that resolves when the pipe is exhausted. *)
let forward_reader pipe ~output_write ~log_writer =
  Async.Pipe.iter_without_pushback pipe ~f:(fun line ->
    Async.Pipe.write_without_pushback_if_open output_write line;
    Option.iter log_writer ~f:(fun writer -> Async.Writer.write_line writer line))
;;

let forward_output log_config ~id ~stdout ~stderr =
  let open Async in
  let output, output_write = Pipe.create () in
  match log_config with
  | None ->
    don't_wait_for
      (let%bind () =
         Deferred.all_unit
           [ forward_reader stdout ~output_write ~log_writer:None
           ; forward_reader stderr ~output_write ~log_writer:None
           ]
       in
       Pipe.close output_write;
       return ());
    output, fun () -> return ()
  | Some log_config ->
    let append = log_config.append in
    (match log_paths log_config id with
     | `Combined path ->
       let forwarding_finished = Ivar.create () in
       don't_wait_for
         (let%bind writer = open_log_writer ~path ~append in
          let log_writer = Some writer in
          let%bind () =
            Deferred.all_unit
              [ forward_reader stdout ~output_write ~log_writer
              ; forward_reader stderr ~output_write ~log_writer
              ]
          in
          Pipe.close output_write;
          let%bind () = Writer.close writer in
          Ivar.fill_exn forwarding_finished ();
          return ());
       output, fun () -> Ivar.read forwarding_finished
     | `Split (~stdout:stdout_path, ~stderr:stderr_path) ->
       let forwarding_finished = Ivar.create () in
       don't_wait_for
         (let%bind stdout_writer = open_log_writer ~path:stdout_path ~append
          and stderr_writer = open_log_writer ~path:stderr_path ~append in
          let%bind () =
            Deferred.all_unit
              [ forward_reader stdout ~output_write ~log_writer:(Some stdout_writer)
              ; forward_reader stderr ~output_write ~log_writer:(Some stderr_writer)
              ]
          in
          Pipe.close output_write;
          let%bind () = Writer.close stdout_writer in
          let%bind () = Writer.close stderr_writer in
          Ivar.fill_exn forwarding_finished ();
          return ());
       output, fun () -> Ivar.read forwarding_finished)
;;

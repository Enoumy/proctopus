open! Core
open! Async

let log_cases
  : (Log.Level.t * [ `String of string | `Sexp of Sexp.t ] * (string * string) list)
      iarray
  =
  [: (* Plain string messages *)
     `Info, `String "Server starting up", []
   ; `Debug, `String "Loading configuration from disk", []
   ; `Info, `String "Health check passed", [] (* String messages with tags *)
   ; `Info, `String "Listening on port 8080", [ "host", "localhost"; "port", "8080" ]
   ; ( `Info
     , `String "Accepted new connection"
     , [ "client", "192.168.1.42"; "connection_id", "conn-001" ] )
     (* Structured sexp messages (as produced by [%log.info "msg" (key : type)]) *)
   ; ( `Debug
     , `Sexp
         [%message
           "Processing request"
             (("GET" : string) : string)
             (("/api/status" : string) : string)]
     , [] )
   ; ( `Info
     , `Sexp
         [%message "Request completed" ~status:("200" : string) ~latency_ms:(42 : int)]
     , [] )
   ; ( `Warn
     , `Sexp [%message "Connection pool running low" ~available:(2 : int) ~max:(50 : int)]
     , [] )
   ; ( `Error
     , `Sexp
         [%message
           "Failed to reach upstream service"
             ~service:("auth" : string)
             ~retries:(3 : int)]
     , [] )
   ; `Debug, `Sexp [%message "Cache miss" ~key:("user:12345" : string)], []
   ; ( `Warn
     , `Sexp
         [%message
           "Disk usage above threshold" ~usage_pct:(87 : int) ~mount:("/data" : string)]
     , [] )
     (* Structured sexp message with tags *)
   ; ( `Info
     , `Sexp [%message "Retrying upstream request" ~attempt:(4 : int)]
     , [ "request_id", "req-42" ] )
  :]
;;

let command =
  Command.async
    ~summary:"Example logger that cycles through log messages, for testing proctopus"
    (let%map_open.Command sexp =
       flag "-sexp" no_arg ~doc:" use sexp log format instead of the default text format"
     in
     fun () ->
       let format = if sexp then `Sexp else `Text in
       let output = Log.Output.stdout ~format () in
       let log = Log.create ~level:`Debug ~output:[ output ] ~on_error:`Raise () in
       let i = ref 0 in
       Clock_ns.every (Time_ns.Span.of_sec 1.0) (fun () ->
         let level, message, tags = log_cases.:(!i) in
         i := (!i + 1) % Iarray.length log_cases;
         Log.message log (Log.Message.create ~level ~tags message));
       Deferred.never ())
;;

let () = Command_unix.run command

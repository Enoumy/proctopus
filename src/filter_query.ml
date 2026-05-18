(** Parsing and evaluation of filter queries.

    A filter query is a space-separated list of tokens. Each token consists of an optional
    list of sigils followed by either a bare word or a double-quoted string.

    Sigils:
    - [!] toggles exclusion: an odd number of [!] means exclude, even means include.
    - [@] means match against the path identifier instead of the log line.

    Quoting:
    - A double-quoted string enables exact (case-sensitive) matching.
    - Within quotes, a backslash before a double-quote produces a literal double-quote (no
      other escapes).
    - A bare word (no quotes) enables case-insensitive substring matching. *)

open! Core

module Token = struct
  type t =
    { path : bool
    ; exclude : bool
    ; exact : bool
    ; content : string
    }
  [@@deriving sexp_of, equal, fields ~getters]
end

let parse_tokens (query : string) : Token.t list =
  let len = String.length query in
  let tokens = ref [] in
  let pos = ref 0 in
  let skip_spaces () =
    while !pos < len && Char.equal (String.get query !pos) ' ' do
      incr pos
    done
  in
  while !pos < len do
    skip_spaces ();
    if !pos >= len
    then ()
    else (
      (* Parse sigils *)
      let bang_count = ref 0 in
      let at_count = ref 0 in
      while
        !pos < len
        &&
        let c = String.get query !pos in
        Char.equal c '!' || Char.equal c '@'
      do
        let c = String.get query !pos in
        if Char.equal c '!' then incr bang_count else incr at_count;
        incr pos
      done;
      if !at_count > 1
      then
        (* Multiple @ sigils: skip this token *)
        while !pos < len && not (Char.equal (String.get query !pos) ' ') do
          incr pos
        done
      else if !pos >= len
      then (* Trailing sigils with no content: ignore *)
        ()
      else (
        let exclude = !bang_count % 2 = 1 in
        let path = !at_count = 1 in
        (* Parse content: quoted string or bare word *)
        if Char.equal (String.get query !pos) '"'
        then (
          (* Quoted string *)
          incr pos;
          let buf = Buffer.create 16 in
          let closed = ref false in
          while !pos < len && not !closed do
            let c = String.get query !pos in
            if Char.equal c '\\'
            then
              if !pos + 1 < len && Char.equal (String.get query (!pos + 1)) '"'
              then (
                Buffer.add_char buf '"';
                pos := !pos + 2)
              else (
                Buffer.add_char buf c;
                incr pos)
            else if Char.equal c '"'
            then (
              closed := true;
              incr pos)
            else (
              Buffer.add_char buf c;
              incr pos)
          done;
          (* Unclosed quotes implicitly close at end of input *)
          tokens
          := { Token.path; exclude; exact = true; content = Buffer.contents buf }
             :: !tokens)
        else (
          (* Bare word: read until space *)
          let start = !pos in
          while !pos < len && not (Char.equal (String.get query !pos) ' ') do
            incr pos
          done;
          let content = String.sub query ~pos:start ~len:(!pos - start) in
          tokens := { Token.path; exclude; exact = false; content } :: !tokens)))
  done;
  List.rev !tokens
;;

(** Evaluate a single token against a line, its path, and its level. Path tokens match
    against the path. Other tokens match against the line or the level. *)
let token_matches (token : Token.t) ~path ~line ~level =
  let is_substring =
    if token.exact then String.is_substring else String.Caseless.is_substring
  in
  if token.path
  then is_substring path ~substring:token.content
  else
    is_substring line ~substring:token.content
    || is_substring level ~substring:token.content
;;

(** Evaluate a parsed filter against a line, its path, and its log level. Returns [true]
    if the line should be shown. An empty token list matches everything. Non-path tokens
    match against both the line and the level.

    A line is shown when all include tokens match AND no exclude token matches. *)
let matches tokens ~path ~level ~line =
  let excludes, includes =
    List.partition_tf tokens ~f:(fun token -> Token.exclude token)
  in
  if List.exists excludes ~f:(fun token -> token_matches token ~path ~line ~level)
  then false
  else List.for_all includes ~f:(fun token -> token_matches token ~path ~line ~level)
;;

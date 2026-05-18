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

module Token : sig
  type t =
    { path : bool
    ; exclude : bool
    ; exact : bool
    ; content : string
    }
  [@@deriving sexp_of, equal]
end

(** Parse a filter query string into a list of tokens. Malformed tokens (multiple [@],
    trailing sigils) are silently skipped. Unclosed quotes implicitly close at end of
    input. *)
val parse_tokens : string -> Token.t list

(** Evaluate a parsed filter against a line, its path, and its log level. Returns [true]
    if the line should be shown. An empty token list matches everything. Non-path tokens
    match against both the line and the level. *)
val matches : Token.t list -> path:string -> level:string -> line:string -> bool

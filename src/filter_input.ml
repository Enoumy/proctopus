(** A simple single-line text input component for filtering. *)

open! Core
open! Bonsai
open! Bonsai_term
open Bonsai.Let_syntax

type t =
  { view : View.t
  ; text : string
  ; handler : Event.t -> unit Effect.t
  ; set_text : string -> unit Effect.t
  }

module Model = struct
  type t =
    { text : string
    ; cursor_pos : int (* 0-based position, can be 0 to String.length text *)
    }
  [@@deriving fields ~getters]

  let empty = { text = ""; cursor_pos = 0 }
  let of_string text = { text; cursor_pos = String.length text }
end

type action =
  | Char of char
  | Backspace
  | Clear
  | Set of string
  | Move_left
  | Move_right
  | Move_to_start
  | Move_to_end

let component ~cursor_attrs ~text_attrs ~is_focused (local_ graph) =
  let model, inject =
    Bonsai.state_machine
      ~default_model:Model.empty
      ~apply_action:(fun _ (model : Model.t) (action : action) ->
        match action with
        | Clear -> Model.empty
        | Backspace ->
          if model.cursor_pos = 0
          then model
          else (
            let before = String.prefix model.text (model.cursor_pos - 1) in
            let after = String.drop_prefix model.text model.cursor_pos in
            { text = before ^ after; cursor_pos = model.cursor_pos - 1 })
        | Char char ->
          let before = String.prefix model.text model.cursor_pos in
          let after = String.drop_prefix model.text model.cursor_pos in
          { text = before ^ Char.to_string char ^ after
          ; cursor_pos = model.cursor_pos + 1
          }
        | Set s -> Model.of_string s
        | Move_left -> { model with cursor_pos = Int.max 0 (model.cursor_pos - 1) }
        | Move_right ->
          { model with
            cursor_pos = Int.min (String.length model.text) (model.cursor_pos + 1)
          }
        | Move_to_start -> { model with cursor_pos = 0 }
        | Move_to_end -> { model with cursor_pos = String.length model.text })
      graph
  in
  let text =
    let%arr model in
    Model.text model
  in
  let set_text =
    let%arr inject in
    fun value -> inject (Set value)
  in
  let handler =
    let%arr inject in
    fun (event : Event.t) ->
      match event with
      | Mouse _ | Paste _ -> Effect.Ignore
      | Key_press { key = ASCII char; mods = [] } -> inject (Char char)
      | Key_press { key = ASCII char; mods = [ Shift ] } ->
        (* Handle Shift+letter the same as letter (char is already uppercase) *)
        inject (Char char)
      | Key_press { key = ASCII ('U' | 'u'); mods = [ Ctrl ] } -> inject Clear
      | Key_press { key = ASCII ('A' | 'a'); mods = [ Ctrl ] } -> inject Move_to_start
      | Key_press { key = ASCII ('E' | 'e'); mods = [ Ctrl ] } -> inject Move_to_end
      | Key_press { key = Backspace; mods = [] } -> inject Backspace
      | Key_press { key = Arrow `Left; mods = [] } -> inject Move_left
      | Key_press { key = Arrow `Right; mods = [] } -> inject Move_right
      | Key_press { key = Home; mods = [] } -> inject Move_to_start
      | Key_press { key = End; mods = [] } -> inject Move_to_end
      | _ -> Effect.Ignore
  in
  let view =
    let%arr model and is_focused and cursor_attrs and text_attrs in
    let before_cursor = String.prefix model.text model.cursor_pos in
    let after_cursor = String.drop_prefix model.text model.cursor_pos in
    let cursor_char, rest =
      if String.is_empty after_cursor
      then " ", ""
      else String.prefix after_cursor 1, String.drop_prefix after_cursor 1
    in
    (* Cursor attrs are layered on top of text attrs so we keep the text styling *)
    let focused_cursor_attrs = text_attrs @ cursor_attrs in
    View.hcat
      [ View.text ~attrs:text_attrs before_cursor
      ; (if is_focused
         then View.text ~attrs:focused_cursor_attrs cursor_char
         else View.text ~attrs:text_attrs cursor_char)
      ; View.text ~attrs:text_attrs rest
      ]
  in
  let%arr text and view and handler and set_text in
  { view; text; handler; set_text }
;;

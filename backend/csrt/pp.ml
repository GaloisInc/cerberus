module CB = Cerb_backend
module CF = Cerb_frontend
include PPrint

(* open Colour *)


let unicode = ref true
let print_debug_level = ref 0


let plain = CF.Pp_utils.to_plain_pretty_string
let (^^^) = Pp_prelude.(^^^)

(* adapting from colour.ml *)
(* https://en.wikipedia.org/wiki/ANSI_escape_code#Colors *)

type colour =
  | Default
  | Black
  | Red
  | Green
  | Yellow
  | Blue
  | Magenta
  | Cyan
  | White

type brightness = 
  | Bright 
  | Dark

type format = 
  | BG of colour * brightness
  | FG of colour * brightness
  | Blinking
  | Underline

let bg_item_code = function
  | Default -> ""
  | Black -> "40"
  | Red -> "41"
  | Green -> "42"
  | Yellow -> "43"
  | Blue -> "44"
  | Magenta -> "45"
  | Cyan -> "46"
  | White -> "47"

let fg_item_code = function
  | Default -> ""
  | Black -> "30"
  | Red -> "31"
  | Green -> "32"
  | Yellow -> "33"
  | Blue -> "34"
  | Magenta -> "35"
  | Cyan -> "36"
  | White -> "37"


let format_item_code = function
  | Blinking -> "5"
  | Underline -> "4"
  | BG (colour,Dark) -> bg_item_code colour
  | BG (colour,Bright) -> bg_item_code colour ^ ";1"
  | FG (colour,Dark) -> fg_item_code colour
  | FG (colour,Bright) -> fg_item_code colour ^ ";1"

(* from colour.ml *)
let format_string format str =
  let code = String.concat ";" (List.map (fun z -> format_item_code z) format) ^ "m" in
  "\x1b[" ^ code ^ str ^ "\x1b[0m"

let format format string = 
  let n = String.length string in
  fancystring (format_string format string) n

let uformat format string n = 
  fancystring (format_string format string) n


let pp_list f l = 
  match l with
  | [] -> !^"(empty)"
  | l -> flow_map (comma ^^ break 1) f l

let typ n typ = n ^^ colon ^^^ typ
let item item content = format [FG(Default,Bright)] item ^^ colon ^^ space ^^ align content

let headline a = 
  (if !print_debug_level >= 2 then hardline else empty) ^^
    format [FG(Magenta,Bright)] ("# " ^ a)

let action a = format [FG (Cyan,Dark)] ("## " ^ a ^ " ")

let p pp = CB.Pipeline.run_pp None (pp ^^ hardline)
let o_p = function
  | None -> ()
  | Some pp -> CB.Pipeline.run_pp None (pp ^^ hardline)
let level l pp = if !print_debug_level >= l then Some (Lazy.force pp) else None
let d l pp = o_p (level l pp)

let error pp = p (format [FG (Red,Bright)] "Error" ^/^ pp ^^ hardline)
let warn pp = p (format [FG (Yellow,Bright)] "Warning:" ^^^ pp)


let time descr f = 
  let t = Unix.gettimeofday () in
  let res = Lazy.force f in
  let t' = Unix.gettimeofday () in
  let () = p (item descr !^(Printf.sprintf "%f" (t' -. t))) in
  res

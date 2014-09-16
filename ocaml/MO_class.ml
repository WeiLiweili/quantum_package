open Core.Std;;
open Qptypes ;;

type t = 
| Core of MO_number.t list
| Inactive of MO_number.t list
| Active of MO_number.t list
| Virtual of MO_number.t list
| Deleted of MO_number.t list
;;


let to_string  x = 
  let print_list l =
    let s = List.map ~f:(fun x-> MO_number.to_int x |> string_of_int )l
      |> (String.concat ~sep:", ")
    in
    "("^s^")"
  in
  
  match x with
  | Core     l ->  "Core : "^(print_list l) 
  | Inactive l ->  "Inactive : "^(print_list l)
  | Active   l ->  "Active : "^(print_list l)
  | Virtual  l ->  "Virtual : "^(print_list l)
  | Deleted  l ->  "Deleted : "^(print_list l)
;;

let _mo_number_list_of_range range = 
 Range.of_string range |> List.map ~f:MO_number.of_int 
;;

let create_core     range = Core     (_mo_number_list_of_range range) ;;
let create_inactive range = Inactive (_mo_number_list_of_range range) ;;
let create_active   range = Active   (_mo_number_list_of_range range) ;;
let create_virtual  range = Virtual  (_mo_number_list_of_range range) ;;
let create_deleted  range = Deleted  (_mo_number_list_of_range range) ;;

let to_bitlist holes particles =
  let mask = Bitlist.of_int64 (Int64.of_int 513) in
  let l = Bitlist.to_mo_number_list mask in
  let i = Inactive l in
  print_string (to_string i)
;;


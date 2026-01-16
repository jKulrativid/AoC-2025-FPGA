open! Core
open Hardcaml

let next_cycle ?(n = 1) sim =
  for _ = 1 to n do
    Cyclesim.cycle sim
  done
;;

let read_input ?(vector_size = 1) file_name =
  In_channel.read_all file_name |> Input_parser.Problem_4.parse ~vector_size
;;

(* TODO: auto-remove whitespaces *)
let concat_test_suite_and_case_name suite_name case_name =
  String.concat ~sep:"-" [ suite_name; case_name ]
;;

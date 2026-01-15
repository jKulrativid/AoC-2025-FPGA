open! Core
open Hardcaml

(* INFO: save .vcd to ~/tmp *)
let get_home () =
  match Sys.getenv "HOME" with
  | Some path -> path
  | None ->
    (match Sys.getenv "USERPROFILE" with
     | Some path -> path
     | None -> ".")
;;

let testdump_dirname = Filename.concat (get_home ()) "/tmp"
let to_vcd_dump file_name = Printf.sprintf "%s/%s.vcd" testdump_dirname file_name

let next_cycle ?(n = 1) sim =
  for _ = 1 to n do
    Cyclesim.cycle sim
  done
;;

let read_input ?(vector_size = 1) file_name =
  In_channel.read_all file_name |> Input_parser.Problem_4.parse ~vector_size
;;

let concat_test_suite_and_case_name suite_name case_name =
  String.concat ~sep:"-" [ suite_name; case_name ]
;;

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

let next_cycle ?(n = 0) sim =
  for _ = 0 to n do
    Cyclesim.cycle sim
  done
;;

let print_reg_by_name sim name =
  match Cyclesim.lookup_reg_by_name sim name with
  | None -> Stdio.print_endline "not found current row"
  | Some r -> Cyclesim.Reg.to_int r |> Int.to_string |> Stdio.print_endline
;;

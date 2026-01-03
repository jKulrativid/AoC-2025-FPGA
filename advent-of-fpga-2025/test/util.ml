open! Base
open Hardcaml

let run_cycle ?(n = 0) sim =
  for _ = 0 to n do
    Cyclesim.cycle sim
  done
;;

let print_reg_by_name sim name =
  match Cyclesim.lookup_reg_by_name sim name with
  | None -> Stdio.print_endline "not found current row"
  | Some r -> Cyclesim.Reg.to_int r |> Int.to_string |> Stdio.print_endline
;;

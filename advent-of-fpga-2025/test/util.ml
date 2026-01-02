open! Base
open Hardcaml

let print_reg_by_name sim name =
  match Cyclesim.lookup_reg_by_name sim name with
  | None -> Stdio.print_endline "not found current row"
  | Some r -> Cyclesim.Reg.to_int r |> Int.to_string |> Stdio.print_endline
;;

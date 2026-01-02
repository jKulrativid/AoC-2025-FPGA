open! Base
open Hardcaml
open Hardcaml_waveterm
open Problem_4
include Util

let%expect_test "Forklift Test" =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let testcases : (int * int * int list) list =
    [ 3, 3, [ 1; 1; 1; 1; 1; 1; 1; 1; 1 ]
    ; 3, 3, [ 1; 0; 1; 1; 1; 0; 0; 1; 1 ]
    ; 3, 3, [ 0; 1; 1; 0; 1; 1; 1; 0; 1 ]
    ; 4, 3, [ 1; 0; 1; 1; 1; 1; 0; 1; 0; 1; 1; 1 ]
    ]
  in
  let run_cycle ?(n = 0) sim =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done
  in
  let run ((rows, cols, stream) : int * int * int list) =
    let waves, sim = Waveform.create @@ Sim.create @@ Forklift.create (Scope.create ()) in
    let i = Cyclesim.inputs sim in
    List.iter stream ~f:(fun din ->
      i.data_in := Bits.of_int din ~width:1;
      i.rows := Bits.of_int rows ~width:Forklift.row_bit_width;
      i.cols := Bits.of_int cols ~width:Forklift.col_bit_width;
      i.clear := Bits.gnd;
      run_cycle sim);
    i.data_in := Bits.of_int zero ~width:1;
    run_cycle ~n:10 sim;
    Waveform.print
      ~display_width:200
      ~display_height:60
      ~display_rules:[ Hardcaml_waveterm.Display_rule.default ]
      waves
  in
  List.iter testcases ~f:run;
  [%expect {| |}]
;;

(*
let%expect_test "Forklift Test" =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let waves, sim =
    Waveform.create
    @@ Sim.create ~config:Cyclesim.Config.trace_all
    @@ Forklift.create (Scope.create ())
  in
  let i = Cyclesim.inputs sim in
  i.clear := Bits.vdd;
  Cyclesim.cycle sim;
  i.clear := Bits.gnd;
  i.rows := Bits.of_int 3 ~width:Forklift.row_bit_width;
  i.cols := Bits.of_int 3 ~width:Forklift.col_bit_width;
  i.clear := Bits.gnd;
  i.data_in := Bits.vdd;
  Cyclesim.cycle sim;
  i.data_in := Bits.vdd;
  Cyclesim.cycle sim;
  i.data_in := Bits.gnd;
  Cyclesim.cycle sim;
  i.data_in := Bits.vdd;
  Cyclesim.cycle sim;
  i.data_in := Bits.vdd;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  match Cyclesim.lookup_node_or_reg_by_name sim "current_row" with
  | None -> Stdio.print_endline "not found :("
  | Some r ->
    Cyclesim.Node.to_int r |> Int.to_string |> Stdio.print_endline;
    Waveform.print ~display_width:200 ~display_height:40 waves;
    [%expect {| |}]
;;
*)

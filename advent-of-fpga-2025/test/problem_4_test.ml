open! Base
open Hardcaml
open Hardcaml_waveterm
open Problem_4
open! Hardcaml_verify
open Input_parser
include Util

let%expect_test "Forklift Test" =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let testcases : (int * int * int list) list =
    (* row, col, data *)
    [ 3, 3, [ 1; 1; 1; 1; 1; 1; 1; 1; 1 ]
    ; 3, 3, [ 1; 0; 1; 1; 1; 0; 0; 1; 1 ]
    ; 3, 3, [ 0; 1; 1; 0; 1; 1; 1; 0; 1 ]
    ; 3, 4, [ 1; 0; 1; 1; 1; 1; 0; 1; 0; 1; 1; 1 ]
    ]
  in
  let run ((rows, cols, stream) : int * int * int list) =
    let waves, sim = Waveform.create @@ Sim.create @@ Forklift.create (Scope.create ()) in
    let i = Cyclesim.inputs sim in
    (* setup config *)
    i.rows := Bits.of_int rows ~width:Forklift.row_bit_width;
    i.cols := Bits.of_int cols ~width:Forklift.col_bit_width;
    i.clear := Bits.gnd;
    i.data_valid := Bits.vdd;
    (*FIXME: test invalid data too *)
    run_cycle sim;
    List.iter stream ~f:(fun din ->
      i.data_in := Bits.of_int din ~width:1;
      run_cycle sim);
    i.data_in := Bits.of_int zero ~width:1;
    run_cycle ~n:10 sim;
    Waveform.print
      ~display_width:200
      ~display_height:30
      ~display_rules:[ Hardcaml_waveterm.Display_rule.default ]
      waves
  in
  List.iter testcases ~f:run;
  [%expect {| |}]
;;

let%expect_test "Forklift AoC Test" =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let _sim = Sim.create @@ Forklift.create (Scope.create ()) in
  ()
;;

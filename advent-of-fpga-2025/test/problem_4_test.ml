open! Core
open Hardcaml
open Hardcaml_waveterm
open Problem_4
open! Hardcaml_verify
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
    i.data_in := Bits.gnd;
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

(* TODO: share this with the above test *)
let run_test_case (test_input : int array array) (expected : int) =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let waves, sim = Waveform.create @@ Sim.create @@ Forklift.create (Scope.create ()) in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  let rec run_cycle_until_last sim =
    let is_last = Bits.to_int !(o.last) in
    if is_last = 1 then
      ()
    else (
      run_cycle sim;
      run_cycle_until_last sim)
  in
  let num_rows = Array.length test_input in
  let num_cols = Array.length test_input.(0) in
  i.rows := Bits.of_int num_rows ~width:Forklift.row_bit_width;
  i.cols := Bits.of_int num_cols ~width:Forklift.col_bit_width;
  i.data_valid := Bits.vdd;
  i.clear := Bits.gnd;
  run_cycle sim;
  Array.iteri test_input ~f:(fun ri r ->
    Array.iteri r ~f:(fun ci c ->
      let ready = Bits.to_int !(o.ready) in
      if ready <> 1 then
        Printf.sprintf
          "the circuit is not ready to take an input at (row, col) of (%d, %d)"
          ri
          ci
        |> failwith;
      i.data_in := Bits.of_int c ~width:1;
      i.data_valid := Bits.vdd;
      run_cycle sim));
  run_cycle_until_last sim;
  let actual = Bits.to_int !(o.removed_paper_count) in
  if expected <> actual then (
    Hardcaml_waveterm.Waveform.print
      ~display_width:200
      ~display_height:30
      ~start_cycle:95
      ~display_rules:[ Hardcaml_waveterm.Display_rule.default ]
      waves;
    Stdio.printf "FAIL: Expected %d, but got %d\n" expected actual)
;;

let%expect_test "Forklift AoC Simple Input" =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let read_input file_name =
    In_channel.read_all file_name |> Input_parser.Problem_4.parse
  in
  let _sim = Sim.create @@ Forklift.create (Scope.create ()) in
  run_test_case (read_input "inputs/day4_test.txt") 13;
  run_test_case (read_input "inputs/day4_real.txt") 1527
;;

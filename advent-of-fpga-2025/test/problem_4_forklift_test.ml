open! Core
open Hardcaml
open Problem_4
open! Hardcaml_verify
module Problem_4_Config = Problem_4.Config
include Util

(* TODO: share this with the above test *)
let run_test_case (suite_name : string) (case_name : string) (test_input : int list list) =
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let oc =
    concat_test_suite_and_case_name suite_name case_name
    |> to_vcd_dump
    |> Out_channel.create
  in
  Exn.protect
    ~f:(fun () ->
      let sim = Vcd.wrap oc @@ Sim.create @@ Forklift.create (Scope.create ()) in
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      let rec run_cycle_until_last_output sim =
        let is_last = Bits.to_int !(o.last_output) in
        if is_last <> 1 then (
          next_cycle sim;
          run_cycle_until_last_output sim)
      in
      let num_rows = List.length test_input in
      let num_cols = List.length @@ List.hd_exn @@ test_input in
      i.rows := Bits.of_int num_rows ~width:Problem_4_Config.row_bit_width;
      i.cols := Bits.of_int num_cols ~width:Problem_4_Config.col_bit_width;
      i.data_valid := Bits.vdd;
      i.clear := Bits.gnd;
      next_cycle sim;
      let feed_input ri ci c =
        let ready = Bits.to_int !(o.ready) in
        if ready <> 1 then
          Printf.sprintf
            "the circuit is not ready to take an input at (row, col) of (%d, %d)"
            ri
            ci
          |> failwith;
        i.data_in := Bits.of_int c ~width:1;
        i.data_valid := Bits.vdd;
        next_cycle sim
      in
      List.iteri test_input ~f:(fun ri r ->
        List.iteri r ~f:(fun ci c -> feed_input ri ci c));
      run_cycle_until_last_output sim;
      let actual = Bits.to_int !(o.removed_paper_count) in
      Stdio.printf "%d\n" actual;
      next_cycle sim (* include last cycle to the .vcd*))
    ~finally:(fun () -> Out_channel.close oc)
;;

(* FIXME: implement formal verification *)

let%expect_test "Forklift Test" =
  let suite_name = "forklift test" in
  let run_test_suite_case = run_test_case suite_name in
  run_test_suite_case "Simple Input 1 (3x3)" [ [ 1; 1; 1 ]; [ 1; 1; 1 ]; [ 1; 1; 1 ] ];
  [%expect {|4|}];
  run_test_suite_case "Simple Input 2 (3x3)" [ [ 0; 1; 1 ]; [ 0; 1; 1 ]; [ 1; 0; 1 ] ];
  [%expect {|4|}];
  run_test_suite_case "Simple Input 4 (3x3)" [ [ 1; 0; 1 ]; [ 1; 1; 0 ]; [ 0; 1; 1 ] ];
  [%expect {|5|}];
  run_test_suite_case
    "Simple Input 3 (3x3)"
    [ [ 1; 0; 1; 1 ]; [ 1; 1; 0; 1 ]; [ 0; 1; 1; 1 ] ];
  [%expect {|6|}];
  run_test_suite_case "AoC Day 4 Test Input (10x10)" (read_input "inputs/day4_test.txt");
  [%expect {|13|}];
  run_test_suite_case "AoC Day 4 Real Input (100x100)" (read_input "inputs/day4_real.txt");
  [%expect {|1527|}]
;;

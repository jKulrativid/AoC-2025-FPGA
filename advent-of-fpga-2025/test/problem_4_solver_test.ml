open! Core
open Hardcaml
open Problem_4
open Hardcaml_waveterm
include Util
module Problem_4_Config = Problem_4.Config

let run_test_case (suite_name : string) (case_name : string) (test_input : int list list) =
  let module Sim = Cyclesim.With_interface (Solver.I) (Solver.O) in
  let oc =
    concat_test_suite_and_case_name suite_name case_name
    |> to_vcd_dump
    |> Out_channel.create
  in
  Exn.protect
    ~f:(fun () ->
      let sim = Vcd.wrap oc @@ Sim.create @@ Solver.create (Scope.create ()) in
      let _waves, sim = Waveform.create sim in
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      let rec _run_until_finished sim =
        if Bits.to_int !(o.finished) <> 1 then (
          next_cycle sim;
          _run_until_finished sim)
      in
      let num_rows = List.length test_input in
      let num_cols = List.length @@ List.hd_exn @@ test_input in
      i.num_rows := Bits.of_int num_rows ~width:Problem_4_Config.row_bit_width;
      i.num_cols := Bits.of_int num_cols ~width:Problem_4_Config.col_bit_width;
      i.data_valid := Bits.vdd;
      i.clear := Bits.gnd;
      next_cycle ~n:2 sim;
      let feed_input c =
        i.data_in := Bits.of_int c ~width:1;
        i.data_valid := Bits.vdd;
        next_cycle sim
      in
      List.iter test_input ~f:(fun r -> List.iter r ~f:(fun c -> feed_input c));
      i.data_in := Bits.gnd;
      i.data_valid := Bits.gnd;
      _run_until_finished sim;
      let actual = Bits.to_int !(o.total_removed_paper_count) in
      Stdio.printf "%d\n" actual;
      (* Waveform.print ~display_width:200 ~display_height:45 ~start_cycle:20 waves *)
      next_cycle sim (* include last cycle to the .vcd*))
    ~finally:(fun () -> Out_channel.close oc)
;;

let%expect_test "AoC Day 4 Test Input (10x10)" =
  let run_test_suite_case = run_test_case "solver test" in
  run_test_suite_case "Simple Input 1 (3x3)" [ [ 0; 1; 1 ]; [ 0; 1; 1 ]; [ 1; 0; 1 ] ];
  [%expect {|6|}];
  run_test_suite_case "Simple Input 2 (3x3)" [ [ 1; 1; 1 ]; [ 1; 1; 1 ]; [ 1; 1; 1 ] ];
  [%expect {|9|}];
  run_test_suite_case "AoC Day 4 Test Input (10x10)" (read_input "inputs/day4_test.txt");
  [%expect {|43|}];
  run_test_suite_case "AoC Day 4 Real Input (100x100)" (read_input "inputs/day4_real.txt");
  [%expect {|8690|}]
;;

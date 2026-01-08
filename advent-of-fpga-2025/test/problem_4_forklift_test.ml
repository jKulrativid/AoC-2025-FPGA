open! Core
open Hardcaml
open Problem_4
open Hardcaml_waveterm
include Util
module Problem_4_Config = Problem_4.Config
module Forklift = Forklift.Make ()

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
      let _waves, sim = Waveform.create sim in
      (* Waveform.print ~display_width:200 ~display_height:45 ~start_cycle:20 waves *)
      next_cycle sim (* include last cycle to the .vcd*))
    ~finally:(fun () -> Out_channel.close oc)
;;

let%expect_test "test forklift" = failwith "TODO:"

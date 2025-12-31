open Base
open Hardcaml
open Exercise

let%expect_test "PWM unit test" =
  let module Sim = Cyclesim.With_interface (Pwm.I) (Pwm.O) in
  let sim = Sim.create Pwm.create in
  let i, o = Cyclesim.inputs sim, Cyclesim.outputs sim in
  let reset_state () =
    i.clear := Bits.one 1;
    Cyclesim.cycle sim;
    i.clear := Bits.zero 1
  in
  let test_cases : (int * int list) list = [ 0, [ 0; 0; 0 ]; 1, [ 1; 0; 0 ] ] in
  let run (duty_cycle, expected_by_clock) =
    i.duty_cycle := Bits.of_int ~width:8 duty_cycle;
    reset_state ();
    List.iteri expected_by_clock ~f:(fun clock_cycle_idx expected_output ->
      let actual_output = Bits.to_int !(o.output) in
      if actual_output <> expected_output then
        Stdio.printf
          "FAIL: DutyCycle=%d Cycle=%d -> Got %d (Expected %d)\n"
          duty_cycle
          clock_cycle_idx
          actual_output
          expected_output;
      Cyclesim.cycle sim)
  in
  List.iter test_cases ~f:(fun tc -> run tc);
  [%expect {| |}]
;;

open! Base
open Hardcaml
open Hardcaml_waveterm

module Adder = struct
  module I = struct
    type 'a t =
      { a : 'a [@bits 8]
      ; b : 'a [@bits 8]
      ; cin : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t =
      { sum : 'a [@bits 8]
      ; cout : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  let create (i : _ I.t) : _ O.t =
    let result = Signal.(uresize i.a 9 +: uresize i.b 9 +: (zero 8 @: i.cin)) in
    { O.sum = Signal.select result 7 0; cout = Signal.select result 8 8 }
  ;;
end

module Circuit = Cyclesim.With_interface (Adder.I) (Adder.O)

let sim = Circuit.create ~config:Cyclesim.Config.trace_all Adder.create
let waves, sim = Waveform.create sim
let i = Cyclesim.inputs sim
let o = Cyclesim.outputs sim

let%expect_test "Adder works correctly" =
  let run ~a ~b ~expected_sum ~expected_cout =
    i.a := Bits.of_int ~width:8 a;
    i.b := Bits.of_int ~width:8 b;
    Cyclesim.cycle sim;
    let actual_sum = Bits.to_int !(o.sum) in
    let actual_cout = Bits.to_int !(o.cout) in
    if expected_sum <> actual_sum || expected_cout <> actual_cout then
      Stdio.printf
        "FAIL: %d + %d = %d cout=%d (Expected %d count=%d)\n"
        a
        b
        actual_sum
        actual_cout
        expected_sum
        expected_cout
    else
      Stdio.printf "success";
    [%expect "success"]
  in
  let test_cases = [ 0, 0, 0, 0; 1, 2, 3, 0 ] in
  List.iter test_cases ~f:(fun (a, b, expected_sum, expected_cout) ->
    run ~a ~b ~expected_sum ~expected_cout)
;;

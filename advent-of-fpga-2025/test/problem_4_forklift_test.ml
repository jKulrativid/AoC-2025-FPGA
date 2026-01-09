open! Core
open Hardcaml
open Problem_4
open Hardcaml_waveterm
include Util
module Problem_4_Config = Problem_4.Config
module Forklift = Forklift.Make ()

let run_test_case (case_name : string) (test_input : int Forklift.Cell.t list list) =
  let open Bits in
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let oc =
    concat_test_suite_and_case_name "" case_name |> to_vcd_dump |> Out_channel.create
  in
  let input_bit_width : int Forklift.Cell.t =
    { d = Forklift.data_bit_width; is_top = 1; is_bottom = 1; is_left = 1; is_right = 1 }
  in
  Exn.protect
    ~f:(fun () ->
      let sim = Vcd.wrap oc @@ Sim.create @@ Forklift.create (Scope.create ()) in
      let waves, sim = Waveform.create sim in
      let i = Cyclesim.inputs sim in
      let _o = Cyclesim.outputs sim in
      i.enable := vdd;
      i.clear := vdd;
      next_cycle sim;
      i.clear := gnd;
      test_input
      |> List.iteri ~f:(fun _ inputs ->
        List.iteri inputs ~f:(fun data_in_idx data_in ->
          let input_signals =
            Forklift.Cell.map2 data_in input_bit_width ~f:(fun v width ->
              Bits.of_int v ~width)
          in
          let hardware_port = i.data_in.(data_in_idx) in
          Forklift.Cell.iter2 hardware_port input_signals ~f:( := ));
        next_cycle sim);
      Array.iter i.data_in ~f:(fun cell ->
        Forklift.Cell.iter2 cell input_bit_width ~f:(fun p width ->
          p := Bits.of_int ~width 0));
      next_cycle sim ~n:Forklift.latency;
      Waveform.print
        ~wave_width:1
        ~signals_width:20
        ~display_width:60
        ~display_height:70
        waves;
      ())
    ~finally:(fun () -> Out_channel.close oc)
;;

let%expect_test "Sliding Window 3x3 Logic" =
  run_test_case
    "all ones"
    [ [ { d = 1; is_top = 1; is_bottom = 0; is_left = 1; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 0; is_left = 1; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 1; is_left = 1; is_right = 0 }
      ]
    ; [ { d = 1; is_top = 1; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 1; is_left = 0; is_right = 0 }
      ]
    ; [ { d = 1; is_top = 1; is_bottom = 0; is_left = 0; is_right = 1 }
      ; { d = 1; is_top = 0; is_bottom = 0; is_left = 0; is_right = 1 }
      ; { d = 1; is_top = 0; is_bottom = 1; is_left = 0; is_right = 1 }
      ]
    ];
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │clear             ││────┐                                 │
    │                  ││    └───────────────────────          │
    │enable            ││────────────────────────────          │
    │                  ││                                      │
    │data_in$d0        ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$d1        ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$d2        ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_bottom0││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_bottom1││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_bottom2││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_left0  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_left1  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_left2  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_right0 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_right1 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_right2 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_top0   ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_top1   ││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_top2   ││                                      │
    │                  ││────────────────────────────          │
    │data_out$d0       ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$d1       ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$d2       ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_bottom││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_bottom││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_bottom││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_left0 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_left1 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_left2 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_right0││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_right1││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_right2││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_top0  ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_top1  ││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_top2  ││                                      │
    │                  ││────────────────────────────          │
    │result            ││                ┌───────────          │
    │                  ││────────────────┘                     │
    └──────────────────┘└──────────────────────────────────────┘
    |}];
  run_test_case
    "diamond shape"
    [ [ { d = 0; is_top = 1; is_bottom = 0; is_left = 1; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 0; is_left = 1; is_right = 0 }
      ; { d = 0; is_top = 0; is_bottom = 1; is_left = 1; is_right = 0 }
      ]
    ; [ { d = 1; is_top = 1; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 1; is_left = 0; is_right = 0 }
      ]
    ; [ { d = 0; is_top = 1; is_bottom = 0; is_left = 0; is_right = 1 }
      ; { d = 1; is_top = 0; is_bottom = 0; is_left = 0; is_right = 1 }
      ; { d = 0; is_top = 0; is_bottom = 1; is_left = 0; is_right = 1 }
      ]
    ];
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │clear             ││────┐                                 │
    │                  ││    └───────────────────────          │
    │enable            ││────────────────────────────          │
    │                  ││                                      │
    │data_in$d0        ││        ┌───┐                         │
    │                  ││────────┘   └───────────────          │
    │data_in$d1        ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$d2        ││        ┌───┐                         │
    │                  ││────────┘   └───────────────          │
    │data_in$is_bottom0││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_bottom1││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_bottom2││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_left0  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_left1  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_left2  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_right0 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_right1 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_right2 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_top0   ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_top1   ││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_top2   ││                                      │
    │                  ││────────────────────────────          │
    │data_out$d0       ││                    ┌───┐             │
    │                  ││────────────────────┘   └───          │
    │data_out$d1       ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$d2       ││                    ┌───┐             │
    │                  ││────────────────────┘   └───          │
    │data_out$is_bottom││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_bottom││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_bottom││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_left0 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_left1 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_left2 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_right0││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_right1││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_right2││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_top0  ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_top1  ││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_top2  ││                                      │
    │                  ││────────────────────────────          │
    │result            ││                    ┌───┐             │
    │                  ││────────────────────┘   └───          │
    └──────────────────┘└──────────────────────────────────────┘
      |}];
  run_test_case
    "3x2 grid"
    [ [ { d = 0; is_top = 0; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 1; is_bottom = 0; is_left = 1; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 1; is_left = 1; is_right = 0 }
      ]
    ; [ { d = 0; is_top = 0; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 1; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 0; is_bottom = 1; is_left = 0; is_right = 0 }
      ]
    ; [ { d = 0; is_top = 0; is_bottom = 0; is_left = 0; is_right = 0 }
      ; { d = 1; is_top = 1; is_bottom = 0; is_left = 0; is_right = 1 }
      ; { d = 0; is_top = 0; is_bottom = 1; is_left = 0; is_right = 1 }
      ]
    ];
  [%expect {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │clear             ││────┐                                 │
    │                  ││    └───────────────────────          │
    │enable            ││────────────────────────────          │
    │                  ││                                      │
    │data_in$d0        ││                                      │
    │                  ││────────────────────────────          │
    │data_in$d1        ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$d2        ││    ┌───────┐                         │
    │                  ││────┘       └───────────────          │
    │data_in$is_bottom0││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_bottom1││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_bottom2││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_left0  ││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_left1  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_left2  ││    ┌───┐                             │
    │                  ││────┘   └───────────────────          │
    │data_in$is_right0 ││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_right1 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_right2 ││            ┌───┐                     │
    │                  ││────────────┘   └───────────          │
    │data_in$is_top0   ││                                      │
    │                  ││────────────────────────────          │
    │data_in$is_top1   ││    ┌───────────┐                     │
    │                  ││────┘           └───────────          │
    │data_in$is_top2   ││                                      │
    │                  ││────────────────────────────          │
    │data_out$d0       ││                                      │
    │                  ││────────────────────────────          │
    │data_out$d1       ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$d2       ││                ┌───────┐             │
    │                  ││────────────────┘       └───          │
    │data_out$is_bottom││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_bottom││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_bottom││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_left0 ││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_left1 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_left2 ││                ┌───┐                 │
    │                  ││────────────────┘   └───────          │
    │data_out$is_right0││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_right1││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_right2││                        ┌───          │
    │                  ││────────────────────────┘             │
    │data_out$is_top0  ││                                      │
    │                  ││────────────────────────────          │
    │data_out$is_top1  ││                ┌───────────          │
    │                  ││────────────────┘                     │
    │data_out$is_top2  ││                                      │
    │                  ││────────────────────────────          │
    │result            ││                    ┌───┐             │
    │                  ││────────────────────┘   └───          │
    └──────────────────┘└──────────────────────────────────────┘
    |}]
;;

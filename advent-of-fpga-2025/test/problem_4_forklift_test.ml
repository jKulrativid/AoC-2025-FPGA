open! Core
open Hardcaml
open Problem_4
open Hardcaml_waveterm
include Util
module Problem_4_Config = Problem_4.Config
module Forklift = Forklift.Make ()

(* TODO: verify that setting enable=0 actually stops the circuit entirely *)

let int_of_binary s =
  String.fold s ~init:0 ~f:(fun acc c ->
    (acc lsl 1)
    +
    if Char.equal c '1' then
      1
    else
      0)
;;

let parse_explicit_grid str =
  let lines =
    String.split_lines str
    |> List.map ~f:String.strip
    |> List.filter ~f:(fun s -> String.length s > 0)
  in
  (* parse header *)
  let row_size, col_size, _bit_width =
    match String.split (List.hd_exn lines) ~on:' ' with
    | [ r; c; b ] -> Int.of_string r, Int.of_string c, Int.of_string b
    | _ -> failwith "Header format must be: 'ROWS COLS BITWIDTH'"
  in
  let grid_lines = List.tl_exn lines in
  (* parse grid *)
  List.map grid_lines ~f:(fun line ->
    let tokens =
      String.split line ~on:' '
      |> List.map ~f:String.strip
      |> List.filter ~f:(fun s -> String.length s > 0)
    in
    List.map tokens ~f:(fun token ->
      match String.lowercase token with
      | "x" ->
        (* do-not-care *)
        { Forklift.Cell.d = 0
        ; valid = 0
        ; last = 0
        ; top = 0
        ; bottom = 0
        ; left = 0
        ; right = 0
        }
      | _ ->
        let parts = String.split token ~on:',' in
        (match parts with
         | [ r_str; c_str; bin_str ] ->
           let r = Int.of_string r_str in
           let c = Int.of_string c_str in
           let d = int_of_binary bin_str in
           { Forklift.Cell.d
           ; valid = 1
           ; last =
               (if r = row_size && c = col_size then
                  1
                else
                  0)
           ; top =
               (if r = 1 then
                  1
                else
                  0)
           ; bottom =
               (if r = row_size then
                  1
                else
                  0)
           ; left =
               (if c = 1 then
                  1
                else
                  0)
           ; right =
               (if c = col_size then
                  1
                else
                  0)
           }
         | _ -> failwith ("invalid token format: " ^ token))))
;;

let run_test_case (case_name : string) (test_input : int Forklift.Cell.t list list) =
  let open Bits in
  let module Sim = Cyclesim.With_interface (Forklift.I) (Forklift.O) in
  let oc =
    concat_test_suite_and_case_name "" case_name |> to_vcd_dump |> Out_channel.create
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
            Forklift.Cell.map2 data_in Forklift.Cell.port_widths ~f:(fun v width ->
              Bits.of_int v ~width)
          in
          let hardware_port = i.data_in.(data_in_idx) in
          Forklift.Cell.iter2 hardware_port input_signals ~f:( := ));
        next_cycle sim);
      Array.iter i.data_in ~f:(fun cell ->
        Forklift.Cell.iter2 cell Forklift.Cell.port_widths ~f:(fun p width ->
          p := Bits.of_int ~width 0));
      next_cycle sim ~n:Forklift.latency;
      Waveform.print
        ~wave_width:1
        ~signals_width:20
        ~display_width:60
        ~display_height:55
        ~display_rules:
          [ Display_rule.port_name_is "clock"
          ; Display_rule.port_name_is "enable"
          ; Display_rule.port_name_is "valid_out"
          ; Display_rule.port_name_matches (Re.Posix.compile_pat "data_in.*d")
          ; Display_rule.port_name_matches (Re.Posix.compile_pat "data_out.*d")
          ; Display_rule.port_name_matches (Re.Posix.compile_pat "result")
          ]
        waves;
      ())
    ~finally:(fun () -> Out_channel.close oc)
;;

let%expect_test "Sliding Window 3x3 Logic (Refactored)" =
  run_test_case
    "all ones"
    (parse_explicit_grid
       {|
        3 3 1
        1,1,1  2,1,1  3,1,1
        1,2,1  2,2,1  3,2,1
        1,3,1  2,3,1  3,3,1
      |});
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────────────────────────────          │
    │enable            ││ 1                                    │
    │                  ││────────────────────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$d0        ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$d1        ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$d2        ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid0    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid1    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid2    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$d0       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$d1       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$d2       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid0   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid1   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid2   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │result$d          ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────────────────          │
    │result$last       ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │result$prev       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │result$valid      ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    └──────────────────┘└──────────────────────────────────────┘
    |}];
  run_test_case
    "diamond shape"
    (parse_explicit_grid
       {|
        3 3 1
        1,1,0  2,1,1  3,1,0
        1,2,1  2,2,1  3,2,1
        1,3,0  2,3,1  3,3,0
      |});
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────────────────────────────          │
    │enable            ││ 1                                    │
    │                  ││────────────────────────────          │
    │                  ││────────┬───┬───────────────          │
    │data_in$d0        ││ 0      │1  │0                        │
    │                  ││────────┴───┴───────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$d1        ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────────┬───┬───────────────          │
    │data_in$d2        ││ 0      │1  │0                        │
    │                  ││────────┴───┴───────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid0    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid1    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid2    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────────────────────┬───┬───          │
    │data_out$d0       ││ 0                  │1  │0            │
    │                  ││────────────────────┴───┴───          │
    │                  ││────────────────┬───────────          │
    │data_out$d1       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────────┬───┬───          │
    │data_out$d2       ││ 0                  │1  │0            │
    │                  ││────────────────────┴───┴───          │
    │                  ││────────────────┬───────────          │
    │data_out$valid0   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid1   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid2   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────────┬───┬───          │
    │result$d          ││ 0                  │1  │0            │
    │                  ││────────────────────┴───┴───          │
    │                  ││────────────────────────────          │
    │result$last       ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │result$prev       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │result$valid      ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    └──────────────────┘└──────────────────────────────────────┘
    |}];
  run_test_case
    "2x3 grid"
    (parse_explicit_grid
       {|
        2 3 1
        x  1,1,1  2,1,1
        x  1,2,1  2,2,1
        x  1,3,1  2,3,0
       |});
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────────────────────────────          │
    │enable            ││ 1                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────────────────          │
    │data_in$d0        ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$d1        ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────┬───────────────          │
    │data_in$d2        ││ 0  │1      │0                        │
    │                  ││────┴───────┴───────────────          │
    │                  ││────────────────────────────          │
    │data_in$valid0    ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid1    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid2    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────────────────────────────          │
    │data_out$d0       ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │data_out$d1       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────┬───          │
    │data_out$d2       ││ 0              │1      │0            │
    │                  ││────────────────┴───────┴───          │
    │                  ││────────────────────────────          │
    │data_out$valid0   ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid1   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid2   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────────┬───┬───          │
    │result$d          ││ 0                  │1  │0            │
    │                  ││────────────────────┴───┴───          │
    │                  ││────────────────────────────          │
    │result$last       ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │result$prev       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │result$valid      ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    └──────────────────┘└──────────────────────────────────────┘
    |}];
  run_test_case
    "2x3 grid but bottom row is at the center row of data_in"
    (parse_explicit_grid
       {|
        2 3 1
        1,1,1  2,1,1  x
        1,2,1  2,2,1  x
        1,3,1  2,3,0  x
      |});
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │                  ││────────────────────────────          │
    │enable            ││ 1                                    │
    │                  ││────────────────────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$d0        ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────┬───────────────          │
    │data_in$d1        ││ 0  │1      │0                        │
    │                  ││────┴───────┴───────────────          │
    │                  ││────────────────────────────          │
    │data_in$d2        ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid0    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────┬───────────┬───────────          │
    │data_in$valid1    ││ 0  │1          │0                    │
    │                  ││────┴───────────┴───────────          │
    │                  ││────────────────────────────          │
    │data_in$valid2    ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │data_out$d0       ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────┬───          │
    │data_out$d1       ││ 0              │1      │0            │
    │                  ││────────────────┴───────┴───          │
    │                  ││────────────────────────────          │
    │data_out$d2       ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid0   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────┬───────────          │
    │data_out$valid1   ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    │                  ││────────────────────────────          │
    │data_out$valid2   ││ 0                                    │
    │                  ││────────────────────────────          │
    │                  ││────────────────────┬───┬───          │
    │result$d          ││ 0                  │1  │0            │
    │                  ││────────────────────┴───┴───          │
    │                  ││────────────────────────┬───          │
    │result$last       ││ 0                      │1            │
    │                  ││────────────────────────┴───          │
    │                  ││────────────────┬───────┬───          │
    │result$prev       ││ 0              │1      │0            │
    │                  ││────────────────┴───────┴───          │
    │                  ││────────────────┬───────────          │
    │result$valid      ││ 0              │1                    │
    │                  ││────────────────┴───────────          │
    └──────────────────┘└──────────────────────────────────────┘
    |}]
;;

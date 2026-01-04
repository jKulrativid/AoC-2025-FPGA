open! Base
open Hardcaml
include Config

module State = struct
  type t =
    | Idle
    | ReadIn
    | ReadCalc
    | CalcRemaining
  [@@deriving compare, enumerate, sexp_of]
end

module I = struct
  type 'a t =
    { data_in : 'a
    ; data_valid : 'a
    ; rows : 'a [@bits row_bit_width]
    ; cols : 'a [@bits col_bit_width]
    ; clock : 'a
    ; clear : 'a
    }
  [@@deriving hardcaml, sexp_of]
end

module O = struct
  type 'a t =
    { ready : 'a
    ; data_out : 'a
    ; valid_out : 'a
      (* valid out now act like 'start'; it won't pause reading input 
        TODO: implement AXI-like tvalid logic
      *)
    ; last : 'a
    ; removed_paper_count : 'a [@bits removed_paper_count_bit_width]
    }
  [@@deriving hardcaml, sexp_of]
end

let get_empty_grid spec =
  let open Signal in
  Array.init 3 ~f:(fun _ ->
    Array.init 3 ~f:(fun col ->
      if col = 2 then
        Always.Variable.wire ~default:gnd
      else
        Always.Variable.reg spec ~width:1))
;;

(* TODO: extract grid logic into a new circuit module *)
let remove_accessible
      (grid : Always.Variable.t array array)
      ~is_top_row
      ~is_bottom_row
      ~is_left_col
      ~is_right_col
  =
  let open Signal in
  let row_mask = [| ~:is_top_row; vdd; ~:is_bottom_row |] in
  let col_mask = [| ~:is_left_col; vdd; ~:is_right_col |] in
  let middle = grid.(1).(1).value in
  let neighbors =
    List.init 3 ~f:(fun ri ->
      List.init 3 ~f:(fun ci ->
        if ri = 1 && ci = 1 then
          []
        else (
          let mask = row_mask.(ri) &: col_mask.(ci) in
          let clean_value = grid.(ri).(ci).value &: mask in
          [ uresize clean_value 4 ])))
    |> List.concat
    |> List.concat
  in
  let neighbors_count = uresize (Signal.concat_msb neighbors |> Signal.popcount) 4 in
  let paper, empty_space = vdd, gnd in
  let is_paper = middle ==:. 1 in
  let is_accessible = neighbors_count <:. 4 in
  mux2 (is_paper &: ~:is_accessible) paper empty_space
;;

let create _scope (inputs : _ I.t) : _ O.t =
  let open Signal in
  let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
  let sm = Always.State_machine.create (module State) spec in
  let num_rows = Always.Variable.reg spec ~width:row_bit_width in
  let num_cols = Always.Variable.reg spec ~width:col_bit_width in
  let reading_row_idx = Always.Variable.reg spec ~width:row_bit_width in
  let reading_col_idx = Always.Variable.reg spec ~width:col_bit_width in
  let processing_row_idx = Always.Variable.reg spec ~width:row_bit_width in
  let processing_col_idx = Always.Variable.reg spec ~width:col_bit_width in
  let offset = Always.Variable.reg spec ~width:col_bit_width in
  let read_addr =
    mux2
      (reading_col_idx.value ==: num_cols.value -:. 1)
      (zero col_bit_width)
      (reading_col_idx.value +:. 1)
  in
  (* outputs *)
  let data_out = Always.Variable.reg spec ~width:1 in
  let valid_out = Always.Variable.reg spec ~width:1 in
  let last = Always.Variable.reg spec ~width:1 in
  let removed_paper_count =
    Always.Variable.reg spec ~width:removed_paper_count_bit_width
  in
  (* events derived from FSM states *)
  let ready = sm.is Idle |: sm.is ReadIn |: sm.is ReadCalc in
  let starting = ready &: inputs.data_valid in
  let running = inputs.data_valid &: ~:(sm.is Idle) in
  let finish_readonly_phase = running &: (offset.value <: num_cols.value) in
  let calculating = running &: (sm.is ReadCalc |: sm.is CalcRemaining) in
  let calculating_last_item =
    calculating
    &: (processing_row_idx.value
        ==: num_rows.value -:. 1
        &: (processing_col_idx.value ==: num_cols.value -:. 1))
  in
  (* TODO: wire this to valid logic *)
  let mid_row_buffer =
    Ram.create
      ~name:"mid_row_buffer"
      ~size:max_row_size
      ~collision_mode:Read_before_write
      ~write_ports:
        [| { write_clock = inputs.clock
           ; write_enable = running
           ; write_address = reading_col_idx.value
           ; write_data = inputs.data_in
           }
        |]
      ~read_ports:
        [| { read_clock = inputs.clock; read_enable = vdd; read_address = read_addr } |]
      ()
  in
  let top_row_buffer =
    Ram.create
      ~name:"top_row_buffer"
      ~size:max_row_size
      ~collision_mode:Read_before_write
      ~write_ports:
        [| { write_clock = inputs.clock
           ; write_enable = running
           ; write_address = reading_col_idx.value
           ; write_data = mid_row_buffer.(0)
           }
        |]
      ~read_ports:
        [| { read_clock = inputs.clock; read_enable = vdd; read_address = read_addr } |]
      ()
  in
  let grid = get_empty_grid spec in
  let is_top_row = processing_row_idx.value ==:. 0 in
  let is_bottom_row = processing_row_idx.value ==: num_rows.value -:. 1 in
  let is_left_col = processing_col_idx.value ==:. 0 in
  let is_right_col = processing_col_idx.value ==: num_cols.value -:. 1 in
  let calculation_result =
    remove_accessible grid ~is_top_row ~is_bottom_row ~is_left_col ~is_right_col
  in
  let reset =
    Always.(
      proc
        [ offset <--. 0
        ; reading_row_idx <--. 0
        ; reading_col_idx <--. 0
        ; processing_row_idx <--. 0
        ; processing_col_idx <--. 0
        ; removed_paper_count <--. 0
        ])
  in
  (* Always DSLs *)
  let datapath_logic =
    let shift_grid =
      let grid_rightmost_values =
        [| top_row_buffer.(0); mid_row_buffer.(0); inputs.data_in |]
      in
      Array.mapi grid ~f:(fun row_idx row ->
        Always.(
          proc
            [ row.(0) <-- row.(1).value
            ; row.(1) <-- row.(2).value
            ; row.(2) <-- grid_rightmost_values.(row_idx)
            ]))
      |> Array.to_list
      |> Always.proc
    in
    let read_in =
      Always.(
        proc
          [ reading_col_idx <-- reading_col_idx.value +:. 1
          ; when_
              (reading_col_idx.value ==: num_cols.value -:. 1)
              [ reading_col_idx <--. 0; reading_row_idx <-- reading_row_idx.value +:. 1 ]
          ])
    in
    let calculate =
      Always.(
        proc
          [ data_out <-- calculation_result
          ; valid_out <--. 1
          ; when_
              (calculation_result ==:. 0 &: (grid.(1).(1).value ==:. 1))
              [ removed_paper_count <-- removed_paper_count.value +:. 1 ]
          ; processing_col_idx <-- processing_col_idx.value +:. 1
          ; when_
              (processing_col_idx.value ==: num_cols.value -:. 1)
              [ processing_col_idx <--. 0
              ; processing_row_idx <-- processing_row_idx.value +:. 1
              ]
          ])
    in
    Always.(
      proc
        [ valid_out <--. 0
        ; when_ starting [ num_rows <-- inputs.rows; num_cols <-- inputs.cols ]
        ; when_ running [ read_in; shift_grid ]
        ; when_ calculating [ calculate ]
        ; if_ (calculating &: calculating_last_item) [ last <--. 1 ] [ last <--. 0 ]
        ])
  in
  let fsm_logic =
    Always.(
      proc
        [ sm.switch
            [ Idle, [ reset; when_ inputs.data_valid [ sm.set_next ReadIn ] ]
            ; ( ReadIn
              , [ if_
                    finish_readonly_phase
                    [ offset <-- offset.value +:. 1 ]
                    [ sm.set_next ReadCalc ]
                ] )
            ; ( ReadCalc
              , [ when_
                    (reading_row_idx.value ==: num_rows.value)
                    [ sm.set_next CalcRemaining ]
                ] )
            ; CalcRemaining, [ when_ calculating_last_item [ sm.set_next Idle ] ]
            ]
        ])
  in
  Always.(compile [ datapath_logic; fsm_logic ]);
  { O.ready
  ; data_out = data_out.value
  ; valid_out = valid_out.value
  ; last = last.value
  ; removed_paper_count = removed_paper_count.value
  }
;;

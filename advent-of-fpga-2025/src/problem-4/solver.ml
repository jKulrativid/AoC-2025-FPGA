open! Base
open Hardcaml

let fifo_size = Config.max_row_size * Config.max_col_size

module State = struct
  type t =
    | Idle
    | Setup (* FIXME:: this handles off-by-one state by forklift *)
    | ReadInput
    | Loop
    | Finished
  [@@deriving compare, enumerate, sexp_of]
end

module I = struct
  type 'a t =
    { num_rows : 'a [@bits Config.row_bit_width]
    ; num_cols : 'a [@bits Config.col_bit_width]
    ; data_in : 'a
    ; data_valid : 'a
    ; clock : 'a
    ; clear : 'a
    }
  [@@deriving hardcaml, sexp_of]
end

module O = struct
  type 'a t =
    { finished : 'a
    ; total_removed_paper_count : 'a [@bits Config.removed_paper_count_bit_width]
    ; dbg_sm : 'a [@bits 3]
    ; dbg_fifo_rd : 'a
    ; dbg_fifo_wr : 'a
    ; dbg_fifo_used : 'a [@bits Config.row_bit_width + Config.col_bit_width]
    ; dbg_fl_ilast : 'a
    ; dbg_fl_olast : 'a
    ; dbg_fl_din : 'a
    ; dbg_fl_vin : 'a
    ; dbg_fl_ready : 'a
    ; dbg_fl_dout : 'a
    ; dbg_fl_vout : 'a
    ; dbg_forklift_rmpaper : 'a [@bits Config.removed_paper_count_bit_width]
    }
  [@@deriving hardcaml, sexp_of]
end

let create _scope (inputs : _ I.t) : _ O.t =
  let open Signal in
  let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
  let sm = Always.State_machine.create (module State) spec in
  let num_rows = Always.Variable.reg spec ~width:Config.row_bit_width in
  let num_cols = Always.Variable.reg spec ~width:Config.col_bit_width in
  let feeding_row_idx = Always.Variable.reg spec ~width:Config.row_bit_width in
  let feeding_col_idx = Always.Variable.reg spec ~width:Config.col_bit_width in
  let total_removed_paper_count =
    Always.Variable.reg spec ~width:Config.removed_paper_count_bit_width
  in
  let forklift_last_output = wire 1 in
  let forklift_removed_paper_count = wire Config.removed_paper_count_bit_width in
  let finish_reading =
    feeding_row_idx.value
    ==: num_rows.value -:. 1
    &: (feeding_col_idx.value ==: num_cols.value -:. 1)
  in
  let setup =
    Always.(
      proc
        [ num_rows <-- inputs.num_rows
        ; num_cols <-- inputs.num_cols
        ; feeding_row_idx <--. 0
        ; feeding_col_idx <--. 0
        ; total_removed_paper_count <--. 0
        ])
  in
  let increment_feeding_position =
    Always.(
      proc
        [ feeding_col_idx <-- feeding_col_idx.value +:. 1
        ; when_
            (feeding_col_idx.value ==: num_cols.value -:. 1)
            [ feeding_col_idx <--. 0; feeding_row_idx <-- feeding_row_idx.value +:. 1 ]
        ])
  in
  Always.(
    compile
      [ sm.switch
          [ Idle, [ when_ inputs.data_valid [ setup; sm.set_next Setup ] ]
          ; Setup, [ if_ finish_reading [ sm.set_next Loop ] [ sm.set_next ReadInput ] ]
          ; ( ReadInput
            , [ when_
                  inputs.data_valid
                  [ if_ finish_reading [ sm.set_next Loop ] [ increment_feeding_position ]
                  ]
              ] )
          ; ( Loop
            , [ when_
                  forklift_last_output
                  [ total_removed_paper_count
                    <-- total_removed_paper_count.value +: forklift_removed_paper_count
                  ; if_
                      (forklift_removed_paper_count ==:. 0)
                      [ sm.set_next Finished ]
                      [ sm.set_next Setup ]
                  ]
              ] )
          ; Finished, [ sm.set_next Idle ]
          ]
      ]);
  let fifo_to_forklift = wire Config.data_bit_width in
  let fifo_valid_to_forklift = wire Config.data_bit_width in
  let forklift_data_in = mux2 (sm.is ReadInput) inputs.data_in fifo_to_forklift in
  let forklift_data_valid =
    mux2
      (sm.is Setup)
      vdd
      (mux2
         (sm.is Loop)
         fifo_valid_to_forklift
         (mux2 (sm.is ReadInput) inputs.data_valid gnd))
  in
  let forklift =
    Forklift.create
      _scope
      { data_in = forklift_data_in
      ; data_valid = forklift_data_valid
      ; rows = num_rows.value
      ; cols = num_cols.value
      ; clock = inputs.clock
      ; clear = inputs.clear
      }
  in
  assign forklift_removed_paper_count forklift.removed_paper_count;
  assign forklift_last_output forklift.last_output;
  let fifo_rd =
    sm.is Setup
    &: finish_reading
    |: (sm.is Loop
        &: forklift.ready
        &: (~:(forklift.last_input) &: ~:(forklift.last_output)))
  in
  let fifo_data_valid = reg spec fifo_rd in
  assign fifo_valid_to_forklift fifo_data_valid;
  let fifo =
    Fifo.create
      ~capacity:fifo_size
      ~clock:inputs.clock
      ~clear:inputs.clear
      ~wr:forklift.valid_out
      ~d:forklift.data_out
      ~rd:fifo_rd
      ()
  in
  assign fifo_to_forklift fifo.q;
  { finished = sm.is Finished
  ; total_removed_paper_count = total_removed_paper_count.value
  ; dbg_sm = sm.current
  ; dbg_fl_ilast = forklift.last_input
  ; dbg_fl_olast = forklift.last_output
  ; dbg_fifo_rd = fifo_rd
  ; dbg_fifo_wr = forklift.valid_out
  ; dbg_fl_ready = forklift.ready
  ; dbg_fifo_used = fifo.used
  ; dbg_fl_din = forklift_data_in
  ; dbg_fl_vin = forklift_data_valid
  ; dbg_fl_dout = forklift.data_out
  ; dbg_fl_vout = forklift.valid_out
  ; dbg_forklift_rmpaper = forklift.removed_paper_count
  }
;;

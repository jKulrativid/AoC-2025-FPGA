open! Base
open Hardcaml

module Make (Sw : Sliding_window_intf.S) = struct
  (* TODO: receive this as params instead *)
  let input_row_bit_width = 16
  let input_col_bit_width = 16
  let data_vector_size = Sw.data_vector_size

  module Wp =
    Window_processor.Make
      (struct
        let input_row_bit_width = input_row_bit_width
        let input_col_bit_width = input_col_bit_width
      end)
      (Sw)

  let fifo_size = Wp.max_input_row_size * Wp.max_input_col_size

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
      { enable : 'a
      ; num_rows : 'a [@bits Wp.input_row_bit_width]
      ; num_cols : 'a [@bits Wp.input_col_bit_width]
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
      ; total_removed_paper_count : 'a [@bits Wp.total_count_bit_width]
      }
    [@@deriving hardcaml, sexp_of]
  end

  let create _scope (inputs : _ I.t) : _ O.t =
    let open Signal in
    let enable = inputs.enable in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let sm = Always.State_machine.create (module State) spec in
    let num_rows = Always.Variable.reg spec ~width:Wp.input_row_bit_width in
    let num_cols = Always.Variable.reg spec ~width:Wp.input_col_bit_width in
    let feeding_row_idx = Always.Variable.reg spec ~width:Wp.input_row_bit_width in
    let feeding_col_idx = Always.Variable.reg spec ~width:Wp.input_col_bit_width in
    let total_removed_paper_count =
      Always.Variable.reg spec ~width:Wp.total_count_bit_width
    in
    let forklift_last_output = wire 1 in
    let forklift_removed_paper_count = wire Wp.total_count_bit_width in
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
                    [ if_
                        finish_reading
                        [ sm.set_next Loop ]
                        [ increment_feeding_position ]
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
    let fifo_to_forklift = wire Wp.data_vector_size in
    let fifo_valid_to_forklift = wire Wp.data_vector_size in
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
      Wp.create
        _scope
        { data_in = forklift_data_in
        ; start = vdd (* TODO *)
        ; enable
        ; data_in_valid = forklift_data_valid
        ; row_size = num_rows.value
        ; col_size = num_cols.value
        ; clock = inputs.clock
        ; clear = inputs.clear
        }
    in
    assign forklift_removed_paper_count forklift.total_count;
    assign forklift_last_output forklift.last;
    let fifo_rd =
      sm.is Setup
      &: finish_reading
      |: (sm.is Loop &: forklift.ready &: (forklift.ready &: ~:(forklift.last)))
    in
    let fifo_data_valid = reg spec fifo_rd in
    assign fifo_valid_to_forklift fifo_data_valid;
    let fifo =
      Fifo.create
        ~capacity:fifo_size
        ~clock:inputs.clock
        ~clear:inputs.clear
        ~wr:forklift.data_out_valid
        ~d:forklift.data_out
        ~rd:fifo_rd
        ()
    in
    assign fifo_to_forklift fifo.q;
    { finished = sm.is Finished
    ; total_removed_paper_count = total_removed_paper_count.value
    }
  ;;
end

open! Base
open Hardcaml

let fifo_size = Config.row_bit_width * Config.col_bit_width

module State = struct
  type t =
    | Idle
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
    { result : 'a
    ; finished : 'a
    ; total_removed_paper_count : 'a [@bits Config.removed_paper_count_bit_width]
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
  let forklift_is_last = wire 1 in
  let forklift_removed_paper_count = wire Config.removed_paper_count_bit_width in
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
  Always.(
    compile
      [ sm.switch
          [ Idle, [ when_ inputs.data_valid [ setup; sm.set_next ReadInput ] ]
          ; ( ReadInput
            , [ when_
                  inputs.data_valid
                  [ feeding_col_idx <-- feeding_col_idx.value +:. 1
                  ; when_
                      (feeding_col_idx.value ==: num_cols.value -:. 1)
                      [ feeding_row_idx <-- feeding_row_idx.value +:. 1 ]
                  ; when_
                      (feeding_row_idx.value
                       ==: num_rows.value -:. 1
                       &: (feeding_col_idx.value ==: num_cols.value -:. 1))
                      [ sm.set_next Loop ]
                  ]
              ] )
          ; ( Loop
            , [ when_
                  forklift_is_last
                  [ total_removed_paper_count
                    <-- total_removed_paper_count.value +: forklift_removed_paper_count
                  ; when_ (forklift_removed_paper_count ==:. 0) [ sm.set_next Finished ]
                  ]
              ] )
          ; Finished, [ sm.set_next Idle ]
          ]
      ]);
  let fifo_to_forklift = wire Config.data_bit_width in
  let forklift =
    Forklift.create
      _scope
      { data_in = mux2 (sm.is ReadInput) inputs.data_in fifo_to_forklift
      ; data_valid =
          mux2
            (sm.is ReadInput)
            inputs.data_valid
            vdd (* TODO: determine if fifo read prev clock *)
      ; rows = num_rows.value
      ; cols = num_cols.value
      ; clock = inputs.clock
      ; clear = inputs.clear
      }
  in
  assign forklift_removed_paper_count forklift.removed_paper_count;
  assign forklift_is_last forklift.last;
  let fifo_wdata = mux2 (sm.is ReadInput) inputs.data_in forklift.data_out in
  let fifo_wr = forklift.valid_out in
  let fifo_rd = forklift.ready in
  let fifo =
    Fifo.create
      ~capacity:fifo_size
      ~clock:inputs.clock
      ~clear:inputs.clear
      ~wr:fifo_wr
      ~d:fifo_wdata
      ~rd:fifo_rd
      ()
  in
  assign fifo_to_forklift fifo.q;
  { result = vdd
  ; finished = sm.is Finished
  ; total_removed_paper_count = total_removed_paper_count.value
  }
;;

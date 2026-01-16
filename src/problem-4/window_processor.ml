open! Base
open Hardcaml

module type Config = sig
  val input_row_bit_width : int
  val input_col_bit_width : int
end

module Make (Cfg : Config) (Sw : Sliding_window_intf.S) = struct
  let input_row_bit_width = Cfg.input_row_bit_width
  let input_col_bit_width = Cfg.input_col_bit_width
  let max_input_row_size = Int.pow 2 Cfg.input_row_bit_width
  let max_input_col_size = Int.pow 2 Cfg.input_col_bit_width
  let total_count_bit_width = Int.ceil_log2 ((max_input_col_size * max_input_row_size) + 1)
  let data_vector_size = Sw.data_vector_size

  module Var = Always.Variable

  module State = struct
    type t =
      | Idle
      | ReadInput
      | Flush
      | Finished
    [@@deriving compare, enumerate, sexp_of]
  end

  module I = struct
    type 'a t =
      { clear : 'a
      ; clock : 'a
      ; col_size : 'a [@bits Cfg.input_col_bit_width]
      ; enable : 'a
      ; data_in : 'a [@bits Sw.data_vector_size]
      ; data_in_valid : 'a
      ; row_size : 'a [@bits Cfg.input_row_bit_width]
      ; start : 'a
      }
    [@@deriving sexp_of, hardcaml ~rtlmangle:"$"]
  end

  module O = struct
    type 'a t =
      { data_out : 'a [@bits Sw.result_bit_width]
      ; data_out_valid : 'a
      ; idle : 'a
      ; last_in : 'a
      ; last_out : 'a
      ; ready : 'a
      ; total_count : 'a [@bits total_count_bit_width]
      }
    [@@deriving sexp_of, hardcaml ~rtlmangle:"$"]
  end

  (** Count bits that is 1 at prev but 0 at current *)
  let count prev current =
    let open Signal in
    let c = prev &: ~:current |> popcount in
    uresize c total_count_bit_width
  ;;

  (** Creates a cascade of Line Buffers (RAMs) to store previous image rows.

      Returns the buffered rows ordered from **Oldest (Top)** to **Newest
      (Bottom-1)**.

      Data Path: [data_in] -> [RAM_N-1] -> ... -> [RAM_0] List Order:
      [ RAM_0; RAM_1; ...; RAM_N-1 ]

      Note: The result does NOT include the current [data_in]. You must append
      it manually. *)
  let create_line_buffers
        ~clock
        ~write_enable
        ~read_enable
        ~reading_col_idx
        ~col_size
        ~(data_in : _ Sw.Cell.t)
        ()
    : _ Sw.Cell.t array
    =
    let open Signal in
    let total_ram_count = Sw.kernel_row_size - 1 in
    let wptr = reading_col_idx in
    let rptr =
      mux2
        (reading_col_idx +:. 1 <: col_size)
        (reading_col_idx +:. 1)
        (zero Cfg.input_col_bit_width)
    in
    let create_ram (wd_cell : _ Sw.Cell.t) : _ Sw.Cell.t =
      let wd = Sw.Cell.Of_signal.pack wd_cell in
      let r =
        Ram.create
          ~collision_mode:Write_before_read
          ~size:max_input_col_size
          ~write_ports:
            [| { write_clock = clock
               ; write_data = wd
               ; write_enable
               ; write_address = wptr
               }
            |]
          ~read_ports:[| { read_clock = clock; read_enable; read_address = rptr } |]
          ()
      in
      let rd = r.(0) in
      Sw.Cell.Of_signal.unpack rd
    in
    Fn.apply_n_times
      ~n:total_ram_count
      (fun (ram_rd_acc, prev_rd) ->
         let ram_rd = create_ram prev_rd in
         ram_rd :: ram_rd_acc, ram_rd)
      ([], data_in)
    |> fst
    |> Array.of_list
  ;;

  let create scope (inputs : _ I.t) : _ O.t =
    let open Signal in
    let enable = inputs.enable in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let sm = Always.State_machine.create ~enable (module State) spec in
    let idle = mux2 (sm.is Idle) vdd gnd in
    let ready = mux2 (sm.is ReadInput) vdd gnd in
    let row_size = Var.reg spec ~enable ~width:Cfg.input_row_bit_width in
    let col_size = Var.reg spec ~enable ~width:Cfg.input_col_bit_width in
    let reading_row_idx = Var.reg spec ~enable ~width:Cfg.input_row_bit_width in
    let reading_col_idx = Var.reg spec ~enable ~width:Cfg.input_col_bit_width in
    let next_row_idx = reading_row_idx.value +:. 1 in
    let next_col_idx = reading_col_idx.value +:. 1 in
    let reading_col_idx_at_last_col = next_col_idx ==: col_size.value in
    let last_input =
      reading_row_idx.value +:. 1
      ==: row_size.value
      &: (reading_col_idx.value +:. 1 ==: col_size.value)
    in
    let result_from_sliding_window = Sw.Result.map Sw.Result.port_widths ~f:wire in
    let result_count =
      count result_from_sliding_window.prev result_from_sliding_window.d
    in
    let total_count = Var.reg spec ~enable ~width:total_count_bit_width in
    Always.(
      let update_read_idx =
        proc
          [ reading_col_idx <-- next_col_idx
          ; when_
              reading_col_idx_at_last_col
              [ reading_col_idx <--. 0; reading_row_idx <-- next_row_idx ]
          ]
      in
      let count =
        proc
          [ when_
              result_from_sliding_window.valid
              [ total_count <-- total_count.value +: result_count ]
          ]
      in
      let reset =
        proc [ total_count <--. 0; reading_row_idx <--. 0; reading_col_idx <--. 0 ]
      in
      compile
        [ sm.switch
            [ ( Idle
              , [ when_
                    inputs.start
                    [ reset
                    ; row_size <-- inputs.row_size
                    ; col_size <-- inputs.col_size
                    ; sm.set_next ReadInput
                    ]
                ] )
            ; ( ReadInput
              , [ when_
                    inputs.data_in_valid
                    [ update_read_idx; count; when_ last_input [ sm.set_next Flush ] ]
                ] )
            ; ( Flush
              , [ update_read_idx
                ; count
                ; when_ result_from_sliding_window.last [ sm.set_next Finished ]
                ] )
            ; Finished, [ sm.set_next Idle ]
            ]
        ]);
    let write_enable = enable &: (sm.is ReadInput |: sm.is Flush) in
    let read_enable = enable &: (sm.is ReadInput |: sm.is Flush) in
    let data_in_cell =
      { Sw.Cell.d = inputs.data_in
      ; valid = inputs.data_in_valid
      ; last = last_input
      ; top = reading_row_idx.value ==:. 0
      ; bottom = reading_row_idx.value +:. 1 ==: row_size.value
      ; left = reading_col_idx.value ==:. 0
      ; right = reading_col_idx.value +:. 1 ==: col_size.value
      }
    in
    let buffered_rows =
      create_line_buffers
        ~clock:inputs.clock
        ~write_enable
        ~read_enable
        ~reading_col_idx:reading_col_idx.value
        ~col_size:col_size.value
        ~data_in:data_in_cell
        ()
    in
    let data_in = Array.(append buffered_rows (of_list [ data_in_cell ])) in
    let sliding_window =
      Sw.create scope { Sw.I.clear = inputs.clear; clock = inputs.clock; enable; data_in }
    in
    Sw.Result.iter2 result_from_sliding_window sliding_window.result ~f:assign;
    let masked_result
          (* Output Guarding:
       We mask the output with 'idle' to ensure that 'valid' and 'last' 
       snap to 0 immediately when the FSM finishes, preventing the 
       last value from sticking on the wires during the Idle state. *)
      =
      Sw.Result.map sliding_window.result ~f:(fun s ->
        reg spec ~enable s |> mux2 idle (zero (width s)))
    in
    { data_out = masked_result.d
    ; data_out_valid = masked_result.valid
    ; idle
    ; last_in = last_input
    ; last_out = masked_result.last
    ; ready
    ; total_count = total_count.value
    }
  ;;

  let hierarchical scope (input : Signal.t I.t) =
    let module H = Hierarchy.In_scope (I) (O) in
    H.create ~scope ~name:"window_processor" create input
  ;;
end

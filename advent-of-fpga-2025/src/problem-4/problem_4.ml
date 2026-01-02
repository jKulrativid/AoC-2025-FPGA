open! Base
open Hardcaml

let () = Caller_id.set_mode Full_trace

(* 
   Implements the "Forklift" logic from Advent of Code (Day 4).
   Filters the grid to remove accessible paper rolls based on the problem specification.
*)
module Forklift = struct
  let max_row_size = 128
  let row_bit_width = Int.ceil_log2 max_row_size
  let col_bit_width = row_bit_width
  let offset_bit_width = col_bit_width + 1
  let window_size = 3

  module State = struct
    type t =
      | Idle
      | Thinking
    [@@deriving compare, enumerate, sexp_of]
  end

  module Thinking_phase = struct
    type t =
      | Lead_in
      | Fetch_calc
      | Calc
    [@@deriving compare, enumerate, sexp_of]
  end

  module I = struct
    type 'a t =
      { data_in : 'a
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
      ; last : 'a
      ; removed_paper_count : 'a (* valid only last=true *)
      ; dbg_grid : 'a array [@length 9]
      ; dbg_mid_row_rdata : 'a
      ; dbg_current_row : 'a [@bits row_bit_width]
      ; dbg_current_col : 'a [@bits col_bit_width]
      ; dbg_read_addr : 'a [@bits col_bit_width]
      ; dbg_offset : 'a [@bits offset_bit_width]
      ; dbg_is : 'a [@bits 4]
      ; dbg_neighbor_count : 'a [@bits 4]
      ; dbg_processing_row : 'a [@bits row_bit_width]
      ; dbg_processing_col : 'a [@bits col_bit_width]
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

  let remove_accessible
        (grid : Always.Variable.t array array)
        ~is_top_row
        ~is_bottom_row
        ~is_left_col
        ~is_right_col
    =
    (* TODO: maybe this can be readable *)
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
    (* let neighbors_count = List.reduce_exn neighbors ~f:( +: ) in *)
    let paper, empty_space = vdd, gnd in
    let is_paper = middle ==:. 1 in
    let is_accessible = neighbors_count <:. 4 in
    mux2 (is_paper &: ~:is_accessible) paper empty_space, neighbors_count
  ;;

  (*let create I.{ data_in; rows; cols; clock; clear } =*)
  let create _ (inputs : _ I.t) =
    let open Signal in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let reading_row_idx = Always.Variable.reg spec ~width:row_bit_width in
    let reading_col_idx = Always.Variable.reg spec ~width:col_bit_width in
    let processing_row_idx = Always.Variable.reg spec ~width:row_bit_width in
    let processing_col_idx = Always.Variable.reg spec ~width:col_bit_width in
    let processing_result = Always.Variable.wire ~default:gnd in
    let dbg_neighbors_count =
      Always.Variable.wire ~default:(zero 4)
      (* TODO: remove this *)
    in
    let offset = Always.Variable.reg spec ~width:offset_bit_width in
    let read_addr =
      mux2
        (reading_col_idx.value ==: inputs.cols -:. 1)
        (zero col_bit_width)
        (reading_col_idx.value +:. 1)
    in
    (* TODO: wire this to valid logic *)
    (* init mid row buffer *)
    let mid_row_buffer =
      Ram.create
        ~name:"mid_row_buffer"
        ~size:max_row_size
        ~collision_mode:Read_before_write
        ~write_ports:
          [| { write_clock = inputs.clock
             ; write_enable = vdd (* TODO: don't write if input is invalid *)
             ; write_address = reading_col_idx.value
             ; write_data = inputs.data_in
             }
          |]
        ~read_ports:
          [| { read_clock = inputs.clock; read_enable = vdd; read_address = read_addr } |]
        ()
    in
    (* init top row buffer *)
    let top_row_buffer =
      Ram.create
        ~name:"top_row_buffer"
        ~size:max_row_size
        ~collision_mode:Read_before_write
        ~write_ports:
          [| { write_clock = inputs.clock
             ; write_enable = vdd (* TODO: don't write if input is invalid *)
             ; write_address = reading_col_idx.value
             ; write_data = mid_row_buffer.(0)
             }
          |]
        ~read_ports:
          [| { read_clock = inputs.clock; read_enable = vdd; read_address = read_addr } |]
        ()
    in
    let grid = get_empty_grid spec in
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
    let is_top_row = processing_row_idx.value ==:. 0 in
    let is_bottom_row = processing_row_idx.value ==: inputs.rows -:. 1 in
    let is_left_col = processing_col_idx.value ==:. 0 in
    let is_right_col = processing_col_idx.value ==: inputs.cols -:. 1 in
    let pr, nc =
      remove_accessible grid ~is_top_row ~is_bottom_row ~is_left_col ~is_right_col
    in
    Always.(
      compile
        [ proc
            [ if_
                ((* TODO: refactor this magic *)
                 offset.value
                 <: uresize inputs.cols offset_bit_width +:. 1)
                [ offset <-- offset.value +:. 1 ]
                [ proc [ processing_result <-- pr; dbg_neighbors_count <-- nc ]
                ; proc
                    [ processing_col_idx <-- processing_col_idx.value +:. 1
                    ; when_
                        (processing_col_idx.value ==: inputs.cols -:. 1)
                        [ processing_col_idx <--. 0
                        ; processing_row_idx <-- processing_row_idx.value +:. 1
                        ; when_
                            (processing_row_idx.value ==: inputs.rows -:. 1)
                            [ processing_row_idx <--. 0 ]
                        ]
                    ]
                ]
            ]
        ; proc
            [ reading_col_idx <-- reading_col_idx.value +:. 1
            ; when_
                (reading_col_idx.value ==: inputs.cols -:. 1)
                [ reading_col_idx <--. 0
                ; reading_row_idx <-- reading_row_idx.value +:. 1
                ; when_
                    (reading_row_idx.value ==: inputs.rows -:. 1)
                    [ (* finish reading *) ]
                ]
            ]
        ; shift_grid
        ]);
    { O.ready = vdd
    ; data_out = processing_result.value
    ; valid_out = vdd
    ; last = vdd
    ; removed_paper_count = vdd
    ; dbg_grid =
        Array.concat_map grid ~f:(fun cols -> Array.map cols ~f:(fun r -> r.value))
    ; dbg_mid_row_rdata = mid_row_buffer.(0)
    ; dbg_current_row = reading_row_idx.value
    ; dbg_current_col = reading_col_idx.value
    ; dbg_read_addr = read_addr
    ; dbg_offset = offset.value
    ; dbg_is = is_top_row @: is_bottom_row @: is_left_col @: is_right_col
    ; dbg_neighbor_count = dbg_neighbors_count.value
    ; dbg_processing_row = processing_row_idx.value
    ; dbg_processing_col = processing_col_idx.value
    }
  ;;
end

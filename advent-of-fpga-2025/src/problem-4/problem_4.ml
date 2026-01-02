open! Base
open Hardcaml

let () = Caller_id.set_mode Full_trace

module AccessiblePaperRollMarker = struct
  module I = struct
    type 'a t = { grid : 'a array [@length 9] } [@@deriving hardcaml, sexp_of]
  end

  module O = struct
    type 'a t = { result : 'a } [@@deriving hardcaml, sexp_of]
  end

  let calc_bit_size = 4

  let create { I.grid } : _ O.t =
    let open Signal in
    let extended_width_grid =
      Array.map grid ~f:(fun item -> uresize item calc_bit_size)
    in
    let paper_count = Array.reduce_exn extended_width_grid ~f:( +: ) in
    O.{ result = paper_count <: of_int ~width:calc_bit_size 4 }
  ;;
end

(* I name it "Forklift" since it does what the forklift does, removing accessible papers. *)
module Forklift = struct
  let max_row_size = 128
  let row_bit_width = Int.ceil_log2 max_row_size
  let col_bit_width = row_bit_width
  let window_size = 3

  module State = struct
    type t =
      | Idle
      | Thinking
        (* rename from "busy" to "thinking", making this block agentic-AI but my thinking is real-time :) *)
    [@@deriving compare ~localize, enumerate]
  end

  module StreamPhase = struct
    type t =
      | LeadIn
      | SteadyState
      | LeadOut
    [@@deriving compare ~localize, enumerate]
  end

  module I = struct
    type 'a t =
      { data_in : 'a
      ; rows : 'a [@bits row_bit_width]
      ; cols : 'a [@bits col_bit_width]
      ; clock : 'a
      ; clear : 'a
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { ready : 'a
      ; data_out : 'a
      ; valid_out : 'a
      ; last : 'a
      ; removed_paper_count : 'a (* valid only last=true *)
      ; dbg_grid : 'a array [@length 8]
      ; dbg_mid_row_rdata : 'a
      ; dbg_current_row : 'a [@bits row_bit_width]
      ; dbg_current_col : 'a [@bits col_bit_width]
      ; dbg_read_addr : 'a [@bits col_bit_width]
      }
    [@@deriving hardcaml]
  end

  let remove_accessible (grid : Always.Variable.t array array) data_in =
    (* FIXME: must handle the edge gracefully *)
    let open Signal in
    let middle = grid.(1).(1).value in
    let neighbor_papers =
      List.reduce_exn
        [ uresize grid.(0).(0).value 4
        ; uresize grid.(0).(1).value 4
        ; uresize grid.(0).(2).value 4
        ; uresize grid.(1).(0).value 4
        ; uresize grid.(1).(2).value 4
        ; uresize grid.(2).(0).value 4
        ; uresize grid.(2).(1).value 4
        ; uresize data_in 4
        ]
        ~f:( +: )
    in
    mux2 (middle ==:. 0) gnd (mux2 (neighbor_papers <:. 4) gnd vdd)
  ;;

  let wrapup_wire x n = Signal.(mux2 (x >: n) (zero col_bit_width) x)

  (*let create I.{ data_in; rows; cols; clock; clear } =*)
  let create _ (inputs : _ I.t) =
    let open Signal in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let current_row = Always.Variable.reg spec ~width:row_bit_width in
    let current_col = Always.Variable.reg spec ~width:col_bit_width in
    let read_addr = wrapup_wire (current_col.value +:. 1) (inputs.cols -:. 1) in
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
             ; write_address = current_col.value
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
             ; write_address = current_col.value
             ; write_data = mid_row_buffer.(0)
             }
          |]
        ~read_ports:
          [| { read_clock = inputs.clock; read_enable = vdd; read_address = read_addr } |]
        ()
    in
    (* calculation goes here *)
    let grid =
      Array.init 3 ~f:(fun ri ->
        (* FIXME: hardcode the generated instead, would be more explicit *)
        let rows =
          if ri <> 2 then
            3
          else
            2
        in
        Array.init rows ~f:(fun _ -> Always.Variable.reg spec ~width:1))
    in
    let shift_grid =
      Always.(
        proc
          [ grid.(0).(0) <-- grid.(0).(1).value
          ; grid.(1).(0) <-- grid.(1).(1).value
          ; grid.(2).(0) <-- grid.(2).(1).value
          ; grid.(0).(1) <-- grid.(0).(2).value
          ; grid.(1).(1) <-- grid.(1).(2).value
          ; grid.(2).(1) <-- inputs.data_in
            (* 
               TODO: handle data_in reading if this is valid or not, 
              or the grid should not be shifted
              if the input data is not valid
            *)
          ; grid.(0).(2) <-- top_row_buffer.(0)
          ; grid.(1).(2) <-- mid_row_buffer.(0)
          ])
    in
    Always.(
      compile
        [ current_row <-- current_row.value +:. 1
        ; current_col <-- current_col.value +:. 1
        ; when_ (current_row.value ==: inputs.rows -:. 1) [ current_row <--. 0 ]
        ; when_ (current_col.value ==: inputs.cols -:. 1) [ current_col <--. 0 ]
        ; shift_grid
        ]);
    { O.ready = vdd
    ; data_out = remove_accessible grid inputs.data_in
    ; valid_out = vdd
    ; last = vdd
    ; removed_paper_count = vdd
    ; dbg_grid =
        Array.concat_map grid ~f:(fun cols -> Array.map cols ~f:(fun r -> r.value))
    ; dbg_mid_row_rdata = mid_row_buffer.(0)
    ; dbg_current_row = current_row.value
    ; dbg_current_col = current_col.value
    ; dbg_read_addr = read_addr
    }
  ;;
end

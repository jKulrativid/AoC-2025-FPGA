open! Base
open Hardcaml

module type S = Sliding_window_intf.S

module Make () : S = struct
  let kernel_row_size = 3
  let kernel_col_size = 3
  let data_bit_width = 1 (* TODO: this should be configurable to support vectorization *)
  let result_bit_width = 1
  let latency = 3 (* TODO: explain how you derive this number *)

  let neighbors_count_bit_width =
    kernel_row_size + kernel_col_size (* TODO: can be less *)
  ;;

  (* Grid-related variables *)
  let grid_middle_row_idx = (kernel_row_size - 1) / 2
  let grid_last_row_idx = kernel_row_size - 1
  let grid_middle_col_idx = (kernel_col_size - 1) / 2
  let grid_last_col_idx = kernel_col_size - 1

  module Cell = struct
    type 'a t =
      { d : 'a [@bits data_bit_width]
      ; is_top : 'a
      ; is_bottom : 'a
      ; is_left : 'a
      ; is_right : 'a
      }
    [@@deriving sexp_of, hardcaml ~rtlmangle:"$"]
  end

  module I = struct
    type 'a t =
      { clear : 'a
      ; clock : 'a
      ; data_in : 'a Cell.t array [@length kernel_row_size]
      ; enable : 'a
      }
    [@@deriving sexp_of, hardcaml ~rtlmangle:"$"]
  end

  module O = struct
    type 'a t =
      { data_out : 'a Cell.t array [@length kernel_row_size]
      ; result : 'a [@bits result_bit_width]
      }
    [@@deriving sexp_of, hardcaml ~rtlmangle:"$"]
  end

  let create_grid (spec : Reg_spec.t) ~(enable : _) ~(data_in : _ Cell.t array)
    : _ Cell.t array array
    =
    let create_reg = Signal.reg spec ~enable in
    let create_row_fn iwire =
      List.fold
        (List.init kernel_col_size ~f:Fn.id)
        ~init:(iwire, [])
        ~f:(fun (prev_wire, acc_arr) _ ->
          let current_reg = Cell.map prev_wire ~f:create_reg in
          current_reg, current_reg :: acc_arr)
      |> snd
      |> Array.of_list
    in
    Array.map data_in ~f:create_row_fn
  ;;

  let create_mask (middle : _ Cell.t) =
    let open Signal in
    let row_mask =
      Array.init kernel_row_size ~f:(fun ri ->
        if ri = 0 then
          ~:(middle.is_top)
        else if ri = grid_last_row_idx then
          ~:(middle.is_bottom)
        else
          vdd)
    in
    let col_mask =
      Array.init kernel_col_size ~f:(fun ri ->
        if ri = 0 then
          ~:(middle.is_left)
        else if ri = grid_last_col_idx then
          ~:(middle.is_right)
        else
          vdd)
    in
    Array.mapi row_mask ~f:(fun ri r ->
      Array.mapi col_mask ~f:(fun ci c ->
        if ri = grid_middle_row_idx && ci = grid_middle_col_idx then
          gnd
        else
          r &: c))
  ;;

  (* modify calculatin here *)
  let calculate ~(grid : _ Cell.t array array) =
    let open Signal in
    let middle = grid.(grid_middle_row_idx).(grid_middle_col_idx) in
    let grid_mask = create_mask middle in
    let count_col_neighbors_fn (c : _ array) : _ =
      c
      |> List.of_array
      |> List.map ~f:(fun binary -> uresize binary neighbors_count_bit_width)
      |> tree ~arity:2 ~f:(List.reduce_exn ~f:( +: ))
    in
    let masked_grid =
      Array.map2_exn grid grid_mask ~f:(fun r row_masks ->
        Array.map2_exn r row_masks ~f:(fun cell cell_mask -> cell_mask &: cell.d))
    in
    let neighbors_count =
      masked_grid
      |> List.of_array
      |> List.map ~f:count_col_neighbors_fn
      |> tree ~arity:2 ~f:(fun r -> r |> List.reduce_exn ~f:( +: ))
      (* |> ( -: ) (uresize middle.d neighbors_count_bit_width) *)
      (* sub out middle item *)
    in
    let is_accessible = neighbors_count <:. 4 in
    middle.d &: ~:is_accessible
  ;;

  let create _scope (inputs : _ I.t) : _ O.t =
    let open Signal in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let grid = create_grid spec ~enable:inputs.enable ~data_in:inputs.data_in in
    let data_out = Array.map grid ~f:(fun r -> r.(0)) in
    let result = reg spec ~enable:inputs.enable (calculate ~grid) in
    { O.data_out; result }
  ;;
end

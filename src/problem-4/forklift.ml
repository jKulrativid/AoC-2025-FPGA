open! Base
open Hardcaml

module type S = Sliding_window_intf.S

module Make (Cfg : Sliding_window_intf.Config) : S = struct
  let kernel_row_size = 3
  let kernel_col_size = 3
  let data_vector_size = Cfg.data_vector_size
  let result_bit_width = Cfg.data_vector_size

  let latency =
    let regs_between_input_to_middle_count = (kernel_col_size + 1) / 2 in
    let output_register = 1 in
    regs_between_input_to_middle_count + output_register
  ;;

  (* Grid-related variables *)
  let grid_middle_row_idx = (kernel_row_size - 1) / 2
  let grid_last_row_idx = kernel_row_size - 1
  let grid_middle_col_idx = (kernel_col_size - 1) / 2
  let grid_last_col_idx = kernel_col_size - 1

  module Cell = struct
    type 'a t =
      { d : 'a [@bits data_vector_size]
      ; last : 'a
      ; valid : 'a
      ; top : 'a
      ; bottom : 'a
      ; left : 'a
      ; right : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  module Result = struct
    type 'a t =
      { prev : 'a [@bits data_vector_size]
      ; d : 'a [@bits result_bit_width]
      ; last : 'a
      ; valid : 'a
      }
    [@@deriving sexp_of, hardcaml]
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
      ; result : 'a Result.t
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
    let all_ones = ones data_vector_size in
    let all_zeros = zero data_vector_size in
    let row_mask =
      Array.init kernel_row_size ~f:(fun ri ->
        if ri = 0 then
          mux2 middle.top all_zeros all_ones
        else if ri = grid_last_row_idx then
          mux2 middle.bottom all_zeros all_ones
        else
          all_ones)
    in
    let col_mask =
      Array.init kernel_col_size ~f:(fun ci ->
        if ci = 0 then
          mux2 middle.left all_zeros all_ones
        else if ci = grid_last_col_idx then
          mux2 middle.right all_zeros all_ones
        else
          all_ones)
    in
    Array.map row_mask ~f:(fun r -> Array.map col_mask ~f:(fun c -> r &: c))
  ;;

  (* modify calculatin here *)
  let calculate ~(grid : _ Cell.t array array) : _ Result.t =
    let open Signal in
    let middle = grid.(grid_middle_row_idx).(grid_middle_col_idx) in
    let grid_mask = create_mask middle in
    let masked_grid_data =
      Array.map2_exn grid grid_mask ~f:(fun r row_masks ->
        Array.map2_exn r row_masks ~f:(fun cell cell_mask -> cell_mask &: cell.d))
    in
    let row_joined_grid_data =
      Array.map masked_grid_data ~f:(fun r -> r |> Array.to_list |> concat_msb)
    in
    let get_row_neighbors ri r =
      (* for simplicity, row neighbors including itself (masked) *)
      let middle_row_lsb = data_vector_size in
      let middle_row_msb = (2 * data_vector_size) - 1 in
      (if ri = grid_middle_row_idx then
         [| srl r 1; sll r 1 |]
       else
         [| srl r 1; r; sll r 1 |])
      |> Array.map ~f:(fun r -> select r middle_row_msb middle_row_lsb)
    in
    let neighbors_by_d =
      row_joined_grid_data |> Array.mapi ~f:get_row_neighbors |> Array.concat_map ~f:Fn.id
    in
    (* TODO: elaborate this vectorization logic *)
    let neighbors_count_by_d =
      Array.init data_vector_size ~f:(fun i ->
        let bit_idx =
          data_vector_size - i - 1
          (* TODO: elaborate this magic *)
        in
        Array.map neighbors_by_d ~f:(fun nb -> bit nb bit_idx)
        |> Array.to_list
        |> concat_msb
        |> popcount)
    in
    let is_accessible =
      Array.map neighbors_count_by_d ~f:(fun nc -> nc <:. 4)
      |> Array.to_list
      |> concat_msb
    in
    let result_d = middle.d &: ~:is_accessible in
    { Result.prev = middle.d; d = result_d; last = middle.last; valid = middle.valid }
  ;;

  let create _scope (inputs : _ I.t) : _ O.t =
    let open Signal in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let grid = create_grid spec ~enable:inputs.enable ~data_in:inputs.data_in in
    let data_out = Array.map grid ~f:(fun r -> r.(0)) in
    let result_next = calculate ~grid in
    let result = Result.map result_next ~f:(reg spec ~enable:inputs.enable) in
    { O.data_out; result }
  ;;

  let hierarchical scope (input : Signal.t I.t) =
    let module H = Hierarchy.In_scope (I) (O) in
    H.create ~scope ~name:"forklift" create input
  ;;
end

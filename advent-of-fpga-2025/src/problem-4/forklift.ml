open! Base
open Hardcaml

module type S = Sliding_window_intf.S

module Make () : S = struct
  let kernel_width = 3
  let kernel_height = 3
  let data_bit_width = 1 (* TODO: this should be configurable to support vectorization *)
  let result_bit_width = 1
  let neighbors_count_bit_width = kernel_width + kernel_height

  module I = struct
    type 'a t =
      { clear : 'a
      ; clock : 'a
      ; enable : 'a
      ; data_in : 'a array [@length kernel_height] [@bits data_bit_width]
      }
    [@@deriving hardcaml, sexp_of]
  end

  module O = struct
    type 'a t =
      { data_out : 'a array [@length kernel_height] [@bits data_bit_width]
      ; result : 'a [@bits result_bit_width]
      }
    [@@deriving hardcaml, sexp_of]
  end

  let create_grid (spec : Reg_spec.t) ~(enable : _) ~(data_in : _ array) : _ array array =
    let create_reg = Signal.reg spec ~enable in
    Array.map data_in ~f:(fun iwire ->
      let _, delays =
        Array.fold_map
          (Array.init kernel_width ~f:Fn.id)
          ~init:iwire
          ~f:(fun prev_wire _ ->
            let current_reg = create_reg prev_wire in
            current_reg, prev_wire)
      in
      delays)
  ;;

  (* modify calculatin here *)
  let calculate ~(grid : _ array array) =
    let open Signal in
    let grid_middle_row_idx = (kernel_height - 1) / 2 in
    let grid_middle_col_idx = (kernel_width - 1) / 2 in
    let middle = grid.(grid_middle_row_idx).(grid_middle_col_idx) in
    let count_col_neighbors_fn (c : _ array) : _ =
      c
      |> List.of_array
      |> List.map ~f:(fun x -> uresize x neighbors_count_bit_width)
      |> tree ~arity:2 ~f:(List.reduce_exn ~f:( +: ))
    in
    let neighbors_count =
      grid
      |> List.of_array
      |> List.map ~f:count_col_neighbors_fn
      |> tree ~arity:2 ~f:(fun r -> r |> List.reduce_exn ~f:( +: ))
    in
    let is_accessible = neighbors_count <:. 4 in
    middle &: is_accessible
  ;;

  let create _scope (inputs : _ I.t) : _ O.t =
    let open Signal in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let grid = create_grid spec ~enable:inputs.enable ~data_in:inputs.data_in in
    let result = reg spec ~enable:inputs.enable (calculate ~grid) in
    { O.data_out = inputs.data_in; result (* TODO *) }
  ;;
end

open! Base

(*
    FIXME: make it a configuation
    and pass via functor 'Make' instead
*)

let data_bit_width = 1 (* TODO: better name for the data since it might be vectorized *)
let row_bit_width = 8
let col_bit_width = 8
let removed_paper_count_bit_width = row_bit_width + col_bit_width
let max_row_size = Int.pow 2 row_bit_width - 1
let max_col_size = Int.pow 2 col_bit_width - 1

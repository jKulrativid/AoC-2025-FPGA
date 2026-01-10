open! Base
open Hardcaml

module type S = sig
  val kernel_row_size : int
  val kernel_col_size : int
  val data_bit_width : int
  val result_bit_width : int
  val latency : int

  module Cell : sig
    type 'a t =
      { d : 'a
      ; valid : 'a
      ; last : 'a
      ; is_top : 'a
      ; is_bottom : 'a
      ; is_left : 'a
      ; is_right : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  module I : sig
    type 'a t =
      { clear : 'a
      ; clock : 'a
      ; data_in : 'a Cell.t array
      ; enable : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  module O : sig
    type 'a t =
      { data_out : 'a Cell.t array
      ; result : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  val create : Scope.t -> Signal.t I.t -> Signal.t O.t
end

module type Sliding_window = sig
  module Make () : S
end

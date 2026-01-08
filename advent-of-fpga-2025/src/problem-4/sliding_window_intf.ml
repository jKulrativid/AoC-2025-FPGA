open! Base
open Hardcaml

module type S = sig
  val kernel_width : int
  val kernel_height : int
  val data_bit_width : int

  module I : sig
    type 'a t =
      { clear : 'a
      ; clock : 'a
      ; enable : 'a
      ; data_in : 'a array
      }
    [@@deriving sexp_of, hardcaml]
  end

  module O : sig
    type 'a t =
      { data_out : 'a array
      ; result : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  val create : Scope.t -> Signal.t I.t -> Signal.t O.t
end

module type Sliding_window = sig
  module Make () : S
end

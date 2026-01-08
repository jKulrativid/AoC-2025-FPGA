open! Base

module type S = sig
  val kernel_width : int
  val kernel_height : int
  val data_bit_width : int
end

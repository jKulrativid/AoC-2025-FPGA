open! Base
open Hardcaml

module Pwm = struct
  module I = struct
    type 'a t =
      { duty_cycle : 'a [@bits 8]
      ; clock : 'a
      ; clear : 'a
      }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = { output : 'a } [@@deriving sexp_of, hardcaml]
  end

  let create (inputs : _ I.t) =
    let open Signal in
    let spec = Reg_spec.create ~clock:inputs.clock ~clear:inputs.clear () in
    let counter = Always.Variable.reg ~width:8 spec in
    let output = counter.value <: inputs.duty_cycle in
    Always.(
      compile [ counter <-- counter.value +:. 1; when_ inputs.clear [ counter <--. 0 ] ]);
    { O.output }
  ;;
end

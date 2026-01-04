open! Base
open Hardcaml

module State = struct
  type t =
    | Idle
    | Setup
    | ReadInput
    | Loop
end

module I = struct
  type 'a t =
    { num_rows : 'a
    ; num_cols : 'a
    ; data_in : 'a
    ; data_valid : 'a
    ; clock : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { ready : 'a
    ; result : 'a
    }
end

(* 
    Idle ---( read rows and cols )--> Calculating(reading stream)
    ---()-->
*)

let _ = Signal.vdd

(* let create _scope (_inputs : _ I.t) : _ O.t = { O.result = Signal.vdd } *)

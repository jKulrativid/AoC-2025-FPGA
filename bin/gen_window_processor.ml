open! Core
open Hardcaml
open Problem_4

module Forklift_cfg = struct
  let data_vector_size = 16
end

module Wp_cfg = struct
  let input_row_bit_width = 10
  let input_col_bit_width = 10
end

module Fl = Forklift.Make (Forklift_cfg)
module Wp = Window_processor.Make (Wp_cfg) (Fl)

let generate_verilog () =
  (* Use the interface from the instantiated module *)
  let module C = Circuit.With_interface (Wp.I) (Wp.O) in
  let scope = Scope.create ~flatten_design:false ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"window_processor_top" (Wp.hierarchical scope) in
  Rtl.print ~database:(Scope.circuit_database scope) Verilog circuit
;;

let command =
  Command.basic
    ~summary:"Generate Window Processor Verilog"
    [%map_open.Command
      let () = return () in
      fun () -> generate_verilog ()]
;;

let () = Command_unix.run command

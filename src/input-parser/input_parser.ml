open Base

module Problem_4 = struct
  type t = int list list

  let parse ?(vector_size = 1) raw_input =
    String.split_lines raw_input
    |> List.map ~f:(fun line ->
      String.to_list line
      |> List.map ~f:(function
        | '@' -> 1
        | _ -> 0)
      |> List.chunks_of ~length:vector_size
      |> List.map ~f:(fun chunk ->
        let len = List.length chunk in
        let chunk =
          if len < vector_size then
            chunk @ List.init (vector_size - len) ~f:(Fn.const 0)
          else
            chunk
        in
        List.fold chunk ~init:0 ~f:(fun acc b -> (acc lsl 1) lor b)))
  ;;

  let visualize ?(vector_size = 1) (inputs : t) =
    Stdio.printf "%d %d\n" (List.length inputs) (List.length @@ List.hd_exn inputs);
    List.iter inputs ~f:(fun row ->
      List.iter row ~f:(fun vec ->
        for i = vector_size - 1 downto 0 do
          Stdio.printf "%d" ((vec lsr i) land 1)
        done;
        Stdio.printf " ");
      Stdio.print_endline "")
  ;;
end

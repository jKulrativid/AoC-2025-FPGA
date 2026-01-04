open Base

module Problem_4 = struct
  type t = int list list

  let parse (raw_input : string) : t =
    let raw_row_to_list raw_row =
      String.to_list raw_row
      |> List.map ~f:(fun raw ->
        if Char.equal raw '@' then
          1
        else
          0)
    in
    String.split_lines raw_input |> List.map ~f:raw_row_to_list
  ;;

  let visualize (inputs : t) : unit =
    List.iter inputs ~f:(fun r ->
      List.iter r ~f:(fun c -> Int.to_string c |> Stdio.print_string);
      Stdio.print_endline "")
  ;;
end

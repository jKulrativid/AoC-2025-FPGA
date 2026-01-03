open Base

module Problem_4 = struct
  let parse raw_input =
    let raw_row_to_list raw_row =
      String.to_list raw_row
      |> List.map ~f:(fun raw ->
        if Char.equal raw '@' then
          1
        else
          0)
    in
    String.split_lines raw_input |> List.map ~f:raw_row_to_list |> List.to_array
  ;;
end

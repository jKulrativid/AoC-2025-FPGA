(*let file_to_run = "problem_2_test.txt"*)
let file_to_run = "problem_2_input.txt"

(* util funcs *)
let string_list_to_string l = List.filter (fun s -> s <> "") l |> String.concat "\n"

let read_lines_modern (filename : string) =
  let ic = open_in filename in
  let rec loop prev : string list =
    match In_channel.input_line ic with
    | Some line -> line :: loop ()
    | None -> []
  in
  loop ()
;;

let str_inc s = int_of_string s |> ( + ) 1 |> string_of_int
(*end util funcs*)

(*  TODO: sort and merge ID range before validating each reduces redundant operation, *)
(* but in the FPGA world I'm not sure, needing verification. *)

let is_valid_id (id : string) : bool =
  let len = String.length id in
  let half_len = len / 2 in
  let rec is_valid_id_at_window_size (window_size : int) : bool =
    if window_size > half_len then
      false
    else
      List.fold_left (fun is_valid 
  in
  is_valid_id_at_window_size 2
;;

let get_sum_invalid_ids_from_id_range (start : string) (_end : string) : int =
  let stop = str_inc _end in
  let rec iterate (current_id : string) : int =
    if current_id = stop then
      0
    else if is_valid_id current_id then
      iterate (str_inc current_id)
    else
      int_of_string current_id + iterate (str_inc current_id)
  in
  iterate start
;;

let get_sum_of_invalid_ids_from_id_ranges (ranges : (string * string) list) : string =
  List.fold_left
    (fun sum (start, _end) -> get_sum_invalid_ids_from_id_range start _end + sum)
    0
    ranges
  |> string_of_int
;;

read_lines_modern file_to_run
|> List.hd
|> String.split_on_char ','
|> List.map (fun raw_str -> Scanf.sscanf raw_str "%[^-]-%s" (fun a b -> a, b))
|> get_sum_of_invalid_ids_from_id_ranges
|> print_endline

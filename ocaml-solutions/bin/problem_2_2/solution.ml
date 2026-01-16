(*
  FIXME: migrate to Base & Core library (just knew they exists).
*)

(* 
  NOTE: Current version is kinda slow (took around 4s to complete the problem_2_input.txt). 
  So, it does require optimization but I ignore it since the goal is to implement this on FPGA,
  which require tons or rethink.
*)

(* 
  TODO: sort and merge ID range before validating each reduces redundant operation,
  but in the FPGA world I'm not sure, needing verification.
*)

(*let file_to_run = "inputs/problem_2_test.txt"*)
let file_to_run = "inputs/problem_2_real.txt"

(* util funcs *)
let string_list_to_string l = List.filter (fun s -> s <> "") l |> String.concat "\n"

let read_lines_modern (filename : string) =
  let ic = open_in filename in
  let rec loop _ : string list =
    match In_channel.input_line ic with
    | Some line -> line :: loop ()
    | None -> []
  in
  loop ()
;;

let str_inc s = int_of_string s |> ( + ) 1 |> string_of_int

(*end util funcs*)

let is_valid_id (id : string) : bool =
  let len = String.length id in
  let half_len = len / 2 in
  let is_invalid_id_at_window_size (window_size : int) : bool =
    let rec get_range_of_start (i : int) : int list =
      if i + window_size = len then [] else i :: get_range_of_start (i + window_size)
    in
    if window_size > half_len
    then false
    else if len mod window_size <> 0
    then false
    else (* TODO: better naming*)
      List.fold_left
        (fun is_valid idx ->
           is_valid
           && String.sub id idx window_size
              = String.sub id (idx + window_size) window_size)
        true
        (get_range_of_start 0)
  in
  (* TODO: use fold_left might be more explicit*)
  let rec is_invalid_at_some_window_size current_size =
    if current_size = 0
    then true
    else if is_invalid_id_at_window_size current_size
    then false
    else is_invalid_at_some_window_size (current_size - 1)
  in
  is_invalid_at_some_window_size half_len
;;

let get_sum_invalid_ids_from_id_range (start : string) (_end : string) : int =
  let stop = str_inc _end in
  let rec iterate (current_id : string) : int =
    if current_id = stop
    then 0
    else if is_valid_id current_id
    then iterate (str_inc current_id)
    else int_of_string current_id + iterate (str_inc current_id)
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

let solve () =
  read_lines_modern file_to_run
  |> List.hd
  |> String.split_on_char ','
  |> List.map (fun raw_str -> Scanf.sscanf raw_str "%[^-]-%s" (fun a b -> a, b))
  |> get_sum_of_invalid_ids_from_id_ranges
  |> print_endline
;;

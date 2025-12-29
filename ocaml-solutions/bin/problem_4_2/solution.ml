open Base
open Stdio

let read_grid () : char array array =
  In_channel.input_lines In_channel.stdin (* 1. Read all lines into a List *)
  |> List.to_array (* 2. Convert List of strings to Array of strings *)
  |> Array.map ~f:String.to_array
;;

let print_grid (g : char array array) : unit =
  Array.iter g ~f:(fun row -> print_endline (String.of_array row))
;;

let is_paper_accessible
      (grid : char array array)
      (r : int)
      (c : int)
      (rows_count : int)
      (cols_count : int)
  : bool
  =
  let offsets = [ -1, -1; -1, 0; -1, 1; 0, -1; 0, 1; 1, -1; 1, 0; 1, 1 ] in
  let adjacent_papers_count =
    List.count offsets ~f:(fun (dr, dc) ->
      let r, c = r + dr, c + dc in
      match r, c with
      | r, _ when r < 0 || r >= rows_count -> false
      | _, c when c < 0 || c >= cols_count -> false
      | r, c -> Char.equal grid.(r).(c) '@')
  in
  if adjacent_papers_count < 4 then
    true
  else
    false
;;

let remove_accessible_papers (grid : char array array) : int * char array array =
  let rows_count = Array.length grid in
  let cols_count =
    if rows_count = 0 then
      0
    else
      Array.length grid.(0)
  in
  Array.fold_mapi grid ~init:0 ~f:(fun r acc row ->
    let row_removed_papers_count, row =
      Array.fold_mapi row ~init:0 ~f:(fun c acc col ->
        let is_accessible = is_paper_accessible grid r c rows_count cols_count in
        match col, is_accessible with
        | '@', true -> 1 + acc, '.'
        | _ -> acc, col)
    in
    acc + row_removed_papers_count, row)
;;

let rec remove_all_accesible_paper (acc : int) (grid : char array array)
  : int * char array array
  =
  let removed_papers_count, removed_grid = remove_accessible_papers grid in
  let acc_removed_papers_count = acc + removed_papers_count in
  match removed_papers_count with
  | 0 -> acc_removed_papers_count, removed_grid
  | n when n > 0 -> remove_all_accesible_paper acc_removed_papers_count removed_grid
  | negative_n ->
    failwith (Printf.sprintf "Error: removed papers count %d is negative!" negative_n)
;;

let solve () =
  let grid = read_grid () in
  print_grid grid;
  let removed_papers_count, _ = remove_all_accesible_paper 0 grid in
  Int.to_string removed_papers_count |> print_endline
;;

(* NOTE: simply call a command with `dune exec ocaml-solutions < inputs/problem_4_test.txt` *)

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

let count_adjacent_papers
      (grid : char array array)
      (r : int)
      (c : int)
      (rows_count : int)
      (cols_count : int)
  : int
  =
  let offsets = [ -1, -1; -1, 0; -1, 1; 0, -1; 0, 1; 1, -1; 1, 0; 1, 1 ] in
  List.count offsets ~f:(fun (dr, dc) ->
    let r, c = r + dr, c + dc in
    match r, c with
    | r, _ when r < 0 || r >= rows_count -> false
    | _, c when c < 0 || c >= cols_count -> false
    | r, c -> Char.equal grid.(r).(c) '@')
;;

let solve () =
  let grid = read_grid () in
  let rows_count = Array.length grid in
  let cols_count = if rows_count = 0 then 0 else Array.length grid.(0) in
  print_grid grid;
  let iter_grid g =
    Array.foldi g ~init:0 ~f:(fun r ac row ->
      ac
      + Array.foldi row ~init:0 ~f:(fun c ac col ->
        match col with
        | '@' ->
          let papers_count = count_adjacent_papers grid r c rows_count cols_count in
          if papers_count < 4 then ac + 1 else ac
        | _ -> ac))
  in
  iter_grid grid |> Int.to_string |> print_endline
;;

(* NOTE: simply call a command with `dune exec ocaml-solutions < inputs/problem_4_test.txt` *)

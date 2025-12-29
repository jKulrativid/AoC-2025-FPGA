(*Problem_2_1.Solution.solve () *)
(* Problem_2_2.Solution.solve () *)
(* Problem_4_1.Solution.solve () *)
Problem_4_2.Solution.solve ()

(*
    NOTE: [problem 4]
    Maybe it's a good idea (optimal for FPGA) to gather neighbor of each array into a list,
    then each item will be executed in an embarassingly parallelism manner.
    -
    BRAM access and locality must be verified. Moreover, convolution might be a useful trick.
    -
    For the part II, it's obvious that we should create a circuit block
    that mark and removed the accessible paper. Also, I notice that loop unrolling
    (apply remove block 4 times without check) might be a performance boost,
    need verification btw.
*)

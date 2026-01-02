# Advent of FPGA 2025

## Theme

I aim to solve 3 problems (note for myself)

- 1st problem will be engineering challenge regarding performance aspect (e.g. can we streamlined this? or can we partition this too?)
- 2nd problem (TBD:)
- 3rd problem I will try out-of-the-forth-wall solution.

Each solution should exploit FPGA superpower of pipelining and parallelism,
and Hardcaml superpower of abstraction, type-safety, and human readability.

## NOTE

- On 1st problem: I accidentially see the near-optimal solution since the problem itself is a subclass of convey's game of life.
  However, there is still a room for optimization such as partitioning or multiple model for solving trivial case (e.g. rows_count <= 2),
  use load balancer to solve multiple grids in an embarrasingly parallelism manner or encode the input like zipping two rows so that we can solve the problem faster.
  Btw, we need benchmarking for verifying the true bottleneck.
- On 1st problem too: if the input is extremely sparse and large,
  can parallel by islands (group of papers surrounded with more than 2 empty blocks).
- On 1st problem too: we might be able to achieve O(1) memory (current solution is O(row size) )
  via implementing redundancy in the stream so that each step contains enough information.
- Maybe there is a place to use cuckoo hash e.g. problem that strictly requires linked list or your life will be much suffered.
- Coding style inspiration : https://github.com/hardcamls/reedsolomon.

## TODO ("make it right" step):

- explain the test strategy and test structure
- promote state-machine readable always block pattern (strength of hardcaml btw.)
- flattern the problems into one folder (no submodule for each problem anymore)
- 1st problem (problem 4) can be further optimized with bit manipulation and popcount.
  explain: store row with int register and then grid will be a list of integers.
- 1st problem (problem 4): explain how the pipeline stall, smoothening input calculation

formatting dune file

```sh
dune format-dune-file <DUNE_FILE_PATH>
```

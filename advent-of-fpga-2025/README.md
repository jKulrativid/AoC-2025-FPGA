# Advent of FPGA 2025

## Theme

I aim to solve 3 problems (note for myself)

- 1st problem will be engineering challenge regarding performance aspect (e.g. can we streamlined this? or can we partition this too?)
- 2nd problem (TBD:)
- 3rd problem I will try out-of-the-forth-wall solution.

Each solution should exploit FPGA superpower of pipelining and parallelism,
and Hardcaml superpower of abstraction, type-safety, and human readability.

## Ultimate Goal

leverage functional programming to simplify code while offering configurability
that system verilog can be matched (e.g. List.map creating systolic array)

clarifying: the "simplified code" should

- allow programmer to construct or derive ASM chart and the circuit or schematic diagram,
  making code as a single source of truth
- apply software principle such as single responsibility helping verification

## NOTE

- On 1st problem: I accidentially see the near-optimal solution since the problem itself is a subclass of convey's game of life.
  However, there is still a room for optimization such as partitioning or multiple model for solving trivial case (e.g. rows_count <= 2),
  use load balancer to solve multiple grids in an embarrasingly parallelism manner or encode the input like zipping two rows so that we can solve the problem faster.
  Btw, we need benchmarking for verifying the true bottleneck.
- 1st problem: 2 things that substantially increase throughput and resource utilization are
  vectorize the 3x3 grid convolutor and move data through DMA (use ram instead of BRAM/URAM).
  However, the second one cannot works efficiently if not vectorized since AXIS DMA width is at least 8 bits (not sure but can read Xilinx user guide).
- Maybe there is a place to use cuckoo caching via implementing redundancy in the stream so that each step contains enough information. e.g. problem that strictly requires linked list or your life will be much suffered.
- Coding style inspiration : https://github.com/hardcamls/reedsolomon.
- 2nd problem (day 12): systolic array seems to be great idea but vectorizing them is incredably complex.
  However, since these problem is NP-hard then we don't have to encode or batch them like 1st problem.
- 2nd problem: since it's NP-hard, why not try approximation algorithm in the FPGA

## TODO ("make it right" step):

- explain the test strategy and test structure
- 1st problem (day 4) can be further optimized with bit manipulation and popcount.
  explain: store row with int register and then grid will be a list of integers.
- 1st problem (day 4): implement horizontal parallelism and SerDes to reduce latency (exploiting embarrasingly parallelism)
- 1st problem (day 4): explain how we exploit memory alignment to maximize resource utils (FF, BRAM, URAM if exists).
- 1st problem (day 4): try self-testing and re-routing (horribly complicated only if we have time).
- 1st problem (day 4): create a transpose logic (where ?) so that for 6x100 we require forklift with width = 3 instead of 100 !!!

formatting dune file

```sh
dune format-dune-file <DUNE_FILE_PATH>
```

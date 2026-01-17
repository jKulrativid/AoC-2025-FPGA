# Advent of FPGA 2025: Hardcaml Solution

A FPGA solution for **Problem 4 -- Printing Department** (both parts), written in **Hardcaml**.

This project implements a parameterized **Sliding Window Processor** capable of handling grid sizes exceeding 100k rows.

[Problem Link](https://adventofcode.com/2025/day/4)

## Getting Started

Install Dependencies

```
opam install . --deps-only --with-test
```

Run Tests

```
dune runtest
```

Generate Verilog File

```
dune exec bin/gen_window_processor.exe > [YOUR FILE DESTINATION e.g. verilog/window_processor.v]
```

## Solution Overview

The biggest bottleneck on FPGAs is running out of block RAM (BRAM) when reading the entire grid.
My design gets around this by acting like a sliding window. Instead of storing the whole frame,
we only keep the absolute minimum history needed, specifically $(N-1) \times R$ rows, or two rows
for our problem, with a 6-bit metadata overhead for each row.

Since the DMA delivers data in wide chunks anyway, I vectorized the processing logic to match that width perfectly.
This means the design is completely **streaming**. Because we never store the full vertical frame, this core can theoretically process
an image with an infinite column height forever, as long as you can store $(N-1) \times R$ rows with overhead inside BRAM.

## Architecture

### Part I Solution

<p align="center">
  <img src="./doc-img/high-level-diagram.png" width="80%" alt="Window Processor Architecture">
</p>

The core design is a **Streaming Processor** that operates on a continuous flow of grid cells without requiring a full frame buffer in the kernel.

- **Window Processor:** Manages `N-1` internal line buffers to generate a 3x3 (or NxN) grid for every clock cycle.
- **Forklift:** A sliding window that implements the convolution-style logic.

### Part II Workaround Component

"While the core architecture is designed to scale via PS and DMA integration, the current challenge prioritizes simulation results.
Consequently, I implemented a standalone iterative solver that wraps the processor in a FIFO feedback loop to drive the grid
until it reaches a steady state (no 1'bit can be removed)."

## File Structure

The project is structured as a hardware generator library. The core logic for Problem 4 resides in `src/problem-4/`.

```text
.
├── bin/
│   └── main.ml                     # unimplemented RTL generator
├── src/
│   └── problem-4/
│       ├── window_processor.ml     # Stream processor solving part I
│       ├── forklift.ml             # 3x3 kernel
│       ├── solver.ml               # Temporary circuit for solving part II
│       └── sliding_window_intf.ml
└── test/                           # Hardcaml simulation-based testbenches
    └── inputs/                     # Test input files including ones provided by Advent of Code
```

## Key Optimizations

| Technique             | Description                                                                                                             |
| :-------------------- | :---------------------------------------------------------------------------------------------------------------------- |
| **Sideband Metadata** | Boundary flags (`top`, `last`, etc.) are precomputed and travel alongside data, minimizing states and counters.         |
| **Tree Reduction**    | Combinational logic uses trees (e.g., `Signal.tree` and `Signal.popcount`) to achieve **O(log N)** critical path depth. |
| **Vectorization**     | The engine processes multiple cells per clock cycle to maximize memory bandwidth.                                       |

## Engineering Principles

This project leverages OCaml's type system to ensure correctness before simulation:

1.  **Modular Functors:** The `Window_processor` is a generic functor, decoupling the data movement logic from the calculation logic (`Forklift`).
2.  **Configuration as a Code:** Settings like `data_vector_size` are configurable rather than hardcoded.
3.  **Minimal State:** The design avoids complex state machines in the data path, preferring counter-based control flow for predictability.
4.  **Arithmetic Safety:** We strictly enforce **Additive Comparisons** (e.g., `idx + 1 < limit`) instead of subtraction (`idx < limit - 1`) to eliminate subtle unsigned integer underflow bugs during runtime.

## Future Roadmap

- implement tests on control flag like `enable`, verifying it's really working as we expected
- make generated Verilog hierarchical (currently it's flat even though I implemented `hierarchical` circuit constructor
  and explicitly passed `~flatten_design:false` flag when creating scope)
- Full hardware-in-the-loop verification on the Kria KR260.

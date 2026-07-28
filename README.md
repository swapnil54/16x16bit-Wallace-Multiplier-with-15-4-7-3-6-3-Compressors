# 16x16bit Wallace Multiplier with 15:4, 7:3 & 6:3 Compressors

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Language: Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)](rtl/)
[![Target: Xilinx Artix--7](https://img.shields.io/badge/FPGA-Artix--7%20xc7a35t-red.svg)](constraints/)
[![Verification: 100% (2^32 pairs)](https://img.shields.io/badge/Verification-2%5E32%20Exhaustive%20Pass-brightgreen.svg)](tb/)

An optimized **16×16-bit unsigned exact Wallace-tree multiplier** implemented in Verilog HDL. This design leverages high-order counters and compressors (**15:4 counters**, **7:3 compressors**, and **6:3 compressors**) to minimize partial-product reduction levels, resulting in low logic delay, compact LUT utilization, and high power efficiency.

---

## 🚀 Key Performance Metrics

Characterization performed on **Xilinx Artix-7 FPGA (`xc7a35tcpg236-1`)** using **Vivado 2025.2** under locked synthesis directives (`-flatten_hierarchy rebuilt`, `-max_dsp 0`).

| Metric | Value | Description / Context |
|---|---|---|
| **Max Operating Frequency ($F_{max}$)** | **143.9 MHz** | Closing period 6.9495 ns (WNS = +0.006 ns) |
| **Critical Path ($t_{cp}$)** | **6.937 ns** | 2.269 ns logic (32.7%) + 4.668 ns routing (67.3%) |
| **Logic Levels** | **10** | End-to-end critical path logic depth |
| **Core Resource Utilization** | **427 LUTs, 7 CARRY, 0 DSP, 0 FF** | Pure combinational multiplier core (`instance core`) |
| **Total Design Resources** | **431 LUTs, 64 FF, 7 CARRY, 0 DSP** | Includes input/output boundary registers |
| **Core Dynamic Power** | **72.0 mW** @ 143.9 MHz | SAIF vector-driven (High Confidence) |
| **Throughput** | **143.9 M multiplies/sec** | 1 result per clock cycle |
| **Energy per Multiply** | **500.4 pJ** | $P_{core} \times T_{clk}$ |
| **Power-Delay Product (PDP)** | **499.5 pJ** | $P_{core} \times t_{cp}$ |
| **Area-Delay Product (ADP)** | **2962.1 LUT·ns** | $\text{LUTs} \times t_{cp}$ |

---

## 📐 Architecture Overview

The 16×16 multiplication generates 256 partial products ($pp_{r,c} = a[c-r] \ \& \ b[r]$), which are reduced through a 4-level compressor tree before a final 32-bit Carry-Propagate Adder (CPA).

### Column-Height Reduction Profile

```text
Stage 0 (Partial Products)  Max Height: 16
        ↓  Level 1  — 43 instances (3× 15:4, 16× 7:3, 8× 6:3, 10 FA, 6 HA)
Stage 1                     Max Height: 7
        ↓  Level 2  — 38 instances (2× 7:3, 4× 6:3, 18 FA, 14 HA)
Stage 2                     Max Height: 5
        ↓  Level 3  — 31 instances (20 FA, 11 HA)
Stage 3                     Max Height: 3
        ↓  Level 4  — 28 instances (7 FA, 21 HA)
Stage 4                     Max Height: 2  →  Final 32-bit CPA
```

### Module Breakdown (140 Leaf Instances)

| Cell Type | Instance Count | Description |
|---|---|---|
| **15:4 Counter** | 3 | High-order counter for wide columns |
| **7:3 Compressor** | 18 | Multi-operand reduction cell |
| **6:3 Compressor** | 12 | Multi-operand reduction cell |
| **Full Adder (FA)** | 55 | 3:2 reduction cell |
| **Half Adder (HA)** | 52 | 2:2 reduction cell |
| **Total Leaf Instances** | **140** | 316 internal wires |

---

## 📂 Repository Structure

```text
wallace-multiplier-16x16/
├── rtl/                                # Synthesizable Verilog Source Code
│   ├── wallace_16x16.v                 # Core 16x16 Wallace Multiplier Top Module
│   ├── wallace_blocks.v                # Leaf Modules (15:4, 7:3, 6:3, FA, HA)
│   ├── wallace_16x16_wrapper_regio.v   # Fully Registered Top (For P&R & Characterization)
│   ├── wallace_16x16_wrapper.v         # Output-Registered Top
│   └── compressor_4_2.v                # 4:2 Compressor Block
├── tb/                                 # Testbenches & Formal Proof
│   ├── tb_wallace_16x16.v              # Combinational Testbench
│   ├── tb_wallace_16x16_wrapper.v      # Clocked Testbench (Latency 1)
│   ├── tb_wallace_16x16_wrapper_regio.v# Clocked Testbench (Latency 2)
│   └── verify_wallace_exhaustive.py    # Bit-Parallel 2^32 Exhaustive Verification Script
├── constraints/                        # Xilinx XDC Constraints
│   ├── wallace_timing_regio.xdc        # Primary Timing Constraint (xc7a35t)
│   └── wallace_timing.xdc              # Secondary Constraint
├── scripts/                            # Vivado Automation TCL Scripts
│   ├── report_core_timing.tcl          # Gate-level Timing & Critical Path Analyzer
│   └── report_core_power.tcl           # SAIF Power & Energy Metrics Reporter
├── docs/                               # Detailed Design Records
│   ├── RESULTS_RECORD.md               # Comprehensive Synthesis & P&R Report
│   ├── RUNBOOK.md                      # Step-by-Step Characterization Procedure
│   └── results.csv                     # Metrics summary table
├── .gitignore                          # Xilinx/Vivado build artifact exclusions
├── LICENSE                             # MIT Open Source License
└── README.md                           # Main Project Documentation
```

---

## 🧪 Verification & Simulation

### 1. Behavioral Testbench Simulation

Run simulation using Vivado `xsim` or ModelSim / Icarus Verilog:

```bash
# Using Vivado Simulator (xsim)
xvlog rtl/wallace_blocks.v rtl/wallace_16x16.v tb/tb_wallace_16x16.v
xelab tb_wallace_16x16 -s sim_top
xsim sim_top -testplusarg SETTLE=20 -runall
```

Expect `PASS` across 20,312 deterministic and pseudo-random test vectors.

### 2. Exhaustive Formal Proof ($2^{32}$ = 4,294,967,296 pairs)

The repository includes a bit-parallel Python verification engine (`tb/verify_wallace_exhaustive.py`) that extracts and validates the gate netlist against a reference model across **all $4,294,967,296$ possible input operand pairs**.

```bash
python tb/verify_wallace_exhaustive.py
```

---

## ⚙️ Vivado Characterization Flow

### Mandatory Synthesis Directives

> [!IMPORTANT]
> To reproduce exact area and timing numbers, set the following synthesis directives in Vivado:
> - `-flatten_hierarchy rebuilt` *(allows cross-boundary LUT optimization while maintaining module reporting)*
> - `-retiming off`
> - `-max_dsp 0` *(forces LUT-based synthesis to compare against behavioural baselines)*

### Running Automated Metrics Reports

1. Open implemented design in Vivado:
   ```tcl
   open_run impl_1
   ```
2. Run timing report script:
   ```tcl
   source scripts/report_core_timing.tcl
   wallace_timing_report
   ```
3. Run SAIF dynamic power report script:
   ```tcl
   source scripts/report_core_power.tcl
   wallace_power_metrics
   ```

---

## 👤 Author & License

- **Author:** [Swapnil](https://github.com/swapnil54)
- **License:** [MIT License](LICENSE)

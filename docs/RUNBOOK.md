# Runbook — Wallace 16×16 characterisation flow

Everything here is aligned to your naming: multiplier instance `core`,
parameter `CLK_PERIOD`, scripts `report_core_timing.tcl` /
`report_core_power.tcl`, procs `wallace_timing_report`, `wallace_power_report`,
`wallace_power_metrics`.

`wallace_16x16.v` is unmodified (md5 `9aa884226b2e7fa28871695817420519`).
`wallace_blocks.v` is netlist-identical to your original — verified over all
4,294,967,296 operand pairs after the lint clean-up.

---

## File roles

| File | Role |
|---|---|
| `wallace_16x16.v` | the multiplier — never edit |
| `wallace_blocks.v` | leaf counters |
| `compressor_4_2.v` | **not instantiated** — keep OUT of the synthesis fileset |
| `wallace_16x16_wrapper.v` | output-registered, latency 1, instance `core` |
| `wallace_16x16_wrapper_regio.v` | fully registered, latency 2, instance `core` — **publish from this** |
| `wallace_timing.xdc` | for the output-only wrapper |
| `wallace_timing_regio.xdc` | for the regio wrapper |
| `tb_wallace_16x16.v` | combinational bench |
| `tb_wallace_16x16_wrapper.v` | clocked bench, latency 1 |
| `tb_wallace_16x16_wrapper_regio.v` | clocked bench, latency 2 |
| `report_core_timing.tcl` | gates + critical path + utilisation |
| `report_core_power.tcl` | SAIF gates + power + energy/PDP/EDP/ADP |
| `verify_wallace_exhaustive.py` | the actual correctness proof (all 2³²) |

All three benches share a **byte-identical vector generator**, so the three
runs exercise exactly the same operand stream. Verified programmatically.

---

## Step 0 — Synthesis settings, locked

    -flatten_hierarchy rebuilt      <-- NOT none
    -retiming off
    -max_dsp 0

**Do not use `-flatten_hierarchy none`.** `wallace_16x16` instantiates 140 leaf
modules. With `none`, Vivado cannot optimise across those boundaries, so a
`compressor_6_3` stays as four separate FA/HA modules instead of collapsing
into three LUT6s — which is precisely the mechanism your high-order-compressor
argument depends on. `rebuilt` flattens for optimisation and then restores the
hierarchy for reporting, so you still get per-instance area and power for
`core`. That is all `none` was buying you.

`-max_dsp 0` matters for the baselines, not for this design: your netlist has
no `*` operator, but a behaviourally written baseline will happily infer DSP48s
and void the comparison. The scripts gate on DSP = 0 either way.

Record the exact part, speed grade, Vivado version and directives. Every
baseline must use the identical set.

## Step 1 — Behavioural sim

Design top `wallace_16x16`, sim top `tb_wallace_16x16`, XDC disabled.

    xsim ... -testplusarg SETTLE=20

20,312 vectors, expect `PASS`. Runs in seconds. Its only job is to confirm
nothing broke in the file swap; the real proof is the Python verifier.

## Step 2 — Search pass (throwaway)

Top `wallace_16x16_wrapper_regio`, XDC `wallace_timing_regio.xdc` with
`set period 1.000`. Synthesise, implement, then:

    open_run impl_1
    source report_core_timing.tcl
    wallace_timing_report

Note `DATAPATH_DELAY` (= t_cp) and the printed *minimum closing period
estimate*. **Take nothing else from this build.** Negative WNS here is expected
and fine — that is the whole point of the 1 ns constraint.

## Step 3 — Closure search

Edit `set period` in the XDC to the estimate from Step 2, re-implement, check
WNS. Step down until WNS goes negative; the smallest period with **WNS ≥ 0 is
your Fmax**. No `period − WNS` derivation, so nobody can argue about whether
setup and uncertainty belong in the number. Two or three iterations.

Every run is gated by `wallace_timing_report`:

| Gate | Meaning |
|---|---|
| G1 | XDC actually matched ports (catches the `12-584` silent failure) |
| G2 | DSP count = 0 |
| G3 | no latches |
| G4 | setup WNS and hold WHS both reported, hold ≥ 0 |
| G5 | instance `core` survived for per-instance reporting |

Any gate failing means the run is not reportable.

## Step 4 — The single build everything comes from

Re-implement at the closing period. From **this one run** take utilisation,
`t_cp`, WNS, and the netlist for the timing simulation. This is what stops the
last report's problem recurring — delay from one build, area from another.

## Step 5 — Gate-level timing simulation, twice

Sim top `tb_wallace_16x16_wrapper_regio`.

1. `CLK_PERIOD` = 200.0 — enormous margin. A failure here is a functional bug,
   not a margin question.
2. `CLK_PERIOD` = the closing period from Step 3. This is the "works at speed"
   evidence, and it is the run you capture SAIF from.

Override at elaboration (`xelab -generic_top "CLK_PERIOD=10.0"`) or at run time
(`-testplusarg CLK_PERIOD=10.0`).

For SAIF, in Simulation Settings:

    xsim.simulate.saif_scope        = tb_wallace_16x16_wrapper_regio/dut
    xsim.simulate.saif_all_signals  = true
    xsim.simulate.saif              = power.saif

Scope is the **wrapper instance inside the testbench** (`dut`), not the
testbench. A testbench-scoped SAIF annotates almost nothing and quietly
degrades the run to a vectorless estimate that still prints a plausible number.

**The bench now drives one multiply per clock.** The previous version applied a
new operand pair every other clock on the 2-stage wrapper, which would have
captured half the real switching activity and roughly halved the energy figure.

## Step 6 — Power

    source report_core_power.tcl
    wallace_power_report <proj>.sim/sim_1/impl/timing/xsim/power.saif
    # optional explicit form:
    # wallace_power_report power.saif tb_wallace_16x16_wrapper_regio/dut 10.0

The script probes the SAIF header, infers `-strip_path`, annotates, and runs
three gates:

| Gate | Meaning |
|---|---|
| P1 | confidence level = High — proves the SAIF actually took |
| P2 | ≥ 90 % of nets annotated — below that it is a hybrid, not a measurement |
| P3 | sim `CLK_PERIOD` = XDC `period` — otherwise activity is scaled against the wrong frequency |

Then read **Logic + Signals for instance `core`** from
`wallace_power_hier.rpt` and feed it in:

    wallace_power_metrics 0.006        ;# core dynamic power in watts
    wallace_record_result "wallace-hoc" results.csv

### What the metrics mean

    E   = P_core × T_clk        energy per multiply, pJ   (1 multiply/clock)
    PDP = P_core × t_cp         power-delay product, pJ
    EDP = PDP    × t_cp         energy-delay product, pJ·ns
    ADP = LUTs   × t_cp         area-delay product, LUT·ns

`E` and `PDP` coincide only when the design is clocked exactly at its critical
path. Both are printed on purpose: `E` is what the circuit costs in the system
you built; `PDP` is the comparison figure. Quoting one under the other's name
silently favours whichever design happens to be clocked slowest.

Worked example (P_core = 6 mW, T_clk = 20 ns, t_cp = 7.5 ns, 377 LUTs):
E = 120 pJ, PDP = 45 pJ, EDP = 337.5 pJ·ns, ADP = 2827.5 LUT·ns, throughput
50 M multiplies/s. Arithmetic cross-checked two ways.

### Two reporting rules

**Never compare total on-chip power.** Static power dominates on this part and
is essentially identical for every multiplier, so it compresses any real
difference into noise. Compare core dynamic power or energy per multiply.

**Exclude I/O power from anything called a core figure.** In your previous run
I/O was 25 mW of 41 mW dynamic — pad power, not multiplier power. Including it
would make the multiplier look about 2.5× hungrier than it is. That is why the
metrics take Logic + Signals for `core` rather than the chip dynamic total.

## Step 7 — Baselines

Steps 0–6 verbatim for a plain 3:2-only Wallace tree and a conventional array
multiplier. Same wrapper, same XDC, same closure procedure, same
`wallace_record_result` call so the rows land in one CSV. This is the step that
turns a verified design into a paper, and it is the one the original sequence
did not mention.

---

## Two things to state explicitly in the write-up

The regio XDC false-paths both I/O sides, so "closes at X ns" is a **core-only**
claim. Say so, or a reviewer will read it as system-level Fmax.

Keep `t_cp` (DATAPATH_DELAY) and Fmax (closing period) as **two separate rows**.
The first compares logic depth fairly across designs; the second is what the
part actually runs at. Conflating them is how the previous report got into
trouble.

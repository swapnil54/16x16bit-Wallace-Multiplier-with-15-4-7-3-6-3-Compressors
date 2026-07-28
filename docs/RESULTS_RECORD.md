# Wallace 16×16 Multiplier — Results Record

**Design:** 16×16 unsigned exact Wallace-tree multiplier with high-order compressors
**Part:** xc7a35tcpg236-1 (Artix-7, speed grade −1)
**Tool:** Vivado 2025.2
**Project:** `trying_WM_again`
**RTL under test:** `wallace_16x16.v`, md5 `9aa884226b2e7fa28871695817420519` — **unmodified throughout**

---

## 1. Headline numbers

Every figure below comes from **one implementation run** at a 6.9495 ns constraint.

| Metric | Value | Notes |
|---|---|---|
| **Critical path t_cp** | **6.937 ns** | `DATAPATH_DELAY`, logic + route only |
| — logic component | 2.269 ns (32.7 %) | |
| — route component | 4.668 ns (67.3 %) | |
| **Fmax** | **143.9 MHz** | closing period 6.9495 ns, WNS +0.006 ns |
| Logic levels | 10 | |
| Clock skew | −0.033 ns | |
| **Core area** | **427 LUT, 7 CARRY, 0 FF, 0 DSP** | instance `core` only |
| Whole design | 431 LUT, 64 FF, 7 CARRY, 0 DSP | includes wrapper flops |
| **Core dynamic power** | **72.0 mW** @ 143.9 MHz | SAIF-based, Confidence High |
| Chip dynamic | 125 mW | includes I/O pads |
| Device static | 70 mW | |
| Total on-chip | 195 mW | **do not use for comparison** |
| **Throughput** | **143.9 M multiplies/s** | 1 multiply per clock |
| **Energy per multiply** | **500.4 pJ** | P_core × T_clk |
| **PDP** | 499.5 pJ | P_core × t_cp |
| **EDP** | 3464.8 pJ·ns | PDP × t_cp |
| **ADP** | 2962.1 LUT·ns | LUTs × t_cp |

Critical path: `a_q_reg[9]/C → product_reg[29]/D`

> **E ≈ PDP (500.4 vs 499.5) is not a coincidence** — they coincide because the design
> is clocked essentially at its critical path (T_clk 6.9495 ≈ t_cp 6.937). A baseline
> clocked below its own critical path will show E > PDP. Watch for that asymmetry when
> comparing.

---

## 2. Architecture

| Property | Value |
|---|---|
| Partial products | 256, each `pp_r_c = a[c−r] & b[r]` |
| Instances | **140** total |
| — half adders | 52 |
| — full adders | 55 |
| — 6:3 compressors | 12 |
| — 7:3 compressors | 18 |
| — 15:4 counters | 3 |
| Internal wires | 316 = exactly the 316 instance outputs |
| Reduction cells | 193 FA + 76 HA = 269 |
| Flat netlist | 2846 nets, 1919 two-input gates (975 AND, 526 XOR, 418 OR) |
| Final CPA | `assign product = A + B` → inferred CARRY4 chain |

### Column-height profile

```
stage 0 (partial products)   max height 16
        ↓  level 1  — 43 instances (3× 15:4, 16× 7:3, 8× 6:3, 10 FA, 6 HA)
stage 1                      max height  7
        ↓  level 2  — 38 instances (2× 7:3, 4× 6:3, 18 FA, 14 HA)
stage 2                      max height  5
        ↓  level 3  — 31 instances (20 FA, 11 HA)
stage 3                      max height  3
        ↓  level 4  — 28 instances (7 FA, 21 HA)
stage 4                      max height  2   →  32-bit CPA
```

Levels derived topologically, independent of the source file's own grouping — and
they land on exactly the same boundaries (43 / 38 / 31 / 28).

### Technology-independent depth

| Block | internal FA/HA crossings |
|---|---|
| 6:3 compressor | 3 |
| 7:3 compressor | 3 |
| 15:4 counter | 7 |

Reduction-tree critical chain (12 cell crossings / 26 two-input gate levels):

```
pp_0_15 → u21(15:4).O3 → u65(6:3).C1 → u99(HA).s → u127(HA).s → A[19]
```

The four "levels" are **compressor** levels, not delay levels — the blocks have
internal depth, and the 15:4 counters at level 1 dominate the chain.

---

## 3. Verification

### 3.1 Exhaustive proof — all 2³² input pairs

Gate-level flattened netlist vs. an independent shift-and-add reference, bit-parallel:

| range of b | vectors | mismatches | dropped carry `u139_c` |
|---|---|---|---|
| 0 – 16 383 | 1 073 741 824 | 0 | always 0 |
| 16 384 – 32 767 | 1 073 741 824 | 0 | always 0 |
| 32 768 – 49 151 | 1 073 741 824 | 0 | always 0 |
| 49 152 – 65 535 | 1 073 741 824 | 0 | always 0 |
| **total** | **4 294 967 296** | **0** | |

Re-run and re-passed after the `wallace_blocks.v` lint clean-up — netlist-identical.

### 3.2 Leaf modules — exhaustive

| module | patterns | result |
|---|---|---|
| `half_adder` | 4 | output = popcount ✓ |
| `full_adder` | 8 | ✓ |
| `counter_5_3` | 32 | ✓ |
| `compressor_6_3` | 64 | ✓ |
| `compressor_7_3` | 128 | ✓ (sum-fold wiring confirmed) |
| `counter_15_4` | 32 768 | ✓ (internal `ovf` constant 0) |
| `compressor_4_2` | 32 | identity holds; `co` independent of `ci` — **not instantiated** |

### 3.3 Algebraic proof

Independent of simulation:

- 256 partial products, all `a[i]&b[j]` terms present exactly once, correct weights
- Every net has **exactly one driver**
- Every net is **consumed at most once** → no bit double-counted
- Every counter instance sees a **single column**
- Every `A[i]` and `B[i]` carries weight exactly `i`
- Σ2^w over the partial products = 4 294 836 225 = (2¹⁶−1)²
- One dropped bit: `u139_c` at weight 32, provably 0 since a·b < 2³² ⇒ `product = A + B` never truncates

### 3.4 Harness validation

11 injected faults — wrong column feed, transposed pp, swapped `A` bits, double-consumed
net, carry-fold 7:3, HA carry → OR, swapped 15:4 weights, dropped bit, wrong CPA tap.
**All 11 caught**; unmutated baseline clean.

### 3.5 Post-implementation timing simulation (SDF, slow corner)

| run | CLK_PERIOD | vectors | observed latency | result |
|---|---|---|---|---|
| 5a sanity | 200.0 ns | 512 | 2 clocks (matches RTL) | **PASS**, 0 mismatches |
| 5b at speed | 6.9495 ns | 20 312 | 3 clocks | **PASS**, 0 mismatches |

The extra cycle at 6.9495 ns is **clock-insertion delay observed from the pad**, not a
fault: the flops run on the BUFG-delayed internal clock (~3 ns, fixed), which at a
3.47 ns half-period pushes the output past the bench's sampling point. Same netlist,
same SDF, only the clock changed — which rules out a setup violation. No
`TIMING VIOLATION` messages. The testbench now measures this itself and self-corrects.

---

## 4. Timing closure search

| period (ns) | WNS (ns) | WHS (ns) | WPWS (ns) | verdict |
|---|---|---|---|---|
| 1.000 | −6.059 | +0.430 | −1.155 | search pass, 32 failing endpoints |
| 7.059 | +0.130 | +0.337 | +3.029 | closes |
| **6.9495** | **+0.006** | **+0.511** | **+2.975** | **closes — adopted** |
| < 6.9495 | negative | — | — | fails |

```
WNS (ns)
 +0.5 ┤
      │                          ● 7.059 (+0.130)
  0.0 ┼──────────────────────────────●─── 6.9495 (+0.006)
      │
 -6.0 ┤ ● 1.000 (-6.059)
      └──┬──────────────────────┬────┬──
       1.0                    7.06  6.95
```

Starting estimate came from `requirement − WNS` = 1.000 − (−6.059) = 7.059 ns.

The pulse-width failure at 1.000 ns was an artifact of the 0.5 ns high time being below
the flop minimum; it cleared at realistic periods.

**Acceptance gates, final run:** G1 port/clock match PASS · G2 DSP = 0 PASS ·
G3 no latches PASS · G4 setup +0.006 / hold +0.511 · G5 `core` instance present PASS.

---

## 5. Power measurement

### SAIF capture

| item | value |
|---|---|
| Source | post-implementation timing sim, 5b run |
| File | `power.saif`, 66 829 bytes |
| Timescale | 1 ps |
| Duration | 141 404 700 ps = 141.40 µs |
| `-strip_path` | `tb_wallace_16x16_wrapper_regio/dut` |
| Nets matched | **505 of 628 = 80.4 %** |
| Confidence level | **High** |
| Capture frequency | 6.9495 ns = 143.9 MHz (matches XDC exactly) |

**Gates:** P1 confidence High **PASS** · P2 annotation 80.4 % **INFO** · P3 sim period = XDC period **PASS**

The unannotated ~20 % is the clock net (deliberately ignored by `read_saif` — its rate
comes from `create_clock`) plus internal nodes with no simulation-netlist counterpart.
Filled probabilistically. Normal for XSim — **must be stated in the write-up**.

### Breakdown

| | vectorless (Low confidence) | SAIF-based (High confidence) |
|---|---|---|
| Total on-chip | 0.471 W | **0.195 W** |
| Dynamic | 0.400 W | **0.125 W** |
| Device static | 0.071 W | 0.070 W |
| I/O | 0.279 W (70 % of dynamic) | — |
| **`core` instance** | — | **0.072 W** |

The vectorless estimate overstated dynamic power by **3.2×**. This is why the SAIF run
matters, and why the earlier 0.471 W figure must not be quoted.

`core` contains **zero flip-flops**, so its 0.072 W is Logic + Signals with no clock
component — exactly the multiplier, with pad power excluded.

---

## 6. Derived-metric definitions

```
t_cp   = 6.937 ns    critical path (DATAPATH_DELAY: logic + route, no setup/skew)
T_clk  = 6.9495 ns   operating period = SAIF capture period = XDC constraint
P_core = 0.072 W     core dynamic power (Logic + Signals of instance `core`)
LUTs   = 427         core only

E   = P_core × T_clk        = 500.4 pJ      energy per multiply (1 mult/clock)
PDP = P_core × t_cp         = 499.5 pJ      power-delay product
EDP = PDP    × t_cp         = 3464.8 pJ·ns  energy-delay product
ADP = LUTs   × t_cp         = 2962.1 LUT·ns area-delay product
```

Cross-check: 0.072 W ÷ 143.895 MHz = 5.0036 × 10⁻¹⁰ J = 500.36 pJ ✓

---

## 7. Recorded CSV row

`results.csv`:

```
design,part,luts_core,luts_total,ff_total,dsp,t_cp_ns,logic_ns,route_ns,
fmax_MHz,T_clk_ns,core_dyn_W,total_W,static_W,E_pJ,PDP_pJ,EDP_pJns,
ADP_LUTns,confidence

wallace-hoc,xc7a35tcpg236-1,427,431,64,0,6.937,2.269,4.668,143.90,6.9495,
0.072,0.195,0.070,500.36,499.46,3464.78,2962.10,High
```

---

## 8. Flow settings — must be identical for every baseline

| Setting | Value |
|---|---|
| Part | xc7a35tcpg236-1 |
| Vivado | 2025.2 |
| `-flatten_hierarchy` | **rebuilt** (default) — never `none` |
| Retiming | off |
| `-max_dsp` | 0 |
| Design top | `wallace_16x16_wrapper_regio` (fully registered, latency 2) |
| XDC | `wallace_timing_regio.xdc`, both I/O sides false-pathed |
| Sim top | `tb_wallace_16x16_wrapper_regio` |
| `saif_scope` | `tb_wallace_16x16_wrapper_regio/dut` |
| `saif_all_signals` | true |
| `xsim.simulate.runtime` | 200us |

`-flatten_hierarchy none` would prevent a `compressor_6_3` from collapsing into three
LUT6s, discarding the exact mechanism the high-order compressors depend on. `rebuilt`
still restores hierarchy for per-instance reporting, which is all `none` was buying.

---

## 9. Caveats to state in any write-up

1. **Fmax 143.9 MHz is CORE-ONLY.** Both I/O sides are false-pathed. Not a system-level figure.
2. **t_cp and Fmax are separate rows.** 6.937 vs 6.9495 differ by setup, skew and uncertainty. Never conflate them.
3. **80.4 % SAIF annotation**, remainder probabilistic.
4. **WNS +0.006 ns is inside run-to-run noise.** A different Vivado version or directive may not close at exactly 6.9495. Consider quoting 6.95 or 7.0 as the reliable figure.
5. **Route is 67 % of the critical path.** Largely placement/congestion, not architecture. Quote logic delay (2.269 ns) and logic levels (10) alongside t_cp if you want a figure the reduction schedule actually controls.
6. **Never compare total on-chip power.** Static dominates and is identical across designs.
7. **Exclude I/O from any core figure.** I/O was 70 % of dynamic power in the vectorless run.
8. **`compressor_4_2` is not in the design.** It exists as a standalone file and must not appear in a "compressor toolkit" claim.
9. **No baselines yet.** Every number above is absolute, not comparative.

---

## 10. Superseded numbers — do not quote

From the earlier project, kept only to avoid confusion:

| | superseded | current |
|---|---|---|
| Wrapper | output-registered only | fully registered |
| LUTs | 377 | 427 core / 431 total |
| "Critical path" | 9.293 ns | 6.937 ns |
| Fmax | 107.6 MHz | 143.9 MHz |
| Registers | 0 (inconsistent with a wrapper run) | 64 |
| Power | 0.471 W total, vectorless | 0.195 W total, SAIF |

The 9.293 ns figure included IBUF + input routing + setup + uncertainty and was derived
as `period − WNS`. It measured a pad-to-flop path, not the multiplier. The two sets are
not comparable and only the current one should be used.

The LUT count rose (377 → 431). Most plausible cause: the tighter closing constraint
drove more aggressive optimisation and logic duplication. Worth confirming if a reviewer
asks, but it is not an error.

---

## 11. Outstanding work

| Task | Status |
|---|---|
| Exhaustive functional proof | done — all 2³² pairs |
| Post-impl timing sim | done — PASS at 200 ns and at speed |
| Timing closure | done — 143.9 MHz core-only |
| SAIF power | done — Confidence High |
| **Plain Wallace baseline (3:2 only)** | generated, 233 cells (209 FA + 24 HA), exhaustively verified — **not yet implemented in Vivado** |
| **Array multiplier baseline** | generated, 240 cells (225 FA + 15 HA) — **verification incomplete** |
| Baseline implementation + comparison table | **not started** |

Each baseline must run its own closure search. Forcing them to 6.9495 ns either fails
or hands this design an unearned advantage.

For context, technology-independent analysis of a depth-greedy FA/HA-only tree:

| | cells | FA/HA crossings | 2-input gate levels |
|---|---|---|---|
| this design | 269 (193 FA + 76 HA) | 12 | 26 |
| FA/HA-only greedy | 233 (209 FA + 24 HA) | 10 | 31 |

The two depth metrics **cross over**. On technology-independent proxies the high-order
compressors are roughly neutral — they buy fewer stages and a more regular structure,
not a clear delay win. Any advantage claim has to rest on the post-route numbers with
baselines run through an identical flow.

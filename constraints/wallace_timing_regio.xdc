# ==========================================================================
#  wallace_timing_regio.xdc -- wallace_16x16_wrapper_regio (latency 2)
#  PUBLISH FROM THIS ONE.
#
#  Pure constraint commands only. Vivado's XDC reader rejects puts / if /
#  concat, so the sanity checks that used to live here now run as gate G1
#  inside report_core_timing.tcl, which is full Tcl.
#
#  Both I/O sides are excluded, so the only timed path is
#      a_q/b_q (FF) -> multiplier -> product (FF)
#  That makes the resulting Fmax a CORE-ONLY figure. Say so in the paper.
#
#  ---------------------------------------------------------------------
#  EDIT THIS between passes.
#     Pass A (search)  : 1.000
#     Pass B (closure) : smallest period with WNS >= 0
#  Must equal CLK_PERIOD in the testbench for the SAIF power run.
#  ---------------------------------------------------------------------
set period 6.9495

create_clock -name clk -period $period [get_ports clk]

# Bus bits must be matched as a[*] / b[*] / product[*]. A bare "a" matches
# nothing, which would leave the multiplier unconstrained and untimed.
set_false_path -from [get_ports {a[*] b[*]}]
set_false_path -to   [get_ports {product[*]}]

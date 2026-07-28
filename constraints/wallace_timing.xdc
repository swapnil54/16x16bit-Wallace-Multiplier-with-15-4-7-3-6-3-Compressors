# ==========================================================================
#  wallace_timing.xdc -- wallace_16x16_wrapper (output-registered, latency 1)
#
#  Pure constraint commands only; sanity checks live in report_core_timing.tcl.
#
#  NOTE the timed path here starts at a package pin, so it includes IBUF and
#  input routing, which are NOT part of the multiplier. Use the _regio pair
#  for anything you publish as a critical-path number.
#
#  EDIT between passes: Pass A 1.000, Pass B the closing period.
# ==========================================================================
set period 1.000

create_clock -name clk -period $period [get_ports clk]

set_input_delay -clock clk 0.000 [get_ports {a[*] b[*]}]

# Excluded so the register-to-pad path can never win WNS and silently become
# the number you report.
set_false_path -to [get_ports {product[*]}]

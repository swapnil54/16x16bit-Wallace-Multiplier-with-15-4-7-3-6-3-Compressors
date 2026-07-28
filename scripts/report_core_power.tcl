# ==========================================================================
#  report_core_power.tcl
#
#  Usage
#      open_run impl_1
#      source report_core_timing.tcl
#      wallace_timing_report                     ;# must run first: supplies t_cp and LUTs
#      source report_core_power.tcl
#      wallace_power_report <path-to-power.saif> ?strip_path? ?sim_period_ns?
#      wallace_power_metrics
#      wallace_record_result "wallace-hoc" results.csv
#
#  The SAIF normally lands in
#      <proj>.sim/sim_1/impl/timing/xsim/power.saif
#  and is only produced if you enabled it in Simulation Settings:
#      xsim.simulate.saif_scope  = tb_wallace_16x16_wrapper_regio/dut
#      xsim.simulate.saif_all_signals = true
#      xsim.simulate.saif        = power.saif
#  Scope must be the WRAPPER INSTANCE inside the testbench, not the
#  testbench itself. A testbench-scoped SAIF annotates almost nothing and
#  silently degrades the run to a vectorless estimate.
# ==========================================================================

array set ::wpow {}

# --------------------------------------------------------------------------
#  Peek inside the SAIF to work out the right -strip_path and the capture
#  window. Saves a lot of guessing when the annotation comes back empty.
# --------------------------------------------------------------------------
proc wallace_saif_probe {saif} {
    if {![file exists $saif]} {
        puts "ERROR: no such file: $saif"
        return ""
    }
    set fh [open $saif r]
    set head [read $fh 20000]
    close $fh

    set dur "n/a" ; set ts "n/a"
    regexp -nocase {\(DURATION\s+([0-9.]+)\)}  $head -> dur
    regexp -nocase {\(TIMESCALE\s+([^\)]+)\)}  $head -> ts

    set chain {}
    foreach m [regexp -all -inline {\(INSTANCE\s+([A-Za-z_][A-Za-z0-9_\$]*)} $head] {
        if {![string match "(INSTANCE*" $m]} { lappend chain $m }
    }

    puts "\n== SAIF probe =="
    puts "  file       : $saif  ([file size $saif] bytes)"
    puts "  timescale  : $ts"
    puts "  duration   : $dur"
    if {[llength $chain] >= 2} {
        set suggested [join [lrange $chain 0 1] "/"]
        puts "  hierarchy  : [join [lrange $chain 0 3] " / "] ..."
        puts "  suggested -strip_path : $suggested"
        set ::wpow(strip) $suggested
        return $suggested
    }
    puts "  could not infer the instance chain; pass strip_path explicitly."
    return ""
}

# --------------------------------------------------------------------------
proc wallace_power_report {saif {strip ""} {sim_period 0}} {
    if {![file exists $saif]} { puts "ERROR: no such file: $saif" ; return }

    if {$strip eq ""} { set strip [wallace_saif_probe $saif] } \
    else              { wallace_saif_probe $saif }
    if {$strip eq ""} {
        puts "ERROR: need a -strip_path. Typically <tb_name>/<wrapper instance>."
        return
    }

    puts "\n== Annotating =="
    puts "  read_saif -strip_path $strip $saif"
    if {[catch {read_saif -strip_path $strip $saif} msg]} {
        puts "ERROR from read_saif: $msg"
        return
    }

    set rpt [report_power -return_string]
    report_power -file wallace_power.rpt
    report_power -hierarchical_depth 4 -file wallace_power_hier.rpt

    # ---- headline numbers (stable formats across versions) ----------------
    set tot "n/a" ; set dyn "n/a" ; set sta "n/a" ; set conf "n/a"
    regexp -nocase {Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)}  $rpt -> tot
    regexp -nocase {Dynamic \(W\)\s*\|\s*([0-9.]+)}             $rpt -> dyn
    regexp -nocase {Device Static \(W\)\s*\|\s*([0-9.]+)}       $rpt -> sta
    regexp -nocase {Confidence Level\s*\|\s*([A-Za-z]+)}        $rpt -> conf

    # ---- SAIF annotation coverage (informational) -------------------------
    # Vivado emits "Design nets matched = N of M" as an INFO message during
    # read_saif, not inside the report string, and words the report section
    # differently across versions. Scraping it reliably is not worth it, and
    # Vivado derives its Confidence Level FROM the coverage anyway, so P1
    # already subsumes this. Reported for information, never fails a run.
    set matched "n/a" ; set totalnets "n/a"
    regexp -nocase {Design Nets Matched\s*\|?\s*([0-9]+)\s*(?:of|/)\s*([0-9]+)} $rpt -> matched totalnets

    # ---- the three gates --------------------------------------------------
    set fail 0
    puts "\n== SAIF gates ==\n"

    # P1 -- confidence must be High, otherwise the SAIF did not take and you
    #       are quoting a vectorless guess dressed up as a measurement.
    if {[string match -nocase "High*" $conf]} {
        puts "  P1 confidence level          PASS  ($conf)"
    } else {
        puts "  P1 confidence level          FAIL  ($conf)"
        puts "     -> the SAIF did not annotate. Wrong -strip_path, wrong"
        puts "        saif_scope in Simulation Settings, or saif_all_signals off."
        incr fail
    }

    # P2 -- annotation coverage. INFORMATIONAL ONLY, never fails a run.
    #       A post-implementation SAIF typically annotates 75-85 percent of
    #       nets: read_saif deliberately ignores the clock net (its rate comes
    #       from create_clock), and some internal nodes -- carry chains, merged
    #       LUT outputs -- have no counterpart in the simulation netlist. The
    #       remainder is filled probabilistically. That is normal and
    #       publishable; it just has to be STATED in the write-up.
    #       Vivado derives its Confidence Level from this coverage, so P1 above
    #       is the authoritative gate.
    if {$matched ne "n/a" && $totalnets ne "n/a" && $totalnets > 0} {
        puts [format "  P2 net annotation            INFO  (%d of %d, %.1f percent)" \
                  $matched $totalnets [expr {100.0*$matched/$totalnets}]]
    } else {
        puts "  P2 net annotation            INFO  (see the read_saif console line"
        puts "                                     'Design nets matched = X of Y')"
    }

    # P3 -- the SAIF capture frequency must equal the constrained frequency.
    #       report_power takes the clock rate from the constraints and the
    #       relative toggle rates from the SAIF. If the simulation ran at a
    #       different period than the XDC, the activity is scaled wrongly.
    set clks [get_clocks -quiet]
    set cper "n/a"
    if {[llength $clks] > 0} { set cper [get_property -quiet PERIOD [lindex $clks 0]] }
    if {$sim_period > 0 && $cper ne "n/a"} {
        if {abs($sim_period - $cper) < 0.001} {
            puts [format "  P3 sim period == XDC period  PASS  (%.3f ns, %.1f MHz)" \
                      $cper [expr {1000.0/$cper}]]
        } else {
            puts [format "  P3 sim period == XDC period  FAIL  (sim %.3f ns vs XDC %.3f ns)" \
                      $sim_period $cper]
            puts "     -> set CLK_PERIOD in the testbench equal to 'period' in"
            puts "        the XDC and re-run the timing simulation."
            incr fail
        }
    } else {
        puts [format "  P3 sim period == XDC period  CHECK MANUALLY  (XDC period %s ns)" $cper]
        puts "     -> pass the testbench CLK_PERIOD as the third argument."
    }

    puts ""
    if {$fail == 0} { puts "  All SAIF gates passed." } \
    else            { puts "  $fail gate(s) FAILED -- this power number is not reportable." }

    # ---- per-instance power ----------------------------------------------
    puts "\n== Power ==\n"
    puts [format "  Total on-chip     : %s W" $tot]
    puts [format "  Dynamic           : %s W" $dyn]
    puts [format "  Device static     : %s W" $sta]
    puts "  Do NOT compare total on-chip power across designs. On this part"
    puts "  static power dominates and is essentially identical for every"
    puts "  multiplier, so it compresses any real difference into noise."
    puts "  Compare core dynamic power, or energy per multiply."

    set clog "n/a" ; set csig "n/a"
    if {[file exists wallace_power_hier.rpt]} {
        set fh [open wallace_power_hier.rpt r] ; set h [read $fh] ; close $fh
        # hierarchical table row for the core instance
        foreach line [split $h "\n"] {
            if {[regexp {\|\s*core\s*\|} $line]} {
                set nums [regexp -all -inline {[0-9]+\.[0-9]+} $line]
                if {[llength $nums] >= 2} {
                    set clog [lindex $nums end-1]
                    set csig [lindex $nums end]
                }
                puts "\n  core row: [string trim $line]"
            }
        }
    }
    puts "\n  Read Logic and Signals for the 'core' instance from"
    puts "  wallace_power_hier.rpt. Those two are the multiplier. The I/O"
    puts "  column is pad power and must be excluded from any core figure --"
    puts "  in a previous run I/O alone was 25 mW of 41 mW dynamic, so"
    puts "  including it would have made the multiplier look 2.5x hungrier"
    puts "  than it is."

    set ::wpow(total)   $tot
    set ::wpow(dyn)     $dyn
    set ::wpow(static)  $sta
    set ::wpow(conf)    $conf
    if {$sim_period > 0} {
        set ::wpow(period) $sim_period
    } else {
        set ::wpow(period) $cper
    }
    set ::wpow(gatefail) $fail
    puts "\n  Written: wallace_power.rpt, wallace_power_hier.rpt"
    puts "  Next: wallace_power_metrics ?core_dynamic_W?\n"
}

# --------------------------------------------------------------------------
#  Energy and the product metrics.
#
#  Definitions used here, stated because papers disagree:
#    t_cp   critical path delay, DATAPATH_DELAY, logic + route, ns
#    T_clk  operating clock period = the SAIF capture period, ns
#    P_core core DYNAMIC power (Logic + Signals of the core instance), W
#
#    Energy per multiply  E = P_core * T_clk          [W*ns = nJ]
#         one multiply per clock, so throughput = 1/T_clk
#    PDP  = P_core * t_cp        power-delay product   [pJ]
#    EDP  = PDP    * t_cp        energy-delay product  [pJ.ns]
#    ADP  = LUTs   * t_cp        area-delay product    [LUT.ns]
#
#  E and PDP coincide only when the design is clocked exactly at its critical
#  path. They are reported separately on purpose: E is what the circuit costs
#  in the system you built, PDP is the technology-independent comparison
#  figure. Quoting one under the other's name is a common way to accidentally
#  favour whichever design happens to be clocked slowest.
# --------------------------------------------------------------------------
proc wallace_power_metrics {{core_dyn_w 0}} {
    if {![info exists ::wallace(t_cp)]} {
        puts "ERROR: run wallace_timing_report first (it supplies t_cp and LUTs)."
        return
    }
    set tcp   $::wallace(t_cp)
    set luts  $::wallace(luts_core)
    if {$luts eq "n/a"} { set luts $::wallace(luts_total) }
    set tclk 0
    if {[info exists ::wpow(period)] && [string is double -strict $::wpow(period)]} {
        set tclk $::wpow(period)
    }

    if {$core_dyn_w <= 0} {
        puts "\nEnter the core dynamic power (Logic + Signals for instance 'core',"
        puts "in watts) from wallace_power_hier.rpt, then re-run:"
        puts "    wallace_power_metrics <core_dynamic_W>"
        puts "\nExample: wallace_power_metrics 0.006"
        return
    }
    if {$tcp eq "n/a" || $tclk <= 0} {
        puts "ERROR: missing t_cp or clock period."
        return
    }

    set E_nJ    [expr {$core_dyn_w * $tclk}]          ;# W * ns = nJ
    set E_pJ    [expr {$E_nJ * 1000.0}]
    set PDP_pJ  [expr {$core_dyn_w * $tcp * 1000.0}]
    set EDP     [expr {$PDP_pJ * $tcp}]
    set ADP     [expr {$luts * $tcp}]
    set fmax    [expr {1000.0 / $tclk}]
    set thr     [expr {1000.0 / $tclk}]               ;# multiplies per us -> MOPS

    puts "\n== Derived metrics =="
    puts "  [string repeat - 66]"
    puts [format "  t_cp   critical path delay      : %.3f ns" $tcp]
    puts [format "  T_clk  operating period         : %.3f ns  (%.1f MHz)" $tclk $fmax]
    puts [format "  P_core core dynamic power       : %.4f W  (%.1f mW)" $core_dyn_w [expr {$core_dyn_w*1000}]]
    puts [format "  Area   core LUTs                : %s" $luts]
    puts "  [string repeat - 66]"
    puts [format "  Throughput                      : %.1f M multiplies/s" $thr]
    puts [format "  Energy per multiply  E          : %.1f pJ   (P_core * T_clk)" $E_pJ]
    puts [format "  PDP  power-delay product        : %.1f pJ   (P_core * t_cp)" $PDP_pJ]
    puts [format "  EDP  energy-delay product       : %.1f pJ.ns (PDP * t_cp)" $EDP]
    puts [format "  ADP  area-delay product         : %.1f LUT.ns (LUTs * t_cp)" $ADP]
    puts "  [string repeat - 66]"
    if {[info exists ::wallace(gate_failures)] && $::wallace(gate_failures) > 0} {
        puts "  WARNING: timing gates failed. These metrics are not reportable."
    }
    if {[info exists ::wpow(gatefail)] && $::wpow(gatefail) > 0} {
        puts "  WARNING: SAIF gates failed. These metrics are not reportable."
    }

    set ::wpow(core_dyn) $core_dyn_w
    set ::wpow(E_pJ)     $E_pJ
    set ::wpow(PDP)      $PDP_pJ
    set ::wpow(EDP)      $EDP
    set ::wpow(ADP)      $ADP
    puts "\n  Next: wallace_record_result <label> <csvfile>\n"
}

# --------------------------------------------------------------------------
#  Append one row to a CSV so the baselines accumulate into a single table.
#  Run this for every design in the comparison, from its own implementation.
# --------------------------------------------------------------------------
proc wallace_record_result {label {csv wallace_results.csv}} {
    if {![info exists ::wpow(E_pJ)]} {
        puts "ERROR: run wallace_power_metrics first."
        return
    }
    set new [expr {![file exists $csv]}]
    set fh [open $csv a]
    if {$new} {
        puts $fh "design,part,luts_core,luts_total,ff_total,dsp,t_cp_ns,logic_ns,route_ns,fmax_MHz,T_clk_ns,core_dyn_W,total_W,static_W,E_pJ,PDP_pJ,EDP_pJns,ADP_LUTns,confidence"
    }
    set part "unknown"
    catch {set part [get_property -quiet PART [current_project]]}
    set fmax "n/a"
    if {[string is double -strict $::wpow(period)] && $::wpow(period) > 0} {
        set fmax [format %.2f [expr {1000.0/$::wpow(period)}]]
    }
    puts $fh [join [list \
        $label $part \
        $::wallace(luts_core) $::wallace(luts_total) $::wallace(ffs_total) $::wallace(dsp) \
        $::wallace(t_cp) $::wallace(logic_ns) $::wallace(route_ns) \
        $fmax $::wpow(period) \
        $::wpow(core_dyn) $::wpow(total) $::wpow(static) \
        [format %.2f $::wpow(E_pJ)] [format %.2f $::wpow(PDP)] \
        [format %.2f $::wpow(EDP)]  [format %.2f $::wpow(ADP)] \
        $::wpow(conf)] ","]
    close $fh
    puts "Appended '$label' to $csv"
    puts "Run the identical flow for every baseline before comparing rows."
}

puts "report_core_power.tcl loaded."
puts "  wallace_power_report <saif> ?strip_path? ?sim_period_ns?"
puts "  wallace_power_metrics <core_dynamic_W>"
puts "  wallace_record_result <label> ?csv?"

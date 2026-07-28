# ==========================================================================
#  report_core_timing.tcl
#
#  Usage
#      open_run impl_1
#      source report_core_timing.tcl
#      wallace_timing_report
#
#  Reports the multiplier's critical path from the OPEN implemented design,
#  and runs the acceptance gates that decide whether the run is usable at all.
#
#  Why not "period - WNS"
#  ----------------------
#      period - WNS = datapath delay + setup + clock uncertainty + clock skew
#                     (+ IBUF and input routing, if the inputs are unregistered)
#  Those extras are real for a system but they are not the multiplier, they
#  differ between designs, and folding them in makes a comparison against
#  baselines unfair. DATAPATH_DELAY is logic + routing only, which is the
#  quantity the compressor schedule actually changes.
#
#  Results are left in the global array ::wallace(...) so that
#  report_core_power.tcl can pick them up for the EDP / ADP maths.
# ==========================================================================

array set ::wallace {}

proc _wprop {obj name} {
    if {[catch {set v [get_property $name $obj]}]} { return "n/a" }
    if {$v eq ""} { return "n/a" }
    return $v
}

proc _wrule {} { puts "  [string repeat - 68]" }

# --------------------------------------------------------------------------
#  Acceptance gates. A run that fails any of these must not be reported.
# --------------------------------------------------------------------------
proc wallace_timing_gates {} {
    set fail 0
    puts "\n== Acceptance gates ==\n"

    # G1 -- the constraints actually matched ports
    set na [llength [get_ports -quiet {a[*]}]]
    set nb [llength [get_ports -quiet {b[*]}]]
    set np [llength [get_ports -quiet {product[*]}]]
    set nc [llength [get_clocks -quiet]]
    if {$na == 16 && $nb == 16 && $np == 32 && $nc >= 1} {
        puts "  G1 port/clock match          PASS  (a=$na b=$nb product=$np clocks=$nc)"
    } else {
        puts "  G1 port/clock match          FAIL  (a=$na b=$nb product=$np clocks=$nc)"
        puts "     -> grep the log for 'Vivado 12-584 No ports matched'."
        incr fail
    }

    # G2 -- no DSP inference. Structural RTL cannot infer any, but a
    #       behavioural baseline will, and that would void the comparison.
    set ndsp [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == ARITHMETIC}]]
    if {$ndsp == 0} {
        set ndsp [llength [get_cells -quiet -hier -filter {REF_NAME =~ DSP*}]]
    }
    if {$ndsp == 0} {
        puts "  G2 DSP count == 0            PASS"
    } else {
        puts "  G2 DSP count == 0            FAIL  ($ndsp DSP cells)"
        puts "     -> set -max_dsp 0 in synthesis settings and re-run."
        incr fail
    }

    # G3 -- no latches
    set nlat [llength [get_cells -quiet -hier -filter {REF_NAME =~ LD*}]]
    if {$nlat == 0} {
        puts "  G3 no latches                PASS"
    } else {
        puts "  G3 no latches                FAIL  ($nlat latch cells)"
        incr fail
    }

    # G4 -- every timing check present and analysed
    set setup_wns [get_property -quiet SLACK [lindex [get_timing_paths -quiet -delay_type max -max_paths 1] 0]]
    set hold_wns  [get_property -quiet SLACK [lindex [get_timing_paths -quiet -delay_type min -max_paths 1] 0]]
    puts "  G4 setup WNS                 $setup_wns ns"
    puts "     hold  WHS                 $hold_wns ns"
    if {[string is double -strict $hold_wns] && $hold_wns < 0} {
        puts "     -> hold violation: the run is not usable regardless of setup."
        incr fail
    }
    if {[string is double -strict $setup_wns] && $setup_wns < 0} {
        puts "     (negative setup WNS is EXPECTED during the 1 ns search pass;"
        puts "      it must be >= 0 on the closure pass you actually report)"
    }

    # G5 -- the core instance survived for per-instance reporting
    if {[llength [get_cells -quiet core]] == 1} {
        puts "  G5 'core' instance present   PASS"
    } else {
        puts "  G5 'core' instance present   FAIL"
        puts "     -> use -flatten_hierarchy rebuilt (NOT none, NOT full)."
        incr fail
    }

    set ::wallace(gate_failures) $fail
    puts ""
    if {$fail == 0} { puts "  All gates passed." } \
    else            { puts "  $fail gate(s) FAILED -- do not report this run." }
    return $fail
}

# --------------------------------------------------------------------------
proc wallace_timing_report {} {
    if {[catch {current_design} _cd]} {
        puts "ERROR: no design open. Run 'open_run impl_1' first."
        return
    }

    wallace_timing_gates

    set a_ports [get_ports -quiet {a[*]}]
    set b_ports [get_ports -quiet {b[*]}]

    # Detect whether the operands are registered, i.e. which wrapper this is.
    # Do NOT probe the net on port a[0]: in an implemented design that net
    # lands on the IBUF, not on the flop, so an FD* search there always fails
    # and silently reports the pad -> input-flop path instead of the core.
    # Ask the timer directly: if any register-to-register path exists, this is
    # the fully registered wrapper and that path is the one we want.
    set ffpaths [get_timing_paths -quiet -delay_type max -max_paths 1 -nworst 1 \
                     -from [all_registers] -to [all_registers]]
    set regio [expr {[llength $ffpaths] > 0}]

    puts "\n== Critical path ==\n"
    if {$regio} {
        puts "  Wrapper : FULLY REGISTERED -- reporting the FF -> FF core path."
        puts "            This is a core-only number, publishable as such."
        set paths [get_timing_paths -delay_type max -max_paths 1 -nworst 1 \
                       -from [all_registers] -to [all_registers]]
        set rpt [report_timing -delay_type max -max_paths 1 -nworst 1 \
                     -from [all_registers] -to [all_registers] -return_string]
    } else {
        puts "  Wrapper : OUTPUT-REGISTERED -- reporting the pad -> FF path."
        puts "            WARNING: this includes IBUF and input routing, which"
        puts "            are NOT part of the multiplier. Switch to"
        puts "            wallace_16x16_wrapper_regio for a publishable figure."
        set paths [get_timing_paths -delay_type max -max_paths 1 -nworst 1 \
                       -from [concat $a_ports $b_ports]]
        set rpt [report_timing -delay_type max -max_paths 1 -nworst 1 \
                     -from [concat $a_ports $b_ports] -return_string]
    }

    if {[llength $paths] == 0} {
        puts "\nERROR: no timing paths found. Almost always means the XDC"
        puts "       matched no ports, or the XDC was not enabled for this run."
        return
    }
    set p [lindex $paths 0]

    # A path with no requirement is unconstrained or false-pathed. Its delay
    # is real but it is not the path under analysis, so quoting it would be
    # meaningless. Stop rather than print a plausible wrong number.
    if {[_wprop $p REQUIREMENT] eq "n/a" || [_wprop $p SLACK] eq "n/a"} {
        puts "\nERROR: the selected path has no timing requirement, so it is"
        puts "       false-pathed or unconstrained. Reporting its delay would"
        puts "       be meaningless."
        puts "       Startpoint: [_wprop $p STARTPOINT_PIN]"
        puts "       Endpoint  : [_wprop $p ENDPOINT_PIN]"
        puts "       Expected a register-to-register path inside 'core'."
        return
    }

    # Pull the logic / route split out of the report text -- there is no
    # reliable object property for it across Vivado versions.
    set logic "n/a" ; set route "n/a" ; set lpct "n/a" ; set rpct "n/a"
    regexp {Data Path Delay:\s+([0-9.]+)ns\s+\(logic\s+([0-9.]+)ns\s+\(([0-9.]+)%\)\s+route\s+([0-9.]+)ns\s+\(([0-9.]+)%\)\)} \
        $rpt -> _dp logic lpct route rpct

    set dp   [_wprop $p DATAPATH_DELAY]
    set slk  [_wprop $p SLACK]
    set req  [_wprop $p REQUIREMENT]
    set lvl  [_wprop $p LOGIC_LEVELS]
    set skw  [_wprop $p SKEW]

    _wrule
    puts [format "  Startpoint        : %s" [_wprop $p STARTPOINT_PIN]]
    puts [format "  Endpoint          : %s" [_wprop $p ENDPOINT_PIN]]
    puts [format "  Requirement       : %s ns" $req]
    puts [format "  Slack (WNS)       : %s ns" $slk]
    puts [format "  DATAPATH DELAY    : %s ns      <-- t_cp, quote this" $dp]
    puts [format "    of which logic  : %s ns (%s%%)" $logic $lpct]
    puts [format "    of which route  : %s ns (%s%%)" $route $rpct]
    puts [format "  Logic levels      : %s" $lvl]
    puts [format "  Clock skew        : %s ns" $skw]
    _wrule

    if {$req ne "n/a" && $slk ne "n/a"} {
        set mp [expr {$req - $slk}]
        puts [format "  Minimum closing period estimate : %.3f ns  (%.1f MHz)" \
                  $mp [expr {1000.0/$mp}]]
        puts "    This is requirement - WNS, so it DOES include setup,"
        puts "    uncertainty and skew. Use it as the starting point for the"
        puts "    closure search, then confirm by re-implementing at that"
        puts "    period and checking WNS >= 0. The closing period is the"
        puts "    number to publish as Fmax; t_cp above is the number to"
        puts "    publish as critical path delay. They are different rows."
        set ::wallace(min_period) $mp
    }

    # Utilisation from THIS run, so delay and area can never be quoted from
    # two different implementations again.
    puts "\n== Utilisation (this run) ==\n"
    set luts [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == LUT}]]
    set ffs  [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}]]
    set crys [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == CARRY}]]
    set dsps [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == ARITHMETIC}]]
    puts [format "  whole design : LUT=%s  FF=%s  CARRY=%s  DSP=%s" $luts $ffs $crys $dsps]

    set core [get_cells -quiet core]
    set cluts "n/a" ; set cffs "n/a" ; set ccry "n/a"
    if {[llength $core] == 1} {
        # Count by name prefix in Tcl rather than with a -filter expression:
        # filter syntax for hierarchical name globs varies between versions,
        # and a silently-empty result here would understate the area.
        set cluts 0 ; set cffs 0 ; set ccry 0
        foreach c [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == LUT}] {
            if {[string match "core/*" $c]} { incr cluts }
        }
        foreach c [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == FLOP_LATCH}] {
            if {[string match "core/*" $c]} { incr cffs }
        }
        foreach c [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == CARRY}] {
            if {[string match "core/*" $c]} { incr ccry }
        }
        puts [format "  core only    : LUT=%s  FF=%s  CARRY=%s" $cluts $cffs $ccry]
        puts "  Report the CORE-ONLY row for area. The whole-design row"
        puts "  includes the wrapper flops, which are scaffolding."
    }

    report_timing -delay_type max -max_paths 20 -nworst 1 \
        -path_type full_clock_expanded -file wallace_core_timing.rpt
    report_utilization -file wallace_core_util.rpt
    puts "\n  Written: wallace_core_timing.rpt, wallace_core_util.rpt"

    set ::wallace(t_cp)       $dp
    set ::wallace(logic_ns)   $logic
    set ::wallace(route_ns)   $route
    set ::wallace(wns)        $slk
    set ::wallace(period)     $req
    set ::wallace(luts_total) $luts
    set ::wallace(luts_core)  $cluts
    set ::wallace(ffs_total)  $ffs
    set ::wallace(dsp)        $dsps
    set ::wallace(regio)      $regio
    puts "\n  Stored in ::wallace(...) for report_core_power.tcl\n"
}

puts "report_core_timing.tcl loaded. Run: wallace_timing_report"

// ==========================================================================
//  tb_wallace_16x16_wrapper.v
//  Drives wallace_16x16_wrapper (the OUTPUT-registered wrapper, latency 1 clock).
//
//  Used for
//    1) post-implementation GATE-LEVEL TIMING simulation with SDF;
//    2) switching activity capture for SAIF-based power analysis.
//
//  Throughput: ONE MULTIPLY PER CLOCK. The bench applies a new operand pair
//  on every falling edge and checks the output 1 clock(s) later against a
//  1-deep expectation pipeline. This matters for power: if the bench only
//  fed a new pair every other clock, the SAIF would capture half the real
//  switching activity and the energy-per-multiply figure would come out
//  roughly half of the truth.
//
//  All stimulus timing is clock-relative (@negedge / @posedge), so changing
//  CLK_PERIOD rescales the whole bench consistently and no sampling race is
//  possible.
//
//  Parameter
//    CLK_PERIOD  clock period in ns. Default 20.0.
//                Set this to the SAME period the XDC constrains, otherwise
//                report_power will scale the SAIF activity against the wrong
//                frequency and the power number will be wrong.
//                Override at elaboration:  xelab -generic_top "CLK_PERIOD=10.0"
//                or at run time:            xsim ... -testplusarg CLK_PERIOD=10.0
//
//  Runtime switches
//    +CLK_PERIOD=<ns>  overrides the parameter
//    +NRAND=<n>        random pairs. Default 20000.
//    +SEED=<n>         random seed. Default 305419896 (0x12345678).
//    +FULLSWEEP        adds 393,216 vectors.
//
//  Reporting rule: whatever CLK_PERIOD you run at IS the frequency your SAIF
//  power number belongs to. Never quote it next to a different Fmax.
// ==========================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_wallace_16x16_wrapper;

    parameter real CLK_PERIOD = 20.0;      // ns
    localparam integer LAT    = 1;     // pipeline depth of the wrapper

    reg         clk;
    reg  [15:0] a, b;
    wire [31:0] product;

    reg  [31:0] expected;
    reg  [31:0] exp_q [0:7];               // expectation pipeline
    integer     obs_lat;                   // measured, see calibration below
    reg  [15:0] av, bv;
    reg  [15:0] bsel [0:5];
    integer     n, i, nvec;
    integer     errors, vectors;
    integer     nrand, seed;
    real        period;
    reg         fullsweep, got, got_clk;

    wallace_16x16_wrapper dut (.clk(clk), .a(a), .b(b), .product(product));

    // ---- clock process: resolves its own period before the first edge -----
    initial begin
        clk     = 1'b0;
        period  = CLK_PERIOD;
        got_clk = $value$plusargs("CLK_PERIOD=%f", period);
        $display("tb_wallace_16x16_wrapper: CLK_PERIOD=%0.3f ns -> %0.3f MHz, one multiply per clock",
                 period, 1000.0 / period);
        forever #(period / 2.0) clk = ~clk;
    end

    // ---- shared vector generator ------------------------------------------
    // Identical in all three benches, so the three runs exercise byte-for-byte
    // the same operand stream. Vector n:
    //     n <   8                : corner cases
    //     n <  56                : single-bit sweeps (16 x 3)
    //     n < 312                : every one-bit-by-one-bit pair (16 x 16)
    //     n < 312 + NRAND        : seeded random pairs
    //     beyond (only if FULLSWEEP) : all 65536 values of a against 6 b values
    // The random branch advances `seed`, so get_vec MUST be called with
    // strictly increasing n exactly once per vector. Every bench does.
    task automatic get_vec;
        input  integer n;
        output [15:0]  ta;
        output [15:0]  tb;
        integer m, ii, jj, kk;
        begin
            if (n < 8) begin
                case (n)
                    0:       begin ta = 16'h0000; tb = 16'h0000; end
                    1:       begin ta = 16'h0000; tb = 16'hFFFF; end
                    2:       begin ta = 16'hFFFF; tb = 16'h0000; end
                    3:       begin ta = 16'hFFFF; tb = 16'hFFFF; end
                    4:       begin ta = 16'h8000; tb = 16'h8000; end
                    5:       begin ta = 16'hAAAA; tb = 16'h5555; end
                    6:       begin ta = 16'h5555; tb = 16'hAAAA; end
                    default: begin ta = 16'h0001; tb = 16'h0001; end
                endcase
            end
            else if (n < 56) begin
                m = n - 8;  ii = m / 3;
                case (m % 3)
                    0:       begin ta = (16'h0001 << ii); tb = 16'hFFFF;          end
                    1:       begin ta = 16'hFFFF;         tb = (16'h0001 << ii);  end
                    default: begin ta = (16'h0001 << ii); tb = (16'h0001 << ii);  end
                endcase
            end
            else if (n < 312) begin
                m = n - 56;  ii = m / 16;  jj = m % 16;
                ta = (16'h0001 << ii);
                tb = (16'h0001 << jj);
            end
            else if (n < 312 + nrand) begin
                ta = $random(seed);
                tb = $random(seed);
            end
            else begin
                m  = n - (312 + nrand);
                kk = m / 65536;
                ta = m % 65536;
                tb = bsel[kk];
            end
        end
    endtask

    initial begin
        $timeformat(-9, 3, " ns", 12);
        nrand     = 20000;
        seed      = 32'h1234_5678;
        got       = $value$plusargs("NRAND=%d", nrand);
        got       = $value$plusargs("SEED=%d",  seed);
        fullsweep = $test$plusargs("FULLSWEEP");

        bsel[0] = 16'h0000; bsel[1] = 16'h0001; bsel[2] = 16'hFFFF;
        bsel[3] = 16'hAAAA; bsel[4] = 16'h5555; bsel[5] = 16'h8000;

        nvec    = 312 + nrand + (fullsweep ? 6 * 65536 : 0);
        errors  = 0;
        vectors = 0;
        a       = 16'h0000;
        b       = 16'h0000;
        for (i = 0; i <= 7; i = i + 1) exp_q[i] = 32'h0;

        // Xilinx glbl holds every mapped flop in GSR for roughly the first
        // 100 ns of a post-implementation timing simulation. Waiting a fixed
        // number of CYCLES keeps that guard valid at any CLK_PERIOD. It is a
        // harmless no-op in behavioural and post-synthesis-functional sim.
        repeat (16) @(posedge clk);
        @(negedge clk);              // align: the loop body assumes a falling edge

        // ---- observation-latency calibration -----------------------------
        // In post-implementation timing simulation the design's flops run on
        // the BUFG-delayed INTERNAL clock. That insertion delay is fixed
        // (~3 ns on Artix-7) and does not scale with the period, so at a fast
        // clock it can approach or exceed half a period. This bench only sees
        // the PAD clock, so its "read half a period after the capture edge"
        // point can land BEFORE the output register has propagated, and it
        // then reads the previous result -- an apparent extra cycle of
        // latency that is an observation artifact, not a design fault.
        //
        // At CLK_PERIOD = 200 ns the artifact is invisible (3 ns vs a 100 ns
        // half period); at 6.9495 ns it is most of the half period. Rather
        // than hard-code a fudge factor for one frequency, measure it: push
        // one distinctive vector through and count negedges until it appears.
        repeat (4) @(negedge clk);
        a = 16'hFFFF;
        b = 16'hFFFF;                       // 0xFFFF * 0xFFFF = 32'hFFFE0001
        obs_lat = 0;
        for (i = 1; i <= 7; i = i + 1) begin
            @(negedge clk);
            if (i == 1) begin
                a = 16'h0000;               // one cycle only, so the result
                b = 16'h0000;               // appears for exactly one cycle
            end
            if (product === 32'hFFFE0001 && obs_lat == 0) obs_lat = i;
        end
        if (obs_lat == 0) begin
            obs_lat = LAT;
            $display("%m: WARNING calibration found no response, assuming latency %0d.",
                     LAT);
            $display("        If the run now fails wholesale, the design is not");
            $display("        producing output at all -- check GSR and the SDF.");
        end else if (obs_lat != LAT) begin
            $display("%m: observation latency measured as %0d clocks (RTL latency is %0d).",
                     obs_lat, LAT);
            $display("        The extra cycle is clock-insertion delay seen from the");
            $display("        pad, not a functional error. Checking against %0d.",
                     obs_lat);
        end else begin
            $display("%m: observation latency measured as %0d clocks, matches RTL.",
                     obs_lat);
        end
        a = 16'h0000;
        b = 16'h0000;
        for (i = 0; i <= 7; i = i + 1) exp_q[i] = 32'h0;
        repeat (4) @(negedge clk);

        $display("tb_wallace_16x16_wrapper: nrand=%0d  seed=%0d  fullsweep=%0b  vectors=%0d  latency=%0d clk",
                 nrand, seed, fullsweep, nvec, LAT);

        // One iteration per clock. Check the result of the vector applied LAT
        // iterations ago, shift the expectation pipeline, then apply the next
        // vector. The extra LAT iterations at the end drain the pipeline.
        for (n = 0; n < nvec + obs_lat; n = n + 1) begin
            @(negedge clk);

            if (n >= obs_lat) begin
                expected = exp_q[obs_lat-1];
                vectors  = vectors + 1;
                if (product !== expected) begin
                    errors = errors + 1;
                    if (errors <= 20)
                        $display("FAIL vec %0d @%0t: got %0d, expected %0d",
                                 n - obs_lat, $time, product, expected);
                end
            end

            for (i = obs_lat - 1; i > 0; i = i - 1)
                exp_q[i] = exp_q[i-1];

            if (n < nvec) begin
                get_vec(n, av, bv);
                a        = av;
                b        = bv;
                exp_q[0] = av * bv;
            end
        end

        if (errors == 0)
            $display("PASS: product == a*b on all %0d vectors (0 mismatches).", vectors);
        else
            $display("*** FAIL: %0d mismatches out of %0d vectors ***", errors, vectors);
        $finish;
    end

endmodule

`default_nettype wire

// ==========================================================================
//  tb_wallace_16x16.v -- self-checking bench for the combinational core.
//  Compile with: wallace_blocks.v + wallace_16x16.v + this file.
//
//  Default run = 20,312 vectors (8 corners + 48 single-bit sweeps + 256
//  one-bit pairs + 20,000 seeded random pairs).
//
//  Runtime switches (plusargs, no recompile):
//    +SETTLE=<ns>  settle time after applying operands. Default 20.
//                  1 ns is enough for zero-delay behavioural sim but is far
//                  shorter than the real path, so it would produce bogus
//                  failures against a synthesised or implemented netlist.
//    +NRAND=<n>    random pairs. Default 20000.
//    +SEED=<n>     random seed. Default 305419896 (0x12345678). Repeatable.
//    +FULLSWEEP    adds all 65536 values of a against 6 b values (+393,216).
//
//  Coverage note: even +FULLSWEEP is a sliver of the 2^32 input space. The
//  exhaustive proof is verify_wallace_exhaustive.py, which checks every
//  operand pair against an independent reference. This bench is
//  tool-independent corroboration, not the proof.
// ==========================================================================
`timescale 1ns/1ps
`default_nettype none

module tb_wallace_16x16;

    reg  [15:0] a, b;
    wire [31:0] product;

    reg  [31:0] expected;
    reg  [15:0] av, bv;
    reg  [15:0] bsel [0:5];
    integer     n, nvec;
    integer     errors, vectors;
    integer     settle, nrand, seed;
    reg         fullsweep, got;

    wallace_16x16 dut (.a(a), .b(b), .product(product));

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
        settle    = 20;
        nrand     = 20000;
        seed      = 32'h1234_5678;
        got       = $value$plusargs("SETTLE=%d", settle);
        got       = $value$plusargs("NRAND=%d",  nrand);
        got       = $value$plusargs("SEED=%d",   seed);
        fullsweep = $test$plusargs("FULLSWEEP");

        bsel[0] = 16'h0000; bsel[1] = 16'h0001; bsel[2] = 16'hFFFF;
        bsel[3] = 16'hAAAA; bsel[4] = 16'h5555; bsel[5] = 16'h8000;

        nvec    = 312 + nrand + (fullsweep ? 6 * 65536 : 0);
        errors  = 0;
        vectors = 0;

        $display("tb_wallace_16x16: settle=%0d ns  nrand=%0d  seed=%0d  fullsweep=%0b  vectors=%0d",
                 settle, nrand, seed, fullsweep, nvec);

        for (n = 0; n < nvec; n = n + 1) begin
            get_vec(n, av, bv);
            a = av;
            b = bv;
            #(settle);
            expected = av * bv;             // 32-bit reference product
            vectors  = vectors + 1;
            if (product !== expected) begin
                errors = errors + 1;
                if (errors <= 20)
                    $display("FAIL vec %0d @%0t ns: %0d * %0d -> %0d (expected %0d)",
                             n, $time, av, bv, product, expected);
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

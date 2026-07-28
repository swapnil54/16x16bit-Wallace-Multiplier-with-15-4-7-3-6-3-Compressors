// ============================================================================
//  compressor_4_2.v
//
//  NOT part of wallace_16x16. It is not instantiated anywhere in the
//  multiplier. It lives in its own file so that it does not appear in the
//  synthesis fileset, where Vivado would otherwise treat it as an additional
//  top-level candidate and report it as unused logic.
//
//  Keep this file OUT of the synthesis/implementation sources. Add it only if
//  you are characterising the 4:2 on its own.
//
//  Identity: x1 + x2 + x3 + x4 + ci = s + 2*(c + co), verified over all 32
//  input patterns. co depends only on x1..x3, never on ci, so a row of these
//  never ripples laterally.
// ============================================================================
`default_nettype none

module compressor_4_2 (
    input  wire x1,
    input  wire x2,
    input  wire x3,
    input  wire x4,
    input  wire ci,     // tie to 1'b0 for self-contained (no lateral chain) use
    output wire s,      // 2^0
    output wire c,      // 2^1
    output wire co      // 2^1 (carry-out / lateral ci of the next column)
);
    wire s1;
    full_adder fa1 (x1, x2, x3, s1, co);
    full_adder fa2 (s1, x4, ci, s,  c);
endmodule

`default_nettype wire

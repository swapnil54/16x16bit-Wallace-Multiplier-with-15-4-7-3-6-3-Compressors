// ============================================================================
//  wallace_blocks.v
//  Exact parallel counters for the 16x16 Wallace-tree multiplier.
//  Each module emits the binary count of its 1-valued inputs.
//
//  Primitive port order (positional instantiation is used below):
//     full_adder (a, b, cin, s, cout)      // s = 2^0, cout = 2^1
//     half_adder (a, b, s, c)              // s = 2^0, c    = 2^1
//
//  Revision note: this file is netlist-identical to the previous version.
//  The only changes are (a) explicit `default_nettype none plus `wire` on
//  every port, (b) removal of the dangling `ovf` net in counter_15_4, and
//  (c) removal of the never-instantiated compressor_4_2 (now in its own
//  file). None of these alter a single logic function -- see
//  verify_wallace_exhaustive.py.
// ============================================================================
`default_nettype none

// ---- Half adder : 2:2 counter ----------------------------------------------
module half_adder (
    input  wire a,
    input  wire b,
    output wire s,     // 2^0
    output wire c      // 2^1
);
    assign s = a ^ b;
    assign c = a & b;
endmodule


// ---- Full adder : 3:2 counter ----------------------------------------------
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire s,     // 2^0
    output wire cout   // 2^1
);
    assign s    = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule


// ---- 5:3 counter (helper used inside the 15:4) -----------------------------
module counter_5_3 (
    input  wire [4:0] x,
    output wire       o0,   // 2^0
    output wire       o1,   // 2^1
    output wire       o2    // 2^2
);
    wire s0, c0, c1;
    full_adder fa0 (x[0], x[1], x[2], s0, c0);
    full_adder fa1 (s0,   x[3], x[4], o0, c1);
    half_adder ha0 (c0,   c1,         o1, o2);
endmodule


// ---- 6:3 compressor --------------------------------------------------------
//  S stays in column i, C1 -> column i+1, C2 -> column i+2.
module compressor_6_3 (
    input  wire [5:0] x,
    output wire       S,    // 2^0
    output wire       C1,   // 2^1
    output wire       C2    // 2^2
);
    wire s0, c0, s1, c1, ch;
    full_adder fa0 (x[0], x[1], x[2], s0, c0);
    full_adder fa1 (x[3], x[4], x[5], s1, c1);
    half_adder ha0 (s0,   s1,         S,  ch);
    full_adder fa2 (c0,   c1,   ch,   C1, C2);
endmodule


// ---- 7:3 compressor --------------------------------------------------------
//  Sum-fold wiring: the 7th input folds with the two group SUMS (fa2), then
//  the three carries combine (fa3).
module compressor_7_3 (
    input  wire [6:0] x,
    output wire       S,    // 2^0
    output wire       C1,   // 2^1
    output wire       C2    // 2^2
);
    wire s0, c0, s1, c1, c2;
    full_adder fa0 (x[0], x[1], x[2], s0, c0);
    full_adder fa1 (x[3], x[4], x[5], s1, c1);
    full_adder fa2 (x[6], s0,   s1,   S,  c2);
    full_adder fa3 (c0,   c1,   c2,   C1, C2);
endmodule


// ---- 15:4 counter ----------------------------------------------------------
//  O0 -> column i, O1 -> i+1, O2 -> i+2, O3 -> i+3.
module counter_15_4 (
    input  wire [14:0] x,
    output wire        O0,  // 2^0
    output wire        O1,  // 2^1
    output wire        O2,  // 2^2
    output wire        O3   // 2^3
);
    // Stage 1: five FAs -> 5 sums (2^0) and 5 carries (2^1)
    wire [4:0] s, c;
    full_adder fa0 (x[0],  x[1],  x[2],  s[0], c[0]);
    full_adder fa1 (x[3],  x[4],  x[5],  s[1], c[1]);
    full_adder fa2 (x[6],  x[7],  x[8],  s[2], c[2]);
    full_adder fa3 (x[9],  x[10], x[11], s[3], c[3]);
    full_adder fa4 (x[12], x[13], x[14], s[4], c[4]);

    // Stage 2: a 5:3 on the sums (2^0..2^2); a 5:3 on the carries (2^1..2^3).
    wire b0, b1, b2;
    wire a1, a2, a3;
    counter_5_3 cs (s, b0, b1, b2);
    counter_5_3 cc (c, a1, a2, a3);

    // Stage 3: merge the two partial counts into one 4-bit number.
    wire w1, w2;
    assign O0 = b0;
    half_adder h1 (b1, a1,     O1, w1);
    full_adder f1 (b2, a2, w1, O2, w2);
    assign O3 = a3 ^ w2;   // the half-adder carry a3 & w2 is identically 0
                           // for a 15-input count, so it is not created.
endmodule

`default_nettype wire

// ==========================================================================
//  wallace_16x16.v  -- 16x16 unsigned exact Wallace-tree multiplier
//  Structural netlist generated directly from the verified §5-§8 schedule.
//  Requires the leaf modules in wallace_blocks.v.
//  Reduction: 16 -> 7 -> 5 -> 3 -> 2 (carry-save) then one 32-bit CPA.
//  The supplied direct testbench checks corners, 48 one-bit-versus-all-ones
//  sweeps, all 256 one-bit pairs, and 20000 random pairs (20,312 total).
//  C32 carry is always 0.
// ==========================================================================
`default_nettype none

module wallace_16x16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [31:0] product
);

    // ---- Partial products: pp_r_c = a[c-r] & b[r] (256 AND terms) --------
    wire pp_0_0 = a[0] & b[0];
    wire pp_0_1 = a[1] & b[0];
    wire pp_0_2 = a[2] & b[0];
    wire pp_0_3 = a[3] & b[0];
    wire pp_0_4 = a[4] & b[0];
    wire pp_0_5 = a[5] & b[0];
    wire pp_0_6 = a[6] & b[0];
    wire pp_0_7 = a[7] & b[0];
    wire pp_0_8 = a[8] & b[0];
    wire pp_0_9 = a[9] & b[0];
    wire pp_0_10 = a[10] & b[0];
    wire pp_0_11 = a[11] & b[0];
    wire pp_0_12 = a[12] & b[0];
    wire pp_0_13 = a[13] & b[0];
    wire pp_0_14 = a[14] & b[0];
    wire pp_0_15 = a[15] & b[0];
    wire pp_1_1 = a[0] & b[1];
    wire pp_1_2 = a[1] & b[1];
    wire pp_1_3 = a[2] & b[1];
    wire pp_1_4 = a[3] & b[1];
    wire pp_1_5 = a[4] & b[1];
    wire pp_1_6 = a[5] & b[1];
    wire pp_1_7 = a[6] & b[1];
    wire pp_1_8 = a[7] & b[1];
    wire pp_1_9 = a[8] & b[1];
    wire pp_1_10 = a[9] & b[1];
    wire pp_1_11 = a[10] & b[1];
    wire pp_1_12 = a[11] & b[1];
    wire pp_1_13 = a[12] & b[1];
    wire pp_1_14 = a[13] & b[1];
    wire pp_1_15 = a[14] & b[1];
    wire pp_1_16 = a[15] & b[1];
    wire pp_2_2 = a[0] & b[2];
    wire pp_2_3 = a[1] & b[2];
    wire pp_2_4 = a[2] & b[2];
    wire pp_2_5 = a[3] & b[2];
    wire pp_2_6 = a[4] & b[2];
    wire pp_2_7 = a[5] & b[2];
    wire pp_2_8 = a[6] & b[2];
    wire pp_2_9 = a[7] & b[2];
    wire pp_2_10 = a[8] & b[2];
    wire pp_2_11 = a[9] & b[2];
    wire pp_2_12 = a[10] & b[2];
    wire pp_2_13 = a[11] & b[2];
    wire pp_2_14 = a[12] & b[2];
    wire pp_2_15 = a[13] & b[2];
    wire pp_2_16 = a[14] & b[2];
    wire pp_2_17 = a[15] & b[2];
    wire pp_3_3 = a[0] & b[3];
    wire pp_3_4 = a[1] & b[3];
    wire pp_3_5 = a[2] & b[3];
    wire pp_3_6 = a[3] & b[3];
    wire pp_3_7 = a[4] & b[3];
    wire pp_3_8 = a[5] & b[3];
    wire pp_3_9 = a[6] & b[3];
    wire pp_3_10 = a[7] & b[3];
    wire pp_3_11 = a[8] & b[3];
    wire pp_3_12 = a[9] & b[3];
    wire pp_3_13 = a[10] & b[3];
    wire pp_3_14 = a[11] & b[3];
    wire pp_3_15 = a[12] & b[3];
    wire pp_3_16 = a[13] & b[3];
    wire pp_3_17 = a[14] & b[3];
    wire pp_3_18 = a[15] & b[3];
    wire pp_4_4 = a[0] & b[4];
    wire pp_4_5 = a[1] & b[4];
    wire pp_4_6 = a[2] & b[4];
    wire pp_4_7 = a[3] & b[4];
    wire pp_4_8 = a[4] & b[4];
    wire pp_4_9 = a[5] & b[4];
    wire pp_4_10 = a[6] & b[4];
    wire pp_4_11 = a[7] & b[4];
    wire pp_4_12 = a[8] & b[4];
    wire pp_4_13 = a[9] & b[4];
    wire pp_4_14 = a[10] & b[4];
    wire pp_4_15 = a[11] & b[4];
    wire pp_4_16 = a[12] & b[4];
    wire pp_4_17 = a[13] & b[4];
    wire pp_4_18 = a[14] & b[4];
    wire pp_4_19 = a[15] & b[4];
    wire pp_5_5 = a[0] & b[5];
    wire pp_5_6 = a[1] & b[5];
    wire pp_5_7 = a[2] & b[5];
    wire pp_5_8 = a[3] & b[5];
    wire pp_5_9 = a[4] & b[5];
    wire pp_5_10 = a[5] & b[5];
    wire pp_5_11 = a[6] & b[5];
    wire pp_5_12 = a[7] & b[5];
    wire pp_5_13 = a[8] & b[5];
    wire pp_5_14 = a[9] & b[5];
    wire pp_5_15 = a[10] & b[5];
    wire pp_5_16 = a[11] & b[5];
    wire pp_5_17 = a[12] & b[5];
    wire pp_5_18 = a[13] & b[5];
    wire pp_5_19 = a[14] & b[5];
    wire pp_5_20 = a[15] & b[5];
    wire pp_6_6 = a[0] & b[6];
    wire pp_6_7 = a[1] & b[6];
    wire pp_6_8 = a[2] & b[6];
    wire pp_6_9 = a[3] & b[6];
    wire pp_6_10 = a[4] & b[6];
    wire pp_6_11 = a[5] & b[6];
    wire pp_6_12 = a[6] & b[6];
    wire pp_6_13 = a[7] & b[6];
    wire pp_6_14 = a[8] & b[6];
    wire pp_6_15 = a[9] & b[6];
    wire pp_6_16 = a[10] & b[6];
    wire pp_6_17 = a[11] & b[6];
    wire pp_6_18 = a[12] & b[6];
    wire pp_6_19 = a[13] & b[6];
    wire pp_6_20 = a[14] & b[6];
    wire pp_6_21 = a[15] & b[6];
    wire pp_7_7 = a[0] & b[7];
    wire pp_7_8 = a[1] & b[7];
    wire pp_7_9 = a[2] & b[7];
    wire pp_7_10 = a[3] & b[7];
    wire pp_7_11 = a[4] & b[7];
    wire pp_7_12 = a[5] & b[7];
    wire pp_7_13 = a[6] & b[7];
    wire pp_7_14 = a[7] & b[7];
    wire pp_7_15 = a[8] & b[7];
    wire pp_7_16 = a[9] & b[7];
    wire pp_7_17 = a[10] & b[7];
    wire pp_7_18 = a[11] & b[7];
    wire pp_7_19 = a[12] & b[7];
    wire pp_7_20 = a[13] & b[7];
    wire pp_7_21 = a[14] & b[7];
    wire pp_7_22 = a[15] & b[7];
    wire pp_8_8 = a[0] & b[8];
    wire pp_8_9 = a[1] & b[8];
    wire pp_8_10 = a[2] & b[8];
    wire pp_8_11 = a[3] & b[8];
    wire pp_8_12 = a[4] & b[8];
    wire pp_8_13 = a[5] & b[8];
    wire pp_8_14 = a[6] & b[8];
    wire pp_8_15 = a[7] & b[8];
    wire pp_8_16 = a[8] & b[8];
    wire pp_8_17 = a[9] & b[8];
    wire pp_8_18 = a[10] & b[8];
    wire pp_8_19 = a[11] & b[8];
    wire pp_8_20 = a[12] & b[8];
    wire pp_8_21 = a[13] & b[8];
    wire pp_8_22 = a[14] & b[8];
    wire pp_8_23 = a[15] & b[8];
    wire pp_9_9 = a[0] & b[9];
    wire pp_9_10 = a[1] & b[9];
    wire pp_9_11 = a[2] & b[9];
    wire pp_9_12 = a[3] & b[9];
    wire pp_9_13 = a[4] & b[9];
    wire pp_9_14 = a[5] & b[9];
    wire pp_9_15 = a[6] & b[9];
    wire pp_9_16 = a[7] & b[9];
    wire pp_9_17 = a[8] & b[9];
    wire pp_9_18 = a[9] & b[9];
    wire pp_9_19 = a[10] & b[9];
    wire pp_9_20 = a[11] & b[9];
    wire pp_9_21 = a[12] & b[9];
    wire pp_9_22 = a[13] & b[9];
    wire pp_9_23 = a[14] & b[9];
    wire pp_9_24 = a[15] & b[9];
    wire pp_10_10 = a[0] & b[10];
    wire pp_10_11 = a[1] & b[10];
    wire pp_10_12 = a[2] & b[10];
    wire pp_10_13 = a[3] & b[10];
    wire pp_10_14 = a[4] & b[10];
    wire pp_10_15 = a[5] & b[10];
    wire pp_10_16 = a[6] & b[10];
    wire pp_10_17 = a[7] & b[10];
    wire pp_10_18 = a[8] & b[10];
    wire pp_10_19 = a[9] & b[10];
    wire pp_10_20 = a[10] & b[10];
    wire pp_10_21 = a[11] & b[10];
    wire pp_10_22 = a[12] & b[10];
    wire pp_10_23 = a[13] & b[10];
    wire pp_10_24 = a[14] & b[10];
    wire pp_10_25 = a[15] & b[10];
    wire pp_11_11 = a[0] & b[11];
    wire pp_11_12 = a[1] & b[11];
    wire pp_11_13 = a[2] & b[11];
    wire pp_11_14 = a[3] & b[11];
    wire pp_11_15 = a[4] & b[11];
    wire pp_11_16 = a[5] & b[11];
    wire pp_11_17 = a[6] & b[11];
    wire pp_11_18 = a[7] & b[11];
    wire pp_11_19 = a[8] & b[11];
    wire pp_11_20 = a[9] & b[11];
    wire pp_11_21 = a[10] & b[11];
    wire pp_11_22 = a[11] & b[11];
    wire pp_11_23 = a[12] & b[11];
    wire pp_11_24 = a[13] & b[11];
    wire pp_11_25 = a[14] & b[11];
    wire pp_11_26 = a[15] & b[11];
    wire pp_12_12 = a[0] & b[12];
    wire pp_12_13 = a[1] & b[12];
    wire pp_12_14 = a[2] & b[12];
    wire pp_12_15 = a[3] & b[12];
    wire pp_12_16 = a[4] & b[12];
    wire pp_12_17 = a[5] & b[12];
    wire pp_12_18 = a[6] & b[12];
    wire pp_12_19 = a[7] & b[12];
    wire pp_12_20 = a[8] & b[12];
    wire pp_12_21 = a[9] & b[12];
    wire pp_12_22 = a[10] & b[12];
    wire pp_12_23 = a[11] & b[12];
    wire pp_12_24 = a[12] & b[12];
    wire pp_12_25 = a[13] & b[12];
    wire pp_12_26 = a[14] & b[12];
    wire pp_12_27 = a[15] & b[12];
    wire pp_13_13 = a[0] & b[13];
    wire pp_13_14 = a[1] & b[13];
    wire pp_13_15 = a[2] & b[13];
    wire pp_13_16 = a[3] & b[13];
    wire pp_13_17 = a[4] & b[13];
    wire pp_13_18 = a[5] & b[13];
    wire pp_13_19 = a[6] & b[13];
    wire pp_13_20 = a[7] & b[13];
    wire pp_13_21 = a[8] & b[13];
    wire pp_13_22 = a[9] & b[13];
    wire pp_13_23 = a[10] & b[13];
    wire pp_13_24 = a[11] & b[13];
    wire pp_13_25 = a[12] & b[13];
    wire pp_13_26 = a[13] & b[13];
    wire pp_13_27 = a[14] & b[13];
    wire pp_13_28 = a[15] & b[13];
    wire pp_14_14 = a[0] & b[14];
    wire pp_14_15 = a[1] & b[14];
    wire pp_14_16 = a[2] & b[14];
    wire pp_14_17 = a[3] & b[14];
    wire pp_14_18 = a[4] & b[14];
    wire pp_14_19 = a[5] & b[14];
    wire pp_14_20 = a[6] & b[14];
    wire pp_14_21 = a[7] & b[14];
    wire pp_14_22 = a[8] & b[14];
    wire pp_14_23 = a[9] & b[14];
    wire pp_14_24 = a[10] & b[14];
    wire pp_14_25 = a[11] & b[14];
    wire pp_14_26 = a[12] & b[14];
    wire pp_14_27 = a[13] & b[14];
    wire pp_14_28 = a[14] & b[14];
    wire pp_14_29 = a[15] & b[14];
    wire pp_15_15 = a[0] & b[15];
    wire pp_15_16 = a[1] & b[15];
    wire pp_15_17 = a[2] & b[15];
    wire pp_15_18 = a[3] & b[15];
    wire pp_15_19 = a[4] & b[15];
    wire pp_15_20 = a[5] & b[15];
    wire pp_15_21 = a[6] & b[15];
    wire pp_15_22 = a[7] & b[15];
    wire pp_15_23 = a[8] & b[15];
    wire pp_15_24 = a[9] & b[15];
    wire pp_15_25 = a[10] & b[15];
    wire pp_15_26 = a[11] & b[15];
    wire pp_15_27 = a[12] & b[15];
    wire pp_15_28 = a[13] & b[15];
    wire pp_15_29 = a[14] & b[15];
    wire pp_15_30 = a[15] & b[15];

    // ---- Internal reduction wires ---------------------------------------
    wire u0_s, u0_c, u1_s, u1_cout, u2_s, u2_cout, u3_s, u3_cout;
    wire u4_s, u4_c, u5_S, u5_C1, u5_C2, u6_S, u6_C1, u6_C2;
    wire u7_S, u7_C1, u7_C2, u8_S, u8_C1, u8_C2, u9_s, u9_c;
    wire u10_S, u10_C1, u10_C2, u11_s, u11_cout, u12_S, u12_C1, u12_C2;
    wire u13_s, u13_cout, u14_S, u14_C1, u14_C2, u15_S, u15_C1, u15_C2;
    wire u16_S, u16_C1, u16_C2, u17_S, u17_C1, u17_C2, u18_S, u18_C1;
    wire u18_C2, u19_S, u19_C1, u19_C2, u20_O0, u20_O1, u20_O2, u20_O3;
    wire u21_O0, u21_O1, u21_O2, u21_O3, u22_O0, u22_O1, u22_O2, u22_O3;
    wire u23_S, u23_C1, u23_C2, u24_S, u24_C1, u24_C2, u25_S, u25_C1;
    wire u25_C2, u26_S, u26_C1, u26_C2, u27_S, u27_C1, u27_C2, u28_S;
    wire u28_C1, u28_C2, u29_S, u29_C1, u29_C2, u30_s, u30_cout, u31_S;
    wire u31_C1, u31_C2, u32_s, u32_cout, u33_S, u33_C1, u33_C2, u34_s;
    wire u34_c, u35_S, u35_C1, u35_C2, u36_S, u36_C1, u36_C2, u37_S;
    wire u37_C1, u37_C2, u38_s, u38_cout, u39_s, u39_c, u40_s, u40_cout;
    wire u41_s, u41_cout, u42_s, u42_c, u43_s, u43_c, u44_s, u44_cout;
    wire u45_s, u45_cout, u46_s, u46_cout, u47_s, u47_c, u48_s, u48_cout;
    wire u49_s, u49_cout, u50_s, u50_cout, u51_s, u51_c, u52_S, u52_C1;
    wire u52_C2, u53_s, u53_cout, u54_s, u54_c, u55_s, u55_cout, u56_s;
    wire u56_c, u57_S, u57_C1, u57_C2, u58_s, u58_cout, u59_s, u59_c;
    wire u60_s, u60_cout, u61_s, u61_c, u62_s, u62_cout, u63_s, u63_cout;
    wire u64_s, u64_c, u65_S, u65_C1, u65_C2, u66_S, u66_C1, u66_C2;
    wire u67_S, u67_C1, u67_C2, u68_S, u68_C1, u68_C2, u69_s, u69_cout;
    wire u70_s, u70_c, u71_s, u71_cout, u72_s, u72_c, u73_s, u73_cout;
    wire u74_s, u74_cout, u75_s, u75_cout, u76_s, u76_cout, u77_s, u77_c;
    wire u78_s, u78_c, u79_s, u79_c, u80_s, u80_c, u81_s, u81_c;
    wire u82_s, u82_c, u83_s, u83_c, u84_s, u84_c, u85_s, u85_cout;
    wire u86_s, u86_cout, u87_s, u87_cout, u88_s, u88_cout, u89_s, u89_cout;
    wire u90_s, u90_cout, u91_s, u91_c, u92_s, u92_cout, u93_s, u93_cout;
    wire u94_s, u94_cout, u95_s, u95_c, u96_s, u96_cout, u97_s, u97_cout;
    wire u98_s, u98_cout, u99_s, u99_c, u100_s, u100_cout, u101_s, u101_cout;
    wire u102_s, u102_cout, u103_s, u103_cout, u104_s, u104_c, u105_s, u105_cout;
    wire u106_s, u106_c, u107_s, u107_cout, u108_s, u108_cout, u109_s, u109_cout;
    wire u110_s, u110_c, u111_s, u111_c, u112_s, u112_c, u113_s, u113_c;
    wire u114_s, u114_c, u115_s, u115_c, u116_s, u116_c, u117_s, u117_c;
    wire u118_s, u118_c, u119_s, u119_c, u120_s, u120_cout, u121_s, u121_cout;
    wire u122_s, u122_c, u123_s, u123_cout, u124_s, u124_cout, u125_s, u125_c;
    wire u126_s, u126_c, u127_s, u127_c, u128_s, u128_c, u129_s, u129_c;
    wire u130_s, u130_cout, u131_s, u131_cout, u132_s, u132_cout, u133_s, u133_c;
    wire u134_s, u134_c, u135_s, u135_c, u136_s, u136_c, u137_s, u137_c;
    wire u138_s, u138_c, u139_s, u139_c;

    // ================= Stage 1 (43 instances) =================
    half_adder     u0 (.a(pp_0_1), .b(pp_1_1), .s(u0_s), .c(u0_c));  // col 1
    full_adder     u1 (.a(pp_0_2), .b(pp_1_2), .cin(pp_2_2), .s(u1_s), .cout(u1_cout));  // col 2
    full_adder     u2 (.a(pp_0_3), .b(pp_1_3), .cin(pp_2_3), .s(u2_s), .cout(u2_cout));  // col 3
    full_adder     u3 (.a(pp_0_4), .b(pp_1_4), .cin(pp_2_4), .s(u3_s), .cout(u3_cout));  // col 4
    half_adder     u4 (.a(pp_3_4), .b(pp_4_4), .s(u4_s), .c(u4_c));  // col 4
    compressor_6_3 u5 (.x({pp_0_5, pp_1_5, pp_2_5, pp_3_5, pp_4_5, pp_5_5}), .S(u5_S), .C1(u5_C1), .C2(u5_C2));  // col 5
    compressor_7_3 u6 (.x({pp_0_6, pp_1_6, pp_2_6, pp_3_6, pp_4_6, pp_5_6, pp_6_6}), .S(u6_S), .C1(u6_C1), .C2(u6_C2));  // col 6
    compressor_7_3 u7 (.x({pp_0_7, pp_1_7, pp_2_7, pp_3_7, pp_4_7, pp_5_7, pp_6_7}), .S(u7_S), .C1(u7_C1), .C2(u7_C2));  // col 7
    compressor_7_3 u8 (.x({pp_0_8, pp_1_8, pp_2_8, pp_3_8, pp_4_8, pp_5_8, pp_6_8}), .S(u8_S), .C1(u8_C1), .C2(u8_C2));  // col 8
    half_adder     u9 (.a(pp_7_8), .b(pp_8_8), .s(u9_s), .c(u9_c));  // col 8
    compressor_7_3 u10 (.x({pp_0_9, pp_1_9, pp_2_9, pp_3_9, pp_4_9, pp_5_9, pp_6_9}), .S(u10_S), .C1(u10_C1), .C2(u10_C2));  // col 9
    full_adder     u11 (.a(pp_7_9), .b(pp_8_9), .cin(pp_9_9), .s(u11_s), .cout(u11_cout));  // col 9
    compressor_7_3 u12 (.x({pp_0_10, pp_1_10, pp_2_10, pp_3_10, pp_4_10, pp_5_10, pp_6_10}), .S(u12_S), .C1(u12_C1), .C2(u12_C2));  // col 10
    full_adder     u13 (.a(pp_7_10), .b(pp_8_10), .cin(pp_9_10), .s(u13_s), .cout(u13_cout));  // col 10
    compressor_6_3 u14 (.x({pp_0_11, pp_1_11, pp_2_11, pp_3_11, pp_4_11, pp_5_11}), .S(u14_S), .C1(u14_C1), .C2(u14_C2));  // col 11
    compressor_6_3 u15 (.x({pp_6_11, pp_7_11, pp_8_11, pp_9_11, pp_10_11, pp_11_11}), .S(u15_S), .C1(u15_C1), .C2(u15_C2));  // col 11
    compressor_7_3 u16 (.x({pp_0_12, pp_1_12, pp_2_12, pp_3_12, pp_4_12, pp_5_12, pp_6_12}), .S(u16_S), .C1(u16_C1), .C2(u16_C2));  // col 12
    compressor_6_3 u17 (.x({pp_7_12, pp_8_12, pp_9_12, pp_10_12, pp_11_12, pp_12_12}), .S(u17_S), .C1(u17_C1), .C2(u17_C2));  // col 12
    compressor_7_3 u18 (.x({pp_0_13, pp_1_13, pp_2_13, pp_3_13, pp_4_13, pp_5_13, pp_6_13}), .S(u18_S), .C1(u18_C1), .C2(u18_C2));  // col 13
    compressor_7_3 u19 (.x({pp_7_13, pp_8_13, pp_9_13, pp_10_13, pp_11_13, pp_12_13, pp_13_13}), .S(u19_S), .C1(u19_C1), .C2(u19_C2));  // col 13
    counter_15_4   u20 (.x({pp_0_14, pp_1_14, pp_2_14, pp_3_14, pp_4_14, pp_5_14, pp_6_14, pp_7_14, pp_8_14, pp_9_14, pp_10_14, pp_11_14, pp_12_14, pp_13_14, pp_14_14}), .O0(u20_O0), .O1(u20_O1), .O2(u20_O2), .O3(u20_O3));  // col 14
    counter_15_4   u21 (.x({pp_0_15, pp_1_15, pp_2_15, pp_3_15, pp_4_15, pp_5_15, pp_6_15, pp_7_15, pp_8_15, pp_9_15, pp_10_15, pp_11_15, pp_12_15, pp_13_15, pp_14_15}), .O0(u21_O0), .O1(u21_O1), .O2(u21_O2), .O3(u21_O3));  // col 15
    counter_15_4   u22 (.x({pp_1_16, pp_2_16, pp_3_16, pp_4_16, pp_5_16, pp_6_16, pp_7_16, pp_8_16, pp_9_16, pp_10_16, pp_11_16, pp_12_16, pp_13_16, pp_14_16, pp_15_16}), .O0(u22_O0), .O1(u22_O1), .O2(u22_O2), .O3(u22_O3));  // col 16
    compressor_7_3 u23 (.x({pp_2_17, pp_3_17, pp_4_17, pp_5_17, pp_6_17, pp_7_17, pp_8_17}), .S(u23_S), .C1(u23_C1), .C2(u23_C2));  // col 17
    compressor_7_3 u24 (.x({pp_9_17, pp_10_17, pp_11_17, pp_12_17, pp_13_17, pp_14_17, pp_15_17}), .S(u24_S), .C1(u24_C1), .C2(u24_C2));  // col 17
    compressor_7_3 u25 (.x({pp_3_18, pp_4_18, pp_5_18, pp_6_18, pp_7_18, pp_8_18, pp_9_18}), .S(u25_S), .C1(u25_C1), .C2(u25_C2));  // col 18
    compressor_6_3 u26 (.x({pp_10_18, pp_11_18, pp_12_18, pp_13_18, pp_14_18, pp_15_18}), .S(u26_S), .C1(u26_C1), .C2(u26_C2));  // col 18
    compressor_6_3 u27 (.x({pp_4_19, pp_5_19, pp_6_19, pp_7_19, pp_8_19, pp_9_19}), .S(u27_S), .C1(u27_C1), .C2(u27_C2));  // col 19
    compressor_6_3 u28 (.x({pp_10_19, pp_11_19, pp_12_19, pp_13_19, pp_14_19, pp_15_19}), .S(u28_S), .C1(u28_C1), .C2(u28_C2));  // col 19
    compressor_7_3 u29 (.x({pp_5_20, pp_6_20, pp_7_20, pp_8_20, pp_9_20, pp_10_20, pp_11_20}), .S(u29_S), .C1(u29_C1), .C2(u29_C2));  // col 20
    full_adder     u30 (.a(pp_12_20), .b(pp_13_20), .cin(pp_14_20), .s(u30_s), .cout(u30_cout));  // col 20
    compressor_7_3 u31 (.x({pp_6_21, pp_7_21, pp_8_21, pp_9_21, pp_10_21, pp_11_21, pp_12_21}), .S(u31_S), .C1(u31_C1), .C2(u31_C2));  // col 21
    full_adder     u32 (.a(pp_13_21), .b(pp_14_21), .cin(pp_15_21), .s(u32_s), .cout(u32_cout));  // col 21
    compressor_7_3 u33 (.x({pp_7_22, pp_8_22, pp_9_22, pp_10_22, pp_11_22, pp_12_22, pp_13_22}), .S(u33_S), .C1(u33_C1), .C2(u33_C2));  // col 22
    half_adder     u34 (.a(pp_14_22), .b(pp_15_22), .s(u34_s), .c(u34_c));  // col 22
    compressor_7_3 u35 (.x({pp_8_23, pp_9_23, pp_10_23, pp_11_23, pp_12_23, pp_13_23, pp_14_23}), .S(u35_S), .C1(u35_C1), .C2(u35_C2));  // col 23
    compressor_7_3 u36 (.x({pp_9_24, pp_10_24, pp_11_24, pp_12_24, pp_13_24, pp_14_24, pp_15_24}), .S(u36_S), .C1(u36_C1), .C2(u36_C2));  // col 24
    compressor_6_3 u37 (.x({pp_10_25, pp_11_25, pp_12_25, pp_13_25, pp_14_25, pp_15_25}), .S(u37_S), .C1(u37_C1), .C2(u37_C2));  // col 25
    full_adder     u38 (.a(pp_11_26), .b(pp_12_26), .cin(pp_13_26), .s(u38_s), .cout(u38_cout));  // col 26
    half_adder     u39 (.a(pp_14_26), .b(pp_15_26), .s(u39_s), .c(u39_c));  // col 26
    full_adder     u40 (.a(pp_12_27), .b(pp_13_27), .cin(pp_14_27), .s(u40_s), .cout(u40_cout));  // col 27
    full_adder     u41 (.a(pp_13_28), .b(pp_14_28), .cin(pp_15_28), .s(u41_s), .cout(u41_cout));  // col 28
    half_adder     u42 (.a(pp_14_29), .b(pp_15_29), .s(u42_s), .c(u42_c));  // col 29

    // ================= Stage 2 (38 instances) =================
    half_adder     u43 (.a(u0_c), .b(u1_s), .s(u43_s), .c(u43_c));  // col 2
    full_adder     u44 (.a(u1_cout), .b(u2_s), .cin(pp_3_3), .s(u44_s), .cout(u44_cout));  // col 3
    full_adder     u45 (.a(u2_cout), .b(u3_s), .cin(u4_s), .s(u45_s), .cout(u45_cout));  // col 4
    full_adder     u46 (.a(u3_cout), .b(u4_c), .cin(u5_S), .s(u46_s), .cout(u46_cout));  // col 5
    half_adder     u47 (.a(u5_C1), .b(u6_S), .s(u47_s), .c(u47_c));  // col 6
    full_adder     u48 (.a(u5_C2), .b(u6_C1), .cin(u7_S), .s(u48_s), .cout(u48_cout));  // col 7
    full_adder     u49 (.a(u6_C2), .b(u7_C1), .cin(u8_S), .s(u49_s), .cout(u49_cout));  // col 8
    full_adder     u50 (.a(u7_C2), .b(u8_C1), .cin(u9_c), .s(u50_s), .cout(u50_cout));  // col 9
    half_adder     u51 (.a(u10_S), .b(u11_s), .s(u51_s), .c(u51_c));  // col 9
    compressor_6_3 u52 (.x({u8_C2, u10_C1, u11_cout, u12_S, u13_s, pp_10_10}), .S(u52_S), .C1(u52_C1), .C2(u52_C2));  // col 10
    full_adder     u53 (.a(u10_C2), .b(u12_C1), .cin(u13_cout), .s(u53_s), .cout(u53_cout));  // col 11
    half_adder     u54 (.a(u14_S), .b(u15_S), .s(u54_s), .c(u54_c));  // col 11
    full_adder     u55 (.a(u12_C2), .b(u14_C1), .cin(u15_C1), .s(u55_s), .cout(u55_cout));  // col 12
    half_adder     u56 (.a(u16_S), .b(u17_S), .s(u56_s), .c(u56_c));  // col 12
    compressor_6_3 u57 (.x({u14_C2, u15_C2, u16_C1, u17_C1, u18_S, u19_S}), .S(u57_S), .C1(u57_C1), .C2(u57_C2));  // col 13
    full_adder     u58 (.a(u16_C2), .b(u17_C2), .cin(u18_C1), .s(u58_s), .cout(u58_cout));  // col 14
    half_adder     u59 (.a(u19_C1), .b(u20_O0), .s(u59_s), .c(u59_c));  // col 14
    full_adder     u60 (.a(u18_C2), .b(u19_C2), .cin(u20_O1), .s(u60_s), .cout(u60_cout));  // col 15
    half_adder     u61 (.a(u21_O0), .b(pp_15_15), .s(u61_s), .c(u61_c));  // col 15
    full_adder     u62 (.a(u20_O2), .b(u21_O1), .cin(u22_O0), .s(u62_s), .cout(u62_cout));  // col 16
    full_adder     u63 (.a(u20_O3), .b(u21_O2), .cin(u22_O1), .s(u63_s), .cout(u63_cout));  // col 17
    half_adder     u64 (.a(u23_S), .b(u24_S), .s(u64_s), .c(u64_c));  // col 17
    compressor_6_3 u65 (.x({u21_O3, u22_O2, u23_C1, u24_C1, u25_S, u26_S}), .S(u65_S), .C1(u65_C1), .C2(u65_C2));  // col 18
    compressor_7_3 u66 (.x({u22_O3, u23_C2, u24_C2, u25_C1, u26_C1, u27_S, u28_S}), .S(u66_S), .C1(u66_C1), .C2(u66_C2));  // col 19
    compressor_7_3 u67 (.x({u25_C2, u26_C2, u27_C1, u28_C1, u29_S, u30_s, pp_15_20}), .S(u67_S), .C1(u67_C1), .C2(u67_C2));  // col 20
    compressor_6_3 u68 (.x({u27_C2, u28_C2, u29_C1, u30_cout, u31_S, u32_s}), .S(u68_S), .C1(u68_C1), .C2(u68_C2));  // col 21
    full_adder     u69 (.a(u29_C2), .b(u31_C1), .cin(u32_cout), .s(u69_s), .cout(u69_cout));  // col 22
    half_adder     u70 (.a(u33_S), .b(u34_s), .s(u70_s), .c(u70_c));  // col 22
    full_adder     u71 (.a(u31_C2), .b(u33_C1), .cin(u34_c), .s(u71_s), .cout(u71_cout));  // col 23
    half_adder     u72 (.a(u35_S), .b(pp_15_23), .s(u72_s), .c(u72_c));  // col 23
    full_adder     u73 (.a(u33_C2), .b(u35_C1), .cin(u36_S), .s(u73_s), .cout(u73_cout));  // col 24
    full_adder     u74 (.a(u35_C2), .b(u36_C1), .cin(u37_S), .s(u74_s), .cout(u74_cout));  // col 25
    full_adder     u75 (.a(u36_C2), .b(u37_C1), .cin(u38_s), .s(u75_s), .cout(u75_cout));  // col 26
    full_adder     u76 (.a(u37_C2), .b(u38_cout), .cin(u39_c), .s(u76_s), .cout(u76_cout));  // col 27
    half_adder     u77 (.a(u40_s), .b(pp_15_27), .s(u77_s), .c(u77_c));  // col 27
    half_adder     u78 (.a(u40_cout), .b(u41_s), .s(u78_s), .c(u78_c));  // col 28
    half_adder     u79 (.a(u41_cout), .b(u42_s), .s(u79_s), .c(u79_c));  // col 29
    half_adder     u80 (.a(u42_c), .b(pp_15_30), .s(u80_s), .c(u80_c));  // col 30

    // ================= Stage 3 (31 instances) =================
    half_adder     u81 (.a(u43_c), .b(u44_s), .s(u81_s), .c(u81_c));  // col 3
    half_adder     u82 (.a(u44_cout), .b(u45_s), .s(u82_s), .c(u82_c));  // col 4
    half_adder     u83 (.a(u45_cout), .b(u46_s), .s(u83_s), .c(u83_c));  // col 5
    half_adder     u84 (.a(u46_cout), .b(u47_s), .s(u84_s), .c(u84_c));  // col 6
    full_adder     u85 (.a(u47_c), .b(u48_s), .cin(pp_7_7), .s(u85_s), .cout(u85_cout));  // col 7
    full_adder     u86 (.a(u48_cout), .b(u49_s), .cin(u9_s), .s(u86_s), .cout(u86_cout));  // col 8
    full_adder     u87 (.a(u49_cout), .b(u50_s), .cin(u51_s), .s(u87_s), .cout(u87_cout));  // col 9
    full_adder     u88 (.a(u50_cout), .b(u51_c), .cin(u52_S), .s(u88_s), .cout(u88_cout));  // col 10
    full_adder     u89 (.a(u52_C1), .b(u53_s), .cin(u54_s), .s(u89_s), .cout(u89_cout));  // col 11
    full_adder     u90 (.a(u52_C2), .b(u53_cout), .cin(u54_c), .s(u90_s), .cout(u90_cout));  // col 12
    half_adder     u91 (.a(u55_s), .b(u56_s), .s(u91_s), .c(u91_c));  // col 12
    full_adder     u92 (.a(u55_cout), .b(u56_c), .cin(u57_S), .s(u92_s), .cout(u92_cout));  // col 13
    full_adder     u93 (.a(u57_C1), .b(u58_s), .cin(u59_s), .s(u93_s), .cout(u93_cout));  // col 14
    full_adder     u94 (.a(u57_C2), .b(u58_cout), .cin(u59_c), .s(u94_s), .cout(u94_cout));  // col 15
    half_adder     u95 (.a(u60_s), .b(u61_s), .s(u95_s), .c(u95_c));  // col 15
    full_adder     u96 (.a(u60_cout), .b(u61_c), .cin(u62_s), .s(u96_s), .cout(u96_cout));  // col 16
    full_adder     u97 (.a(u62_cout), .b(u63_s), .cin(u64_s), .s(u97_s), .cout(u97_cout));  // col 17
    full_adder     u98 (.a(u63_cout), .b(u64_c), .cin(u65_S), .s(u98_s), .cout(u98_cout));  // col 18
    half_adder     u99 (.a(u65_C1), .b(u66_S), .s(u99_s), .c(u99_c));  // col 19
    full_adder     u100 (.a(u65_C2), .b(u66_C1), .cin(u67_S), .s(u100_s), .cout(u100_cout));  // col 20
    full_adder     u101 (.a(u66_C2), .b(u67_C1), .cin(u68_S), .s(u101_s), .cout(u101_cout));  // col 21
    full_adder     u102 (.a(u67_C2), .b(u68_C1), .cin(u69_s), .s(u102_s), .cout(u102_cout));  // col 22
    full_adder     u103 (.a(u68_C2), .b(u69_cout), .cin(u70_c), .s(u103_s), .cout(u103_cout));  // col 23
    half_adder     u104 (.a(u71_s), .b(u72_s), .s(u104_s), .c(u104_c));  // col 23
    full_adder     u105 (.a(u71_cout), .b(u72_c), .cin(u73_s), .s(u105_s), .cout(u105_cout));  // col 24
    half_adder     u106 (.a(u73_cout), .b(u74_s), .s(u106_s), .c(u106_c));  // col 25
    full_adder     u107 (.a(u74_cout), .b(u75_s), .cin(u39_s), .s(u107_s), .cout(u107_cout));  // col 26
    full_adder     u108 (.a(u75_cout), .b(u76_s), .cin(u77_s), .s(u108_s), .cout(u108_cout));  // col 27
    full_adder     u109 (.a(u76_cout), .b(u77_c), .cin(u78_s), .s(u109_s), .cout(u109_cout));  // col 28
    half_adder     u110 (.a(u78_c), .b(u79_s), .s(u110_s), .c(u110_c));  // col 29
    half_adder     u111 (.a(u79_c), .b(u80_s), .s(u111_s), .c(u111_c));  // col 30

    // ================= Stage 4 (28 instances) =================
    half_adder     u112 (.a(u81_c), .b(u82_s), .s(u112_s), .c(u112_c));  // col 4
    half_adder     u113 (.a(u82_c), .b(u83_s), .s(u113_s), .c(u113_c));  // col 5
    half_adder     u114 (.a(u83_c), .b(u84_s), .s(u114_s), .c(u114_c));  // col 6
    half_adder     u115 (.a(u84_c), .b(u85_s), .s(u115_s), .c(u115_c));  // col 7
    half_adder     u116 (.a(u85_cout), .b(u86_s), .s(u116_s), .c(u116_c));  // col 8
    half_adder     u117 (.a(u86_cout), .b(u87_s), .s(u117_s), .c(u117_c));  // col 9
    half_adder     u118 (.a(u87_cout), .b(u88_s), .s(u118_s), .c(u118_c));  // col 10
    half_adder     u119 (.a(u88_cout), .b(u89_s), .s(u119_s), .c(u119_c));  // col 11
    full_adder     u120 (.a(u89_cout), .b(u90_s), .cin(u91_s), .s(u120_s), .cout(u120_cout));  // col 12
    full_adder     u121 (.a(u90_cout), .b(u91_c), .cin(u92_s), .s(u121_s), .cout(u121_cout));  // col 13
    half_adder     u122 (.a(u92_cout), .b(u93_s), .s(u122_s), .c(u122_c));  // col 14
    full_adder     u123 (.a(u93_cout), .b(u94_s), .cin(u95_s), .s(u123_s), .cout(u123_cout));  // col 15
    full_adder     u124 (.a(u94_cout), .b(u95_c), .cin(u96_s), .s(u124_s), .cout(u124_cout));  // col 16
    half_adder     u125 (.a(u96_cout), .b(u97_s), .s(u125_s), .c(u125_c));  // col 17
    half_adder     u126 (.a(u97_cout), .b(u98_s), .s(u126_s), .c(u126_c));  // col 18
    half_adder     u127 (.a(u98_cout), .b(u99_s), .s(u127_s), .c(u127_c));  // col 19
    half_adder     u128 (.a(u99_c), .b(u100_s), .s(u128_s), .c(u128_c));  // col 20
    half_adder     u129 (.a(u100_cout), .b(u101_s), .s(u129_s), .c(u129_c));  // col 21
    full_adder     u130 (.a(u101_cout), .b(u102_s), .cin(u70_s), .s(u130_s), .cout(u130_cout));  // col 22
    full_adder     u131 (.a(u102_cout), .b(u103_s), .cin(u104_s), .s(u131_s), .cout(u131_cout));  // col 23
    full_adder     u132 (.a(u103_cout), .b(u104_c), .cin(u105_s), .s(u132_s), .cout(u132_cout));  // col 24
    half_adder     u133 (.a(u105_cout), .b(u106_s), .s(u133_s), .c(u133_c));  // col 25
    half_adder     u134 (.a(u106_c), .b(u107_s), .s(u134_s), .c(u134_c));  // col 26
    half_adder     u135 (.a(u107_cout), .b(u108_s), .s(u135_s), .c(u135_c));  // col 27
    half_adder     u136 (.a(u108_cout), .b(u109_s), .s(u136_s), .c(u136_c));  // col 28
    half_adder     u137 (.a(u109_cout), .b(u110_s), .s(u137_s), .c(u137_c));  // col 29
    half_adder     u138 (.a(u110_c), .b(u111_s), .s(u138_s), .c(u138_c));  // col 30
    half_adder     u139 (.a(u111_c), .b(u80_c), .s(u139_s), .c(u139_c));  // col 31

    // ---- Final carry-propagate add: product = A + B ---------------------
    wire [31:0] A = {u139_s, u138_s, u137_s, u136_s, u135_s, u134_s, u133_s, u132_s, u131_s, u130_s, u129_s, u128_s, u127_s, u126_s, u125_s, u124_s, u123_s, u122_s, u121_s, u120_s, u119_s, u118_s, u117_s, u116_s, u115_s, u114_s, u113_s, u112_s, u81_s, u43_s, u0_s, pp_0_0};
    wire [31:0] B = {u138_c, u137_c, u136_c, u135_c, u134_c, u133_c, u132_cout, u131_cout, u130_cout, u129_c, u128_c, u127_c, u126_c, u125_c, u124_cout, u123_cout, u122_c, u121_cout, u120_cout, u119_c, u118_c, u117_c, u116_c, u115_c, u114_c, u113_c, u112_c, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
    assign product = A + B;   // synthesizer infers a fast adder

endmodule
`default_nettype wire

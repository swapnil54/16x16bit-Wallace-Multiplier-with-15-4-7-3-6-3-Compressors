// ==========================================================================
//  wallace_16x16_wrapper.v -- output-registered wrapper (latency 1 clock)
//
//  Purpose: give STA a capture flop and give power analysis a clock. The
//  multiplier itself is unchanged and is instantiated as `core`, so
//  report_power's hierarchical table and report_utilization can both be
//  filtered to the multiplier alone.
//
//  IMPORTANT: the operands are NOT registered here, so the only timed path
//  starts at a package pin and therefore includes IBUF + input routing.
//  That is fine for a gate-level functional/power run, but it is NOT the
//  multiplier's own delay. Use wallace_16x16_wrapper_regio for anything you
//  intend to publish as a critical-path number.
//
//  Pairs with: wallace_timing.xdc, tb_wallace_16x16_wrapper.v
// ==========================================================================
`timescale 1ns/1ps
`default_nettype none

module wallace_16x16_wrapper (
    input  wire        clk,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [31:0] product
);

    wire [31:0] mult_out;

    wallace_16x16 core (
        .a       (a),
        .b       (b),
        .product (mult_out)
    );

    always @(posedge clk) begin
        product <= mult_out;
    end

endmodule

`default_nettype wire

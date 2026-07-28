// ==========================================================================
//  wallace_16x16_wrapper_regio.v -- fully registered wrapper (latency 2)
//
//  Operands are captured in input flops, the combinational multiplier drives
//  an output flop. The only timed path is therefore
//
//      a_q/b_q (FF) -> AND array -> reduction tree -> CPA -> product (FF)
//
//  which is the multiplier and nothing else. This is the configuration to
//  use for every number you publish: critical path, Fmax, utilisation and
//  power all come from here.
//
//  The multiplier is instantiated as `core` so that report_power
//  -hierarchical and report_utilization -cells can isolate it from the
//  wrapper flops and the I/O buffers.
//
//  Throughput: one multiply per clock (the pipeline is 2 deep but fully
//  pipelined). Energy per multiply = core dynamic power x clock period.
//
//  Pairs with: wallace_timing_regio.xdc, tb_wallace_16x16_wrapper_regio.v
// ==========================================================================
`timescale 1ns/1ps
`default_nettype none

module wallace_16x16_wrapper_regio (
    input  wire        clk,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [31:0] product
);

    reg  [15:0] a_q, b_q;
    wire [31:0] mult_out;

    wallace_16x16 core (
        .a       (a_q),
        .b       (b_q),
        .product (mult_out)
    );

    always @(posedge clk) begin
        a_q     <= a;
        b_q     <= b;
        product <= mult_out;
    end

endmodule

`default_nettype wire

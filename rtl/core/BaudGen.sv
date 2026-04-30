//==============================================================================
// File Name   : BaudGen.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : Clock divider that generates the 16x oversampling tick for UART
//               transmit and receive logic.
// Notes       : TX and RX share the same tick so loopback tests isolate datapath
//               behavior without introducing independent baud drift.
//==============================================================================

`timescale 1ns / 1ps

module BaudGen #(
    parameter int CLK_FREQ  = 100_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input  logic i_clk,
    input  logic i_resetn,
    output logic o_tick_16x
);

    localparam int TICK_CNT = CLK_FREQ / (BAUD_RATE * 16);
    localparam int TICK_BIT = $clog2(TICK_CNT);

    logic [TICK_BIT-1:0] r_counter;

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_counter  <= '0;
            o_tick_16x <= 1'b0;
        end else if (r_counter == TICK_CNT - 1) begin
            r_counter  <= '0;
            o_tick_16x <= 1'b1;
        end else begin
            r_counter  <= r_counter + 1'b1;
            o_tick_16x <= 1'b0;
        end
    end

endmodule

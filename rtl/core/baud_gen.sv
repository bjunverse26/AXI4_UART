`timescale 1ns / 1ps

module baud_gen #(
    parameter CLK_FREQ      = 100_000_000,
    parameter BAUD_RATE     = 115_200
) (
    input logic             clk,
    input logic             resetn,

    output logic            tick_16x
);

    localparam TICK_CNT = CLK_FREQ / ((BAUD_RATE) * 16);
    localparam TICK_BIT = $clog2(TICK_CNT);

    logic [TICK_BIT-1:0] reg_counter;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            reg_counter <= '0;
            tick_16x <= 1'b0;
        end else begin
            if (reg_counter == TICK_CNT - 1) begin
                reg_counter <= '0;
                tick_16x <= 1'b1;
            end else begin
                reg_counter <= reg_counter + 1;
                tick_16x <= 1'b0;
            end
        end
    end

endmodule

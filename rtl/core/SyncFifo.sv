//==============================================================================
// File Name   : SyncFifo.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : Single-clock byte FIFO used by the UART TX and RX paths.
// Notes       : The pointer MSB is used as a phase bit, allowing full and empty
//               detection with compact pointer comparisons.
//==============================================================================

`timescale 1ns / 1ps

module SyncFifo #(
    parameter int ADDR_WIDTH = 4
) (
    input  logic       i_clk,
    input  logic       i_resetn,

    input  logic       i_wr_en,
    input  logic [7:0] i_wdata,
    output logic       o_full,

    input  logic       i_rd_en,
    output logic [7:0] o_rdata,
    output logic       o_empty
);

    localparam int MEM_DEPTH = 1 << ADDR_WIDTH;

    logic [7:0]          r_fifo_mem [0:MEM_DEPTH-1];
    logic [ADDR_WIDTH:0] r_wptr;
    logic [ADDR_WIDTH:0] r_rptr;

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_wptr  <= '0;
            r_rptr  <= '0;
            o_rdata <= '0;
        end else begin
            if (i_wr_en && !o_full) begin
                r_fifo_mem[r_wptr[ADDR_WIDTH-1:0]] <= i_wdata;
                r_wptr <= r_wptr + 1'b1;
            end

            if (i_rd_en && !o_empty) begin
                o_rdata <= r_fifo_mem[r_rptr[ADDR_WIDTH-1:0]];
                r_rptr <= r_rptr + 1'b1;
            end
        end
    end

    assign o_full  = (r_wptr[ADDR_WIDTH] != r_rptr[ADDR_WIDTH])
                   && (r_wptr[ADDR_WIDTH-1:0] == r_rptr[ADDR_WIDTH-1:0]);
    assign o_empty = (r_wptr == r_rptr);

endmodule

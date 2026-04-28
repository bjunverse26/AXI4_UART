`timescale 1ns / 1ps

module sync_fifo #(
    parameter ADDR_WIDTH = 4
) (
    input  logic                    clk,
    input  logic                    resetn,

    input  logic                    wr_en,
    input  logic [7:0]              wdata,
    output logic                    full,

    input  logic                    rd_en,
    output logic [7:0]              rdata,
    output logic                    empty
);

    localparam MEM_DEPTH = 1 << ADDR_WIDTH;

    logic [7:0]             fifo_mem [0:MEM_DEPTH-1];
    logic [ADDR_WIDTH:0]    wptr;
    logic [ADDR_WIDTH:0]    rptr;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            wptr  <= '0;
            rptr  <= '0;
            rdata <= '0;
        end else begin
            if (wr_en && !full) begin
                fifo_mem[wptr[ADDR_WIDTH-1:0]] <= wdata;
                wptr <= wptr + 1'b1;
            end

            if (rd_en && !empty) begin
                rdata <= fifo_mem[rptr[ADDR_WIDTH-1:0]];
                rptr <= rptr + 1'b1;
            end
        end
    end

    assign full  = (wptr[ADDR_WIDTH] != rptr[ADDR_WIDTH]) &&
                   (wptr[ADDR_WIDTH-1:0] == rptr[ADDR_WIDTH-1:0]);

    assign empty = (wptr == rptr);

endmodule

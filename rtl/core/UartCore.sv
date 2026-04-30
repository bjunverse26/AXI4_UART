//==============================================================================
// File Name   : UartCore.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : UART datapath wrapper containing baud generation, TX/RX FIFOs,
//               transmitter, and receiver.
// Notes       : Bytes are pulled from the TX FIFO only when the transmitter is
//               idle, decoupling AXI register writes from serial line timing.
//==============================================================================

`timescale 1ns / 1ps

module UartCore #(
    parameter int CLK_FREQ   = 100_000_000,
    parameter int BAUD_RATE  = 115_200,
    parameter int ADDR_WIDTH = 4
) (
    input  logic       i_clk,
    input  logic       i_resetn,
    output logic       o_tx,
    input  logic       i_rx,
    input  logic [7:0] i_tx_wdata,
    input  logic       i_tx_wr_en,
    output logic       o_tx_full,
    input  logic       i_rx_rd_en,
    output logic [7:0] o_rx_rdata,
    output logic       o_rx_empty
);

    typedef enum logic [1:0] {
        S_TX_IDLE,
        S_TX_START,
        S_TX_WAIT
    } tx_state_t;

    tx_state_t r_tx_state;

    logic       w_tick_16x;
    logic [7:0] w_tx_din;
    logic       w_tx_fifo_empty;
    logic       w_tx_busy;
    logic       w_tx_done;
    logic       r_tx_rd_en;
    logic       r_tx_start;
    logic [7:0] w_rx_dout;
    logic       w_rx_done;
    logic       w_rx_wr_en;
    logic       w_rx_fifo_full;

    assign w_rx_wr_en = !w_rx_fifo_full && w_rx_done;

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_tx_state <= S_TX_IDLE;
            r_tx_rd_en <= 1'b0;
            r_tx_start <= 1'b0;
        end else begin
            r_tx_rd_en <= 1'b0;
            r_tx_start <= 1'b0;

            case (r_tx_state)
                S_TX_IDLE: begin
                    if (!w_tx_fifo_empty && !w_tx_busy) begin
                        r_tx_rd_en <= 1'b1;
                        r_tx_state <= S_TX_START;
                    end
                end

                S_TX_START: begin
                    r_tx_start <= 1'b1;
                    r_tx_state <= S_TX_WAIT;
                end

                S_TX_WAIT: begin
                    if (w_tx_done) begin
                        r_tx_state <= S_TX_IDLE;
                    end
                end

                default: begin
                    r_tx_state <= S_TX_IDLE;
                end
            endcase
        end
    end

    BaudGen #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_baud_gen (
        .i_clk      (i_clk),
        .i_resetn   (i_resetn),
        .o_tick_16x (w_tick_16x)
    );

    SyncFifo #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_tx_fifo (
        .i_clk    (i_clk),
        .i_resetn (i_resetn),
        .i_wr_en  (i_tx_wr_en),
        .i_wdata  (i_tx_wdata),
        .o_full   (o_tx_full),
        .i_rd_en  (r_tx_rd_en),
        .o_rdata  (w_tx_din),
        .o_empty  (w_tx_fifo_empty)
    );

    UartTx u_uart_tx (
        .i_clk       (i_clk),
        .i_resetn    (i_resetn),
        .i_tx_start  (r_tx_start),
        .i_din       (w_tx_din),
        .i_tick_16x  (w_tick_16x),
        .o_tx        (o_tx),
        .o_tx_busy   (w_tx_busy),
        .o_tx_done   (w_tx_done)
    );

    UartRx u_uart_rx (
        .i_clk      (i_clk),
        .i_resetn   (i_resetn),
        .i_rx       (i_rx),
        .i_tick_16x (w_tick_16x),
        .o_dout     (w_rx_dout),
        .o_rx_done  (w_rx_done)
    );

    SyncFifo #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_rx_fifo (
        .i_clk    (i_clk),
        .i_resetn (i_resetn),
        .i_wr_en  (w_rx_wr_en),
        .i_wdata  (w_rx_dout),
        .o_full   (w_rx_fifo_full),
        .i_rd_en  (i_rx_rd_en),
        .o_rdata  (o_rx_rdata),
        .o_empty  (o_rx_empty)
    );

endmodule

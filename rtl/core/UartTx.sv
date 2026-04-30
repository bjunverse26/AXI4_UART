//==============================================================================
// File Name   : UartTx.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : UART transmitter that serializes one byte into start, data, and
//               stop bits.
// Notes       : Each UART bit is held for sixteen oversampling ticks to match the
//               receiver timing model used in loopback verification.
//==============================================================================

`timescale 1ns / 1ps

module UartTx (
    input  logic       i_clk,
    input  logic       i_resetn,
    input  logic       i_tx_start,
    input  logic [7:0] i_din,
    input  logic       i_tick_16x,
    output logic       o_tx,
    output logic       o_tx_busy,
    output logic       o_tx_done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t r_state;

    logic [7:0] r_din;
    logic [3:0] r_tick_cnt;
    logic [2:0] r_bit_cnt;

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_state    <= S_IDLE;
            r_din      <= '0;
            r_tick_cnt <= '0;
            r_bit_cnt  <= '0;
            o_tx       <= 1'b1;
            o_tx_busy  <= 1'b0;
            o_tx_done  <= 1'b0;
        end else begin
            o_tx_done <= 1'b0;

            case (r_state)
                S_IDLE: begin
                    o_tx       <= 1'b1;
                    o_tx_busy  <= 1'b0;
                    r_tick_cnt <= '0;
                    r_bit_cnt  <= '0;

                    if (i_tx_start) begin
                        r_din     <= i_din;
                        o_tx_busy <= 1'b1;
                        r_state   <= S_START;
                    end
                end

                S_START: begin
                    o_tx      <= 1'b0;
                    o_tx_busy <= 1'b1;

                    if (i_tick_16x) begin
                        if (r_tick_cnt == 4'd15) begin
                            r_tick_cnt <= '0;
                            r_state    <= S_DATA;
                        end else begin
                            r_tick_cnt <= r_tick_cnt + 1'b1;
                        end
                    end
                end

                S_DATA: begin
                    o_tx      <= r_din[0];
                    o_tx_busy <= 1'b1;

                    if (i_tick_16x) begin
                        if (r_tick_cnt == 4'd15) begin
                            r_tick_cnt <= '0;

                            if (r_bit_cnt == 3'd7) begin
                                r_bit_cnt <= '0;
                                r_state   <= S_STOP;
                            end else begin
                                r_din     <= r_din >> 1;
                                r_bit_cnt <= r_bit_cnt + 1'b1;
                            end
                        end else begin
                            r_tick_cnt <= r_tick_cnt + 1'b1;
                        end
                    end
                end

                S_STOP: begin
                    o_tx      <= 1'b1;
                    o_tx_busy <= 1'b1;

                    if (i_tick_16x) begin
                        if (r_tick_cnt == 4'd15) begin
                            r_tick_cnt <= '0;
                            o_tx_done  <= 1'b1;
                            o_tx_busy  <= 1'b0;
                            r_state    <= S_IDLE;
                        end else begin
                            r_tick_cnt <= r_tick_cnt + 1'b1;
                        end
                    end
                end

                default: begin
                    r_state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

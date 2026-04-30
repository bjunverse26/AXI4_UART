//==============================================================================
// File Name   : UartRx.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : UART receiver with input synchronization and 16x oversampling.
// Notes       : The RX pin is synchronized before entering the FSM so metastable
//               input behavior is not fed directly into frame decoding.
//==============================================================================

`timescale 1ns / 1ps

module UartRx (
    input  logic       i_clk,
    input  logic       i_resetn,
    input  logic       i_rx,
    input  logic       i_tick_16x,
    output logic [7:0] o_dout,
    output logic       o_rx_done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t r_state;

    logic [7:0] r_dout;
    logic [3:0] r_tick_cnt;
    logic [2:0] r_bit_cnt;
    logic       r_rx_sync1;
    logic       r_rx_sync2;

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_rx_sync1 <= 1'b1;
            r_rx_sync2 <= 1'b1;
        end else begin
            r_rx_sync1 <= i_rx;
            r_rx_sync2 <= r_rx_sync1;
        end
    end

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_state    <= S_IDLE;
            r_dout     <= '0;
            r_tick_cnt <= '0;
            r_bit_cnt  <= '0;
            o_dout     <= '0;
            o_rx_done  <= 1'b0;
        end else begin
            o_rx_done <= 1'b0;

            case (r_state)
                S_IDLE: begin
                    r_tick_cnt <= '0;
                    r_bit_cnt  <= '0;

                    if (r_rx_sync2 == 1'b0) begin
                        r_state <= S_START;
                    end
                end

                S_START: begin
                    if (i_tick_16x) begin
                        if (r_tick_cnt == 4'd7) begin
                            r_tick_cnt <= '0;

                            if (r_rx_sync2 == 1'b0) begin
                                r_state <= S_DATA;
                            end else begin
                                r_state <= S_IDLE;
                            end
                        end else begin
                            r_tick_cnt <= r_tick_cnt + 1'b1;
                        end
                    end
                end

                S_DATA: begin
                    if (i_tick_16x) begin
                        if (r_tick_cnt == 4'd15) begin
                            r_dout     <= {r_rx_sync2, r_dout[7:1]};
                            r_tick_cnt <= '0;

                            if (r_bit_cnt == 3'd7) begin
                                r_bit_cnt <= '0;
                                r_state   <= S_STOP;
                            end else begin
                                r_bit_cnt <= r_bit_cnt + 1'b1;
                            end
                        end else begin
                            r_tick_cnt <= r_tick_cnt + 1'b1;
                        end
                    end
                end

                S_STOP: begin
                    if (i_tick_16x) begin
                        if (r_tick_cnt == 4'd15) begin
                            r_tick_cnt <= '0;

                            if (r_rx_sync2 == 1'b1) begin
                                o_dout    <= r_dout;
                                o_rx_done <= 1'b1;
                            end

                            r_state <= S_IDLE;
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

`timescale 1ns / 1ps

module uart_rx (
    input  logic            clk,
    input  logic            resetn,

    input  logic            rx,
    input  logic            tick_16x,

    output logic [7:0]      dout,
    output logic            rx_done
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t     rx_state;

    logic [7:0] reg_dout;
    logic [3:0] reg_cnt;
    logic [2:0] reg_bit;

    logic       rx_sync1;
    logic       rx_sync2;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_state <= IDLE;
            reg_dout <= '0;
            reg_cnt  <= '0;
            reg_bit  <= '0;
            dout     <= '0;
            rx_done  <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            case (rx_state)
                IDLE: begin
                    reg_cnt <= '0;
                    reg_bit <= '0;

                    if (rx_sync2 == 1'b0) begin
                        rx_state <= START;
                    end
                end

                START: begin
                    if (tick_16x) begin
                        if (reg_cnt == 4'd7) begin
                            reg_cnt <= '0;
                            if (rx_sync2 == 1'b0) begin
                                rx_state <= DATA;
                            end else begin
                                rx_state <= IDLE;
                            end
                        end else begin
                            reg_cnt <= reg_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    if (tick_16x) begin
                        if (reg_cnt == 4'd15) begin
                            reg_dout <= {rx_sync2, reg_dout[7:1]};
                            reg_cnt <= '0;

                            if (reg_bit == 3'd7) begin
                                reg_bit  <= '0;
                                rx_state <= STOP;
                            end else begin
                                reg_bit <= reg_bit + 1'b1;
                            end
                        end else begin
                            reg_cnt <= reg_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (tick_16x) begin
                        if (reg_cnt == 4'd15) begin
                            reg_cnt <= '0;
                            if (rx_sync2 == 1'b1) begin
                                dout    <= reg_dout;
                                rx_done <= 1'b1;
                            end
                            rx_state <= IDLE;
                        end else begin
                            reg_cnt <= reg_cnt + 1'b1;
                        end
                    end
                end

                default: begin
                    rx_state <= IDLE;
                end
            endcase
        end
    end

endmodule

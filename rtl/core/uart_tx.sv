module uart_tx (
    input  logic                clk,
    input  logic                resetn,

    input  logic                tx_start,
    input  logic [7:0]          din,
    input  logic                tick_16x,

    output logic                tx,
    output logic                tx_busy,
    output logic                tx_done
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t     tx_state;

    logic [7:0] reg_din;
    logic [3:0] reg_cnt;
    logic [2:0] reg_bit;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            tx_state <= IDLE;
            reg_din  <= '0;
            reg_cnt  <= '0;
            reg_bit  <= '0;
            tx       <= 1'b1;
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (tx_state)
                IDLE: begin
                    tx <= 1'b1;
                    reg_cnt <= '0;
                    reg_bit <= '0;

                    if (tx_start) begin
                        reg_din  <= din;
                        tx_state <= START;
                        tx_busy  <= 1'b1;
                    end
                end

                START: begin
                    tx <= 1'b0;

                    if (tick_16x) begin
                        if (reg_cnt == 4'd15) begin
                            reg_cnt  <= '0;
                            tx_state <= DATA;
                            tx_busy  <= 1'b1;
                        end else begin
                            reg_cnt <= reg_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    tx <= reg_din[0];

                    if (tick_16x) begin
                        if (reg_cnt == 4'd15) begin
                            reg_cnt <= '0;

                            if (reg_bit == 3'd7) begin
                                reg_bit  <= '0;
                                tx_state <= STOP;
                                tx_busy  <= 1'b1;
                            end else begin
                                reg_din <= reg_din >> 1;
                                reg_bit <= reg_bit + 1'b1;
                            end
                        end else begin
                            reg_cnt <= reg_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;

                    if (tick_16x) begin
                        if (reg_cnt == 4'd15) begin
                            reg_cnt  <= '0;
                            tx_done  <= 1'b1;
                            tx_state <= IDLE;
                            tx_busy  <= 1'b0;
                        end else begin
                            reg_cnt <= reg_cnt + 1'b1;
                        end
                    end
                end

                default: begin
                    tx_state <= IDLE;
                end
            endcase
        end
    end

endmodule

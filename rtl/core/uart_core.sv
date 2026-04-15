module uart_core #(
    parameter CLK_FREQ          = 100_000_000,
    parameter BAUD_RATE         = 115_200,
    parameter ADDR_WIDTH        = 4
) (
    input logic                 clk,
    input logic                 resetn,

    output logic                tx,
    input logic                 rx,

    input logic [7:0]           tx_wdata,
    input logic                 tx_wr_en,
    output logic                tx_full,

    input logic                 rx_rd_en,
    output logic [7:0]          rx_rdata,
    output logic                rx_empty
);

    typedef enum logic [1:0] {
        TX_IDLE = 2'b00,
        TX_START = 2'b01,
        TX_WAIT = 2'b10
    } tx_state_t;

    tx_state_t tx_state;
    logic tick_16x;

    logic [7:0] tx_din;
    logic tx_fifo_empty;
    logic tx_busy;
    logic tx_done;
    logic tx_rd_en;
    logic tx_start;

    logic [7:0] rx_dout;
    logic rx_done;
    logic rx_wr_en;
    logic rx_fifo_full;

    assign rx_wr_en = !rx_fifo_full && rx_done;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            tx_state <= TX_IDLE;
            tx_rd_en <= 1'b0;
            tx_start <= 1'b0;
        end else begin
            tx_rd_en <= 1'b0;
            tx_start <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    if (!tx_fifo_empty && !tx_busy) begin
                        tx_rd_en <= 1'b1;
                        tx_state <= TX_START;
                    end
                end

                TX_START: begin
                    tx_start <= 1'b1;
                    tx_state <= TX_WAIT;
                end

                TX_WAIT: begin
                    if (tx_done) begin
                        tx_state <= TX_IDLE;
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_baud_gen (
        .clk(clk),
        .resetn(resetn),
        .tick_16x(tick_16x)
    );

    sync_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_tx_fifo (
        .clk(clk),
        .resetn(resetn),
        .wr_en(tx_wr_en),
        .wdata(tx_wdata),
        .full(tx_full),
        .rd_en(tx_rd_en),
        .rdata(tx_din),
        .empty(tx_fifo_empty)
    );

    uart_tx u_tx (
        .clk(clk),
        .resetn(resetn),
        .tx_start(tx_start),
        .din(tx_din),
        .tick_16x(tick_16x),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    uart_rx u_rx (
        .clk(clk),
        .resetn(resetn),
        .rx(rx),
        .tick_16x(tick_16x),
        .dout(rx_dout),
        .rx_done(rx_done)
    );

    sync_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_rx_fifo (
        .clk(clk),
        .resetn(resetn),
        .wr_en(rx_wr_en),
        .wdata(rx_dout),
        .full(rx_fifo_full),
        .rd_en(rx_rd_en),
        .rdata(rx_rdata),
        .empty(rx_empty)
    );

endmodule

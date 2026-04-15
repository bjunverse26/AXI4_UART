module axi_uart #(
    parameter CLK_FREQ          = 100_000_000,
    parameter BAUD_RATE         = 115_200,
    parameter AXI_ADDR_WIDTH    = 32,
    parameter AXI_DATA_WIDTH    = 32,
    parameter AXI_STRB          = (AXI_DATA_WIDTH / 8),
    parameter FIFO_ADDR_WIDTH   = 4
) (
    input logic                         s_axi_aclk,
    input logic                         s_axi_aresetn,

    input logic [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input logic [2:0]                   s_axi_awprot,
    input logic                         s_axi_awvalid,
    output logic                        s_axi_awready,

    input logic [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input logic [AXI_STRB-1:0]          s_axi_wstrb,
    input logic                         s_axi_wvalid,
    output logic                        s_axi_wready,

    output logic [1:0]                  s_axi_bresp,
    output logic                        s_axi_bvalid,
    input logic                         s_axi_bready,

    input logic [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input logic [2:0]                   s_axi_arprot,
    input logic                         s_axi_arvalid,
    output logic                        s_axi_arready,

    output logic [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]                  s_axi_rresp,
    output logic                        s_axi_rvalid,
    input logic                         s_axi_rready,

    output logic                        tx,
    input logic                         rx
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_CTRL   = 'h0;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_STATUS = 'h1;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_TXDATA = 'h2;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_RXDATA = 'h3;

    typedef enum logic [1:0] {
        W_IDLE = 2'b00,
        W_DATA = 2'b01,
        W_ADDR = 2'b10,
        W_RESP = 2'b11
    } w_state_t;

    typedef enum logic [1:0] {
        R_IDLE = 2'b00,
        R_POP  = 2'b01,
        R_RESP = 2'b10
    } r_state_t;

    w_state_t w_state;
    r_state_t r_state;

    logic aw_hs;
    logic w_hs;
    logic b_hs;
    logic ar_hs;
    logic r_hs;

    logic [AXI_ADDR_WIDTH-1:2]  wr_addr;
    logic [AXI_DATA_WIDTH-1:0]  wr_data;
    logic [AXI_STRB-1:0]        wr_strb;
    logic [AXI_ADDR_WIDTH-1:2]  rd_addr;

    logic [31:0] ctrl_reg;
    logic [AXI_DATA_WIDTH-1:0]  rd_data;

    logic [7:0]                 tx_wdata;
    logic                       tx_wr_en;
    logic                       tx_full;
    logic                       rx_rd_en;
    logic [7:0]                 rx_rdata;
    logic                       rx_empty;

    assign aw_hs = s_axi_awvalid && s_axi_awready;
    assign w_hs  = s_axi_wvalid && s_axi_wready;
    assign b_hs  = s_axi_bvalid && s_axi_bready;
    assign ar_hs = s_axi_arvalid && s_axi_arready;
    assign r_hs  = s_axi_rvalid && s_axi_rready;

    always_comb begin
        s_axi_awready = 1'b0;
        s_axi_wready = 1'b0;
        s_axi_bvalid = 1'b0;

        case (w_state)
            W_IDLE: begin
                s_axi_awready = 1'b1;
                s_axi_wready = 1'b1;
            end

            W_DATA: begin
                s_axi_wready = 1'b1;
            end

            W_ADDR: begin
                s_axi_awready = 1'b1;
            end

            W_RESP: begin
                s_axi_bvalid = 1'b1;
            end
        endcase
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            w_state <= W_IDLE;
            s_axi_bresp <= RESP_OKAY;
            wr_addr <= '0;
            wr_data <= '0;
            wr_strb <= '0;
            ctrl_reg <= '0;
            tx_wdata <= '0;
            tx_wr_en <= 1'b0;
        end else begin
            tx_wr_en <= 1'b0;

            case (w_state)
                W_IDLE: begin
                    if (aw_hs && w_hs) begin
                        wr_addr <= s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        wr_data <= s_axi_wdata;
                        wr_strb <= s_axi_wstrb;

                        case(s_axi_awaddr[AXI_ADDR_WIDTH-1:2])
                            ADDR_CTRL: begin
                                if (s_axi_wstrb[0]) begin
                                    ctrl_reg[7:0] <= s_axi_wdata[7:0];
                                end
                                if (s_axi_wstrb[1]) begin
                                    ctrl_reg[15:8] <= s_axi_wdata[15:8];
                                end
                                if (s_axi_wstrb[2]) begin
                                    ctrl_reg[23:16] <= s_axi_wdata[23:16];
                                end
                                if (s_axi_wstrb[3]) begin
                                    ctrl_reg[31:24] <= s_axi_wdata[31:24];
                                end
                                s_axi_bresp <= RESP_OKAY;
                            end

                            ADDR_TXDATA: begin
                                if (!tx_full && s_axi_wstrb[0]) begin
                                    tx_wdata <= s_axi_wdata[7:0];
                                    tx_wr_en <= 1'b1;
                                    s_axi_bresp <= RESP_OKAY;
                                end else begin
                                    s_axi_bresp <= RESP_SLVERR;
                                end
                            end

                            default: begin
                                s_axi_bresp <= RESP_DECERR;
                            end
                        endcase

                        w_state <= W_RESP;
                    end else if (aw_hs) begin
                        wr_addr <= s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        w_state <= W_DATA;
                    end else if (w_hs) begin
                        wr_data <= s_axi_wdata;
                        wr_strb <= s_axi_wstrb;
                        w_state <= W_ADDR;
                    end
                end

                W_DATA: begin
                    if (w_hs) begin
                        wr_data <= s_axi_wdata;
                        wr_strb <= s_axi_wstrb;

                        case (wr_addr)
                            ADDR_CTRL: begin
                                if (s_axi_wstrb[0]) begin
                                    ctrl_reg[7:0] <= s_axi_wdata[7:0];
                                end
                                if (s_axi_wstrb[1]) begin
                                    ctrl_reg[15:8] <= s_axi_wdata[15:8];
                                end
                                if (s_axi_wstrb[2]) begin
                                    ctrl_reg[23:16] <= s_axi_wdata[23:16];
                                end
                                if (s_axi_wstrb[3]) begin
                                    ctrl_reg[31:24] <= s_axi_wdata[31:24];
                                end
                                s_axi_bresp <= RESP_OKAY;
                            end

                            ADDR_TXDATA: begin
                                if (!tx_full && s_axi_wstrb[0]) begin
                                    tx_wdata    <= s_axi_wdata[7:0];
                                    tx_wr_en    <= 1'b1;
                                    s_axi_bresp <= RESP_OKAY;
                                end else begin
                                    s_axi_bresp <= RESP_SLVERR;
                                end
                            end

                            default: begin
                                s_axi_bresp <= RESP_DECERR;
                            end
                        endcase

                        w_state <= W_RESP;
                    end
                end

                W_ADDR: begin
                    if (aw_hs) begin
                        wr_addr <= s_axi_awaddr[AXI_ADDR_WIDTH-1:2];

                         case (s_axi_awaddr[AXI_ADDR_WIDTH-1:2])
                            ADDR_CTRL: begin
                                if (wr_strb[0]) begin
                                    ctrl_reg[7:0] <= wr_data[7:0];
                                end
                                if (wr_strb[1]) begin
                                    ctrl_reg[15:8] <= wr_data[15:8];
                                end
                                if (wr_strb[2]) begin
                                    ctrl_reg[23:16] <= wr_data[23:16];
                                end
                                if (wr_strb[3]) begin
                                    ctrl_reg[31:24] <= wr_data[31:24];
                                end
                                s_axi_bresp <= RESP_OKAY;
                            end

                            ADDR_TXDATA: begin
                                if (!tx_full && wr_strb[0]) begin
                                    tx_wdata    <= wr_data[7:0];
                                    tx_wr_en    <= 1'b1;
                                    s_axi_bresp <= RESP_OKAY;
                                end else begin
                                    s_axi_bresp <= RESP_SLVERR;
                                end
                            end

                            default: begin
                                s_axi_bresp <= RESP_DECERR;
                            end
                        endcase

                        w_state <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (b_hs) begin
                        w_state <= W_IDLE;
                    end
                end

                default: begin
                    w_state <= W_IDLE;
                end
            endcase
        end
    end

    always_comb begin
        s_axi_arready = (r_state == R_IDLE);
        s_axi_rvalid  = (r_state == R_RESP);
        s_axi_rdata   = rd_data;

        if ((r_state == R_RESP) && (rd_addr == ADDR_RXDATA) && (s_axi_rresp == RESP_OKAY)) begin
            s_axi_rdata = {{(AXI_DATA_WIDTH-8){1'b0}}, rx_rdata};
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            r_state <= R_IDLE;
            rd_addr <= '0;
            rd_data <= '0;
            s_axi_rresp <= RESP_OKAY;
            rx_rd_en <= 1'b0;
        end else begin
            rx_rd_en <= 1'b0;

            case (r_state)
                R_IDLE: begin
                    if (ar_hs) begin
                        rd_addr <= s_axi_araddr[AXI_ADDR_WIDTH-1:2];

                        case (s_axi_araddr[AXI_ADDR_WIDTH-1:2])
                            ADDR_CTRL: begin
                                rd_data <= ctrl_reg;
                                s_axi_rresp <= RESP_OKAY;
                                r_state <= R_RESP;
                            end

                            ADDR_STATUS: begin
                                rd_data <= {{(AXI_DATA_WIDTH-2){1'b0}}, rx_empty, tx_full};
                                s_axi_rresp <= RESP_OKAY;
                                r_state <= R_RESP;
                            end

                            ADDR_TXDATA: begin
                                rd_data <= '0;
                                s_axi_rresp <= RESP_SLVERR;
                                r_state <= R_RESP;
                            end

                            ADDR_RXDATA: begin
                                if (!rx_empty) begin
                                    rx_rd_en <= 1'b1;
                                    s_axi_rresp <= RESP_OKAY;
                                    r_state <= R_POP;
                                end else begin
                                    rd_data <= '0;
                                    s_axi_rresp <= RESP_SLVERR;
                                    r_state <= R_RESP;
                                end
                            end

                            default: begin
                                rd_data     <= '0;
                                s_axi_rresp <= RESP_DECERR;
                                r_state     <= R_RESP;
                            end
                        endcase
                    end
                end

                R_POP: begin
                    r_state <= R_RESP;
                end

                R_RESP: begin
                    if (r_hs) begin
                        r_state <= R_IDLE;
                    end
                end

                default: begin
                    r_state <= R_IDLE;
                end
            endcase
        end
    end

    uart_core #(
        .CLK_FREQ   (CLK_FREQ),
        .BAUD_RATE  (BAUD_RATE),
        .ADDR_WIDTH (FIFO_ADDR_WIDTH)
    ) u_uart_core (
        .clk        (s_axi_aclk),
        .resetn     (s_axi_aresetn),
        .rx         (rx),
        .tx         (tx),
        .tx_wdata   (tx_wdata),
        .tx_wr_en   (tx_wr_en),
        .tx_full    (tx_full),
        .rx_rd_en   (rx_rd_en),
        .rx_rdata   (rx_rdata),
        .rx_empty   (rx_empty)
    );

endmodule

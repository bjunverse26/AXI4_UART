`timescale 1ns / 1ps

module axi_uart_slave #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_STRB       = (AXI_DATA_WIDTH / 8)
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

    output logic [AXI_ADDR_WIDTH-1:2]   reg_wr_addr,
    output logic [AXI_DATA_WIDTH-1:0]   reg_wr_data,
    output logic [AXI_STRB-1:0]         reg_wr_strb,
    output logic                        reg_wr_en,
    input logic [1:0]                   reg_wr_resp,

    output logic [AXI_ADDR_WIDTH-1:2]   reg_rd_addr,
    output logic                        reg_rd_en,
    input logic [AXI_DATA_WIDTH-1:0]    reg_rd_data,
    input logic [1:0]                   reg_rd_resp,
    input logic                         reg_rd_wait
);

    localparam logic [1:0] RESP_OKAY = 2'b00;

    typedef enum logic [1:0] {
        W_IDLE = 2'b00,
        W_DATA = 2'b01,
        W_ADDR = 2'b10,
        W_RESP = 2'b11
    } w_state_t;

    typedef enum logic [1:0] {
        R_IDLE = 2'b00,
        R_WAIT = 2'b01,
        R_RESP = 2'b10
    } r_state_t;

    w_state_t w_state;
    r_state_t r_state;

    logic aw_hs;
    logic w_hs;
    logic b_hs;
    logic ar_hs;
    logic r_hs;

    logic [AXI_ADDR_WIDTH-1:2] wr_addr_latched;
    logic [AXI_DATA_WIDTH-1:0] wr_data_latched;
    logic [AXI_STRB-1:0]       wr_strb_latched;
    logic [AXI_ADDR_WIDTH-1:2] rd_addr_latched;
    logic [AXI_DATA_WIDTH-1:0] rd_data_latched;
    logic                      rd_wait_latched;

    assign aw_hs = s_axi_awvalid && s_axi_awready;
    assign w_hs  = s_axi_wvalid && s_axi_wready;
    assign b_hs  = s_axi_bvalid && s_axi_bready;
    assign ar_hs = s_axi_arvalid && s_axi_arready;
    assign r_hs  = s_axi_rvalid && s_axi_rready;

    always_comb begin
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_bvalid  = 1'b0;

        case (w_state)
            W_IDLE: begin
                s_axi_awready = 1'b1;
                s_axi_wready  = 1'b1;
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

    always_comb begin
        reg_wr_en   = 1'b0;
        reg_wr_addr = wr_addr_latched;
        reg_wr_data = wr_data_latched;
        reg_wr_strb = wr_strb_latched;

        case (w_state)
            W_IDLE: begin
                if (aw_hs && w_hs) begin
                    reg_wr_en   = 1'b1;
                    reg_wr_addr = s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                    reg_wr_data = s_axi_wdata;
                    reg_wr_strb = s_axi_wstrb;
                end
            end

            W_DATA: begin
                if (w_hs) begin
                    reg_wr_en   = 1'b1;
                    reg_wr_data = s_axi_wdata;
                    reg_wr_strb = s_axi_wstrb;
                end
            end

            W_ADDR: begin
                if (aw_hs) begin
                    reg_wr_en   = 1'b1;
                    reg_wr_addr = s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                end
            end

            default: begin
                reg_wr_en = 1'b0;
            end
        endcase
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            w_state <= W_IDLE;
            s_axi_bresp <= RESP_OKAY;
            wr_addr_latched <= '0;
            wr_data_latched <= '0;
            wr_strb_latched <= '0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (aw_hs && w_hs) begin
                        wr_addr_latched <= s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        wr_data_latched <= s_axi_wdata;
                        wr_strb_latched <= s_axi_wstrb;
                        s_axi_bresp <= reg_wr_resp;
                        w_state <= W_RESP;
                    end else if (aw_hs) begin
                        wr_addr_latched <= s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        w_state <= W_DATA;
                    end else if (w_hs) begin
                        wr_data_latched <= s_axi_wdata;
                        wr_strb_latched <= s_axi_wstrb;
                        w_state <= W_ADDR;
                    end
                end

                W_DATA: begin
                    if (w_hs) begin
                        wr_data_latched <= s_axi_wdata;
                        wr_strb_latched <= s_axi_wstrb;
                        s_axi_bresp <= reg_wr_resp;
                        w_state <= W_RESP;
                    end
                end

                W_ADDR: begin
                    if (aw_hs) begin
                        wr_addr_latched <= s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        s_axi_bresp <= reg_wr_resp;
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
        s_axi_rdata   = rd_wait_latched ? reg_rd_data : rd_data_latched;
        reg_rd_en     = ar_hs;

        if (r_state == R_IDLE) begin
            reg_rd_addr = s_axi_araddr[AXI_ADDR_WIDTH-1:2];
        end else begin
            reg_rd_addr = rd_addr_latched;
        end
    end

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            r_state <= R_IDLE;
            rd_addr_latched <= '0;
            rd_data_latched <= '0;
            rd_wait_latched <= 1'b0;
            s_axi_rresp <= RESP_OKAY;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (ar_hs) begin
                        rd_addr_latched <= s_axi_araddr[AXI_ADDR_WIDTH-1:2];
                        rd_data_latched <= reg_rd_data;
                        rd_wait_latched <= reg_rd_wait;
                        s_axi_rresp <= reg_rd_resp;

                        if (reg_rd_wait) begin
                            r_state <= R_WAIT;
                        end else begin
                            r_state <= R_RESP;
                        end
                    end
                end

                R_WAIT: begin
                    r_state <= R_RESP;
                end

                R_RESP: begin
                    if (r_hs) begin
                        rd_wait_latched <= 1'b0;
                        r_state <= R_IDLE;
                    end
                end

                default: begin
                    r_state <= R_IDLE;
                end
            endcase
        end
    end

endmodule

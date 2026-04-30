//==============================================================================
// File Name   : AxiUartSlave.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : AXI4-Lite slave front end for the UART register map.
// Notes       : Address and data channels are normalized into a single register
//               write pulse so the register map does not need protocol-specific
//               ordering logic.
//==============================================================================

`timescale 1ns / 1ps

module AxiUartSlave #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_STRB       = AXI_DATA_WIDTH / 8
) (
    input  logic                          i_s_axi_aclk,
    input  logic                          i_s_axi_aresetn,

    input  logic [AXI_ADDR_WIDTH-1:0]     i_s_axi_awaddr,
    input  logic [2:0]                    i_s_axi_awprot,
    input  logic                          i_s_axi_awvalid,
    output logic                          o_s_axi_awready,

    input  logic [AXI_DATA_WIDTH-1:0]     i_s_axi_wdata,
    input  logic [AXI_STRB-1:0]           i_s_axi_wstrb,
    input  logic                          i_s_axi_wvalid,
    output logic                          o_s_axi_wready,

    output logic [1:0]                    o_s_axi_bresp,
    output logic                          o_s_axi_bvalid,
    input  logic                          i_s_axi_bready,

    input  logic [AXI_ADDR_WIDTH-1:0]     i_s_axi_araddr,
    input  logic [2:0]                    i_s_axi_arprot,
    input  logic                          i_s_axi_arvalid,
    output logic                          o_s_axi_arready,

    output logic [AXI_DATA_WIDTH-1:0]     o_s_axi_rdata,
    output logic [1:0]                    o_s_axi_rresp,
    output logic                          o_s_axi_rvalid,
    input  logic                          i_s_axi_rready,

    output logic [AXI_ADDR_WIDTH-1:2]     o_reg_wr_addr,
    output logic [AXI_DATA_WIDTH-1:0]     o_reg_wr_data,
    output logic [AXI_STRB-1:0]           o_reg_wr_strb,
    output logic                          o_reg_wr_en,
    input  logic [1:0]                    i_reg_wr_resp,

    output logic [AXI_ADDR_WIDTH-1:2]     o_reg_rd_addr,
    output logic                          o_reg_rd_en,
    input  logic [AXI_DATA_WIDTH-1:0]     i_reg_rd_data,
    input  logic [1:0]                    i_reg_rd_resp,
    input  logic                          i_reg_rd_wait
);

    localparam logic [1:0] RESP_OKAY = 2'b00;

    typedef enum logic [1:0] {
        W_IDLE,
        W_DATA,
        W_ADDR,
        W_RESP
    } write_state_t;

    typedef enum logic [1:0] {
        R_IDLE,
        R_WAIT,
        R_RESP
    } read_state_t;

    write_state_t r_write_state;
    read_state_t  r_read_state;

    logic w_aw_hs;
    logic w_w_hs;
    logic w_b_hs;
    logic w_ar_hs;
    logic w_r_hs;

    logic [AXI_ADDR_WIDTH-1:2] r_wr_addr_latched;
    logic [AXI_DATA_WIDTH-1:0] r_wr_data_latched;
    logic [AXI_STRB-1:0]       r_wr_strb_latched;
    logic [AXI_ADDR_WIDTH-1:2] r_rd_addr_latched;
    logic [AXI_DATA_WIDTH-1:0] r_rd_data_latched;
    logic                      r_rd_wait_latched;

    assign w_aw_hs = i_s_axi_awvalid && o_s_axi_awready;
    assign w_w_hs  = i_s_axi_wvalid  && o_s_axi_wready;
    assign w_b_hs  = o_s_axi_bvalid  && i_s_axi_bready;
    assign w_ar_hs = i_s_axi_arvalid && o_s_axi_arready;
    assign w_r_hs  = o_s_axi_rvalid  && i_s_axi_rready;

    always_comb begin
        o_s_axi_awready = 1'b0;
        o_s_axi_wready  = 1'b0;
        o_s_axi_bvalid  = 1'b0;

        case (r_write_state)
            W_IDLE: begin
                o_s_axi_awready = 1'b1;
                o_s_axi_wready  = 1'b1;
            end

            W_DATA: begin
                o_s_axi_wready = 1'b1;
            end

            W_ADDR: begin
                o_s_axi_awready = 1'b1;
            end

            W_RESP: begin
                o_s_axi_bvalid = 1'b1;
            end

            default: begin
                o_s_axi_awready = 1'b0;
                o_s_axi_wready  = 1'b0;
                o_s_axi_bvalid  = 1'b0;
            end
        endcase
    end

    always_comb begin
        o_reg_wr_en   = 1'b0;
        o_reg_wr_addr = r_wr_addr_latched;
        o_reg_wr_data = r_wr_data_latched;
        o_reg_wr_strb = r_wr_strb_latched;

        case (r_write_state)
            W_IDLE: begin
                if (w_aw_hs && w_w_hs) begin
                    o_reg_wr_en   = 1'b1;
                    o_reg_wr_addr = i_s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                    o_reg_wr_data = i_s_axi_wdata;
                    o_reg_wr_strb = i_s_axi_wstrb;
                end
            end

            W_DATA: begin
                if (w_w_hs) begin
                    o_reg_wr_en   = 1'b1;
                    o_reg_wr_data = i_s_axi_wdata;
                    o_reg_wr_strb = i_s_axi_wstrb;
                end
            end

            W_ADDR: begin
                if (w_aw_hs) begin
                    o_reg_wr_en   = 1'b1;
                    o_reg_wr_addr = i_s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                end
            end

            default: begin
                o_reg_wr_en = 1'b0;
            end
        endcase
    end

    always_ff @(posedge i_s_axi_aclk or negedge i_s_axi_aresetn) begin
        if (!i_s_axi_aresetn) begin
            r_write_state    <= W_IDLE;
            o_s_axi_bresp    <= RESP_OKAY;
            r_wr_addr_latched <= '0;
            r_wr_data_latched <= '0;
            r_wr_strb_latched <= '0;
        end else begin
            case (r_write_state)
                W_IDLE: begin
                    if (w_aw_hs && w_w_hs) begin
                        r_wr_addr_latched <= i_s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        r_wr_data_latched <= i_s_axi_wdata;
                        r_wr_strb_latched <= i_s_axi_wstrb;
                        o_s_axi_bresp     <= i_reg_wr_resp;
                        r_write_state     <= W_RESP;
                    end else if (w_aw_hs) begin
                        r_wr_addr_latched <= i_s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        r_write_state     <= W_DATA;
                    end else if (w_w_hs) begin
                        r_wr_data_latched <= i_s_axi_wdata;
                        r_wr_strb_latched <= i_s_axi_wstrb;
                        r_write_state     <= W_ADDR;
                    end
                end

                W_DATA: begin
                    if (w_w_hs) begin
                        r_wr_data_latched <= i_s_axi_wdata;
                        r_wr_strb_latched <= i_s_axi_wstrb;
                        o_s_axi_bresp     <= i_reg_wr_resp;
                        r_write_state     <= W_RESP;
                    end
                end

                W_ADDR: begin
                    if (w_aw_hs) begin
                        r_wr_addr_latched <= i_s_axi_awaddr[AXI_ADDR_WIDTH-1:2];
                        o_s_axi_bresp     <= i_reg_wr_resp;
                        r_write_state     <= W_RESP;
                    end
                end

                W_RESP: begin
                    if (w_b_hs) begin
                        r_write_state <= W_IDLE;
                    end
                end

                default: begin
                    r_write_state <= W_IDLE;
                end
            endcase
        end
    end

    always_comb begin
        o_s_axi_arready = (r_read_state == R_IDLE);
        o_s_axi_rvalid  = (r_read_state == R_RESP);
        o_s_axi_rdata   = r_rd_wait_latched ? i_reg_rd_data : r_rd_data_latched;
        o_reg_rd_en     = w_ar_hs;

        if (r_read_state == R_IDLE) begin
            o_reg_rd_addr = i_s_axi_araddr[AXI_ADDR_WIDTH-1:2];
        end else begin
            o_reg_rd_addr = r_rd_addr_latched;
        end
    end

    always_ff @(posedge i_s_axi_aclk or negedge i_s_axi_aresetn) begin
        if (!i_s_axi_aresetn) begin
            r_read_state     <= R_IDLE;
            r_rd_addr_latched <= '0;
            r_rd_data_latched <= '0;
            r_rd_wait_latched <= 1'b0;
            o_s_axi_rresp    <= RESP_OKAY;
        end else begin
            case (r_read_state)
                R_IDLE: begin
                    if (w_ar_hs) begin
                        r_rd_addr_latched <= i_s_axi_araddr[AXI_ADDR_WIDTH-1:2];
                        r_rd_data_latched <= i_reg_rd_data;
                        r_rd_wait_latched <= i_reg_rd_wait;
                        o_s_axi_rresp     <= i_reg_rd_resp;

                        if (i_reg_rd_wait) begin
                            r_read_state <= R_WAIT;
                        end else begin
                            r_read_state <= R_RESP;
                        end
                    end
                end

                R_WAIT: begin
                    r_read_state <= R_RESP;
                end

                R_RESP: begin
                    if (w_r_hs) begin
                        r_rd_wait_latched <= 1'b0;
                        r_read_state      <= R_IDLE;
                    end
                end

                default: begin
                    r_read_state <= R_IDLE;
                end
            endcase
        end
    end

endmodule

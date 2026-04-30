//==============================================================================
// File Name   : AxiUart.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : Top-level AXI4-Lite UART peripheral integration.
// Notes       : The AXI slave, register map, and UART datapath are partitioned so
//               software-visible behavior and serial timing can be verified
//               independently.
//==============================================================================

`timescale 1ns / 1ps

module AxiUart #(
    parameter int CLK_FREQ        = 100_000_000,
    parameter int BAUD_RATE       = 115_200,
    parameter int AXI_ADDR_WIDTH  = 32,
    parameter int AXI_DATA_WIDTH  = 32,
    parameter int AXI_STRB        = AXI_DATA_WIDTH / 8,
    parameter int FIFO_ADDR_WIDTH = 4
) (
    input  logic                         i_s_axi_aclk,
    input  logic                         i_s_axi_aresetn,

    input  logic [AXI_ADDR_WIDTH-1:0]    i_s_axi_awaddr,
    input  logic [2:0]                   i_s_axi_awprot,
    input  logic                         i_s_axi_awvalid,
    output logic                         o_s_axi_awready,

    input  logic [AXI_DATA_WIDTH-1:0]    i_s_axi_wdata,
    input  logic [AXI_STRB-1:0]          i_s_axi_wstrb,
    input  logic                         i_s_axi_wvalid,
    output logic                         o_s_axi_wready,

    output logic [1:0]                   o_s_axi_bresp,
    output logic                         o_s_axi_bvalid,
    input  logic                         i_s_axi_bready,

    input  logic [AXI_ADDR_WIDTH-1:0]    i_s_axi_araddr,
    input  logic [2:0]                   i_s_axi_arprot,
    input  logic                         i_s_axi_arvalid,
    output logic                         o_s_axi_arready,

    output logic [AXI_DATA_WIDTH-1:0]    o_s_axi_rdata,
    output logic [1:0]                   o_s_axi_rresp,
    output logic                         o_s_axi_rvalid,
    input  logic                         i_s_axi_rready,

    output logic                         o_tx,
    input  logic                         i_rx
);

    logic [AXI_ADDR_WIDTH-1:2] w_reg_wr_addr;
    logic [AXI_DATA_WIDTH-1:0] w_reg_wr_data;
    logic [AXI_STRB-1:0]       w_reg_wr_strb;
    logic                      w_reg_wr_en;
    logic [1:0]                w_reg_wr_resp;

    logic [AXI_ADDR_WIDTH-1:2] w_reg_rd_addr;
    logic                      w_reg_rd_en;
    logic [AXI_DATA_WIDTH-1:0] w_reg_rd_data;
    logic [1:0]                w_reg_rd_resp;
    logic                      w_reg_rd_wait;

    logic [7:0]                w_tx_wdata;
    logic                      w_tx_wr_en;
    logic                      w_tx_full;
    logic                      w_rx_rd_en;
    logic [7:0]                w_rx_rdata;
    logic                      w_rx_empty;

    AxiUartSlave #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_STRB       (AXI_STRB)
    ) u_axi_uart_slave (
        .i_s_axi_aclk    (i_s_axi_aclk),
        .i_s_axi_aresetn (i_s_axi_aresetn),
        .i_s_axi_awaddr  (i_s_axi_awaddr),
        .i_s_axi_awprot  (i_s_axi_awprot),
        .i_s_axi_awvalid (i_s_axi_awvalid),
        .o_s_axi_awready (o_s_axi_awready),
        .i_s_axi_wdata   (i_s_axi_wdata),
        .i_s_axi_wstrb   (i_s_axi_wstrb),
        .i_s_axi_wvalid  (i_s_axi_wvalid),
        .o_s_axi_wready  (o_s_axi_wready),
        .o_s_axi_bresp   (o_s_axi_bresp),
        .o_s_axi_bvalid  (o_s_axi_bvalid),
        .i_s_axi_bready  (i_s_axi_bready),
        .i_s_axi_araddr  (i_s_axi_araddr),
        .i_s_axi_arprot  (i_s_axi_arprot),
        .i_s_axi_arvalid (i_s_axi_arvalid),
        .o_s_axi_arready (o_s_axi_arready),
        .o_s_axi_rdata   (o_s_axi_rdata),
        .o_s_axi_rresp   (o_s_axi_rresp),
        .o_s_axi_rvalid  (o_s_axi_rvalid),
        .i_s_axi_rready  (i_s_axi_rready),
        .o_reg_wr_addr   (w_reg_wr_addr),
        .o_reg_wr_data   (w_reg_wr_data),
        .o_reg_wr_strb   (w_reg_wr_strb),
        .o_reg_wr_en     (w_reg_wr_en),
        .i_reg_wr_resp   (w_reg_wr_resp),
        .o_reg_rd_addr   (w_reg_rd_addr),
        .o_reg_rd_en     (w_reg_rd_en),
        .i_reg_rd_data   (w_reg_rd_data),
        .i_reg_rd_resp   (w_reg_rd_resp),
        .i_reg_rd_wait   (w_reg_rd_wait)
    );

    AxiUartRegisterMap #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_STRB       (AXI_STRB)
    ) u_register_map (
        .i_clk          (i_s_axi_aclk),
        .i_resetn       (i_s_axi_aresetn),
        .i_reg_wr_addr  (w_reg_wr_addr),
        .i_reg_wr_data  (w_reg_wr_data),
        .i_reg_wr_strb  (w_reg_wr_strb),
        .i_reg_wr_en    (w_reg_wr_en),
        .o_reg_wr_resp  (w_reg_wr_resp),
        .i_reg_rd_addr  (w_reg_rd_addr),
        .i_reg_rd_en    (w_reg_rd_en),
        .o_reg_rd_data  (w_reg_rd_data),
        .o_reg_rd_resp  (w_reg_rd_resp),
        .o_reg_rd_wait  (w_reg_rd_wait),
        .o_tx_wdata     (w_tx_wdata),
        .o_tx_wr_en     (w_tx_wr_en),
        .i_tx_full      (w_tx_full),
        .o_rx_rd_en     (w_rx_rd_en),
        .i_rx_rdata     (w_rx_rdata),
        .i_rx_empty     (w_rx_empty)
    );

    UartCore #(
        .CLK_FREQ   (CLK_FREQ),
        .BAUD_RATE  (BAUD_RATE),
        .ADDR_WIDTH (FIFO_ADDR_WIDTH)
    ) u_uart_core (
        .i_clk       (i_s_axi_aclk),
        .i_resetn    (i_s_axi_aresetn),
        .o_tx        (o_tx),
        .i_rx        (i_rx),
        .i_tx_wdata  (w_tx_wdata),
        .i_tx_wr_en  (w_tx_wr_en),
        .o_tx_full   (w_tx_full),
        .i_rx_rd_en  (w_rx_rd_en),
        .o_rx_rdata  (w_rx_rdata),
        .o_rx_empty  (w_rx_empty)
    );

endmodule

`timescale 1ns / 1ps

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

    logic [AXI_ADDR_WIDTH-1:2]  reg_wr_addr;
    logic [AXI_DATA_WIDTH-1:0]  reg_wr_data;
    logic [AXI_STRB-1:0]        reg_wr_strb;
    logic                       reg_wr_en;
    logic [1:0]                 reg_wr_resp;

    logic [AXI_ADDR_WIDTH-1:2]  reg_rd_addr;
    logic                       reg_rd_en;
    logic [AXI_DATA_WIDTH-1:0]  reg_rd_data;
    logic [1:0]                 reg_rd_resp;
    logic                       reg_rd_wait;

    logic [7:0]                 tx_wdata;
    logic                       tx_wr_en;
    logic                       tx_full;
    logic                       rx_rd_en;
    logic [7:0]                 rx_rdata;
    logic                       rx_empty;

    axi_uart_slave #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_STRB       (AXI_STRB)
    ) u_axi_uart_slave (
        .s_axi_aclk     (s_axi_aclk),
        .s_axi_aresetn  (s_axi_aresetn),

        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),

        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),

        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),

        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),

        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),

        .reg_wr_addr    (reg_wr_addr),
        .reg_wr_data    (reg_wr_data),
        .reg_wr_strb    (reg_wr_strb),
        .reg_wr_en      (reg_wr_en),
        .reg_wr_resp    (reg_wr_resp),

        .reg_rd_addr    (reg_rd_addr),
        .reg_rd_en      (reg_rd_en),
        .reg_rd_data    (reg_rd_data),
        .reg_rd_resp    (reg_rd_resp),
        .reg_rd_wait    (reg_rd_wait)
    );

    axi_uart_register_map #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_STRB       (AXI_STRB)
    ) u_register_map (
        .clk            (s_axi_aclk),
        .resetn         (s_axi_aresetn),

        .reg_wr_addr    (reg_wr_addr),
        .reg_wr_data    (reg_wr_data),
        .reg_wr_strb    (reg_wr_strb),
        .reg_wr_en      (reg_wr_en),
        .reg_wr_resp    (reg_wr_resp),

        .reg_rd_addr    (reg_rd_addr),
        .reg_rd_en      (reg_rd_en),
        .reg_rd_data    (reg_rd_data),
        .reg_rd_resp    (reg_rd_resp),
        .reg_rd_wait    (reg_rd_wait),

        .tx_wdata       (tx_wdata),
        .tx_wr_en       (tx_wr_en),
        .tx_full        (tx_full),
        .rx_rd_en       (rx_rd_en),
        .rx_rdata       (rx_rdata),
        .rx_empty       (rx_empty)
    );

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

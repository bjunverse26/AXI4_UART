//==============================================================================
// File Name   : TbAxiUartSva.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : Directed self-checking testbench for the AXI4-Lite UART
//               peripheral.
// Notes       : Scenario tasks keep the initial block readable while checker
//               tasks provide consistent PASS/FAIL accounting.
//==============================================================================

`timescale 1ns / 1ps

//==============================================================================
// Testbench Interface
//==============================================================================

interface AxiUartIf #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_STRB       = AXI_DATA_WIDTH / 8
) (
    input logic i_s_axi_aclk
);
    logic                         i_s_axi_aresetn;
    logic [AXI_ADDR_WIDTH-1:0]    i_s_axi_awaddr;
    logic [2:0]                   i_s_axi_awprot;
    logic                         i_s_axi_awvalid;
    logic                         o_s_axi_awready;
    logic [AXI_DATA_WIDTH-1:0]    i_s_axi_wdata;
    logic [AXI_STRB-1:0]          i_s_axi_wstrb;
    logic                         i_s_axi_wvalid;
    logic                         o_s_axi_wready;
    logic [1:0]                   o_s_axi_bresp;
    logic                         o_s_axi_bvalid;
    logic                         i_s_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0]    i_s_axi_araddr;
    logic [2:0]                   i_s_axi_arprot;
    logic                         i_s_axi_arvalid;
    logic                         o_s_axi_arready;
    logic [AXI_DATA_WIDTH-1:0]    o_s_axi_rdata;
    logic [1:0]                   o_s_axi_rresp;
    logic                         o_s_axi_rvalid;
    logic                         i_s_axi_rready;
    logic                         o_tx;
    logic                         i_rx;
endinterface

module TbAxiUartSva;

    //==============================================================================
    // Testbench Parameters And State
    //==============================================================================

    localparam int CLK_FREQ       = 32;
    localparam int BAUD_RATE      = 1;
    localparam int AXI_ADDR_WIDTH = 32;
    localparam int AXI_DATA_WIDTH = 32;
    localparam int AXI_STRB       = AXI_DATA_WIDTH / 8;
    localparam int CLK_PERIOD     = 10;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam logic [31:0] ADDR_CTRL   = 32'h0000_0000;
    localparam logic [31:0] ADDR_STATUS = 32'h0000_0004;
    localparam logic [31:0] ADDR_TXDATA = 32'h0000_0008;
    localparam logic [31:0] ADDR_RXDATA = 32'h0000_000C;
    localparam logic [31:0] ADDR_BAD    = 32'h0000_0010;

    logic w_aclk;
    logic [31:0] r_read_data;
    int unsigned r_test_number;
    int unsigned r_test_pass;
    int unsigned r_test_fail;

    //==============================================================================
    // Interface Instance
    //==============================================================================

    AxiUartIf #(
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_STRB       (AXI_STRB)
    ) axi_if (
        .i_s_axi_aclk (w_aclk)
    );

    //==============================================================================
    // DUT Instantiation
    //==============================================================================

    AxiUart #(
        .CLK_FREQ        (CLK_FREQ),
        .BAUD_RATE       (BAUD_RATE),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .FIFO_ADDR_WIDTH (4)
    ) u_dut (
        .i_s_axi_aclk    (axi_if.i_s_axi_aclk),
        .i_s_axi_aresetn (axi_if.i_s_axi_aresetn),
        .i_s_axi_awaddr  (axi_if.i_s_axi_awaddr),
        .i_s_axi_awprot  (axi_if.i_s_axi_awprot),
        .i_s_axi_awvalid (axi_if.i_s_axi_awvalid),
        .o_s_axi_awready (axi_if.o_s_axi_awready),
        .i_s_axi_wdata   (axi_if.i_s_axi_wdata),
        .i_s_axi_wstrb   (axi_if.i_s_axi_wstrb),
        .i_s_axi_wvalid  (axi_if.i_s_axi_wvalid),
        .o_s_axi_wready  (axi_if.o_s_axi_wready),
        .o_s_axi_bresp   (axi_if.o_s_axi_bresp),
        .o_s_axi_bvalid  (axi_if.o_s_axi_bvalid),
        .i_s_axi_bready  (axi_if.i_s_axi_bready),
        .i_s_axi_araddr  (axi_if.i_s_axi_araddr),
        .i_s_axi_arprot  (axi_if.i_s_axi_arprot),
        .i_s_axi_arvalid (axi_if.i_s_axi_arvalid),
        .o_s_axi_arready (axi_if.o_s_axi_arready),
        .o_s_axi_rdata   (axi_if.o_s_axi_rdata),
        .o_s_axi_rresp   (axi_if.o_s_axi_rresp),
        .o_s_axi_rvalid  (axi_if.o_s_axi_rvalid),
        .i_s_axi_rready  (axi_if.i_s_axi_rready),
        .o_tx            (axi_if.o_tx),
        .i_rx            (axi_if.i_rx)
    );

    //==============================================================================
    // UART Loopback Connection
    //==============================================================================

    assign axi_if.i_rx = axi_if.o_tx;

    //==============================================================================
    // Protocol Monitor
    //==============================================================================

    AxiUartProtocolSva u_sva (
        .i_aclk     (axi_if.i_s_axi_aclk),
        .i_aresetn  (axi_if.i_s_axi_aresetn),
        .i_awaddr   (axi_if.i_s_axi_awaddr),
        .i_awvalid  (axi_if.i_s_axi_awvalid),
        .i_awready  (axi_if.o_s_axi_awready),
        .i_wdata    (axi_if.i_s_axi_wdata),
        .i_wstrb    (axi_if.i_s_axi_wstrb),
        .i_wvalid   (axi_if.i_s_axi_wvalid),
        .i_wready   (axi_if.o_s_axi_wready),
        .i_bresp    (axi_if.o_s_axi_bresp),
        .i_bvalid   (axi_if.o_s_axi_bvalid),
        .i_bready   (axi_if.i_s_axi_bready),
        .i_araddr   (axi_if.i_s_axi_araddr),
        .i_arvalid  (axi_if.i_s_axi_arvalid),
        .i_arready  (axi_if.o_s_axi_arready),
        .i_rdata    (axi_if.o_s_axi_rdata),
        .i_rresp    (axi_if.o_s_axi_rresp),
        .i_rvalid   (axi_if.o_s_axi_rvalid),
        .i_rready   (axi_if.i_s_axi_rready),
        .i_tx       (axi_if.o_tx),
        .i_rx_empty (u_dut.w_rx_empty),
        .i_tx_full  (u_dut.w_tx_full)
    );

    //==============================================================================
    // Clock Generation
    //==============================================================================

    initial begin
        w_aclk = 1'b0;
        forever #(CLK_PERIOD / 2) w_aclk = ~w_aclk;
    end

    //==============================================================================
    // Test Sequence
    //==============================================================================

    initial begin
        init_interface();
        apply_reset();
        run_initial_status_case();
        run_empty_rx_case();
        run_ctrl_write_read_cases();
        run_backpressure_cases();
        run_unsupported_access_cases();
        run_uart_loopback_case();
        run_error_response_cases();
        report_summary();
    end

    //==============================================================================
    // Utility Functions
    //==============================================================================

    function automatic string resp_to_string(input logic [1:0] resp);
        case (resp)
            2'b00: resp_to_string = "OKAY";
            2'b01: resp_to_string = "EXOKAY";
            2'b10: resp_to_string = "SLVERR";
            2'b11: resp_to_string = "DECERR";
        endcase
    endfunction

    //==============================================================================
    // Initialization And Reset Tasks
    //==============================================================================

    task automatic init_interface();
        begin
            axi_if.i_s_axi_aresetn = 1'b0;
            axi_if.i_s_axi_awaddr  = '0;
            axi_if.i_s_axi_awprot  = 3'b000;
            axi_if.i_s_axi_awvalid = 1'b0;
            axi_if.i_s_axi_wdata   = '0;
            axi_if.i_s_axi_wstrb   = '0;
            axi_if.i_s_axi_wvalid  = 1'b0;
            axi_if.i_s_axi_bready  = 1'b0;
            axi_if.i_s_axi_araddr  = '0;
            axi_if.i_s_axi_arprot  = 3'b000;
            axi_if.i_s_axi_arvalid = 1'b0;
            axi_if.i_s_axi_rready  = 1'b0;
            r_test_number          = 0;
            r_test_pass            = 0;
            r_test_fail            = 0;
        end
    endtask

    task automatic apply_reset();
        begin
            repeat (10) @(posedge w_aclk);
            axi_if.i_s_axi_aresetn = 1'b1;
            repeat (5) @(posedge w_aclk);
        end
    endtask

    task automatic check_resp(input logic [1:0] expected, input logic [1:0] actual, input string msg);
        begin
            if (expected == actual) begin
                $display("[PASS] %s expected=%s actual=%s", msg, resp_to_string(expected), resp_to_string(actual));
                r_test_pass++;
            end else begin
                $display("[FAIL] %s expected=%s actual=%s", msg, resp_to_string(expected), resp_to_string(actual));
                r_test_fail++;
            end
        end
    endtask

    task automatic check_data(input logic [31:0] expected, input logic [31:0] actual, input string msg);
        begin
            if (expected == actual) begin
                $display("[PASS] %s expected=0x%08h actual=0x%08h", msg, expected, actual);
                r_test_pass++;
            end else begin
                $display("[FAIL] %s expected=0x%08h actual=0x%08h", msg, expected, actual);
                r_test_fail++;
            end
        end
    endtask

    //==============================================================================
    // Bus Driver Tasks
    //==============================================================================

    task automatic write_same_cycle(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic [1:0] resp);
        begin
            axi_if.i_s_axi_awaddr  = addr;
            axi_if.i_s_axi_awvalid = 1'b1;
            axi_if.i_s_axi_wdata   = data;
            axi_if.i_s_axi_wstrb   = strb;
            axi_if.i_s_axi_wvalid  = 1'b1;
            axi_if.i_s_axi_bready  = 1'b1;
            @(posedge w_aclk iff (axi_if.o_s_axi_awready && axi_if.o_s_axi_wready));
            axi_if.i_s_axi_awvalid = 1'b0;
            axi_if.i_s_axi_wvalid  = 1'b0;
            @(posedge w_aclk iff axi_if.o_s_axi_bvalid);
            resp = axi_if.o_s_axi_bresp;
            axi_if.i_s_axi_bready = 1'b0;
        end
    endtask

    task automatic write_aw_then_w(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic [1:0] resp);
        begin
            axi_if.i_s_axi_awaddr  = addr;
            axi_if.i_s_axi_awvalid = 1'b1;
            axi_if.i_s_axi_bready  = 1'b1;
            @(posedge w_aclk iff axi_if.o_s_axi_awready);
            axi_if.i_s_axi_awvalid = 1'b0;
            axi_if.i_s_axi_wdata   = data;
            axi_if.i_s_axi_wstrb   = strb;
            axi_if.i_s_axi_wvalid  = 1'b1;
            @(posedge w_aclk iff axi_if.o_s_axi_wready);
            axi_if.i_s_axi_wvalid = 1'b0;
            @(posedge w_aclk iff axi_if.o_s_axi_bvalid);
            resp = axi_if.o_s_axi_bresp;
            axi_if.i_s_axi_bready = 1'b0;
        end
    endtask

    task automatic write_w_then_aw(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic [1:0] resp);
        begin
            axi_if.i_s_axi_wdata   = data;
            axi_if.i_s_axi_wstrb   = strb;
            axi_if.i_s_axi_wvalid  = 1'b1;
            axi_if.i_s_axi_bready  = 1'b1;
            @(posedge w_aclk iff axi_if.o_s_axi_wready);
            axi_if.i_s_axi_wvalid  = 1'b0;
            axi_if.i_s_axi_awaddr  = addr;
            axi_if.i_s_axi_awvalid = 1'b1;
            @(posedge w_aclk iff axi_if.o_s_axi_awready);
            axi_if.i_s_axi_awvalid = 1'b0;
            @(posedge w_aclk iff axi_if.o_s_axi_bvalid);
            resp = axi_if.o_s_axi_bresp;
            axi_if.i_s_axi_bready = 1'b0;
        end
    endtask

    //==============================================================================
    // Read Driver Tasks
    //==============================================================================

    task automatic read_data(input logic [31:0] addr, output logic [31:0] data, output logic [1:0] resp);
        begin
            axi_if.i_s_axi_araddr  = addr;
            axi_if.i_s_axi_arvalid = 1'b1;
            axi_if.i_s_axi_rready  = 1'b1;
            @(posedge w_aclk iff axi_if.o_s_axi_arready);
            axi_if.i_s_axi_arvalid = 1'b0;
            @(posedge w_aclk iff axi_if.o_s_axi_rvalid);
            data = axi_if.o_s_axi_rdata;
            resp = axi_if.o_s_axi_rresp;
            axi_if.i_s_axi_rready = 1'b0;
        end
    endtask

    task automatic wait_rx_not_empty(output logic [31:0] status_data, output logic [1:0] status_resp);
        int timeout;

        begin
            timeout = 0;
            read_data(ADDR_STATUS, status_data, status_resp);
            while (status_data[1] && (timeout < 300)) begin
                repeat (4) @(posedge w_aclk);
                read_data(ADDR_STATUS, status_data, status_resp);
                timeout++;
            end

            if (timeout >= 300) begin
                $display("[FAIL] RX FIFO did not receive loopback data");
                r_test_fail++;
            end
        end
    endtask

    //==============================================================================
    // Directed Test Scenarios
    //==============================================================================

    task automatic run_initial_status_case();
        logic [1:0] rd_resp;

        begin
            r_test_number++;
            read_data(ADDR_STATUS, r_read_data, rd_resp);
            check_resp(RESP_OKAY, rd_resp, "Initial STATUS response");
            check_data(32'h0000_0002, {30'b0, r_read_data[1:0]}, "Initial STATUS flags");
        end
    endtask

    task automatic run_empty_rx_case();
        logic [1:0] rd_resp;

        begin
            r_test_number++;
            read_data(ADDR_RXDATA, r_read_data, rd_resp);
            check_resp(RESP_SLVERR, rd_resp, "Empty RXDATA read response");
        end
    endtask

    task automatic run_ctrl_write_read_cases();
        logic [1:0] wr_resp;
        logic [1:0] rd_resp;

        begin
            r_test_number++;
            write_aw_then_w(ADDR_CTRL, 32'hA5A5_5A5A, 4'b1111, wr_resp);
            check_resp(RESP_OKAY, wr_resp, "CTRL AW->W write response");
            read_data(ADDR_CTRL, r_read_data, rd_resp);
            check_data(32'hA5A5_5A5A, r_read_data, "CTRL AW->W readback");

            r_test_number++;
            write_w_then_aw(ADDR_CTRL, 32'h5A5A_A5A5, 4'b1111, wr_resp);
            check_resp(RESP_OKAY, wr_resp, "CTRL W->AW write response");
            read_data(ADDR_CTRL, r_read_data, rd_resp);
            check_data(32'h5A5A_A5A5, r_read_data, "CTRL W->AW readback");
        end
    endtask

    task automatic run_backpressure_cases();
        logic [1:0] wr_resp;
        logic [1:0] rd_resp;

        begin
            r_test_number++;
            write_same_cycle(ADDR_CTRL, 32'h0000_00C3, 4'b1111, wr_resp);
            check_resp(RESP_OKAY, wr_resp, "CTRL same-cycle write response");
            read_data(ADDR_STATUS, r_read_data, rd_resp);
            check_resp(RESP_OKAY, rd_resp, "STATUS read response");
        end
    endtask

    task automatic run_unsupported_access_cases();
        logic [1:0] rd_resp;

        begin
            r_test_number++;
            read_data(ADDR_TXDATA, r_read_data, rd_resp);
            check_resp(RESP_SLVERR, rd_resp, "TXDATA read response");
        end
    endtask

    task automatic run_uart_loopback_case();
        logic [1:0] wr_resp;
        logic [1:0] rd_resp;
        logic [31:0] status_data;

        begin
            r_test_number++;
            write_same_cycle(ADDR_TXDATA, 32'h0000_005A, 4'b0001, wr_resp);
            check_resp(RESP_OKAY, wr_resp, "TXDATA write response");
            wait_rx_not_empty(status_data, rd_resp);
            check_resp(RESP_OKAY, rd_resp, "STATUS poll response after loopback");
            read_data(ADDR_RXDATA, r_read_data, rd_resp);
            check_resp(RESP_OKAY, rd_resp, "RXDATA read response");
            check_data(32'h0000_005A, {24'b0, r_read_data[7:0]}, "RXDATA loopback byte");
        end
    endtask

    task automatic run_error_response_cases();
        logic [1:0] wr_resp;
        logic [1:0] rd_resp;

        begin
            r_test_number++;
            read_data(ADDR_BAD, r_read_data, rd_resp);
            check_resp(RESP_DECERR, rd_resp, "Invalid address read response");

            r_test_number++;
            write_same_cycle(ADDR_BAD, 32'h1234_5678, 4'b1111, wr_resp);
            check_resp(RESP_DECERR, wr_resp, "Invalid address write response");

            r_test_number++;
            write_same_cycle(ADDR_TXDATA, 32'h0000_00A5, 4'b0000, wr_resp);
            check_resp(RESP_SLVERR, wr_resp, "Zero strobe TXDATA write response");
        end
    endtask

    //==============================================================================
    // Summary Reporting
    //==============================================================================

    task automatic report_summary();
        begin
            $display("\n========================================");
            $display("    AXI-UART Test Execution Summary");
            $display("========================================");
            $display("Total Tests: %0d", r_test_number);
            $display("Passed:      %0d", r_test_pass);
            $display("Failed:      %0d", r_test_fail);
            $display("========================================\n");

            if (r_test_fail == 0) begin
                $display("*** ALL TESTS PASSED ***");
                $finish(0);
            end else begin
                $display("*** SOME TESTS FAILED ***");
                $finish(1);
            end
        end
    endtask

endmodule

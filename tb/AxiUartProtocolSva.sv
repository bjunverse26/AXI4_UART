//==============================================================================
// File Name   : AxiUartProtocolSva.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : Assertion and coverage monitor for AXI4-Lite UART register
//               transactions.
// Notes       : Generic AXI channel rules and UART-specific response rules are
//               checked in one passive monitor for the directed testbench.
//==============================================================================

`timescale 1ns / 1ps

module AxiUartProtocolSva (
    input logic        i_aclk,
    input logic        i_aresetn,
    input logic [31:0] i_awaddr,
    input logic        i_awvalid,
    input logic        i_awready,
    input logic [31:0] i_wdata,
    input logic [3:0]  i_wstrb,
    input logic        i_wvalid,
    input logic        i_wready,
    input logic [1:0]  i_bresp,
    input logic        i_bvalid,
    input logic        i_bready,
    input logic [31:0] i_araddr,
    input logic        i_arvalid,
    input logic        i_arready,
    input logic [31:0] i_rdata,
    input logic [1:0]  i_rresp,
    input logic        i_rvalid,
    input logic        i_rready,
    input logic        i_tx,
    input logic        i_rx_empty,
    input logic        i_tx_full
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam logic [31:0] ADDR_STATUS = 32'h0000_0004;
    localparam logic [31:0] ADDR_TXDATA = 32'h0000_0008;
    localparam logic [31:0] ADDR_RXDATA = 32'h0000_000C;
    localparam logic [31:0] ADDR_BAD    = 32'h0000_0010;

    integer r_sva_error_count = 0;

    sequence aw_hs;
        i_awvalid && i_awready;
    endsequence

    sequence w_hs;
        i_wvalid && i_wready;
    endsequence

    sequence ar_hs;
        i_arvalid && i_arready;
    endsequence

    property valid_holds_until_ready(logic valid_sig, logic ready_sig);
        @(posedge i_aclk) disable iff (!i_aresetn)
        valid_sig && !ready_sig |=> valid_sig;
    endproperty

    property write_eventually_gets_b;
        @(posedge i_aclk) disable iff (!i_aresetn)
        ((aw_hs ##[0:16] w_hs) or (w_hs ##[0:16] aw_hs))
        |-> ##[0:16] i_bvalid;
    endproperty

    property read_eventually_gets_r;
        @(posedge i_aclk) disable iff (!i_aresetn)
        ar_hs |-> ##[0:16] i_rvalid;
    endproperty

    assert_aw_valid_stable: assert property (valid_holds_until_ready(i_awvalid, i_awready))
        else begin r_sva_error_count++; $error("[SVA FAIL] AWVALID dropped before AWREADY"); end

    assert_w_valid_stable: assert property (valid_holds_until_ready(i_wvalid, i_wready))
        else begin r_sva_error_count++; $error("[SVA FAIL] WVALID dropped before WREADY"); end

    assert_b_valid_stable: assert property (valid_holds_until_ready(i_bvalid, i_bready))
        else begin r_sva_error_count++; $error("[SVA FAIL] BVALID dropped before BREADY"); end

    assert_ar_valid_stable: assert property (valid_holds_until_ready(i_arvalid, i_arready))
        else begin r_sva_error_count++; $error("[SVA FAIL] ARVALID dropped before ARREADY"); end

    assert_r_valid_stable: assert property (valid_holds_until_ready(i_rvalid, i_rready))
        else begin r_sva_error_count++; $error("[SVA FAIL] RVALID dropped before RREADY"); end

    assert_aw_addr_stable: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_awvalid && !i_awready |=> $stable(i_awaddr)
    ) else begin r_sva_error_count++; $error("[SVA FAIL] AWADDR changed while waiting"); end

    assert_w_data_stable: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_wvalid && !i_wready |=> ($stable(i_wdata) && $stable(i_wstrb))
    ) else begin r_sva_error_count++; $error("[SVA FAIL] WDATA/WSTRB changed while waiting"); end

    assert_ar_addr_stable: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_arvalid && !i_arready |=> $stable(i_araddr)
    ) else begin r_sva_error_count++; $error("[SVA FAIL] ARADDR changed while waiting"); end

    assert_reset_valid: assert property (
        @(posedge i_aclk) !i_aresetn |-> (!i_bvalid && !i_rvalid && (i_tx == 1'b1))
    ) else begin r_sva_error_count++; $error("[SVA FAIL] Reset outputs are not idle"); end

    assert_write_eventually_gets_b: assert property (write_eventually_gets_b)
        else begin r_sva_error_count++; $error("[SVA FAIL] Write did not produce BVALID in time"); end

    assert_read_eventually_gets_r: assert property (read_eventually_gets_r)
        else begin r_sva_error_count++; $error("[SVA FAIL] Read did not produce RVALID in time"); end

    assert_valid_bresp_values: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_bvalid |-> (i_bresp inside {RESP_OKAY, RESP_SLVERR, RESP_DECERR})
    ) else begin r_sva_error_count++; $error("[SVA FAIL] Invalid BRESP value"); end

    assert_valid_rresp_values: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_rvalid |-> (i_rresp inside {RESP_OKAY, RESP_SLVERR, RESP_DECERR})
    ) else begin r_sva_error_count++; $error("[SVA FAIL] Invalid RRESP value"); end

    assert_status_data_matches_flags: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_rvalid && (i_rresp == RESP_OKAY) && (i_araddr == ADDR_STATUS)
        |-> (i_rdata[1:0] == {i_rx_empty, i_tx_full})
    ) else begin r_sva_error_count++; $error("[SVA FAIL] STATUS flags mismatch"); end

    assert_txdata_read_slverr: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_arvalid && i_arready && (i_araddr == ADDR_TXDATA)
        |-> ##[0:16] (i_rvalid && (i_rresp == RESP_SLVERR))
    ) else begin r_sva_error_count++; $error("[SVA FAIL] TXDATA read did not return SLVERR"); end

    assert_empty_rxdata_read_slverr: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_arvalid && i_arready && (i_araddr == ADDR_RXDATA) && i_rx_empty
        |-> ##[0:16] (i_rvalid && (i_rresp == RESP_SLVERR))
    ) else begin r_sva_error_count++; $error("[SVA FAIL] Empty RXDATA read did not return SLVERR"); end

    assert_bad_read_decerr: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_arvalid && i_arready && (i_araddr == ADDR_BAD)
        |-> ##[0:16] (i_rvalid && (i_rresp == RESP_DECERR))
    ) else begin r_sva_error_count++; $error("[SVA FAIL] Invalid read did not return DECERR"); end

    assert_bad_write_decerr: assert property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_awvalid && i_awready && i_wvalid && i_wready && (i_awaddr == ADDR_BAD)
        |-> ##[0:16] (i_bvalid && (i_bresp == RESP_DECERR))
    ) else begin r_sva_error_count++; $error("[SVA FAIL] Invalid write did not return DECERR"); end

    cover_aw_handshake: cover property (@(posedge i_aclk) i_awvalid && i_awready);
    cover_w_handshake : cover property (@(posedge i_aclk) i_wvalid  && i_wready);
    cover_b_handshake : cover property (@(posedge i_aclk) i_bvalid  && i_bready);
    cover_ar_handshake: cover property (@(posedge i_aclk) i_arvalid && i_arready);
    cover_r_handshake : cover property (@(posedge i_aclk) i_rvalid  && i_rready);
    cover_uart_loopback: cover property (
        @(posedge i_aclk) disable iff (!i_aresetn)
        i_awvalid && i_awready && i_wvalid && i_wready && (i_awaddr == ADDR_TXDATA) && i_wstrb[0]
        ##[1:256] i_arvalid && i_arready && (i_araddr == ADDR_RXDATA)
        ##[0:16] i_rvalid && i_rready && (i_rresp == RESP_OKAY)
    );

    final begin
        if (r_sva_error_count == 0) begin
            $display("[SVA PASS] All required AXI-UART assertions passed.");
        end else begin
            $display("[SVA SUMMARY] Total assertion failures: %0d", r_sva_error_count);
        end
    end

endmodule

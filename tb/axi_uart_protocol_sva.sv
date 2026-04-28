`timescale 1ns / 1ps

module axi_uart_protocol_sva (
    input wire        aclk,
    input wire        aresetn,

    // AXI write address 채널
    input wire [31:0] awaddr,
    input wire        awvalid,
    input wire        awready,

    // AXI write data 채널
    input wire [31:0] wdata,
    input wire [3:0]  wstrb,
    input wire        wvalid,
    input wire        wready,

    // AXI write response 채널
    input wire [1:0]  bresp,
    input wire        bvalid,
    input wire        bready,

    // AXI read address 채널
    input wire [31:0] araddr,
    input wire        arvalid,
    input wire        arready,

    // AXI read data 채널
    input wire [31:0] rdata,
    input wire [1:0]  rresp,
    input wire        rvalid,
    input wire        rready,

    // UART 상태 신호
    input wire        tx,
    input wire        rx_empty,
    input wire        tx_full
);

    // assertion 실패 횟수 카운트
    integer sva_error_count = 0;

    // AXI 응답 코드
    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;
    localparam [1:0] RESP_DECERR = 2'b11;

    // UART 레지스터 주소
    localparam [31:0] ADDR_CTRL   = 32'h0000_0000;
    localparam [31:0] ADDR_STATUS = 32'h0000_0004;
    localparam [31:0] ADDR_TXDATA = 32'h0000_0008;
    localparam [31:0] ADDR_RXDATA = 32'h0000_000C;
    localparam [31:0] ADDR_BAD    = 32'h0000_0010;

    // AXI VALID는 READY 전까지 유지되어야 함
    property aw_valid_stable;
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> awvalid;
    endproperty

    property w_valid_stable;
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> wvalid;
    endproperty

    property b_valid_stable;
        @(posedge aclk) disable iff (!aresetn)
        bvalid && !bready |=> bvalid;
    endproperty

    property ar_valid_stable;
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> arvalid;
    endproperty

    property r_valid_stable;
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> rvalid;
    endproperty

    // VALID가 유지되는 동안 payload도 안정적이어야 함
    property aw_addr_stable;
        @(posedge aclk) disable iff (!aresetn)
        awvalid && !awready |=> $stable(awaddr);
    endproperty

    property w_data_stable;
        @(posedge aclk) disable iff (!aresetn)
        wvalid && !wready |=> ($stable(wdata) && $stable(wstrb));
    endproperty

    property ar_addr_stable;
        @(posedge aclk) disable iff (!aresetn)
        arvalid && !arready |=> $stable(araddr);
    endproperty

    property b_resp_stable;
        @(posedge aclk) disable iff (!aresetn)
        bvalid && !bready |=> $stable(bresp);
    endproperty

    property r_data_stable;
        @(posedge aclk) disable iff (!aresetn)
        rvalid && !rready |=> ($stable(rdata) && $stable(rresp));
    endproperty

    // reset 동안 response valid는 비활성 상태여야 함
    property reset_clears_response_valid;
        @(posedge aclk)
        !aresetn |-> (!bvalid && !rvalid);
    endproperty

    // AXI 각 채널 handshake 정의
    sequence aw_hs;
        awvalid && awready;
    endsequence

    sequence w_hs;
        wvalid && wready;
    endsequence

    sequence ar_hs;
        arvalid && arready;
    endsequence

    sequence b_hs;
        bvalid && bready;
    endsequence

    sequence r_hs;
        rvalid && rready;
    endsequence

    // write address/data가 수락되면 일정 시간 내 B 응답이 와야 함
    property write_eventually_gets_b;
        @(posedge aclk) disable iff (!aresetn)
        ((aw_hs ##[0:16] w_hs) or (w_hs ##[0:16] aw_hs))
        |-> ##[0:16] bvalid;
    endproperty

    // read address가 수락되면 일정 시간 내 R 응답이 와야 함
    property read_eventually_gets_r;
        @(posedge aclk) disable iff (!aresetn)
        ar_hs |-> ##[0:16] rvalid;
    endproperty

    // 응답값은 허용된 값만 사용해야 함
    property valid_bresp_values;
        @(posedge aclk) disable iff (!aresetn)
        bvalid |-> (bresp inside {RESP_OKAY, RESP_SLVERR, RESP_DECERR});
    endproperty

    property valid_rresp_values;
        @(posedge aclk) disable iff (!aresetn)
        rvalid |-> (rresp inside {RESP_OKAY, RESP_SLVERR, RESP_DECERR});
    endproperty

    // reset 중 UART TX는 idle 상태여야 함
    property reset_tx_idle;
        @(posedge aclk)
        !aresetn |-> (tx == 1'b1);
    endproperty

    // STATUS read는 OKAY 응답이어야 함
    property status_read_returns_okay;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arready && (araddr == ADDR_STATUS))
        |-> ##[0:16] (rvalid && (rresp == RESP_OKAY));
    endproperty

    // TXDATA를 read하면 SLVERR여야 함
    property txdata_read_returns_slverr;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arready && (araddr == ADDR_TXDATA))
        |-> ##[0:16] (rvalid && (rresp == RESP_SLVERR));
    endproperty

    // RX FIFO가 비어 있을 때 RXDATA read는 SLVERR여야 함
    property empty_rxdata_read_returns_slverr;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arready && (araddr == ADDR_RXDATA) && rx_empty)
        |-> ##[0:16] (rvalid && (rresp == RESP_SLVERR));
    endproperty

    // 잘못된 read 주소는 DECERR여야 함
    property bad_read_returns_decerr;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && arready && (araddr == ADDR_BAD))
        |-> ##[0:16] (rvalid && (rresp == RESP_DECERR));
    endproperty

    // TXDATA에 zero strobe write 시 SLVERR여야 함
    property txdata_zero_strobe_returns_slverr;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awready && wvalid && wready && (awaddr == ADDR_TXDATA) && (wstrb == 4'b0000))
        |-> ##[0:16] (bvalid && (bresp == RESP_SLVERR));
    endproperty

    // 잘못된 write 주소는 DECERR여야 함
    property bad_write_returns_decerr;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && awready && wvalid && wready && (awaddr == ADDR_BAD))
        |-> ##[0:16] (bvalid && (bresp == RESP_DECERR));
    endproperty

    // STATUS 데이터가 실제 UART 플래그와 일치해야 함
    property status_data_matches_flags;
        @(posedge aclk) disable iff (!aresetn)
        rvalid && (rresp == RESP_OKAY) && (araddr == ADDR_STATUS)
        |-> (rdata[1:0] == {rx_empty, tx_full});
    endproperty

    // AWVALID 유지 확인
    assert_aw_valid_stable: assert property(aw_valid_stable)
        else begin sva_error_count++; $error("[SVA FAIL] AWVALID dropped before AWREADY"); end

    // WVALID 유지 확인
    assert_w_valid_stable: assert property(w_valid_stable)
        else begin sva_error_count++; $error("[SVA FAIL] WVALID dropped before WREADY"); end

    // BVALID 유지 확인
    assert_b_valid_stable: assert property(b_valid_stable)
        else begin sva_error_count++; $error("[SVA FAIL] BVALID dropped before BREADY"); end

    // ARVALID 유지 확인
    assert_ar_valid_stable: assert property(ar_valid_stable)
        else begin sva_error_count++; $error("[SVA FAIL] ARVALID dropped before ARREADY"); end

    // RVALID 유지 확인
    assert_r_valid_stable: assert property(r_valid_stable)
        else begin sva_error_count++; $error("[SVA FAIL] RVALID dropped before RREADY"); end

    // AWADDR 안정성 확인
    assert_aw_addr_stable: assert property(aw_addr_stable)
        else begin sva_error_count++; $error("[SVA FAIL] AWADDR changed while waiting"); end

    // WDATA/WSTRB 안정성 확인
    assert_w_data_stable: assert property(w_data_stable)
        else begin sva_error_count++; $error("[SVA FAIL] WDATA/WSTRB changed while waiting"); end

    // ARADDR 안정성 확인
    assert_ar_addr_stable: assert property(ar_addr_stable)
        else begin sva_error_count++; $error("[SVA FAIL] ARADDR changed while waiting"); end

    // BRESP 안정성 확인
    assert_b_resp_stable: assert property(b_resp_stable)
        else begin sva_error_count++; $error("[SVA FAIL] BRESP changed while waiting"); end

    // RDATA/RRESP 안정성 확인
    assert_r_data_stable: assert property(r_data_stable)
        else begin sva_error_count++; $error("[SVA FAIL] RDATA/RRESP changed while waiting"); end

    // reset 중 response valid 비활성 확인
    assert_reset_valid: assert property(reset_clears_response_valid)
        else begin sva_error_count++; $error("[SVA FAIL] BVALID/RVALID active during reset"); end

    // write 후 B 응답 도착 확인
    assert_write_eventually_gets_b: assert property(write_eventually_gets_b)
        else begin sva_error_count++; $error("[SVA FAIL] Write did not produce BVALID in time"); end

    // read 후 R 응답 도착 확인
    assert_read_eventually_gets_r: assert property(read_eventually_gets_r)
        else begin sva_error_count++; $error("[SVA FAIL] Read did not produce RVALID in time"); end

    // BRESP 값 범위 확인
    assert_valid_bresp_values: assert property(valid_bresp_values)
        else begin sva_error_count++; $error("[SVA FAIL] Invalid BRESP value"); end

    // RRESP 값 범위 확인
    assert_valid_rresp_values: assert property(valid_rresp_values)
        else begin sva_error_count++; $error("[SVA FAIL] Invalid RRESP value"); end

    // reset 중 TX idle 확인
    assert_reset_tx_idle: assert property(reset_tx_idle)
        else begin sva_error_count++; $error("[SVA FAIL] TX is not idle during reset"); end

    // STATUS read 응답 확인
    assert_status_read_returns_okay: assert property(status_read_returns_okay)
        else begin sva_error_count++; $error("[SVA FAIL] STATUS read did not return OKAY"); end

    // TXDATA read 응답 확인
    assert_txdata_read_returns_slverr: assert property(txdata_read_returns_slverr)
        else begin sva_error_count++; $error("[SVA FAIL] TXDATA read did not return SLVERR"); end

    // empty RXDATA read 응답 확인
    assert_empty_rxdata_read_returns_slverr: assert property(empty_rxdata_read_returns_slverr)
        else begin sva_error_count++; $error("[SVA FAIL] Empty RXDATA read did not return SLVERR"); end

    // invalid read 응답 확인
    assert_bad_read_returns_decerr: assert property(bad_read_returns_decerr)
        else begin sva_error_count++; $error("[SVA FAIL] Invalid read did not return DECERR"); end

    // zero-strobe write 응답 확인
    assert_txdata_zero_strobe_returns_slverr: assert property(txdata_zero_strobe_returns_slverr)
        else begin sva_error_count++; $error("[SVA FAIL] Zero-strobe TXDATA write did not return SLVERR"); end

    // invalid write 응답 확인
    assert_bad_write_returns_decerr: assert property(bad_write_returns_decerr)
        else begin sva_error_count++; $error("[SVA FAIL] Invalid write did not return DECERR"); end

    // STATUS 데이터와 UART 상태 일치 확인
    assert_status_data_matches_flags: assert property(status_data_matches_flags)
        else begin sva_error_count++; $error("[SVA FAIL] STATUS data does not match UART flags"); end

    // 기본 handshake coverage
    cover_aw_handshake: cover property(@(posedge aclk) awvalid && awready);
    cover_w_handshake : cover property(@(posedge aclk) wvalid  && wready);
    cover_b_handshake : cover property(@(posedge aclk) bvalid  && bready);
    cover_ar_handshake: cover property(@(posedge aclk) arvalid && arready);
    cover_r_handshake : cover property(@(posedge aclk) rvalid  && rready);

    // stall/backpressure coverage
    cover_aw_stall: cover property(@(posedge aclk) awvalid && !awready);
    cover_w_stall : cover property(@(posedge aclk) wvalid  && !wready);
    cover_b_stall : cover property(@(posedge aclk) bvalid  && !bready);
    cover_ar_stall: cover property(@(posedge aclk) arvalid && !arready);
    cover_r_stall : cover property(@(posedge aclk) rvalid  && !rready);

    // write 순서 coverage
    cover_aw_then_w: cover property(@(posedge aclk)
        (awvalid && awready) ##[0:16] (wvalid && wready));

    cover_w_then_aw: cover property(@(posedge aclk)
        (wvalid && wready) ##[0:16] (awvalid && awready));

    cover_aw_w_same_cycle: cover property(@(posedge aclk)
        (awvalid && awready && wvalid && wready));

    // write/read end-to-end coverage
    cover_write_to_b_aw_first: cover property(@(posedge aclk)
        ((awvalid && awready) ##[0:16] (wvalid && wready))
        ##[0:16] (bvalid && bready));

    cover_write_to_b_w_first: cover property(@(posedge aclk)
        ((wvalid && wready) ##[0:16] (awvalid && awready))
        ##[0:16] (bvalid && bready));

    cover_read_to_r: cover property(@(posedge aclk)
        (arvalid && arready) ##[0:16] (rvalid && rready));

    // CTRL write 후 CTRL read coverage
    cover_ctrl_access: cover property(@(posedge aclk) disable iff (!aresetn)
        (awvalid && awready && (awaddr == ADDR_CTRL)) ##[0:16] (bvalid && bready) ##[0:16]
        (arvalid && arready && (araddr == ADDR_CTRL)) ##[0:16] (rvalid && rready));

    // TX write 후 RX read 성공 coverage
    cover_uart_loopback: cover property(@(posedge aclk) disable iff (!aresetn)
        (awvalid && awready && wvalid && wready && (awaddr == ADDR_TXDATA) && (wstrb[0]))
        ##[1:256] (arvalid && arready && (araddr == ADDR_RXDATA))
        ##[0:16] (rvalid && rready && (rresp == RESP_OKAY)));

    // empty RX read 에러 coverage
    cover_empty_rx_slverr: cover property(@(posedge aclk) disable iff (!aresetn)
        (arvalid && arready && (araddr == ADDR_RXDATA))
        ##[0:16] (rvalid && rready && (rresp == RESP_SLVERR)));

    // invalid read 에러 coverage
    cover_bad_read_decerr: cover property(@(posedge aclk) disable iff (!aresetn)
        (arvalid && arready && (araddr == ADDR_BAD))
        ##[0:16] (rvalid && rready && (rresp == RESP_DECERR)));

    // invalid write 에러 coverage
    cover_bad_write_decerr: cover property(@(posedge aclk) disable iff (!aresetn)
        (awvalid && awready && wvalid && wready && (awaddr == ADDR_BAD))
        ##[0:16] (bvalid && bready && (bresp == RESP_DECERR)));

    // zero-strobe write 에러 coverage
    cover_zero_strobe_slverr: cover property(@(posedge aclk) disable iff (!aresetn)
        (awvalid && awready && wvalid && wready && (awaddr == ADDR_TXDATA) && (wstrb == 4'b0000))
        ##[0:16] (bvalid && bready && (bresp == RESP_SLVERR)));

    // 시뮬레이션 종료 시 결과 출력
    final begin
        if (sva_error_count == 0)
            $display("[SVA PASS] All required AXI-UART assertions passed.");
        else
            $display("[SVA SUMMARY] Total assertion failures: %0d", sva_error_count);
    end

endmodule

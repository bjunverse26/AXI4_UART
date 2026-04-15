`timescale 1ns / 1ps

module tb_axi_uart_sva;

    // 기본 파라미터
    localparam int CLK_FREQ       = 32;
    localparam int BAUD_RATE      = 1;
    localparam int AXI_ADDR_WIDTH = 32;
    localparam int AXI_DATA_WIDTH = 32;
    localparam int AXI_STRB       = AXI_DATA_WIDTH / 8;

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

    // 클럭 / 리셋
    logic clk;
    logic resetn;

    // AXI write address 채널
    logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [2:0]                s_axi_awprot;
    logic                      s_axi_awvalid;
    logic                      s_axi_awready;

    // AXI write data 채널
    logic [AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [AXI_STRB-1:0]       s_axi_wstrb;
    logic                      s_axi_wvalid;
    logic                      s_axi_wready;

    // AXI write response 채널
    logic [1:0]                s_axi_bresp;
    logic                      s_axi_bvalid;
    logic                      s_axi_bready;

    // AXI read address 채널
    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic [2:0]                s_axi_arprot;
    logic                      s_axi_arvalid;
    logic                      s_axi_arready;

    // AXI read data 채널
    logic [AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]                s_axi_rresp;
    logic                      s_axi_rvalid;
    logic                      s_axi_rready;

    // UART 핀
    logic tx;
    logic rx;

    // 테스트용 변수
    time time_start;
    time time_end;
    logic [31:0] read_data;
    integer test_number;
    integer test_pass;
    integer test_fail;

    // DUT 인스턴스
    axi_uart #(
        .CLK_FREQ        (CLK_FREQ),
        .BAUD_RATE       (BAUD_RATE),
        .AXI_ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH  (AXI_DATA_WIDTH),
        .FIFO_ADDR_WIDTH (4)
    ) dut (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (resetn),

        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),

        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),

        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),

        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),

        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),

        .tx            (tx),
        .rx            (rx)
    );

    // UART loopback 연결
    assign rx = tx;

    // SVA 모듈 연결
    axi_uart_protocol_sva u_sva (
        .aclk    (clk),
        .aresetn (resetn),
        .awaddr  (s_axi_awaddr),
        .awvalid (s_axi_awvalid),
        .awready (s_axi_awready),
        .wdata   (s_axi_wdata),
        .wstrb   (s_axi_wstrb),
        .wvalid  (s_axi_wvalid),
        .wready  (s_axi_wready),
        .bresp   (s_axi_bresp),
        .bvalid  (s_axi_bvalid),
        .bready  (s_axi_bready),
        .araddr  (s_axi_araddr),
        .arvalid (s_axi_arvalid),
        .arready (s_axi_arready),
        .rdata   (s_axi_rdata),
        .rresp   (s_axi_rresp),
        .rvalid  (s_axi_rvalid),
        .rready  (s_axi_rready),
        .tx      (tx),
        .rx_empty(dut.rx_empty),
        .tx_full (dut.tx_full)
    );

    // 클럭 생성
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 응답 코드를 문자열로 변환
    function string get_resp_string;
        input [1:0] resp;
        begin
            case (resp)
                2'b00: get_resp_string = "OKAY";
                2'b01: get_resp_string = "EXOKAY";
                2'b10: get_resp_string = "SLVERR";
                2'b11: get_resp_string = "DECERR";
            endcase
        end
    endfunction

    // 데이터 비교용 헬퍼
    task check_data;
        input [31:0] expected;
        input [31:0] actual;
        input string msg;
        begin
            if (expected == actual) begin
                $display("[PASS] %s", msg);
                $display("- Expected : 0x%08h", expected);
                $display("- Actual   : 0x%08h", actual);
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] %s", msg);
                $display("- Expected : 0x%08h", expected);
                $display("- Actual   : 0x%08h", actual);
                test_fail = test_fail + 1;
            end
            $display("");
        end
    endtask

    // 응답값 비교용 헬퍼
    task check_resp;
        input [1:0] expected;
        input [1:0] actual;
        input string msg;
        begin
            if (expected == actual) begin
                $display("[PASS] %s", msg);
                $display("- Expected RESP : %s", get_resp_string(expected));
                $display("- Actual RESP   : %s", get_resp_string(actual));
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] %s", msg);
                $display("- Expected RESP : %s", get_resp_string(expected));
                $display("- Actual RESP   : %s", get_resp_string(actual));
                test_fail = test_fail + 1;
            end
            $display("");
        end
    endtask

    // AW 먼저, W 나중에 보내는 write
    task write_aw_then_w;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        output [1:0] resp;
        begin
            time_start    = $time;

            // AW 전송
            s_axi_awaddr  = addr;
            s_axi_awprot  = 3'b000;
            s_axi_awvalid = 1'b1;
            s_axi_bready  = 1'b1;
            @(posedge clk iff s_axi_awready);
            s_axi_awvalid = 1'b0;

            // W 전송
            s_axi_wdata  = data;
            s_axi_wstrb  = strb;
            s_axi_wvalid = 1'b1;
            @(posedge clk iff s_axi_wready);
            s_axi_wvalid = 1'b0;

            // B 응답 수신
            @(posedge clk iff s_axi_bvalid);
            resp = s_axi_bresp;
            s_axi_bready = 1'b0;
            time_end = $time;
        end
    endtask

    // W 먼저, AW 나중에 보내는 write
    task write_w_then_aw;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        output [1:0] resp;
        begin
            time_start   = $time;

            // W 전송
            s_axi_wdata  = data;
            s_axi_wstrb  = strb;
            s_axi_wvalid = 1'b1;
            s_axi_bready = 1'b1;
            @(posedge clk iff s_axi_wready);
            s_axi_wvalid = 1'b0;

            // AW 전송
            s_axi_awaddr  = addr;
            s_axi_awprot  = 3'b000;
            s_axi_awvalid = 1'b1;
            @(posedge clk iff s_axi_awready);
            s_axi_awvalid = 1'b0;

            // B 응답 수신
            @(posedge clk iff s_axi_bvalid);
            resp = s_axi_bresp;
            s_axi_bready = 1'b0;
            time_end = $time;
        end
    endtask

    // AW와 W를 같은 cycle에 보내는 write
    task write_same_cycle;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        output [1:0] resp;
        begin
            time_start    = $time;
            s_axi_awaddr  = addr;
            s_axi_awprot  = 3'b000;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wstrb   = strb;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;

            @(posedge clk iff (s_axi_awready && s_axi_wready));
            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;

            @(posedge clk iff s_axi_bvalid);
            resp = s_axi_bresp;
            s_axi_bready = 1'b0;
            time_end = $time;
        end
    endtask

    // B 채널 backpressure를 주는 write
    task write_with_b_backpressure;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        input integer delay_cycles;
        output [1:0] resp;
        begin
            time_start    = $time;
            s_axi_awaddr  = addr;
            s_axi_awprot  = 3'b000;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = data;
            s_axi_wstrb   = strb;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b0;

            // AW/W handshake
            @(posedge clk iff (s_axi_awready && s_axi_wready));
            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;

            // BVALID 이후 ready를 일부러 늦게 줌
            @(posedge clk iff s_axi_bvalid);
            repeat(delay_cycles) @(posedge clk);
            resp = s_axi_bresp;
            s_axi_bready = 1'b1;
            @(posedge clk);
            s_axi_bready = 1'b0;
            time_end = $time;
        end
    endtask

    // 기본 read
    task read_test;
        input [31:0] addr;
        output [31:0] data;
        output [1:0]  resp;
        begin
            time_start    = $time;
            s_axi_araddr  = addr;
            s_axi_arprot  = 3'b000;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b1;
            @(posedge clk iff s_axi_arready);
            s_axi_arvalid = 1'b0;

            @(posedge clk iff s_axi_rvalid);
            data = s_axi_rdata;
            resp = s_axi_rresp;
            s_axi_rready = 1'b0;
            time_end = $time;
        end
    endtask

    // R 채널 backpressure를 주는 read
    task read_with_r_backpressure;
        input [31:0] addr;
        input integer delay_cycles;
        output [31:0] data;
        output [1:0]  resp;
        begin
            time_start    = $time;
            s_axi_araddr  = addr;
            s_axi_arprot  = 3'b000;
            s_axi_arvalid = 1'b1;
            s_axi_rready  = 1'b0;
            @(posedge clk iff s_axi_arready);
            s_axi_arvalid = 1'b0;

            // RVALID 이후 ready를 일부러 늦게 줌
            @(posedge clk iff s_axi_rvalid);
            repeat(delay_cycles) @(posedge clk);
            data = s_axi_rdata;
            resp = s_axi_rresp;
            s_axi_rready = 1'b1;
            @(posedge clk);
            s_axi_rready = 1'b0;
            time_end = $time;
        end
    endtask

    // RX FIFO가 비어있지 않을 때까지 STATUS polling
    task wait_rx_not_empty;
        output [31:0] status_data;
        output [1:0]  status_resp;
        integer timeout;
        begin
            timeout = 0;
            read_test(ADDR_STATUS, status_data, status_resp);
            while (status_data[1] && timeout < 300) begin
                repeat (4) @(posedge clk);
                read_test(ADDR_STATUS, status_data, status_resp);
                timeout = timeout + 1;
            end

            if (timeout >= 300) begin
                $display("[FAIL] RX FIFO did not receive loopback data");
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 메인 테스트 시나리오
    initial begin
        logic [1:0]  wr_resp;
        logic [1:0]  rd_resp;
        logic [31:0] status_data;

        // 초기값 설정
        resetn = 1'b0;

        s_axi_awaddr  = '0;
        s_axi_awprot  = 3'b000;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = '0;
        s_axi_arprot  = 3'b000;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        test_pass   = 0;
        test_fail   = 0;
        test_number = 0;

        // reset 유지 후 해제
        repeat (10) @(posedge clk);
        resetn = 1'b1;
        repeat (5) @(posedge clk);

        $display("\n========================================");
        $display("       AXI-UART Verification TB");
        $display("========================================");

        // 초기 STATUS 확인
        test_number = test_number + 1;
        $display("Test %0d: Initial STATUS read", test_number);
        read_test(ADDR_STATUS, read_data, rd_resp);
        check_resp(RESP_OKAY, rd_resp, "Initial STATUS read response");
        check_data(32'h0000_0002, {30'b0, read_data[1:0]}, "Initial STATUS flags");

        // 빈 RXDATA read 에러 확인
        test_number = test_number + 1;
        $display("Test %0d: Empty RXDATA read", test_number);
        read_test(ADDR_RXDATA, read_data, rd_resp);
        check_resp(RESP_SLVERR, rd_resp, "Empty RXDATA read response");

        // CTRL AW->W write/readback 확인
        test_number = test_number + 1;
        $display("Test %0d: CTRL AW then W write/read", test_number);
        write_aw_then_w(ADDR_CTRL, 32'hA5A5_5A5A, 4'b1111, wr_resp);
        check_resp(RESP_OKAY, wr_resp, "CTRL AW->W write response");
        read_test(ADDR_CTRL, read_data, rd_resp);
        check_resp(RESP_OKAY, rd_resp, "CTRL read response after AW->W write");
        check_data(32'hA5A5_5A5A, read_data, "CTRL readback after AW->W write");

        // CTRL W->AW write/readback 확인
        test_number = test_number + 1;
        $display("Test %0d: CTRL W then AW write/read", test_number);
        write_w_then_aw(ADDR_CTRL, 32'h5A5A_A5A5, 4'b1111, wr_resp);
        check_resp(RESP_OKAY, wr_resp, "CTRL W->AW write response");
        read_test(ADDR_CTRL, read_data, rd_resp);
        check_resp(RESP_OKAY, rd_resp, "CTRL read response after W->AW write");
        check_data(32'h5A5A_A5A5, read_data, "CTRL readback after W->AW write");

        // B 채널 backpressure 확인
        test_number = test_number + 1;
        $display("Test %0d: B channel backpressure", test_number);
        write_with_b_backpressure(ADDR_CTRL, 32'h0000_00C3, 4'b1111, 3, wr_resp);
        check_resp(RESP_OKAY, wr_resp, "CTRL write response with B backpressure");

        // R 채널 backpressure 확인
        test_number = test_number + 1;
        $display("Test %0d: R channel backpressure", test_number);
        read_with_r_backpressure(ADDR_STATUS, 3, read_data, rd_resp);
        check_resp(RESP_OKAY, rd_resp, "STATUS read response with R backpressure");

        // TXDATA read 불가 확인
        test_number = test_number + 1;
        $display("Test %0d: TXDATA read is not supported", test_number);
        read_test(ADDR_TXDATA, read_data, rd_resp);
        check_resp(RESP_SLVERR, rd_resp, "TXDATA read response");

        // TX -> RX loopback 확인
        test_number = test_number + 1;
        $display("Test %0d: TX loopback to RXDATA", test_number);
        write_same_cycle(ADDR_TXDATA, 32'h0000_005A, 4'b0001, wr_resp);
        check_resp(RESP_OKAY, wr_resp, "TXDATA write response");
        wait_rx_not_empty(status_data, rd_resp);
        check_resp(RESP_OKAY, rd_resp, "STATUS poll response after TXDATA write");
        check_data(32'h0000_0000, {30'b0, status_data[1:0]}, "STATUS flags after loopback receive");
        read_test(ADDR_RXDATA, read_data, rd_resp);
        check_resp(RESP_OKAY, rd_resp, "RXDATA read response");
        check_data(32'h0000_005A, {24'b0, read_data[7:0]}, "RXDATA loopback byte");

        // 잘못된 주소 read 확인
        test_number = test_number + 1;
        $display("Test %0d: Invalid address read", test_number);
        read_test(ADDR_BAD, read_data, rd_resp);
        check_resp(RESP_DECERR, rd_resp, "Invalid address read response");

        // 잘못된 주소 write 확인
        test_number = test_number + 1;
        $display("Test %0d: Invalid address write", test_number);
        write_same_cycle(ADDR_BAD, 32'h1234_5678, 4'b1111, wr_resp);
        check_resp(RESP_DECERR, wr_resp, "Invalid address write response");

        // zero strobe write 확인
        test_number = test_number + 1;
        $display("Test %0d: Zero strobe TXDATA write", test_number);
        write_same_cycle(ADDR_TXDATA, 32'h0000_00A5, 4'b0000, wr_resp);
        check_resp(RESP_SLVERR, wr_resp, "Zero strobe TXDATA write response");

        // 결과 요약
        $display("\n========================================");
        $display("    Test Execution Summary");
        $display("========================================");
        $display("Total Tests:    %0d", test_number);
        $display("Passed:         %0d", test_pass);
        $display("Failed:         %0d", test_fail);
        if ((test_pass + test_fail) != 0)
            $display("Pass Rate:      %0d%%", (test_pass * 100) / (test_pass + test_fail));
        $display("========================================\n");

        // 최종 종료
        if (test_fail == 0) begin
            $display("*** ALL TESTS PASSED ***");
            $finish(0);
        end else begin
            $display("*** SOME TESTS FAILED ***");
            $finish(1);
        end
    end

endmodule

# AXI4 UART Design Project

32-bit AXI4-Lite Slave interface로 UART Core를 제어하는 memory-mapped peripheral을 설계하고, Directed Testbench와 SystemVerilog Assertions(SVA)로 AXI access, UART loopback, error response, protocol 동작을 검증한 RTL 프로젝트입니다.

## 프로젝트 개요

이 프로젝트는 AXI4-Lite 기반 register map을 통해 UART 송수신 경로를 제어하는 것을 목표로 합니다.  
AXI master는 `CTRL`, `STATUS`, `TXDATA`, `RXDATA` register를 통해 UART Core에 접근하고, 내부 UART Core는 Baud Generator, TX/RX FIFO, UART TX/RX block으로 구성됩니다.

검증 구조는 AXI4-Lite 프로젝트와 같은 틀로 맞췄습니다. Testbench는 directed scenario와 결과 summary를 담당하고, SVA는 AXI4-Lite 필수 protocol assertion과 UART 전용 register behavior assertion을 함께 확인합니다.

## 한눈에 보기

| 항목 | 내용 |
| --- | --- |
| 프로젝트 유형 | RTL 설계 + 기능 검증 + protocol 검증 |
| 인터페이스 | AXI4-Lite Slave, UART |
| AXI 데이터 폭 | 32-bit |
| UART 데이터 폭 | 8-bit |
| Register 공간 | 4개 register |
| 검증 방식 | Directed Testbench, SVA |
| 주요 검증 항목 | AXI access, UART loopback, invalid access, zero strobe |

## 핵심 성과

- AXI4-Lite Slave와 UART Core를 연결한 memory-mapped UART peripheral 구현
- `CTRL`, `STATUS`, `TXDATA`, `RXDATA` 기반 register map 구성
- `AW->W`, `W->AW`, `AW+W` same-cycle write transaction 처리
- TX FIFO write 후 `tx` to `rx` loopback을 통한 RX FIFO readback 검증
- empty RX read, unsupported TX read, invalid address, zero-strobe write response 검증
- AXI4-Lite 공통 assertion과 UART 전용 assertion을 분리된 SVA 모듈에서 관리
- Directed test 11개 scenario와 SVA를 통해 기능 및 protocol 안정성 검증

## 기능

- 32-bit AXI4-Lite Slave interface
- AW, W, B, AR, R channel 기반 transaction 처리
- Memory-mapped UART register map
- `CTRL` register byte-enable write
- `STATUS` read를 통한 `{rx_empty, tx_full}` 상태 확인
- `TXDATA` write를 통한 TX FIFO push
- `RXDATA` read를 통한 RX FIFO pop
- Baud Generator 기반 UART TX/RX 동작
- TX/RX FIFO 기반 data buffering
- `DECERR`, `SLVERR` response case 처리
- SVA 기반 AXI4-Lite protocol 및 UART register behavior 검증

## 기술 스택

| 구분 | 내용 |
| --- | --- |
| 언어 | SystemVerilog |
| 설계 방식 | RTL Design |
| Protocol | AXI4-Lite, UART |
| 검증 방식 | Directed Testbench, SystemVerilog Assertions |
| 시뮬레이터 | Vivado XSIM |

## 프로젝트 구조

```text
AXI4_UART/
+-- constraints/
|   +-- top.xdc
+-- docs/
|   +-- Read Transaction.png
|   +-- Write Transaction.png
+-- rtl/
|   +-- axi_uart.sv
|   +-- core/
|       +-- baud_gen.sv
|       +-- sync_fifo.sv
|       +-- uart_core.sv
|       +-- uart_rx.sv
|       +-- uart_tx.sv
+-- tb/
|   +-- axi_uart_protocol_sva.sv
|   +-- tb_axi_uart_sva.sv
+-- sim/
+-- LICENSE
+-- README.md
```

## 결과

- [`rtl/axi_uart.sv`](rtl/axi_uart.sv)에서 AXI4-Lite Slave, Register Map, UART Core 연결 구조 구현
- [`rtl/core/uart_core.sv`](rtl/core/uart_core.sv), [`rtl/core/uart_tx.sv`](rtl/core/uart_tx.sv), [`rtl/core/uart_rx.sv`](rtl/core/uart_rx.sv)로 UART 송수신 경로 구성
- [`tb/tb_axi_uart_sva.sv`](tb/tb_axi_uart_sva.sv)에서 11개 directed scenario 검증
- [`tb/axi_uart_protocol_sva.sv`](tb/axi_uart_protocol_sva.sv)에서 AXI4-Lite 필수 assertion과 UART 전용 assertion 확인
- 시뮬레이션 결과 기준 11개 test, 20개 check 전체 통과

예상 시뮬레이션 결과:

```text
Total Tests:    11
Passed:         20
Failed:         0
Pass Rate:      100%
*** ALL TESTS PASSED ***
[SVA PASS] All required AXI-UART assertions passed.
```

## 참고

- AXI read transaction image: [`docs/Read Transaction.png`](docs/Read%20Transaction.png)
- AXI write transaction image: [`docs/Write Transaction.png`](docs/Write%20Transaction.png)
- Board constraint file: [`constraints/top.xdc`](constraints/top.xdc)

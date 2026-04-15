# AXI4 UART Design Project

32-bit AXI4-Lite Slave interface로 UART Core를 제어하는 memory-mapped peripheral을 설계하고, Directed Testbench와 SystemVerilog Assertions(SVA)로 AXI access, UART loopback, error response, protocol 동작을 검증한 RTL 프로젝트입니다.

## 프로젝트 개요

이 프로젝트는 AXI4-Lite 기반 register map을 통해 UART 송수신 경로를 제어하는 것을 목표로 합니다.  
AXI master는 `CTRL`, `STATUS`, `TXDATA`, `RXDATA` register를 통해 UART Core에 접근하며, 내부 UART Core는 Baud Generator, TX/RX FIFO, UART TX/RX block으로 구성됩니다.

검증 구조는 AXI4-Lite 프로젝트와 같은 형식을 따릅니다. Testbench는 directed scenario와 check summary를 담당하고, SVA는 별도 protocol monitor module로 분리해 AXI4-Lite 필수 assertion/coverage와 UART-specific assertion/coverage를 함께 관리합니다.

## 한눈에 보기

| 항목 | 내용 |
| --- | --- |
| 프로젝트 유형 | RTL 설계 + 기능 검증 + protocol 검증 |
| 인터페이스 | AXI4-Lite Slave, UART |
| AXI 데이터 폭 | 32-bit |
| UART 데이터 폭 | 8-bit |
| Register 공간 | 4개 register |
| 검증 방식 | Directed Testbench, SVA |
| Testbench | 11개 directed scenario |
| Assertion | 23개 assertion |
| Coverage | 21개 coverage property |

## 주요 기능

- 32-bit AXI4-Lite Slave interface 설계
- AW, W, B, AR, R channel 분리 처리
- `AW->W`, `W->AW`, `AW+W` same-cycle write case 지원
- Memory-mapped UART register map 구성
- `CTRL` register의 `WSTRB` 기반 byte-enable write 지원
- `STATUS` read를 통한 `{rx_empty, tx_full}` 상태 확인
- `TXDATA` write를 통한 TX FIFO push
- `RXDATA` read를 통한 RX FIFO pop
- 정의되지 않은 주소 접근 시 `DECERR` 반환
- empty RX read 및 invalid TX write 상황에서 `SLVERR` 반환
- `tx` to `rx` loopback 기반 UART 송수신 검증
- SVA 기반 AXI4-Lite protocol assertion 및 UART register behavior assertion 구성

## Register Map

| Address | Name | Access | 설명 |
| --- | --- | --- | --- |
| `0x0000_0000` | `CTRL` | R/W | 32-bit control register, byte-enable write 지원 |
| `0x0000_0004` | `STATUS` | R | `{30'b0, rx_empty, tx_full}` 상태 반환 |
| `0x0000_0008` | `TXDATA` | W | `WDATA[7:0]`을 TX FIFO에 push |
| `0x0000_000C` | `RXDATA` | R | RX FIFO에서 1 byte를 pop하여 `RDATA[7:0]`으로 반환 |
| 그 외 주소 | Reserved | R/W | `DECERR` 반환 |

## 검증 구조

검증 환경은 AXI4-Lite 프로젝트와 동일하게 testbench와 SVA를 분리한 구조입니다.

- [`tb/tb_axi_uart_sva.sv`](tb/tb_axi_uart_sva.sv): directed testbench, AXI transaction task, score check, UART loopback scenario, summary 출력
- [`tb/axi_uart_protocol_sva.sv`](tb/axi_uart_protocol_sva.sv): AXI4-Lite protocol assertion과 UART register behavior assertion 및 coverage

### Directed Test Scenario

| No. | Scenario |
| --- | --- |
| 1 | Initial `STATUS` read |
| 2 | Empty `RXDATA` read |
| 3 | `CTRL` `AW->W` write/readback |
| 4 | `CTRL` `W->AW` write/readback |
| 5 | B channel backpressure |
| 6 | R channel backpressure |
| 7 | Unsupported `TXDATA` read |
| 8 | `TXDATA` write 후 `RXDATA` loopback read |
| 9 | Invalid address read |
| 10 | Invalid address write |
| 11 | Zero-strobe `TXDATA` write |

### AXI4-Lite 필수 Assertion

AXI4_UART에서도 AXI4-Lite 프로젝트에서 확인한 필수 protocol 항목을 동일하게 검증합니다.

- `VALID`는 matching `READY`가 오기 전까지 유지
- stall 중 address, data, strobe, response, read data 안정성 유지
- reset 중 response channel 비활성화
- AW/W handshake 이후 bounded B response 발생
- AR handshake 이후 bounded R response 발생
- 유효한 `BRESP`, `RRESP` encoding 확인

### UART 전용 Assertion

- reset 중 `tx` idle 상태 확인
- `STATUS` read 시 `OKAY` 반환
- `TXDATA` read 시 `SLVERR` 반환
- empty 상태에서 `RXDATA` read 시 `SLVERR` 반환
- invalid read/write 시 `DECERR` 반환
- zero-strobe `TXDATA` write 시 `SLVERR` 반환
- `STATUS` read data가 `{rx_empty, tx_full}`와 일치하는지 확인

### 필수 Coverage

- AW, W, B, AR, R handshake
- AW, W, B, AR, R stall case
- `AW->W`, `W->AW`, same-cycle write ordering
- Write-to-B response path
- Read-to-R response path
- `CTRL` write/read access
- UART TX-to-RX loopback
- Empty RX read `SLVERR`
- Invalid read/write `DECERR`
- Zero-strobe write `SLVERR`

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

## 주요 파일

- [`rtl/axi_uart.sv`](rtl/axi_uart.sv): AXI4-Lite Slave, Register Map, UART Core를 연결하는 top module
- [`rtl/core/uart_core.sv`](rtl/core/uart_core.sv): Baud Generator, TX/RX FIFO, UART TX/RX를 연결하는 UART Core
- [`rtl/core/baud_gen.sv`](rtl/core/baud_gen.sv): 16x baud tick generator
- [`rtl/core/sync_fifo.sv`](rtl/core/sync_fifo.sv): TX/RX 경로에 사용하는 synchronous FIFO
- [`rtl/core/uart_tx.sv`](rtl/core/uart_tx.sv): UART transmitter
- [`rtl/core/uart_rx.sv`](rtl/core/uart_rx.sv): UART receiver
- [`tb/tb_axi_uart_sva.sv`](tb/tb_axi_uart_sva.sv): directed 기능 검증용 testbench
- [`tb/axi_uart_protocol_sva.sv`](tb/axi_uart_protocol_sva.sv): AXI4-Lite 및 UART assertion/coverage module

## 참고

- AXI read transaction image: [`docs/Read Transaction.png`](docs/Read%20Transaction.png)
- AXI write transaction image: [`docs/Write Transaction.png`](docs/Write%20Transaction.png)
- Board constraint file: [`constraints/top.xdc`](constraints/top.xdc)

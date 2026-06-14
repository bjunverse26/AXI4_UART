# AXI4 UART Design Project

## 프로젝트 개요

AXI4_UART는 32-bit AXI4-Lite slave interface로 UART 송수신 경로를 제어하는 memory-mapped peripheral RTL 프로젝트입니다. AXI master는 `CTRL`, `STATUS`, `TXDATA`, `RXDATA` register를 통해 UART core에 접근하며, UART core는 baud generator, TX/RX FIFO와 serial block으로 구성됩니다.

## 주요 특징

- AXI4-Lite 기반 UART peripheral top을 구현했습니다.
- `CTRL`, `STATUS`, `TXDATA`, `RXDATA` 4개 register map을 구성했습니다.
- TX FIFO write와 RX FIFO read를 AXI register access로 추상화했습니다.
- 16x oversampling tick 기반 UART TX/RX loopback을 검증했습니다.
- Directed testbench와 SVA를 분리했습니다.
- Invalid address, unsupported TX read, empty RX read와 zero-strobe TX write response를 검증했습니다.

## 상세 스펙

| 항목 | 내용 |
| --- | --- |
| AXI 데이터 폭 | 32-bit |
| UART 데이터 폭 | 8-bit |
| 기본 clock | 100 MHz |
| 기본 baud rate | 115200 bps |
| FIFO 주소 폭 | 기본 4-bit |
| 정상 response | OKAY |
| 오류 response | SLVERR, DECERR |
| RTL | `rtl/AxiUart.sv`, `rtl/AxiUartSlave.sv`, `rtl/AxiUartRegisterMap.sv`, `rtl/core/*.sv` |
| 검증 | `tb/TbAxiUartSva.sv`, `tb/AxiUartProtocolSva.sv` |

## 검증 및 결과

- 초기 status, empty RX read, CTRL read/write, TXDATA/RXDATA loopback과 invalid access를 directed scenario로 검증했습니다.
- SVA로 AXI4-Lite `VALID` 유지, payload 안정성, bounded response와 UART status flag를 검증했습니다.
- Interface와 task 기반 self-checking testbench로 시나리오와 결과 비교를 자동화했습니다.

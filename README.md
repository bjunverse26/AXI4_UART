# AXI4 UART Design Project

## 프로젝트 개요

AXI4_UART는 32-bit AXI4-Lite slave interface로 UART 송수신 경로를 제어하는 memory-mapped peripheral RTL 프로젝트입니다. AXI master는 `CTRL`, `STATUS`, `TXDATA`, `RXDATA` register를 통해 UART core에 접근하고, UART core는 baud generator, TX/RX FIFO, TX/RX serial block으로 구성됩니다.

## 주요 특징

- AXI4-Lite 기반 UART peripheral top 구현
- `CTRL`, `STATUS`, `TXDATA`, `RXDATA` 4개 register map 제공
- TX FIFO write와 RX FIFO read를 AXI register access로 추상화
- 16x oversampling tick 기반 UART TX/RX loopback 검증
- Directed testbench와 SVA를 분리한 검증 구조
- invalid address, unsupported TX read, empty RX read, zero-strobe TX write response 검증

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

## 검증 결과 요약

- 초기 status, empty RX read, CTRL read/write, TXDATA/RXDATA loopback, invalid access를 directed scenario로 검증
- SVA로 AXI4-Lite valid 유지, payload 안정성, bounded response, UART status flag 일치 여부 확인
- 테스트벤치는 interface와 task 기반으로 구성되어 initial block에서 시나리오 흐름을 한눈에 확인 가능

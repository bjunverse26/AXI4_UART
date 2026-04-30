//==============================================================================
// File Name   : AxiUartRegisterMap.sv
// Project     : AXI4_UART
// Author      : Beomjun Kim
// Description : Register map that translates AXI accesses into UART control,
//               status, TX FIFO push, and RX FIFO pop operations.
// Notes       : Error responses are generated here because only this layer knows
//               whether a UART-specific access is legal.
//==============================================================================

`timescale 1ns / 1ps

module AxiUartRegisterMap #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_STRB       = AXI_DATA_WIDTH / 8
) (
    input  logic                          i_clk,
    input  logic                          i_resetn,

    input  logic [AXI_ADDR_WIDTH-1:2]     i_reg_wr_addr,
    input  logic [AXI_DATA_WIDTH-1:0]     i_reg_wr_data,
    input  logic [AXI_STRB-1:0]           i_reg_wr_strb,
    input  logic                          i_reg_wr_en,
    output logic [1:0]                    o_reg_wr_resp,

    input  logic [AXI_ADDR_WIDTH-1:2]     i_reg_rd_addr,
    input  logic                          i_reg_rd_en,
    output logic [AXI_DATA_WIDTH-1:0]     o_reg_rd_data,
    output logic [1:0]                    o_reg_rd_resp,
    output logic                          o_reg_rd_wait,

    output logic [7:0]                    o_tx_wdata,
    output logic                          o_tx_wr_en,
    input  logic                          i_tx_full,
    output logic                          o_rx_rd_en,
    input  logic [7:0]                    i_rx_rdata,
    input  logic                          i_rx_empty
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_CTRL   = 'h0;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_STATUS = 'h1;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_TXDATA = 'h2;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_RXDATA = 'h3;

    logic [AXI_DATA_WIDTH-1:0] r_ctrl_reg;

    always_comb begin
        case (i_reg_wr_addr)
            ADDR_CTRL: begin
                o_reg_wr_resp = RESP_OKAY;
            end

            ADDR_TXDATA: begin
                if (!i_tx_full && i_reg_wr_strb[0]) begin
                    o_reg_wr_resp = RESP_OKAY;
                end else begin
                    o_reg_wr_resp = RESP_SLVERR;
                end
            end

            default: begin
                o_reg_wr_resp = RESP_DECERR;
            end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            r_ctrl_reg <= '0;
            o_tx_wdata <= '0;
            o_tx_wr_en <= 1'b0;
        end else begin
            o_tx_wr_en <= 1'b0;

            if (i_reg_wr_en) begin
                case (i_reg_wr_addr)
                    ADDR_CTRL: begin
                        for (int i = 0; i < AXI_STRB; i = i + 1) begin
                            if (i_reg_wr_strb[i]) begin
                                r_ctrl_reg[8*i +: 8] <= i_reg_wr_data[8*i +: 8];
                            end
                        end
                    end

                    ADDR_TXDATA: begin
                        if (!i_tx_full && i_reg_wr_strb[0]) begin
                            o_tx_wdata <= i_reg_wr_data[7:0];
                            o_tx_wr_en <= 1'b1;
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    always_comb begin
        o_reg_rd_data = '0;
        o_reg_rd_resp = RESP_OKAY;
        o_reg_rd_wait = 1'b0;

        case (i_reg_rd_addr)
            ADDR_CTRL: begin
                o_reg_rd_data = r_ctrl_reg;
            end

            ADDR_STATUS: begin
                o_reg_rd_data = {{(AXI_DATA_WIDTH-2){1'b0}}, i_rx_empty, i_tx_full};
            end

            ADDR_TXDATA: begin
                o_reg_rd_resp = RESP_SLVERR;
            end

            ADDR_RXDATA: begin
                o_reg_rd_data = {{(AXI_DATA_WIDTH-8){1'b0}}, i_rx_rdata};

                if (!i_rx_empty) begin
                    o_reg_rd_wait = i_reg_rd_en;
                end else begin
                    o_reg_rd_resp = RESP_SLVERR;
                end
            end

            default: begin
                o_reg_rd_resp = RESP_DECERR;
            end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_resetn) begin
        if (!i_resetn) begin
            o_rx_rd_en <= 1'b0;
        end else begin
            o_rx_rd_en <= 1'b0;

            if (i_reg_rd_en && (i_reg_rd_addr == ADDR_RXDATA) && !i_rx_empty) begin
                o_rx_rd_en <= 1'b1;
            end
        end
    end

endmodule

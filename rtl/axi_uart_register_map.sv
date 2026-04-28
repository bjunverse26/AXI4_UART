`timescale 1ns / 1ps

module axi_uart_register_map #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_STRB       = (AXI_DATA_WIDTH / 8)
) (
    input logic                         clk,
    input logic                         resetn,

    input logic [AXI_ADDR_WIDTH-1:2]    reg_wr_addr,
    input logic [AXI_DATA_WIDTH-1:0]    reg_wr_data,
    input logic [AXI_STRB-1:0]          reg_wr_strb,
    input logic                         reg_wr_en,
    output logic [1:0]                  reg_wr_resp,

    input logic [AXI_ADDR_WIDTH-1:2]    reg_rd_addr,
    input logic                         reg_rd_en,
    output logic [AXI_DATA_WIDTH-1:0]   reg_rd_data,
    output logic [1:0]                  reg_rd_resp,
    output logic                        reg_rd_wait,

    output logic [7:0]                  tx_wdata,
    output logic                        tx_wr_en,
    input logic                         tx_full,
    output logic                        rx_rd_en,
    input logic [7:0]                   rx_rdata,
    input logic                         rx_empty
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_CTRL   = 'h0;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_STATUS = 'h1;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_TXDATA = 'h2;
    localparam logic [AXI_ADDR_WIDTH-1:2] ADDR_RXDATA = 'h3;

    logic [AXI_DATA_WIDTH-1:0] ctrl_reg;

    always_comb begin
        case (reg_wr_addr)
            ADDR_CTRL: begin
                reg_wr_resp = RESP_OKAY;
            end

            ADDR_TXDATA: begin
                if (!tx_full && reg_wr_strb[0]) begin
                    reg_wr_resp = RESP_OKAY;
                end else begin
                    reg_wr_resp = RESP_SLVERR;
                end
            end

            default: begin
                reg_wr_resp = RESP_DECERR;
            end
        endcase
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            ctrl_reg <= '0;
            tx_wdata <= '0;
            tx_wr_en <= 1'b0;
        end else begin
            tx_wr_en <= 1'b0;

            if (reg_wr_en) begin
                case (reg_wr_addr)
                    ADDR_CTRL: begin
                        for (int i = 0; i < AXI_STRB; i++) begin
                            if (reg_wr_strb[i]) begin
                                ctrl_reg[8*i +: 8] <= reg_wr_data[8*i +: 8];
                            end
                        end
                    end

                    ADDR_TXDATA: begin
                        if (!tx_full && reg_wr_strb[0]) begin
                            tx_wdata <= reg_wr_data[7:0];
                            tx_wr_en <= 1'b1;
                        end
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    always_comb begin
        reg_rd_data = '0;
        reg_rd_resp = RESP_OKAY;
        reg_rd_wait = 1'b0;

        case (reg_rd_addr)
            ADDR_CTRL: begin
                reg_rd_data = ctrl_reg;
            end

            ADDR_STATUS: begin
                reg_rd_data = {{(AXI_DATA_WIDTH-2){1'b0}}, rx_empty, tx_full};
            end

            ADDR_TXDATA: begin
                reg_rd_resp = RESP_SLVERR;
            end

            ADDR_RXDATA: begin
                reg_rd_data = {{(AXI_DATA_WIDTH-8){1'b0}}, rx_rdata};

                if (!rx_empty) begin
                    reg_rd_wait = reg_rd_en;
                end else begin
                    reg_rd_resp = RESP_SLVERR;
                end
            end

            default: begin
                reg_rd_resp = RESP_DECERR;
            end
        endcase
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rx_rd_en <= 1'b0;
        end else begin
            rx_rd_en <= 1'b0;

            if (reg_rd_en && (reg_rd_addr == ADDR_RXDATA) && !rx_empty) begin
                rx_rd_en <= 1'b1;
            end
        end
    end

endmodule

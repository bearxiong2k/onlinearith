`timescale 1ns/1ps

module sram_bank_128x256 (
    input  logic         clk_i,
    input  logic         en_i,
    input  logic         we_i,
    input  logic [6:0]   addr_i,
    input  logic [255:0] wdata_i,
    output logic [255:0] rdata_o
);

  genvar bank;
  generate
    for (bank = 0; bank < 8; bank = bank + 1) begin : g_bank
      hs128x32_wrapper u_macro (
          .clk_i   (clk_i),
          .en_i    (en_i),
          .we_i    (we_i),
          .addr_i  (addr_i),
          .wdata_i (wdata_i[bank*32 +: 32]),
          .rdata_o (rdata_o[bank*32 +: 32])
      );
    end
  endgenerate

endmodule

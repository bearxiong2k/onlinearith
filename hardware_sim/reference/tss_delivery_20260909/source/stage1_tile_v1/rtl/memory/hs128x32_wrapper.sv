`timescale 1ns/1ps

module hs128x32_wrapper (
    input  logic        clk_i,
    input  logic        en_i,
    input  logic        we_i,
    input  logic [6:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o
);

  localparam logic [2:0] EMA_NORMAL  = 3'b011;
  localparam logic [1:0] EMAW_NORMAL = 2'b01;

  HS128X32 u_sram (
      .Q     (rdata_o),
      .CLK   (clk_i),
      .CEN   (~en_i),
      .WEN   (~we_i),
      .A     (addr_i),
      .D     (wdata_i),
      .EMA   (EMA_NORMAL),
      .EMAW  (EMAW_NORMAL),
      .EMAS  (1'b0),
      .RET1N (1'b1)
  );

endmodule

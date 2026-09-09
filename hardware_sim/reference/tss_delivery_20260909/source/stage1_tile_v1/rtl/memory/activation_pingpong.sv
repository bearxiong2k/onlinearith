`timescale 1ns/1ps

module activation_pingpong (
    input  logic         clk_i,

    input  logic         load_en_i,
    input  logic         load_bank_i,
    input  logic [6:0]   load_addr_i,
    input  logic [255:0] load_value_i,
    input  logic [127:0] load_fine_i,
    input  logic [7:0]   load_beta_x_i,

    input  logic         read_en_i,
    input  logic         read_bank_i,
    input  logic [6:0]   read_addr_i,
    output logic [255:0] read_value_o,
    output logic [127:0] read_fine_o,
    output logic [7:0]   read_beta_x_o
);

  logic [1:0]   bank_en;
  logic [1:0]   bank_we;
  logic [6:0]   bank_addr [0:1];
  logic [255:0] value_wdata [0:1];
  logic [127:0] fine_wdata [0:1];
  logic [31:0]  beta_wdata [0:1];
  logic [255:0] value_rdata [0:1];
  logic [127:0] fine_rdata [0:1];
  logic [31:0]  beta_rdata [0:1];
  integer       b;

  always_comb begin
    for (b = 0; b < 2; b = b + 1) begin
      bank_en[b]    = (load_en_i && (load_bank_i == b[0])) ||
                      (read_en_i && (read_bank_i == b[0]));
      bank_we[b]    = load_en_i && (load_bank_i == b[0]);
      bank_addr[b]  = bank_we[b] ? load_addr_i : read_addr_i;
      value_wdata[b]= load_value_i;
      fine_wdata[b] = load_fine_i;
      beta_wdata[b] = {24'b0, load_beta_x_i};
    end
  end

  genvar bank;
  generate
    for (bank = 0; bank < 2; bank = bank + 1) begin : g_activation_bank
      sram_bank_128x256 u_value (
          .clk_i   (clk_i),
          .en_i    (bank_en[bank]),
          .we_i    (bank_we[bank]),
          .addr_i  (bank_addr[bank]),
          .wdata_i (value_wdata[bank]),
          .rdata_o (value_rdata[bank])
      );

      sram_bank_128x128 u_fine (
          .clk_i   (clk_i),
          .en_i    (bank_en[bank]),
          .we_i    (bank_we[bank]),
          .addr_i  (bank_addr[bank]),
          .wdata_i (fine_wdata[bank]),
          .rdata_o (fine_rdata[bank])
      );

      hs128x32_wrapper u_beta_x (
          .clk_i   (clk_i),
          .en_i    (bank_en[bank]),
          .we_i    (bank_we[bank]),
          .addr_i  (bank_addr[bank]),
          .wdata_i (beta_wdata[bank]),
          .rdata_o (beta_rdata[bank])
      );
    end
  endgenerate

  always_comb begin
    read_value_o  = value_rdata[read_bank_i];
    read_fine_o   = fine_rdata[read_bank_i];
    read_beta_x_o = beta_rdata[read_bank_i][7:0];
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (load_en_i && read_en_i && (load_bank_i == read_bank_i)) begin
      $fatal(1, "activation_pingpong cannot read and write the same single-port bank");
    end
  end
`endif

endmodule

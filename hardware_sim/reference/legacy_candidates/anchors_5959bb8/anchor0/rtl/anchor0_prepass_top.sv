`default_nettype none
`include "anchor0_config.svh"

module anchor0_prepass_top #(
  parameter int B_BLOCKS = `A0_B_BLOCKS,
  parameter int BETA_W   = `A0_BETA_W,
  parameter int ERAW_W   = `A0_ERAW_W,
  parameter int D_W      = `A0_D_W,
  parameter int ADDR_W   = (B_BLOCKS <= 1) ? 1 : $clog2(B_BLOCKS)
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  // Start one metadata-only prepass for one owner channel.
  input  logic                         start_i,

  // Commit the completed shadow delay bank to active at the token / channel
  // assignment boundary. This is intentionally separate from start_i.
  input  logic                         swap_i,

  // Incoming metadata stream for the scan phase.
  input  logic                         scan_valid_i,
  output logic                         scan_ready_o,
  input  logic signed [BETA_W-1:0]     beta_x_i,
  input  logic signed [BETA_W-1:0]     beta_w_g_i,
  input  logic signed [BETA_W-1:0]     beta_w_u_i,

  // Active delay-bank read port for the downstream block-ahead window builder.
  input  logic [ADDR_W-1:0]            active_rd_addr_i,
  output logic [D_W-1:0]               active_rd_g_o,
  output logic [D_W-1:0]               active_rd_u_o,

  // Status / observability.
  output logic                         busy_o,
  output logic                         done_o,
  output logic                         active_sel_o,
  output logic signed [ERAW_W-1:0]     emax_g_o,
  output logic signed [ERAW_W-1:0]     emax_u_o
);


  logic                         rawexp_wr_en;
  logic [ADDR_W-1:0]            rawexp_wr_addr;
  logic signed [ERAW_W-1:0]     rawexp_wr_g;
  logic signed [ERAW_W-1:0]     rawexp_wr_u;
  logic [ADDR_W-1:0]            rawexp_rd_addr;
  logic signed [ERAW_W-1:0]     rawexp_rd_g;
  logic signed [ERAW_W-1:0]     rawexp_rd_u;

  logic                         delay_wr_en;
  logic [ADDR_W-1:0]            delay_wr_addr;
  logic [D_W-1:0]               delay_wr_g;
  logic [D_W-1:0]               delay_wr_u;

  anchor0_prepass_core #(
    .B_BLOCKS (B_BLOCKS),
    .BETA_W   (BETA_W),
    .ERAW_W   (ERAW_W),
    .D_W      (D_W)
  ) u_core (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .start_i         (start_i),
    .busy_o          (busy_o),
    .done_o          (done_o),
    .scan_valid_i    (scan_valid_i),
    .scan_ready_o    (scan_ready_o),
    .beta_x_i        (beta_x_i),
    .beta_w_g_i      (beta_w_g_i),
    .beta_w_u_i      (beta_w_u_i),
    .rawexp_wr_en_o  (rawexp_wr_en),
    .rawexp_wr_addr_o(rawexp_wr_addr),
    .rawexp_wr_g_o   (rawexp_wr_g),
    .rawexp_wr_u_o   (rawexp_wr_u),
    .rawexp_rd_addr_o(rawexp_rd_addr),
    .rawexp_rd_g_i   (rawexp_rd_g),
    .rawexp_rd_u_i   (rawexp_rd_u),
    .delay_wr_en_o   (delay_wr_en),
    .delay_wr_addr_o (delay_wr_addr),
    .delay_wr_g_o    (delay_wr_g),
    .delay_wr_u_o    (delay_wr_u),
    .emax_g_o        (emax_g_o),
    .emax_u_o        (emax_u_o)
  );

  anchor0_shadow_banks #(
    .B_BLOCKS (B_BLOCKS),
    .ERAW_W   (ERAW_W),
    .D_W      (D_W)
  ) u_banks (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .rawexp_wr_en_i  (rawexp_wr_en),
    .rawexp_wr_addr_i(rawexp_wr_addr),
    .rawexp_wr_g_i   (rawexp_wr_g),
    .rawexp_wr_u_i   (rawexp_wr_u),
    .rawexp_rd_addr_i(rawexp_rd_addr),
    .rawexp_rd_g_o   (rawexp_rd_g),
    .rawexp_rd_u_o   (rawexp_rd_u),
    .delay_wr_en_i   (delay_wr_en),
    .delay_wr_addr_i (delay_wr_addr),
    .delay_wr_g_i    (delay_wr_g),
    .delay_wr_u_i    (delay_wr_u),
    .swap_i          (swap_i),
    .active_sel_o    (active_sel_o),
    .active_rd_addr_i(active_rd_addr_i),
    .active_rd_g_o   (active_rd_g_o),
    .active_rd_u_o   (active_rd_u_o)
  );

endmodule

`default_nettype wire

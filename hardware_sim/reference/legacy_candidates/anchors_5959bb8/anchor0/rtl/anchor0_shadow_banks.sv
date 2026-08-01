`default_nettype none
`include "anchor0_config.svh"

module anchor0_shadow_banks #(
  parameter int B_BLOCKS = `A0_B_BLOCKS,
  parameter int ERAW_W   = `A0_ERAW_W,
  parameter int D_W      = `A0_D_W,
  parameter int ADDR_W   = (B_BLOCKS <= 1) ? 1 : $clog2(B_BLOCKS)
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  // Transient raw-exp shadow storage used between scan and resolve.
  input  logic                         rawexp_wr_en_i,
  input  logic [ADDR_W-1:0]            rawexp_wr_addr_i,
  input  logic signed [ERAW_W-1:0]     rawexp_wr_g_i,
  input  logic signed [ERAW_W-1:0]     rawexp_wr_u_i,
  input  logic [ADDR_W-1:0]            rawexp_rd_addr_i,
  output logic signed [ERAW_W-1:0]     rawexp_rd_g_o,
  output logic signed [ERAW_W-1:0]     rawexp_rd_u_o,

  // Double-buffered coarse-delay banks.
  input  logic                         delay_wr_en_i,
  input  logic [ADDR_W-1:0]            delay_wr_addr_i,
  input  logic [D_W-1:0]               delay_wr_g_i,
  input  logic [D_W-1:0]               delay_wr_u_i,

  // External swap at token / channel-assignment boundary.
  input  logic                         swap_i,
  output logic                         active_sel_o,

  // Active-bank read port for the downstream scheduler (Anchor 1).
  input  logic [ADDR_W-1:0]            active_rd_addr_i,
  output logic [D_W-1:0]               active_rd_g_o,
  output logic [D_W-1:0]               active_rd_u_o
);


  logic signed [ERAW_W-1:0] rawexp_g_mem [0:B_BLOCKS-1];
  logic signed [ERAW_W-1:0] rawexp_u_mem [0:B_BLOCKS-1];

  logic [D_W-1:0] delay_bank0_g_mem [0:B_BLOCKS-1];
  logic [D_W-1:0] delay_bank0_u_mem [0:B_BLOCKS-1];
  logic [D_W-1:0] delay_bank1_g_mem [0:B_BLOCKS-1];
  logic [D_W-1:0] delay_bank1_u_mem [0:B_BLOCKS-1];

  logic active_sel_q;

  assign active_sel_o   = active_sel_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_sel_q <= 1'b0;
      rawexp_rd_g_o <= '0;
      rawexp_rd_u_o <= '0;
      active_rd_g_o <= '0;
      active_rd_u_o <= '0;
    end else begin
      if (rawexp_wr_en_i) begin
        rawexp_g_mem[rawexp_wr_addr_i] <= rawexp_wr_g_i;
        rawexp_u_mem[rawexp_wr_addr_i] <= rawexp_wr_u_i;
      end

      rawexp_rd_g_o <= rawexp_g_mem[rawexp_rd_addr_i];
      rawexp_rd_u_o <= rawexp_u_mem[rawexp_rd_addr_i];

      if (delay_wr_en_i) begin
        // Write into the shadow bank, i.e. the bank not currently visible to
        // the downstream window builder.
        if (active_sel_q) begin
          delay_bank0_g_mem[delay_wr_addr_i] <= delay_wr_g_i;
          delay_bank0_u_mem[delay_wr_addr_i] <= delay_wr_u_i;
        end else begin
          delay_bank1_g_mem[delay_wr_addr_i] <= delay_wr_g_i;
          delay_bank1_u_mem[delay_wr_addr_i] <= delay_wr_u_i;
        end
      end

      if (swap_i) begin
        active_sel_q <= ~active_sel_q;
      end

      if (active_sel_q) begin
        active_rd_g_o <= delay_bank1_g_mem[active_rd_addr_i];
        active_rd_u_o <= delay_bank1_u_mem[active_rd_addr_i];
      end else begin
        active_rd_g_o <= delay_bank0_g_mem[active_rd_addr_i];
        active_rd_u_o <= delay_bank0_u_mem[active_rd_addr_i];
      end
    end
  end

endmodule

`default_nettype wire

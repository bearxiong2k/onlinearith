`default_nettype none
`include "anchor0_config.svh"

module anchor0_prepass_core #(
  parameter int B_BLOCKS = `A0_B_BLOCKS,
  parameter int BETA_W   = `A0_BETA_W,
  parameter int ERAW_W   = `A0_ERAW_W,
  parameter int D_W      = `A0_D_W,
  parameter int ADDR_W   = (B_BLOCKS <= 1) ? 1 : $clog2(B_BLOCKS)
) (
  input  logic                         clk_i,
  input  logic                         rst_ni,

  // Launch one prepass for one owner channel.
  input  logic                         start_i,
  output logic                         busy_o,
  output logic                         done_o,

  // Scan-phase metadata stream: one block per accepted beat.
  input  logic                         scan_valid_i,
  output logic                         scan_ready_o,
  input  logic signed [BETA_W-1:0]     beta_x_i,
  input  logic signed [BETA_W-1:0]     beta_w_g_i,
  input  logic signed [BETA_W-1:0]     beta_w_u_i,

  // Raw-exp shadow bank interface.
  output logic                         rawexp_wr_en_o,
  output logic [ADDR_W-1:0]            rawexp_wr_addr_o,
  output logic signed [ERAW_W-1:0]     rawexp_wr_g_o,
  output logic signed [ERAW_W-1:0]     rawexp_wr_u_o,
  output logic [ADDR_W-1:0]            rawexp_rd_addr_o,
  input  logic signed [ERAW_W-1:0]     rawexp_rd_g_i,
  input  logic signed [ERAW_W-1:0]     rawexp_rd_u_i,

  // Delay shadow bank write interface.
  output logic                         delay_wr_en_o,
  output logic [ADDR_W-1:0]            delay_wr_addr_o,
  output logic [D_W-1:0]               delay_wr_g_o,
  output logic [D_W-1:0]               delay_wr_u_o,

  // Exposed for debug / observability only.
  output logic signed [ERAW_W-1:0]     emax_g_o,
  output logic signed [ERAW_W-1:0]     emax_u_o
);


  localparam logic [1:0] ST_IDLE    = 2'd0;
  localparam logic [1:0] ST_SCAN    = 2'd1;
  localparam logic [1:0] ST_RESOLVE = 2'd2;

  localparam logic signed [ERAW_W-1:0] ERAW_MIN = {1'b1, {(ERAW_W-1){1'b0}}};

  logic [1:0] state_q;
  logic [ADDR_W-1:0] scan_idx_q;
  logic [ADDR_W-1:0] resolve_rd_idx_q;
  logic [ADDR_W-1:0] resolve_wr_addr_q;
  logic signed [ERAW_W-1:0] emax_g_q;
  logic signed [ERAW_W-1:0] emax_u_q;
  logic resolve_wr_valid_q;
  logic resolve_reads_done_q;

  logic signed [ERAW_W-1:0] raw_g_calc;
  logic signed [ERAW_W-1:0] raw_u_calc;
  logic signed [ERAW_W:0]   diff_g_calc;
  logic signed [ERAW_W:0]   diff_u_calc;

  logic scan_fire;
  logic scan_last;
  logic resolve_wr_last;

  function automatic logic signed [ERAW_W-1:0] sx_beta(
    input logic signed [BETA_W-1:0] val_i
  );
    sx_beta = {{(ERAW_W-BETA_W){val_i[BETA_W-1]}}, val_i};
  endfunction

  assign raw_g_calc   = sx_beta(beta_x_i) + sx_beta(beta_w_g_i);
  assign raw_u_calc   = sx_beta(beta_x_i) + sx_beta(beta_w_u_i);
  assign diff_g_calc  = $signed({emax_g_q[ERAW_W-1], emax_g_q}) -
                        $signed({rawexp_rd_g_i[ERAW_W-1], rawexp_rd_g_i});
  assign diff_u_calc  = $signed({emax_u_q[ERAW_W-1], emax_u_q}) -
                        $signed({rawexp_rd_u_i[ERAW_W-1], rawexp_rd_u_i});

  assign scan_fire    = (state_q == ST_SCAN) && scan_valid_i;
  assign scan_last    = (scan_idx_q == (B_BLOCKS-1));
  assign resolve_wr_last = resolve_wr_valid_q && (resolve_wr_addr_q == (B_BLOCKS-1));

  assign busy_o       = (state_q != ST_IDLE);
  assign scan_ready_o = (state_q == ST_SCAN);
  assign done_o       = (state_q == ST_RESOLVE) && resolve_wr_last;

  assign emax_g_o     = emax_g_q;
  assign emax_u_o     = emax_u_q;

  // Pure metadata arithmetic only:
  //   E_raw[p,b] = beta_x[b] + beta_w[p,b]
  //   E_max[p]   = max_b E_raw[p,b]
  //   D[p,b]     = E_max[p] - E_raw[p,b]
  always_comb begin
    rawexp_wr_en_o   = 1'b0;
    rawexp_wr_addr_o = scan_idx_q;
    rawexp_wr_g_o    = raw_g_calc;
    rawexp_wr_u_o    = raw_u_calc;

    rawexp_rd_addr_o = resolve_rd_idx_q;

    delay_wr_en_o    = (state_q == ST_RESOLVE) && resolve_wr_valid_q;
    delay_wr_addr_o  = resolve_wr_addr_q;
    delay_wr_g_o     = diff_g_calc[D_W-1:0];
    delay_wr_u_o     = diff_u_calc[D_W-1:0];

    if ((state_q == ST_SCAN) && scan_valid_i) begin
      rawexp_wr_en_o = 1'b1;
    end

  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q              <= ST_IDLE;
      scan_idx_q           <= '0;
      resolve_rd_idx_q     <= '0;
      resolve_wr_addr_q    <= '0;
      resolve_wr_valid_q   <= 1'b0;
      resolve_reads_done_q <= 1'b0;
      emax_g_q             <= ERAW_MIN;
      emax_u_q             <= ERAW_MIN;
    end else begin
      unique case (state_q)
        ST_IDLE: begin
          scan_idx_q           <= '0;
          resolve_rd_idx_q     <= '0;
          resolve_wr_addr_q    <= '0;
          resolve_wr_valid_q   <= 1'b0;
          resolve_reads_done_q <= 1'b0;
          if (start_i) begin
            state_q  <= ST_SCAN;
            emax_g_q <= ERAW_MIN;
            emax_u_q <= ERAW_MIN;
          end
        end

        ST_SCAN: begin
          if (scan_fire) begin
            if (raw_g_calc > emax_g_q) begin
              emax_g_q <= raw_g_calc;
            end
            if (raw_u_calc > emax_u_q) begin
              emax_u_q <= raw_u_calc;
            end

            if (scan_last) begin
              state_q              <= ST_RESOLVE;
              resolve_rd_idx_q     <= '0;
              resolve_wr_addr_q    <= '0;
              resolve_wr_valid_q   <= 1'b0;
              resolve_reads_done_q <= 1'b0;
            end else begin
              scan_idx_q <= scan_idx_q + 1'b1;
            end
          end
        end

        ST_RESOLVE: begin
          if (resolve_wr_last) begin
            state_q <= ST_IDLE;
            resolve_wr_valid_q <= 1'b0;
            resolve_reads_done_q <= 1'b0;
          end else begin
            if (!resolve_reads_done_q) begin
              resolve_wr_valid_q <= 1'b1;
              resolve_wr_addr_q  <= resolve_rd_idx_q;

              if (resolve_rd_idx_q == (B_BLOCKS-1)) begin
                resolve_reads_done_q <= 1'b1;
              end else begin
                resolve_rd_idx_q <= resolve_rd_idx_q + 1'b1;
              end
            end else begin
              resolve_wr_valid_q <= 1'b0;
            end
          end
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none

module tb_anchor0_smoke;
  localparam int B_BLOCKS = 4;
  localparam int BETA_W   = 8;
  localparam int ERAW_W   = 9;
  localparam int D_W      = 9;
  localparam int ADDR_W   = 2;

  logic clk;
  logic rst_ni;
  logic start_i;
  logic swap_i;
  logic scan_valid_i;
  logic scan_ready_o;
  logic signed [BETA_W-1:0] beta_x_i;
  logic signed [BETA_W-1:0] beta_w_g_i;
  logic signed [BETA_W-1:0] beta_w_u_i;
  logic [ADDR_W-1:0] active_rd_addr_i;
  logic [D_W-1:0] active_rd_g_o;
  logic [D_W-1:0] active_rd_u_o;
  logic busy_o;
  logic done_o;
  logic active_sel_o;
  logic signed [ERAW_W-1:0] emax_g_o;
  logic signed [ERAW_W-1:0] emax_u_o;

  logic [D_W-1:0] exp_d_g [0:B_BLOCKS-1];
  logic [D_W-1:0] exp_d_u [0:B_BLOCKS-1];

  anchor0_prepass_top #(
    .B_BLOCKS (B_BLOCKS),
    .BETA_W   (BETA_W),
    .ERAW_W   (ERAW_W),
    .D_W      (D_W),
    .ADDR_W   (ADDR_W)
  ) dut (
    .clk_i           (clk),
    .rst_ni          (rst_ni),
    .start_i         (start_i),
    .swap_i          (swap_i),
    .scan_valid_i    (scan_valid_i),
    .scan_ready_o    (scan_ready_o),
    .beta_x_i        (beta_x_i),
    .beta_w_g_i      (beta_w_g_i),
    .beta_w_u_i      (beta_w_u_i),
    .active_rd_addr_i(active_rd_addr_i),
    .active_rd_g_o   (active_rd_g_o),
    .active_rd_u_o   (active_rd_u_o),
    .busy_o          (busy_o),
    .done_o          (done_o),
    .active_sel_o    (active_sel_o),
    .emax_g_o        (emax_g_o),
    .emax_u_o        (emax_u_o)
  );

  always #5 clk = ~clk;

  task automatic push_scan(
    input logic signed [BETA_W-1:0] bx,
    input logic signed [BETA_W-1:0] bwg,
    input logic signed [BETA_W-1:0] bwu
  );
    begin
      beta_x_i    = bx;
      beta_w_g_i  = bwg;
      beta_w_u_i  = bwu;
      scan_valid_i = 1'b1;
      @(posedge clk);
      if (!scan_ready_o) begin
        $fatal(1, "scan_valid_i asserted when scan_ready_o is low");
      end
    end
  endtask

  integer i;
  initial begin
    clk             = 1'b0;
    rst_ni          = 1'b0;
    start_i         = 1'b0;
    swap_i          = 1'b0;
    scan_valid_i    = 1'b0;
    beta_x_i        = '0;
    beta_w_g_i      = '0;
    beta_w_u_i      = '0;
    active_rd_addr_i = '0;

    exp_d_g[0] = 9'd0;
    exp_d_g[1] = 9'd6;
    exp_d_g[2] = 9'd6;
    exp_d_g[3] = 9'd0;

    exp_d_u[0] = 9'd2;
    exp_d_u[1] = 9'd0;
    exp_d_u[2] = 9'd1;
    exp_d_u[3] = 9'd3;

    repeat (3) @(posedge clk);
    rst_ni = 1'b1;

    @(posedge clk);
    start_i = 1'b1;
    @(posedge clk);
    start_i = 1'b0;

    wait (scan_ready_o == 1'b1);

    // Scan-phase stalls should hold the block index and max state.
    repeat (2) begin
      @(posedge clk);
      if (!scan_ready_o || !busy_o || done_o) begin
        $fatal(1, "scan stall did not preserve scan phase");
      end
    end

    // beta_x    = [ 1, -2,  0,  3]
    // beta_w_g  = [ 4,  1, -1,  2] -> E_raw_g = [5, -1, -1, 5], E_max_g = 5
    // beta_w_u  = [ 0,  5,  2, -3] -> E_raw_u = [1, 3, 2, 0],  E_max_u = 3
    push_scan(8'sd1,  8'sd4,  8'sd0);
    push_scan(-8'sd2, 8'sd1,  8'sd5);
    scan_valid_i = 1'b0;
    repeat (2) begin
      @(posedge clk);
      if (!scan_ready_o || done_o) begin
        $fatal(1, "mid-scan stall did not preserve scan phase");
      end
    end
    push_scan(8'sd0, -8'sd1,  8'sd2);
    push_scan(8'sd3,  8'sd2, -8'sd3);

    scan_valid_i = 1'b0;
    beta_x_i     = '0;
    beta_w_g_i   = '0;
    beta_w_u_i   = '0;

    wait (done_o == 1'b1);
    @(posedge clk);

    if (emax_g_o !== 9'sd5) begin
      $fatal(1, "Unexpected emax_g_o: %0d", emax_g_o);
    end
    if (emax_u_o !== 9'sd3) begin
      $fatal(1, "Unexpected emax_u_o: %0d", emax_u_o);
    end

    @(negedge clk);
    swap_i = 1'b1;
    @(negedge clk);
    swap_i = 1'b0;

    for (i = 0; i < B_BLOCKS; i = i + 1) begin
      active_rd_addr_i = i;
      @(posedge clk);
      #1;
      if (active_rd_g_o !== exp_d_g[i]) begin
        $fatal(1, "Mismatch active_rd_g_o[%0d]: got %0d exp %0d", i, active_rd_g_o, exp_d_g[i]);
      end
      if (active_rd_u_o !== exp_d_u[i]) begin
        $fatal(1, "Mismatch active_rd_u_o[%0d]: got %0d exp %0d", i, active_rd_u_o, exp_d_u[i]);
      end
    end

    $display("tb_anchor0_smoke PASS");
    $finish;
  end

endmodule

`default_nettype wire

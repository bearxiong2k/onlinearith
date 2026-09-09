module stage1_tile (
    input  logic          clk_i,
    input  logic          rst_ni,

    input  logic          start_i,
    input  logic [7:0]    active_lane_mask_i,
    output logic          busy_o,
    output logic          done_o,
    output logic          delay_saturation_o,
    output logic [8*28-1:0] gate_acc_o,
    output logic [8*28-1:0] up_acc_o,

    input  logic          act_valid_i,
    output logic          act_ready_o,
    input  logic [6:0]    act_block_idx_i,
    input  logic [255:0]  act_value_i,
    input  logic [127:0]  act_fine_i,

    input  logic          cfg_valid_i,
    output logic          cfg_ready_o,
    input  logic [2:0]    cfg_target_i,
    input  logic          cfg_bank_i,
    input  logic [3:0]    cfg_path_i,
    input  logic [6:0]    cfg_addr_i,
    input  logic [3:0]    cfg_word_i,
    input  logic [31:0]   cfg_wdata_i,
    output logic          cfg_error_o
);

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_SCAN_READ,
    ST_SCAN_CAPTURE,
    ST_DELAY_READ,
    ST_DELAY_WRITE,
    ST_COMPUTE_WAIT_ACT,
    ST_COMPUTE_CAPTURE,
    ST_COMPUTE_WAIT
  } state_t;

  state_t state_q;
  logic [6:0] block_idx_q;
  logic [7:0] active_lane_mask_q;
  logic       acc_clear_q;
  logic [9:0] emax_q [0:15];
  logic [7:0] horizon_q [0:15];
  logic [63:0] lambda_lut_q;

  logic          cfg_idle;
  logic          beta_x_load_en_i;
  logic [6:0]    beta_x_load_addr_i;
  logic [7:0]    beta_x_load_data_i;
  logic          weight_load_en_i;
  logic [3:0]    weight_load_path_i;
  logic [6:0]    weight_load_addr_i;
  logic [255:0]  weight_load_data_i;
  logic          beta_w_load_en_i;
  logic [6:0]    beta_w_load_addr_i;
  logic [127:0]  beta_w_load_data_i;
  logic          horizon_load_en_i;
  logic [3:0]    horizon_load_path_i;
  logic [7:0]    horizon_load_data_i;
  logic          lambda_load_en_i;
  logic [3:0]    lambda_load_index_i;
  logic [3:0]    lambda_load_data_i;

  logic         beta_x_read_en;
  logic [6:0]   beta_x_read_addr;
  logic         activation_load_en;
  logic [255:0] activation_rdata;
  logic [127:0] fine_rdata;
  logic [7:0]   beta_x_rdata;

  logic         beta_w_en;
  logic         beta_w_we;
  logic [6:0]   beta_w_addr;
  logic [127:0] beta_w_rdata;

  logic         delay_en;
  logic         delay_we;
  logic [6:0]   delay_addr;
  logic [127:0] delay_wdata;
  logic [127:0] delay_calc_wdata;
  logic [127:0] delay_rdata;
  logic         delay_saturation_comb;

  logic [15:0]  weight_en;
  logic [15:0]  weight_we;
  logic [6:0]   weight_addr [0:15];
  logic [255:0] weight_wdata [0:15];
  logic [255:0] weight_rdata [0:15];

  logic         path_data_valid;
  logic [7:0]   pair_retire;
  logic signed [27:0] gate_acc [0:7];
  logic signed [27:0] up_acc [0:7];
  logic [9:0]   e_now [0:15];
  logic [9:0]   delay_delta [0:15];
  logic [6:0]   compute_read_addr;
  logic         compute_read_en;
  integer       ctrl_p;
  integer       calc_p;
  integer       seq_q;
  integer       assert_q;

  assign busy_o = (state_q != ST_IDLE);
  assign act_ready_o = (state_q == ST_COMPUTE_WAIT_ACT);
  assign activation_load_en = act_valid_i && act_ready_o &&
                              (act_block_idx_i == block_idx_q);
  assign path_data_valid = (state_q == ST_COMPUTE_CAPTURE);

  stage1_config_frontend u_config (
      .clk_i                    (clk_i),
      .rst_ni                   (rst_ni),
      .busy_i                   (busy_o),
      .start_i                  (start_i),
      .cfg_valid_i              (cfg_valid_i),
      .cfg_ready_o              (cfg_ready_o),
      .cfg_target_i             (cfg_target_i),
      .cfg_bank_i               (cfg_bank_i),
      .cfg_path_i               (cfg_path_i),
      .cfg_addr_i               (cfg_addr_i),
      .cfg_word_i               (cfg_word_i),
      .cfg_wdata_i              (cfg_wdata_i),
      .cfg_error_o              (cfg_error_o),
      .cfg_idle_o               (cfg_idle),
      .beta_x_load_en_o         (beta_x_load_en_i),
      .beta_x_load_addr_o       (beta_x_load_addr_i),
      .beta_x_load_data_o       (beta_x_load_data_i),
      .weight_load_en_o         (weight_load_en_i),
      .weight_load_path_o       (weight_load_path_i),
      .weight_load_addr_o       (weight_load_addr_i),
      .weight_load_data_o       (weight_load_data_i),
      .beta_w_load_en_o         (beta_w_load_en_i),
      .beta_w_load_addr_o       (beta_w_load_addr_i),
      .beta_w_load_data_o       (beta_w_load_data_i),
      .horizon_load_en_o        (horizon_load_en_i),
      .horizon_load_path_o      (horizon_load_path_i),
      .horizon_load_data_o      (horizon_load_data_i),
      .lambda_load_en_o         (lambda_load_en_i),
      .lambda_load_index_o      (lambda_load_index_i),
      .lambda_load_data_o       (lambda_load_data_i)
  );

  always_comb begin
    beta_x_read_en    = 1'b0;
    beta_x_read_addr  = block_idx_q;
    beta_w_en         = beta_w_load_en_i;
    beta_w_we         = beta_w_load_en_i;
    beta_w_addr       = beta_w_load_addr_i;
    delay_en          = 1'b0;
    delay_we          = 1'b0;
    delay_addr        = block_idx_q;
    delay_wdata       = '0;
    compute_read_en   = 1'b0;
    compute_read_addr = block_idx_q;

    if ((state_q == ST_SCAN_READ) || (state_q == ST_DELAY_READ)) begin
      beta_x_read_en   = 1'b1;
      beta_x_read_addr = block_idx_q;
      beta_w_en        = 1'b1;
      beta_w_we        = 1'b0;
      beta_w_addr      = block_idx_q;
    end

    if (state_q == ST_DELAY_WRITE) begin
      delay_en    = 1'b1;
      delay_we    = 1'b1;
      delay_addr  = block_idx_q;
      delay_wdata = delay_calc_wdata;
    end

    if ((state_q == ST_COMPUTE_WAIT_ACT) && act_valid_i &&
        (act_block_idx_i == block_idx_q)) begin
      compute_read_en   = 1'b1;
      compute_read_addr = block_idx_q;
    end

    if (compute_read_en) begin
      delay_en   = 1'b1;
      delay_we   = 1'b0;
      delay_addr = compute_read_addr;
    end

    for (ctrl_p = 0; ctrl_p < 16; ctrl_p = ctrl_p + 1) begin
      weight_en[ctrl_p]    = compute_read_en ||
                        (weight_load_en_i && (weight_load_path_i == ctrl_p[3:0]));
      weight_we[ctrl_p]    = weight_load_en_i && (weight_load_path_i == ctrl_p[3:0]);
      weight_addr[ctrl_p]  = weight_we[ctrl_p] ? weight_load_addr_i : compute_read_addr;
      weight_wdata[ctrl_p] = weight_load_data_i;
    end
  end

  always_comb begin
    delay_calc_wdata      = '0;
    delay_saturation_comb = 1'b0;
    for (calc_p = 0; calc_p < 16; calc_p = calc_p + 1) begin
      e_now[calc_p] = {2'b0, beta_x_rdata} +
                      {2'b0, beta_w_rdata[calc_p*8 +: 8]};
      if (emax_q[calc_p] >= e_now[calc_p]) begin
        delay_delta[calc_p] = emax_q[calc_p] - e_now[calc_p];
      end else begin
        delay_delta[calc_p] = '0;
      end
      if (delay_delta[calc_p] > 10'd255) begin
        delay_calc_wdata[calc_p*8 +: 8] = 8'hff;
        delay_saturation_comb = 1'b1;
      end else begin
        delay_calc_wdata[calc_p*8 +: 8] = delay_delta[calc_p][7:0];
      end
    end
  end

  activation_dff_store u_activation (
      .clk_i                   (clk_i),
      .beta_x_load_en_i        (beta_x_load_en_i),
      .beta_x_load_addr_i      (beta_x_load_addr_i),
      .beta_x_load_data_i      (beta_x_load_data_i),
      .beta_x_read_en_i        (beta_x_read_en),
      .beta_x_read_addr_i      (beta_x_read_addr),
      .beta_x_read_data_o      (beta_x_rdata),
      .activation_load_en_i    (activation_load_en),
      .activation_value_i      (act_value_i),
      .activation_fine_i       (act_fine_i),
      .activation_value_o      (activation_rdata),
      .activation_fine_o       (fine_rdata)
  );

  sram_bank_128x128 u_beta_w (
      .clk_i   (clk_i),
      .en_i    (beta_w_en),
      .we_i    (beta_w_we),
      .addr_i  (beta_w_addr),
      .wdata_i (beta_w_load_data_i),
      .rdata_o (beta_w_rdata)
  );

  sram_bank_128x128 u_delay (
      .clk_i   (clk_i),
      .en_i    (delay_en),
      .we_i    (delay_we),
      .addr_i  (delay_addr),
      .wdata_i (delay_wdata),
      .rdata_o (delay_rdata)
  );

  genvar path;
  generate
    for (path = 0; path < 16; path = path + 1) begin : g_weight
      sram_bank_128x256 u_weight (
          .clk_i   (clk_i),
          .en_i    (weight_en[path]),
          .we_i    (weight_we[path]),
          .addr_i  (weight_addr[path]),
          .wdata_i (weight_wdata[path]),
          .rdata_o (weight_rdata[path])
      );
    end
  endgenerate

  genvar pair;
  generate
    for (pair = 0; pair < 8; pair = pair + 1) begin : g_pair
      stage1_lane_pair u_pair (
          .clk_i          (clk_i),
          .rst_ni         (rst_ni),
          .acc_clear_i    (acc_clear_q),
          .data_valid_i   (path_data_valid),
          .active_i       (active_lane_mask_q[pair]),
          .activation_i   (activation_rdata),
          .fine_code_i    (fine_rdata),
          .gate_weight_i  (weight_rdata[2*pair]),
          .up_weight_i    (weight_rdata[2*pair+1]),
          .gate_delay_i   (delay_rdata[(2*pair)*8 +: 8]),
          .up_delay_i     (delay_rdata[(2*pair+1)*8 +: 8]),
          .gate_horizon_i (horizon_q[2*pair]),
          .up_horizon_i   (horizon_q[2*pair+1]),
          .lambda_lut_i   (lambda_lut_q),
          .retire_o       (pair_retire[pair]),
          .gate_acc_o     (gate_acc[pair]),
          .up_acc_o       (up_acc[pair])
      );

      assign gate_acc_o[pair*28 +: 28] = gate_acc[pair];
      assign up_acc_o[pair*28 +: 28]   = up_acc[pair];
    end
  endgenerate

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q             <= ST_IDLE;
      block_idx_q         <= '0;
      active_lane_mask_q  <= '0;
      acc_clear_q         <= 1'b0;
      done_o              <= 1'b0;
      delay_saturation_o  <= 1'b0;
      lambda_lut_q        <= '0;
      for (seq_q = 0; seq_q < 16; seq_q = seq_q + 1) begin
        emax_q[seq_q]    <= '0;
        horizon_q[seq_q] <= '0;
      end
    end else begin
      done_o      <= 1'b0;
      acc_clear_q <= 1'b0;

      if (horizon_load_en_i && !busy_o) begin
        horizon_q[horizon_load_path_i] <= horizon_load_data_i;
      end
      if (lambda_load_en_i && !busy_o) begin
        lambda_lut_q[lambda_load_index_i*4 +: 4] <= lambda_load_data_i;
      end

      case (state_q)
        ST_IDLE: begin
          if (start_i && cfg_idle) begin
            active_lane_mask_q <= active_lane_mask_i;
            block_idx_q        <= '0;
            acc_clear_q        <= 1'b1;
            delay_saturation_o <= 1'b0;
            for (seq_q = 0; seq_q < 16; seq_q = seq_q + 1) begin
              emax_q[seq_q] <= '0;
            end
            state_q <= ST_SCAN_READ;
          end
        end

        ST_SCAN_READ: begin
          state_q <= ST_SCAN_CAPTURE;
        end

        ST_SCAN_CAPTURE: begin
          for (seq_q = 0; seq_q < 16; seq_q = seq_q + 1) begin
            if (e_now[seq_q] > emax_q[seq_q]) begin
              emax_q[seq_q] <= e_now[seq_q];
            end
          end
          if (block_idx_q == 7'd127) begin
            block_idx_q <= '0;
            state_q     <= ST_DELAY_READ;
          end else begin
            block_idx_q <= block_idx_q + 7'd1;
            state_q     <= ST_SCAN_READ;
          end
        end

        ST_DELAY_READ: begin
          state_q <= ST_DELAY_WRITE;
        end

        ST_DELAY_WRITE: begin
          if (delay_saturation_comb) begin
            delay_saturation_o <= 1'b1;
          end
          if (block_idx_q == 7'd127) begin
            block_idx_q <= '0;
            state_q     <= ST_COMPUTE_WAIT_ACT;
          end else begin
            block_idx_q <= block_idx_q + 7'd1;
            state_q     <= ST_DELAY_READ;
          end
        end

        ST_COMPUTE_WAIT_ACT: begin
          if (activation_load_en) begin
            state_q <= ST_COMPUTE_CAPTURE;
          end
        end

        ST_COMPUTE_CAPTURE: begin
          state_q <= ST_COMPUTE_WAIT;
        end

        ST_COMPUTE_WAIT: begin
          if (pair_retire[0]) begin
            if (block_idx_q == 7'd127) begin
              done_o  <= 1'b1;
              state_q <= ST_IDLE;
            end else begin
              block_idx_q <= block_idx_q + 7'd1;
              state_q     <= ST_COMPUTE_WAIT_ACT;
            end
          end
        end

        default: state_q <= ST_IDLE;
      endcase
    end
  end

  // synopsys translate_off
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      if (start_i && busy_o) begin
        $fatal(1, "start_i asserted while tile is busy");
      end
      if (act_valid_i && act_ready_o && (act_block_idx_i != block_idx_q)) begin
        $fatal(1, "activation stream block index does not match tile request");
      end
      if (busy_o && (beta_x_load_en_i || weight_load_en_i ||
                     beta_w_load_en_i || horizon_load_en_i ||
                     lambda_load_en_i)) begin
        $fatal(1, "static configuration write attempted while tile is busy");
      end
      for (assert_q = 1; assert_q < 8; assert_q = assert_q + 1) begin
        if (pair_retire[assert_q] != pair_retire[0]) begin
          $fatal(1, "lane-pair retirement lost tile lockstep");
        end
      end
    end
  end
  // synopsys translate_on

endmodule

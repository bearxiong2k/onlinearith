module stage1_config_frontend (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         busy_i,
    input  logic         start_i,

    input  logic         cfg_valid_i,
    output logic         cfg_ready_o,
    input  logic [2:0]   cfg_target_i,
    input  logic         cfg_bank_i,
    input  logic [3:0]   cfg_path_i,
    input  logic [6:0]   cfg_addr_i,
    input  logic [3:0]   cfg_word_i,
    input  logic [31:0]  cfg_wdata_i,
    output logic         cfg_error_o,
    output logic         cfg_idle_o,

    output logic         beta_x_load_en_o,
    output logic [6:0]   beta_x_load_addr_o,
    output logic [7:0]   beta_x_load_data_o,

    output logic         weight_load_en_o,
    output logic [3:0]   weight_load_path_o,
    output logic [6:0]   weight_load_addr_o,
    output logic [255:0] weight_load_data_o,

    output logic         beta_w_load_en_o,
    output logic [6:0]   beta_w_load_addr_o,
    output logic [127:0] beta_w_load_data_o,

    output logic         horizon_load_en_o,
    output logic [3:0]   horizon_load_path_o,
    output logic [7:0]   horizon_load_data_o,

    output logic         lambda_load_en_o,
    output logic [3:0]   lambda_load_index_o,
    output logic [3:0]   lambda_load_data_o
);

  localparam logic [2:0] CFG_BETA_X  = 3'd0;
  localparam logic [2:0] CFG_WEIGHT  = 3'd1;
  localparam logic [2:0] CFG_BETA_W  = 3'd2;
  localparam logic [2:0] CFG_HORIZON = 3'd3;
  localparam logic [2:0] CFG_LAMBDA  = 3'd4;

  logic         seq_active_q;
  logic [2:0]   seq_target_q;
  logic         seq_bank_q;
  logic [3:0]   seq_path_q;
  logic [6:0]   seq_addr_q;
  logic [3:0]   expected_word_q;
  logic [255:0] value_stage_q;
  logic [127:0] beta_stage_q;
  logic         cfg_accept;
  logic         continuation_ok;
  logic         error_event;

  assign cfg_idle_o = !seq_active_q;
  assign cfg_ready_o = !busy_i;
  assign cfg_accept = cfg_valid_i && cfg_ready_o;
  assign continuation_ok = seq_active_q &&
                           (seq_target_q == cfg_target_i) &&
                           (seq_bank_q == cfg_bank_i) &&
                           (seq_path_q == cfg_path_i) &&
                           (seq_addr_q == cfg_addr_i) &&
                           (expected_word_q == cfg_word_i);

  always_comb begin
    beta_x_load_en_o    = 1'b0;
    beta_x_load_addr_o  = cfg_addr_i;
    beta_x_load_data_o  = cfg_wdata_i[7:0];

    weight_load_en_o    = 1'b0;
    weight_load_path_o  = cfg_path_i;
    weight_load_addr_o  = cfg_addr_i;
    weight_load_data_o  = value_stage_q;

    beta_w_load_en_o    = 1'b0;
    beta_w_load_addr_o  = cfg_addr_i;
    beta_w_load_data_o  = beta_stage_q;

    horizon_load_en_o   = 1'b0;
    horizon_load_path_o = cfg_path_i;
    horizon_load_data_o = cfg_wdata_i[7:0];

    lambda_load_en_o    = 1'b0;
    lambda_load_index_o = cfg_path_i;
    lambda_load_data_o  = cfg_wdata_i[3:0];

    error_event = start_i && seq_active_q;

    if (cfg_accept) begin
      case (cfg_target_i)
        CFG_BETA_X: begin
          if ((cfg_word_i != 4'd0) || seq_active_q) begin
            error_event = 1'b1;
          end else begin
            beta_x_load_en_o = 1'b1;
          end
        end

        CFG_WEIGHT: begin
          if ((cfg_word_i != 4'd0) && !continuation_ok) begin
            error_event = 1'b1;
          end
          if ((cfg_word_i == 4'd7) && continuation_ok) begin
            weight_load_en_o = 1'b1;
            weight_load_data_o[7*32 +: 32] = cfg_wdata_i;
          end
        end

        CFG_BETA_W: begin
          if ((cfg_word_i != 4'd0) && !continuation_ok) begin
            error_event = 1'b1;
          end
          if ((cfg_word_i == 4'd3) && continuation_ok) begin
            beta_w_load_en_o = 1'b1;
            beta_w_load_data_o[3*32 +: 32] = cfg_wdata_i;
          end
        end

        CFG_HORIZON: begin
          if ((cfg_word_i != 4'd0) || seq_active_q) begin
            error_event = 1'b1;
          end else begin
            horizon_load_en_o = 1'b1;
          end
        end

        CFG_LAMBDA: begin
          if ((cfg_word_i != 4'd0) || seq_active_q) begin
            error_event = 1'b1;
          end else begin
            lambda_load_en_o = 1'b1;
          end
        end

        default: error_event = 1'b1;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      seq_active_q    <= 1'b0;
      seq_target_q    <= '0;
      seq_bank_q      <= 1'b0;
      seq_path_q      <= '0;
      seq_addr_q      <= '0;
      expected_word_q <= '0;
      value_stage_q   <= '0;
      beta_stage_q    <= '0;
      cfg_error_o     <= 1'b0;
    end else begin
      if (error_event) begin
        cfg_error_o <= 1'b1;
      end

      if (cfg_accept) begin
        case (cfg_target_i)
          CFG_WEIGHT: begin
            if (cfg_word_i == 4'd0) begin
              if (seq_active_q) begin
                cfg_error_o <= 1'b1;
              end
              seq_active_q    <= 1'b1;
              seq_target_q    <= cfg_target_i;
              seq_bank_q      <= cfg_bank_i;
              seq_path_q      <= cfg_path_i;
              seq_addr_q      <= cfg_addr_i;
              expected_word_q <= 4'd1;
              value_stage_q   <= {224'b0, cfg_wdata_i};
            end else if (continuation_ok) begin
              if (cfg_word_i <= 4'd6) begin
                value_stage_q[cfg_word_i*32 +: 32] <= cfg_wdata_i;
              end
              if (cfg_word_i == 4'd7) begin
                seq_active_q    <= 1'b0;
                expected_word_q <= '0;
              end else begin
                expected_word_q <= expected_word_q + 4'd1;
              end
            end else begin
              seq_active_q <= 1'b0;
            end
          end

          CFG_BETA_W: begin
            if (cfg_word_i == 4'd0) begin
              if (seq_active_q) begin
                cfg_error_o <= 1'b1;
              end
              seq_active_q    <= 1'b1;
              seq_target_q    <= cfg_target_i;
              seq_bank_q      <= cfg_bank_i;
              seq_path_q      <= cfg_path_i;
              seq_addr_q      <= cfg_addr_i;
              expected_word_q <= 4'd1;
              beta_stage_q    <= {96'b0, cfg_wdata_i};
            end else if (continuation_ok) begin
              if (cfg_word_i <= 4'd2) begin
                beta_stage_q[cfg_word_i*32 +: 32] <= cfg_wdata_i;
              end
              if (cfg_word_i == 4'd3) begin
                seq_active_q    <= 1'b0;
                expected_word_q <= '0;
              end else begin
                expected_word_q <= expected_word_q + 4'd1;
              end
            end else begin
              seq_active_q <= 1'b0;
            end
          end

          CFG_BETA_X, CFG_HORIZON, CFG_LAMBDA: begin
            if (seq_active_q || (cfg_word_i != 4'd0)) begin
              seq_active_q <= 1'b0;
            end
          end

          default: seq_active_q <= 1'b0;
        endcase
      end
    end
  end

endmodule

`timescale 1ns/1ps

module stage1_path_engine (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         acc_clear_i,
    input  logic         data_valid_i,
    input  logic         active_i,
    input  logic [255:0] activation_i,
    input  logic [255:0] weight_i,
    input  logic [127:0] fine_code_i,
    input  logic [7:0]   delay_i,
    input  logic [7:0]   horizon_i,
    input  logic [63:0]  lambda_lut_i,
    output logic         retire_o,
    output logic signed [20:0] block_sum_o,
    output logic signed [27:0] accumulator_o
);

  logic signed [15:0] product_comb [0:31];
  logic signed [15:0] product_q [0:31];
  logic signed [16:0] level1_comb [0:15];
  logic signed [17:0] level2_comb [0:7];
  logic signed [17:0] level2_q [0:7];
  logic signed [18:0] level3_comb [0:3];
  logic signed [19:0] level4_comb [0:1];
  logic signed [19:0] level4_q [0:1];
  logic signed [20:0] level5_comb;
  logic signed [20:0] block_sum_q;
  logic                 valid_product_q;
  logic                 valid_l2_q;
  logic                 valid_l4_q;
  logic                 valid_sum_q;
  logic [3:0]           fine_code;
  logic [3:0]           lambda;
  logic [8:0]           tau;
  integer               i;
  integer               j;

  always_comb begin
    for (i = 0; i < 32; i = i + 1) begin
      fine_code = fine_code_i[i*4 +: 4];
      lambda    = lambda_lut_i[fine_code*4 +: 4];
      tau       = {1'b0, delay_i} + {5'b0, lambda};
      if (active_i && (tau < {1'b0, horizon_i})) begin
        product_comb[i] = $signed(activation_i[i*8 +: 8]) *
                          $signed(weight_i[i*8 +: 8]);
      end else begin
        product_comb[i] = '0;
      end
    end

    for (i = 0; i < 16; i = i + 1) begin
      level1_comb[i] = $signed({product_q[2*i][15], product_q[2*i]}) +
                       $signed({product_q[2*i+1][15], product_q[2*i+1]});
    end
    for (i = 0; i < 8; i = i + 1) begin
      level2_comb[i] = $signed({level1_comb[2*i][16], level1_comb[2*i]}) +
                       $signed({level1_comb[2*i+1][16], level1_comb[2*i+1]});
    end
    for (i = 0; i < 4; i = i + 1) begin
      level3_comb[i] = $signed({level2_q[2*i][17], level2_q[2*i]}) +
                       $signed({level2_q[2*i+1][17], level2_q[2*i+1]});
    end
    for (i = 0; i < 2; i = i + 1) begin
      level4_comb[i] = $signed({level3_comb[2*i][18], level3_comb[2*i]}) +
                       $signed({level3_comb[2*i+1][18], level3_comb[2*i+1]});
    end
    level5_comb = $signed({level4_q[0][19], level4_q[0]}) +
                  $signed({level4_q[1][19], level4_q[1]});
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      valid_product_q <= 1'b0;
      valid_l2_q      <= 1'b0;
      valid_l4_q      <= 1'b0;
      valid_sum_q     <= 1'b0;
      retire_o        <= 1'b0;
      block_sum_q     <= '0;
      accumulator_o   <= '0;
      for (j = 0; j < 32; j = j + 1) begin
        product_q[j] <= '0;
      end
      for (j = 0; j < 8; j = j + 1) begin
        level2_q[j] <= '0;
      end
      for (j = 0; j < 2; j = j + 1) begin
        level4_q[j] <= '0;
      end
    end else begin
      valid_product_q <= data_valid_i;
      valid_l2_q      <= valid_product_q;
      valid_l4_q      <= valid_l2_q;
      valid_sum_q     <= valid_l4_q;
      retire_o        <= valid_sum_q;

      if (data_valid_i) begin
        for (j = 0; j < 32; j = j + 1) begin
          product_q[j] <= product_comb[j];
        end
      end
      if (valid_product_q) begin
        for (j = 0; j < 8; j = j + 1) begin
          level2_q[j] <= level2_comb[j];
        end
      end
      if (valid_l2_q) begin
        for (j = 0; j < 2; j = j + 1) begin
          level4_q[j] <= level4_comb[j];
        end
      end
      if (valid_l4_q) begin
        block_sum_q <= level5_comb;
      end

      if (acc_clear_i) begin
        accumulator_o <= '0;
      end else if (valid_sum_q) begin
        accumulator_o <= accumulator_o +
                         $signed({{7{block_sum_q[20]}}, block_sum_q});
      end
    end
  end

  assign block_sum_o = block_sum_q;

endmodule

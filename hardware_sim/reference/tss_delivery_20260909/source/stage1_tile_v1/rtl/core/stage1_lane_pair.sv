`timescale 1ns/1ps

module stage1_lane_pair (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         acc_clear_i,
    input  logic         data_valid_i,
    input  logic         active_i,
    input  logic [255:0] activation_i,
    input  logic [127:0] fine_code_i,
    input  logic [255:0] gate_weight_i,
    input  logic [255:0] up_weight_i,
    input  logic [7:0]   gate_delay_i,
    input  logic [7:0]   up_delay_i,
    input  logic [7:0]   gate_horizon_i,
    input  logic [7:0]   up_horizon_i,
    input  logic [63:0]  lambda_lut_i,
    output logic         retire_o,
    output logic signed [27:0] gate_acc_o,
    output logic signed [27:0] up_acc_o
);

  logic gate_retire;
  logic up_retire;
  logic signed [20:0] unused_gate_sum;
  logic signed [20:0] unused_up_sum;

  stage1_path_engine u_gate (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .acc_clear_i   (acc_clear_i),
      .data_valid_i  (data_valid_i),
      .active_i      (active_i),
      .activation_i  (activation_i),
      .weight_i      (gate_weight_i),
      .fine_code_i   (fine_code_i),
      .delay_i       (gate_delay_i),
      .horizon_i     (gate_horizon_i),
      .lambda_lut_i  (lambda_lut_i),
      .retire_o      (gate_retire),
      .block_sum_o   (unused_gate_sum),
      .accumulator_o (gate_acc_o)
  );

  stage1_path_engine u_up (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .acc_clear_i   (acc_clear_i),
      .data_valid_i  (data_valid_i),
      .active_i      (active_i),
      .activation_i  (activation_i),
      .weight_i      (up_weight_i),
      .fine_code_i   (fine_code_i),
      .delay_i       (up_delay_i),
      .horizon_i     (up_horizon_i),
      .lambda_lut_i  (lambda_lut_i),
      .retire_o      (up_retire),
      .block_sum_o   (unused_up_sum),
      .accumulator_o (up_acc_o)
  );

  assign retire_o = gate_retire & up_retire;

`ifndef SYNTHESIS
  always_ff @(posedge clk_i) begin
    if (rst_ni && (gate_retire != up_retire)) begin
      $fatal(1, "Gate and Up path retirement lost lockstep");
    end
  end
`endif

endmodule

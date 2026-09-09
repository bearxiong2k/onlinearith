`timescale 1ns/1ps

module activation_dff_store (
    input  logic         clk_i,

    input  logic         beta_x_load_en_i,
    input  logic [6:0]   beta_x_load_addr_i,
    input  logic [7:0]   beta_x_load_data_i,

    input  logic         beta_x_read_en_i,
    input  logic [6:0]   beta_x_read_addr_i,
    output logic [7:0]   beta_x_read_data_o,

    input  logic         activation_load_en_i,
    input  logic [255:0] activation_value_i,
    input  logic [127:0] activation_fine_i,
    output logic [255:0] activation_value_o,
    output logic [127:0] activation_fine_o
);

  logic [7:0] beta_x_q [0:127];
  logic [255:0] activation_value_q;
  logic [127:0] activation_fine_q;

  assign activation_value_o = activation_value_q;
  assign activation_fine_o  = activation_fine_q;

  always_ff @(posedge clk_i) begin
    if (beta_x_load_en_i) begin
      beta_x_q[beta_x_load_addr_i] <= beta_x_load_data_i;
    end

    if (beta_x_read_en_i) begin
      beta_x_read_data_o <= beta_x_q[beta_x_read_addr_i];
    end

    if (activation_load_en_i) begin
      activation_value_q <= activation_value_i;
      activation_fine_q  <= activation_fine_i;
    end
  end

endmodule

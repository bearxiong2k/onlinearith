`timescale 1ns / 1ps
/*
 * Anchor 4 storage: double-buffered coarse delay bank.
 *
 * Logical object:
 *   D[p,b,c] = E_max[p,c] - E_raw[p,b,c]
 *
 * The active bank feeds the one-block-ahead scheduler for the current token/channel
 * assignment while the shadow bank is filled by the scale prepass for the next one.
 *
 * Bank semantics:
 *   - active_sel_r == 1'b0 : bank0 is active, bank1 is shadow
 *   - active_sel_r == 1'b1 : bank1 is active, bank0 is shadow
 *
 * swap_banks_i models the token or channel-assignment boundary where:
 *   delay_bank_shadow -> delay_bank_active
 *
 * This module includes only the storage banks and the 1-bit bank-select state. It does
 * not include the prepass arithmetic (Anchor 0) or the local window builder (Anchor 1).
 */
(* keep_hierarchy *)
module tss_delay_bank #(
    parameter integer WIDTH  = 8,
    parameter integer DEPTH  = 128,
    parameter integer ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 swap_banks_i,

    input  wire                 shadow_wr_en_i,
    input  wire [ADDR_W-1:0]    shadow_wr_addr_i,
    input  wire [WIDTH-1:0]     shadow_wr_data_i,

    input  wire                 active_rd_en_i,
    input  wire [ADDR_W-1:0]    active_rd_addr_i,
    output wire [WIDTH-1:0]     active_rd_data_o,

    output wire                 active_sel_o
);

    reg active_sel_r;

    wire bank0_wr_en_w;
    wire bank1_wr_en_w;
    wire bank0_rd_en_w;
    wire bank1_rd_en_w;

    wire [WIDTH-1:0] bank0_rd_w;
    wire [WIDTH-1:0] bank1_rd_w;

    assign bank0_wr_en_w = shadow_wr_en_i &  active_sel_r;
    assign bank1_wr_en_w = shadow_wr_en_i & ~active_sel_r;

    assign bank0_rd_en_w = active_rd_en_i & ~active_sel_r;
    assign bank1_rd_en_w = active_rd_en_i &  active_sel_r;

    assign active_rd_data_o = active_sel_r ? bank1_rd_w : bank0_rd_w;
    assign active_sel_o     = active_sel_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_sel_r <= 1'b0;
        end else if (swap_banks_i) begin
            active_sel_r <= ~active_sel_r;
        end
    end

    tss_sync_ram #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH),
        .ADDR_W(ADDR_W)
    ) u_bank0 (
        .clk      (clk),
        .wr_en_i  (bank0_wr_en_w),
        .wr_addr_i(shadow_wr_addr_i),
        .wr_data_i(shadow_wr_data_i),
        .rd_en_i  (bank0_rd_en_w),
        .rd_addr_i(active_rd_addr_i),
        .rd_data_o(bank0_rd_w)
    );

    tss_sync_ram #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH),
        .ADDR_W(ADDR_W)
    ) u_bank1 (
        .clk      (clk),
        .wr_en_i  (bank1_wr_en_w),
        .wr_addr_i(shadow_wr_addr_i),
        .wr_data_i(shadow_wr_data_i),
        .rd_en_i  (bank1_rd_en_w),
        .rd_addr_i(active_rd_addr_i),
        .rd_data_o(bank1_rd_w)
    );

endmodule

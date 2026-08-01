`timescale 1ns / 1ps
/*
 * Anchor 4 storage: calibrated per-path, per-channel horizon store.
 *
 * Logical object:
 *   H[p,c]
 *
 * Included because temporal significance scheduling introduces per-path, per-channel
 * horizons as incremental control metadata.
 *
 * Recommended use:
 *   DEPTH = PATHS * OWNER_LANES
 *   WIDTH = HORIZON_W
 *
 * This module is storage-only. It does not implement calibration logic.
 */
(* keep_hierarchy *)
module tss_horizon_store #(
    parameter integer WIDTH  = 8,
    parameter integer DEPTH  = 16,
    parameter integer ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  wire                 clk,
    input  wire                 wr_en_i,
    input  wire [ADDR_W-1:0]    wr_addr_i,
    input  wire [WIDTH-1:0]     wr_data_i,
    input  wire                 rd_en_i,
    input  wire [ADDR_W-1:0]    rd_addr_i,
    output wire [WIDTH-1:0]     rd_data_o
);

    tss_sync_ram #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH),
        .ADDR_W(ADDR_W)
    ) u_h_store (
        .clk      (clk),
        .wr_en_i  (wr_en_i),
        .wr_addr_i(wr_addr_i),
        .wr_data_i(wr_data_i),
        .rd_en_i  (rd_en_i),
        .rd_addr_i(rd_addr_i),
        .rd_data_o(rd_data_o)
    );

endmodule

`timescale 1ns / 1ps
/*
 * Generic synchronous 1R/1W storage primitive used by Anchor 4 storage-only modules.
 *
 * This module is intentionally simple:
 *   - one write port
 *   - one synchronous read port
 *   - no bulk memory reset
 *
 * Anchor 4 models incremental storage overhead only. The goal is to preserve the
 * memory bits and their read/write interface for synthesis, not to implement the
 * surrounding scheduling or packetization logic.
 */
(* keep_hierarchy *)
module tss_sync_ram #(
    parameter integer WIDTH = 8,
    parameter integer DEPTH = 32,
    parameter integer ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  wire                  clk,
    input  wire                  wr_en_i,
    input  wire [ADDR_W-1:0]     wr_addr_i,
    input  wire [WIDTH-1:0]      wr_data_i,
    input  wire                  rd_en_i,
    input  wire [ADDR_W-1:0]     rd_addr_i,
    output reg  [WIDTH-1:0]      rd_data_o
);

    (* keep = "true" *) reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en_i) begin
            mem[wr_addr_i] <= wr_data_i;
        end
        if (rd_en_i) begin
            rd_data_o <= mem[rd_addr_i];
        end
    end

endmodule

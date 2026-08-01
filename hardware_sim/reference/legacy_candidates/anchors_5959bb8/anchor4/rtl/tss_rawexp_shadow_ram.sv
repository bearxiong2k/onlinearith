`timescale 1ns / 1ps
/*
 * Anchor 4 storage: temporary raw-exp shadow RAM used during the metadata-only scale prepass.
 *
 * Logical object:
 *   E_raw[p,b,c] = beta_x[n,b] + beta_w[p,c,b]
 *
 * This storage is filled during the prepass scan and read back during the resolve pass
 * after E_max[p,c] is known. It is intentionally storage-only and excludes prepass adders
 * and max-reduction logic (those belong to Anchor 0).
 */
(* keep_hierarchy *)
module tss_rawexp_shadow_ram #(
    parameter integer WIDTH  = 10,
    parameter integer DEPTH  = 128,
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
    ) u_rawexp_shadow (
        .clk      (clk),
        .wr_en_i  (wr_en_i),
        .wr_addr_i(wr_addr_i),
        .wr_data_i(wr_data_i),
        .rd_en_i  (rd_en_i),
        .rd_addr_i(rd_addr_i),
        .rd_data_o(rd_data_o)
    );

endmodule

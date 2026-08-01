module tss_anchor1_sched_anchor #(
    parameter integer K         = 32,
    parameter integer D_W       = 6,
    parameter integer LAMBDA_W  = 4,
    parameter integer H_W       = 6,
    parameter integer START_W   = H_W,
    parameter integer REM_W     = H_W
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  load_shadow_i,
    input  logic                  swap_i,
    input  logic [D_W-1:0]        d_block_i,
    input  logic [H_W-1:0]        horizon_i,
    input  logic [K*LAMBDA_W-1:0] lambda_vec_i,

    output logic                  cfg_active_block_kill_o,
    output logic [K-1:0]          cfg_active_active_o,
    output logic [K*START_W-1:0]  cfg_active_start_ctr_o,
    output logic [K*REM_W-1:0]    cfg_active_rem_ctr_o,
    output logic [K-2:0]          cfg_active_subtree_init_o,

    output logic                  cfg_shadow_block_kill_o,
    output logic [K-1:0]          cfg_shadow_active_o,
    output logic [K*START_W-1:0]  cfg_shadow_start_ctr_o,
    output logic [K*REM_W-1:0]    cfg_shadow_rem_ctr_o,
    output logic [K-2:0]          cfg_shadow_subtree_init_o
);
    // Integrated Anchor 1 wrapper.
    //
    // Use cases:
    //   1) synthesize tss_anchor1_window_builder alone
    //      -> A_sched_logic only
    //   2) synthesize tss_anchor1_cfg_bank alone
    //      -> cfg_active/cfg_shadow storage overhead (belongs in added storage)
    //   3) synthesize this integrated top
    //      -> timing, full event energy, and integration sanity

    logic                 cfg_next_block_kill;
    logic [K-1:0]         cfg_next_active;
    logic [K*START_W-1:0] cfg_next_start_ctr;
    logic [K*REM_W-1:0]   cfg_next_rem_ctr;
    logic [K-2:0]         cfg_next_subtree_init;

    tss_anchor1_window_builder #(
        .K(K),
        .D_W(D_W),
        .LAMBDA_W(LAMBDA_W),
        .H_W(H_W),
        .START_W(START_W),
        .REM_W(REM_W)
    ) u_builder (
        .d_block_i(d_block_i),
        .horizon_i(horizon_i),
        .lambda_vec_i(lambda_vec_i),
        .cfg_next_block_kill_o(cfg_next_block_kill),
        .cfg_next_active_o(cfg_next_active),
        .cfg_next_start_ctr_o(cfg_next_start_ctr),
        .cfg_next_rem_ctr_o(cfg_next_rem_ctr),
        .cfg_next_subtree_init_o(cfg_next_subtree_init)
    );

    tss_anchor1_cfg_bank #(
        .K(K),
        .START_W(START_W),
        .REM_W(REM_W)
    ) u_cfg_bank (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .load_shadow_i(load_shadow_i),
        .swap_i(swap_i),
        .cfg_next_block_kill_i(cfg_next_block_kill),
        .cfg_next_active_i(cfg_next_active),
        .cfg_next_start_ctr_i(cfg_next_start_ctr),
        .cfg_next_rem_ctr_i(cfg_next_rem_ctr),
        .cfg_next_subtree_init_i(cfg_next_subtree_init),
        .cfg_active_block_kill_o(cfg_active_block_kill_o),
        .cfg_active_active_o(cfg_active_active_o),
        .cfg_active_start_ctr_o(cfg_active_start_ctr_o),
        .cfg_active_rem_ctr_o(cfg_active_rem_ctr_o),
        .cfg_active_subtree_init_o(cfg_active_subtree_init_o),
        .cfg_shadow_block_kill_o(cfg_shadow_block_kill_o),
        .cfg_shadow_active_o(cfg_shadow_active_o),
        .cfg_shadow_start_ctr_o(cfg_shadow_start_ctr_o),
        .cfg_shadow_rem_ctr_o(cfg_shadow_rem_ctr_o),
        .cfg_shadow_subtree_init_o(cfg_shadow_subtree_init_o)
    );
endmodule

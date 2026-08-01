module tss_anchor1_cfg_bank #(
    parameter integer K       = 32,
    parameter integer START_W = 6,
    parameter integer REM_W   = 6
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  logic                  load_shadow_i,
    input  logic                  swap_i,

    input  logic                  cfg_next_block_kill_i,
    input  logic [K-1:0]          cfg_next_active_i,
    input  logic [K*START_W-1:0]  cfg_next_start_ctr_i,
    input  logic [K*REM_W-1:0]    cfg_next_rem_ctr_i,
    input  logic [K-2:0]          cfg_next_subtree_init_i,

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
    // Double-buffered config state for Anchor 1.
    //
    // load_shadow_i: latch a newly built configuration into cfg_shadow.
    // swap_i       : promote the PREVIOUS cfg_shadow value into cfg_active.
    //
    // If load_shadow_i and swap_i are both asserted in the same cycle,
    // nonblocking assignment semantics intentionally give:
    //   - cfg_active <= old cfg_shadow
    //   - cfg_shadow <= new cfg_next
    // which matches the steady-state one-block-ahead schedule.

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cfg_active_block_kill_o   <= 1'b1;
            cfg_active_active_o       <= '0;
            cfg_active_start_ctr_o    <= '0;
            cfg_active_rem_ctr_o      <= '0;
            cfg_active_subtree_init_o <= '0;

            cfg_shadow_block_kill_o   <= 1'b1;
            cfg_shadow_active_o       <= '0;
            cfg_shadow_start_ctr_o    <= '0;
            cfg_shadow_rem_ctr_o      <= '0;
            cfg_shadow_subtree_init_o <= '0;
        end else begin
            if (swap_i) begin
                cfg_active_block_kill_o   <= cfg_shadow_block_kill_o;
                cfg_active_active_o       <= cfg_shadow_active_o;
                cfg_active_start_ctr_o    <= cfg_shadow_start_ctr_o;
                cfg_active_rem_ctr_o      <= cfg_shadow_rem_ctr_o;
                cfg_active_subtree_init_o <= cfg_shadow_subtree_init_o;
            end

            if (load_shadow_i) begin
                cfg_shadow_block_kill_o   <= cfg_next_block_kill_i;
                cfg_shadow_active_o       <= cfg_next_active_i;
                cfg_shadow_start_ctr_o    <= cfg_next_start_ctr_i;
                cfg_shadow_rem_ctr_o      <= cfg_next_rem_ctr_i;
                cfg_shadow_subtree_init_o <= cfg_next_subtree_init_i;
            end
        end
    end
endmodule

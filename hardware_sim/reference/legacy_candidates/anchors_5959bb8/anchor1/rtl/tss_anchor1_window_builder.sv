module tss_anchor1_window_builder #(
    parameter integer K         = 32,
    parameter integer D_W       = 6,
    parameter integer LAMBDA_W  = 4,
    parameter integer H_W       = 6,
    parameter integer START_W   = H_W,
    parameter integer REM_W     = H_W
) (
    input  logic [D_W-1:0]            d_block_i,
    input  logic [H_W-1:0]            horizon_i,
    input  logic [K*LAMBDA_W-1:0]     lambda_vec_i,

    output logic                      cfg_next_block_kill_o,
    output logic [K-1:0]              cfg_next_active_o,
    output logic [K*START_W-1:0]      cfg_next_start_ctr_o,
    output logic [K*REM_W-1:0]        cfg_next_rem_ctr_o,
    output logic [K-2:0]              cfg_next_subtree_init_o
);
    // Anchor 1: one-path, one-block-ahead window builder.
    //
    // Contract:
    //   - This module intentionally consumes PREDECODED lambda_x values.
    //   - It does NOT decode activation exponent fields.
    //   - It does NOT perform the scale prepass or compute D.
    //   - It implements exactly:
    //         tau_k = D + lambda_k
    //         L_k   = max(0, H - tau_k)
    //     and then forms the packed win_cfg fields used by the local data path.
    //
    // Flattened bus ordering:
    //   leaf k start counter lives at cfg_next_start_ctr_o[k*START_W +: START_W]
    //   leaf k rem counter   lives at cfg_next_rem_ctr_o[k*REM_W   +: REM_W]
    //
    // subtree_init heap order for K=32:
    //   bit  0 : root      covers leaves [0:31]
    //   bits 1:2           cover leaves [0:15],  [16:31]
    //   bits 3:6           cover leaves [0:7],   [8:15], [16:23], [24:31]
    //   bits 7:14          cover 4-leaf groups
    //   bits 15:30         cover 2-leaf groups
    //
    // Semantics:
    //   cfg_next_active_o[k] = 1 iff L_k > 0, i.e. tau_k < H.
    //   cfg_next_start_ctr_o[k] = tau_k for active leaves, else 0.
    //   cfg_next_rem_ctr_o[k]   = H - tau_k for active leaves, else 0.
    //   cfg_next_subtree_init_o marks STRUCTURALLY LIVE subtrees:
    //       OR of cfg_next_active_o over the leaves covered by that node.
    //     It is not a cycle-by-cycle node clock-enable.

    localparam integer TAU_W        = ((D_W > LAMBDA_W) ? D_W : LAMBDA_W) + 1;
    localparam integer CMP_W        = ((TAU_W > H_W) ? TAU_W : H_W);

    integer k;
    integer tree_idx;

    logic [TAU_W-1:0] tau_val [0:K-1];
    logic [CMP_W-1:0] horizon_ext;
    logic [(2*K)-2:0] tree_live;

    always_comb begin
        cfg_next_block_kill_o   = 1'b1;
        cfg_next_active_o       = '0;
        cfg_next_start_ctr_o    = '0;
        cfg_next_rem_ctr_o      = '0;
        cfg_next_subtree_init_o = '0;

        horizon_ext = {{(CMP_W-H_W){1'b0}}, horizon_i};

        for (k = 0; k < K; k = k + 1) begin
            tau_val[k] = {{(TAU_W-D_W){1'b0}}, d_block_i}
                       + {{(TAU_W-LAMBDA_W){1'b0}}, lambda_vec_i[k*LAMBDA_W +: LAMBDA_W]};

            if ({{(CMP_W-TAU_W){1'b0}}, tau_val[k]} < horizon_ext) begin
                cfg_next_active_o[k] = 1'b1;
                cfg_next_start_ctr_o[k*START_W +: START_W] = tau_val[k];
                cfg_next_rem_ctr_o[k*REM_W +: REM_W] = horizon_ext - {{(CMP_W-TAU_W){1'b0}}, tau_val[k]};
            end
        end

        cfg_next_block_kill_o = ~(|cfg_next_active_o);

        tree_live = '0;
        for (k = 0; k < K; k = k + 1) begin
            tree_live[(K - 1) + k] = cfg_next_active_o[k];
        end
        for (tree_idx = K - 2; tree_idx >= 0; tree_idx = tree_idx - 1) begin
            tree_live[tree_idx] = tree_live[(2*tree_idx) + 1] | tree_live[(2*tree_idx) + 2];
        end
        for (k = 0; k < (K - 1); k = k + 1) begin
            cfg_next_subtree_init_o[k] = tree_live[k];
        end
    end
endmodule

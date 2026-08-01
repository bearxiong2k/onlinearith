`timescale 1ns/1ps

module tb_tss_anchor1_sched_anchor;
    localparam integer K        = 32;
    localparam integer D_W      = 6;
    localparam integer LAMBDA_W = 4;
    localparam integer H_W      = 6;
    localparam integer START_W  = H_W;
    localparam integer REM_W    = H_W;

    logic                  clk;
    logic                  rst_ni;
    logic                  load_shadow;
    logic                  swap;
    logic [D_W-1:0]        d_block;
    logic [H_W-1:0]        horizon;
    logic [K*LAMBDA_W-1:0] lambda_vec;

    logic                  cfg_active_block_kill;
    logic [K-1:0]          cfg_active_active;
    logic [K*START_W-1:0]  cfg_active_start_ctr;
    logic [K*REM_W-1:0]    cfg_active_rem_ctr;
    logic [K-2:0]          cfg_active_subtree_init;

    logic                  cfg_shadow_block_kill;
    logic [K-1:0]          cfg_shadow_active;
    logic [K*START_W-1:0]  cfg_shadow_start_ctr;
    logic [K*REM_W-1:0]    cfg_shadow_rem_ctr;
    logic [K-2:0]          cfg_shadow_subtree_init;

    tss_anchor1_sched_anchor #(
        .K(K),
        .D_W(D_W),
        .LAMBDA_W(LAMBDA_W),
        .H_W(H_W),
        .START_W(START_W),
        .REM_W(REM_W)
    ) dut (
        .clk_i(clk),
        .rst_ni(rst_ni),
        .load_shadow_i(load_shadow),
        .swap_i(swap),
        .d_block_i(d_block),
        .horizon_i(horizon),
        .lambda_vec_i(lambda_vec),
        .cfg_active_block_kill_o(cfg_active_block_kill),
        .cfg_active_active_o(cfg_active_active),
        .cfg_active_start_ctr_o(cfg_active_start_ctr),
        .cfg_active_rem_ctr_o(cfg_active_rem_ctr),
        .cfg_active_subtree_init_o(cfg_active_subtree_init),
        .cfg_shadow_block_kill_o(cfg_shadow_block_kill),
        .cfg_shadow_active_o(cfg_shadow_active),
        .cfg_shadow_start_ctr_o(cfg_shadow_start_ctr),
        .cfg_shadow_rem_ctr_o(cfg_shadow_rem_ctr),
        .cfg_shadow_subtree_init_o(cfg_shadow_subtree_init)
    );

    always #5 clk = ~clk;

    task automatic set_lambda(input integer idx, input integer value);
        begin
            lambda_vec[idx*LAMBDA_W +: LAMBDA_W] = value[LAMBDA_W-1:0];
        end
    endtask

    function automatic [START_W-1:0] shadow_start(input integer idx);
        begin
            shadow_start = cfg_shadow_start_ctr[idx*START_W +: START_W];
        end
    endfunction

    function automatic [REM_W-1:0] shadow_rem(input integer idx);
        begin
            shadow_rem = cfg_shadow_rem_ctr[idx*REM_W +: REM_W];
        end
    endfunction

    task automatic check_equal(
        input bit        cond,
        input [255:0]    msg
    );
        begin
            if (!cond) begin
                $display("FAIL: %0s", msg);
                $fatal(1);
            end
        end
    endtask

    integer i;

    initial begin
        clk         = 1'b0;
        rst_ni      = 1'b0;
        load_shadow = 1'b0;
        swap        = 1'b0;
        d_block     = '0;
        horizon     = '0;
        lambda_vec  = '0;

        repeat (2) @(posedge clk);
        rst_ni <= 1'b1;
        @(posedge clk);
        #1;

        check_equal(cfg_active_block_kill == 1'b1, "active reset should be safe-kill");
        check_equal(cfg_shadow_block_kill == 1'b1, "shadow reset should be safe-kill");

        // Case 1: mixed active / inactive / partial-window behavior.
        // D = 2, H = 6, lambda pattern repeats 0..7.
        d_block = 6'd2;
        horizon = 6'd6;
        lambda_vec = '0;
        for (i = 0; i < K; i = i + 1) begin
            set_lambda(i, i % 8);
        end

        load_shadow = 1'b1;
        swap        = 1'b0;
        @(posedge clk);
        #1;
        load_shadow = 1'b0;

        check_equal(cfg_shadow_block_kill == 1'b0, "shadow block_kill should be 0");
        check_equal(cfg_shadow_active[0] == 1'b1, "leaf0 should be active");
        check_equal(cfg_shadow_active[1] == 1'b1, "leaf1 should be active");
        check_equal(cfg_shadow_active[2] == 1'b1, "leaf2 should be active");
        check_equal(cfg_shadow_active[3] == 1'b1, "leaf3 should be active");
        check_equal(cfg_shadow_active[4] == 1'b0, "leaf4 should be inactive");
        check_equal(cfg_shadow_active[5] == 1'b0, "leaf5 should be inactive");
        check_equal(cfg_shadow_active[6] == 1'b0, "leaf6 should be inactive");
        check_equal(cfg_shadow_active[7] == 1'b0, "leaf7 should be inactive");

        check_equal(shadow_start(0) == 6'd2, "leaf0 start should be 2");
        check_equal(shadow_start(1) == 6'd3, "leaf1 start should be 3");
        check_equal(shadow_start(2) == 6'd4, "leaf2 start should be 4");
        check_equal(shadow_start(3) == 6'd5, "leaf3 start should be 5");
        check_equal(shadow_rem(0)   == 6'd4, "leaf0 rem should be 4");
        check_equal(shadow_rem(1)   == 6'd3, "leaf1 rem should be 3");
        check_equal(shadow_rem(2)   == 6'd2, "leaf2 rem should be 2");
        check_equal(shadow_rem(3)   == 6'd1, "leaf3 rem should be 1");
        check_equal(shadow_rem(4)   == 6'd0, "leaf4 rem should be 0");

        // Subtree heap order spot checks for leaves 0..7.
        check_equal(cfg_shadow_subtree_init[0]  == 1'b1, "root subtree should be live");
        check_equal(cfg_shadow_subtree_init[15] == 1'b1, "pair [0:1] should be live");
        check_equal(cfg_shadow_subtree_init[16] == 1'b1, "pair [2:3] should be live");
        check_equal(cfg_shadow_subtree_init[17] == 1'b0, "pair [4:5] should be dead");
        check_equal(cfg_shadow_subtree_init[18] == 1'b0, "pair [6:7] should be dead");

        // Promote shadow -> active.
        swap = 1'b1;
        @(posedge clk);
        #1;
        swap = 1'b0;

        check_equal(cfg_active_block_kill == 1'b0, "active block_kill should be 0 after swap");
        check_equal(cfg_active_active[3:0] == 4'b1111, "active leaves 0..3 should be live");
        check_equal(cfg_active_active[7:4] == 4'b0000, "active leaves 4..7 should be dead");

        // Case 2: whole-block kill.
        d_block = 6'd10;
        horizon = 6'd6;
        lambda_vec = '0;

        load_shadow = 1'b1;
        @(posedge clk);
        #1;
        load_shadow = 1'b0;

        check_equal(cfg_shadow_block_kill == 1'b1, "shadow block_kill should be 1 for full kill");
        check_equal(cfg_shadow_active == '0, "all leaves should be inactive for full kill");
        check_equal(cfg_shadow_subtree_init == '0, "all subtree bits should be 0 for full kill");

        // Case 3: tau == H is inactive.
        d_block = 6'd4;
        horizon = 6'd4;
        lambda_vec = '0;

        load_shadow = 1'b1;
        @(posedge clk);
        #1;
        load_shadow = 1'b0;

        check_equal(cfg_shadow_block_kill == 1'b1, "tau == H should kill the block when all leaves match");
        check_equal(cfg_shadow_active == '0, "tau == H leaves should be inactive");
        check_equal(cfg_shadow_subtree_init == '0, "tau == H should not mark live subtrees");

        // Case 4: tau == 0 starts immediately with rem == H.
        d_block = 6'd0;
        horizon = 6'd1;
        lambda_vec = '0;
        for (i = 1; i < K; i = i + 1) begin
            set_lambda(i, 7);
        end

        load_shadow = 1'b1;
        @(posedge clk);
        #1;
        load_shadow = 1'b0;

        check_equal(cfg_shadow_block_kill == 1'b0, "single tau == 0 leaf should keep block live");
        check_equal(cfg_shadow_active[0] == 1'b1, "tau == 0 leaf0 should be active");
        check_equal(cfg_shadow_active[K-1:1] == '0, "only leaf0 should be active in tau == 0 case");
        check_equal(shadow_start(0) == 6'd0, "tau == 0 start should be 0");
        check_equal(shadow_rem(0) == 6'd1, "tau == 0 rem should equal H");

        // Case 5: H == 0 kills every leaf, including tau == 0.
        d_block = 6'd0;
        horizon = 6'd0;
        lambda_vec = '0;

        load_shadow = 1'b1;
        @(posedge clk);
        #1;
        load_shadow = 1'b0;

        check_equal(cfg_shadow_block_kill == 1'b1, "H == 0 should kill the block");
        check_equal(cfg_shadow_active == '0, "H == 0 should make all leaves inactive");
        check_equal(cfg_shadow_subtree_init == '0, "H == 0 should not mark live subtrees");

        // Case 6: steady-state overlap event.
        // swap old shadow to active while loading a new shadow in the same cycle.
        d_block = 6'd1;
        horizon = 6'd5;
        lambda_vec = '0;
        for (i = 0; i < K; i = i + 1) begin
            set_lambda(i, (i < 4) ? i : 7);
        end

        load_shadow = 1'b1;
        swap        = 1'b1;
        @(posedge clk);
        #1;
        load_shadow = 1'b0;
        swap        = 1'b0;

        // active takes the OLD whole-kill shadow, new shadow gets the mixed config.
        check_equal(cfg_active_block_kill == 1'b1, "active should receive previous whole-kill shadow");
        check_equal(cfg_shadow_block_kill == 1'b0, "new shadow should receive newly built config");
        check_equal(cfg_shadow_active[3:0] == 4'b1111, "new shadow leaves 0..3 should be live");
        check_equal(cfg_shadow_active[7:4] == 4'b0000, "new shadow leaves 4..7 should be dead");

        $display("PASS: Anchor 1 scheduler directed checks completed.");
        $finish;
    end
endmodule

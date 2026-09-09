# Control-Plane Anchor Stats

Source repo: `/home/xzj/coding/anchors` (`../anchors` from this workspace).
Current machine-readable interface:
`/home/xzj/coding/anchors/reports/tss_anchor_costs_v1.json`.

These are the useful reviewer-facing stats for the TSS control-plane rebuttal.
The anchor repo uses a modular, trace-driven hardware methodology: convert the
software trace into a non-overlapping event ledger, then multiply event counts
by synthesized RTL anchors. This avoids using executed-digit ratio as a direct
hardware proxy.

## Methodology Sentence

Use this compressed wording in the rebuttal:

> We evaluate TSS with a trace-driven event model anchored by synthesized RTL
> blocks: a metadata scale-prepass engine, a one-block-ahead window builder, a
> 32-leaf stage-1 block engine, and a payload boundary FIFO. Dynamic energy is
> computed from per-action anchor costs and non-overlapping event counts from
> the simulator; latency is derived from block-serial service time plus exposed
> prepass and queueing time. Area overhead counts only incremental TSS control
> and metadata storage, not baseline MX metadata, weight SRAM, activation
> buffers, or common projection engines.

## Anchor 0: Scale Prepass

Source: `/home/xzj/coding/anchors/anchor0/README.md`

Scope: one owner-channel prepass engine, both stage-1 paths processed in
parallel. It computes `E_raw = beta_x + beta_w`, `E_max`, and coarse delays
`D = E_max - E_raw`; it does not include `lambda_x`, horizon lookup, the window
builder, or any floating-point scale multiplication.

| Metric | Value | Notes |
|---|---:|---|
| `A_pre_logic` | 639.198 um^2 | `anchor0_prepass_core`, regenerated 2026-06-12 |
| Added storage, flop upper bound | 51327.892 um^2 | raw-exp shadow + delay banks |
| Added storage, SRAM estimate | 6415.987 um^2 | 8x density estimate |
| Total with SRAM-estimated storage | 7055.184 um^2 | logic + storage estimate |
| `Fmax_pre_core` | 1.770 GHz | ABC timing proxy |
| `Fmax_pre_top` | 1.606 GHz | ABC timing proxy, worst emitted delay 622.48 ps |
| `C_scan_blk` | 1 cycle/block | continuous scan-valid |
| `C_resolve_blk` | 1 cycle/block | steady state after raw-exp read fill |
| `C_resolve_fill` | 1 cycle/prepass | synchronous raw-exp read pipeline fill |
| `E_scan_blk` | 0.221 pJ/block | rough capacitance model |
| `E_resolve_blk` | 0.201 pJ/block | rough capacitance model |
| Optional external metadata read | +0.015 pJ/scan | if beta metadata SRAM read is charged here |

Latency accounting:

```text
T_pre = N_pre_scan * 1 cycle + N_pre_resolve * 1 cycle
      + N_prepass_instance * 1 cycle
T_ctrl_exposed = max(0, T_pre - available_overlap)
```

For a resident channel with 128 blocks, the prepass service is 128 scan cycles
plus 128 steady-state resolve cycles plus one fill cycle, and it is
double-buffered for the next token/channel assignment.

## Anchor 1: One-Block-Ahead Window Scheduler

Source: `/home/xzj/coding/anchors/anchor1/README.md`

Scope: one path, one owner lane, one block. It starts after `lambda_x` has been
decoded and receives `D[p,b,c]`, `H[p,c]`, and `lambda_x[n,b,0:31]`. It builds
`active`, `start_ctr`, `rem_ctr`, and subtree initialization config for the next
block.

| Metric | Value | Notes |
|---|---:|---|
| `A_sched_logic` | 2498.804 um^2 | builder-only mapped area |
| `A_cfg_state` | 6435.072 um^2 | active/shadow config bank |
| `A_anchor1_total` | 8905.414 um^2 | integrated top |
| `Fmax_sched` | 1.505 GHz | integrated-top ABC proxy, delay 664.32 ps |
| `Fmax_sched_logic` | 1.540 GHz | builder-only ABC proxy, delay 649.44 ps |
| `C_cfg_blk` | 1 cycle/configured block | unpipelined builder |
| `E_cfg_blk` | pending | no local activity-based power tool in repo |

Reviewer-facing interpretation: the one-block-ahead scheduler fits in one
cycle and has >1.5 GHz proxy timing. Because it configures block `b+1` while
block `b` executes, its throughput is hidden as long as the block-serial
data-plane slot provides enough slack for the synchronous D/H read and config
capture pipeline. V1 budgets this as two config-latency cycles after the
metadata read path is staged.

## Shared `lambda_x` Decode And Metadata Fanout

Source: `/home/xzj/coding/anchors/reports/tss_anchor_costs_v1.json`

Anchor 1 starts after shared activation-side `lambda_x` decode. V1 does not
pretend this logic is part of Anchor 1's synthesized area; it records explicit
formula-backed rows and charges them through the external narrow-integer
controller macro allowance below.

Formula for nonzero activation elements:

```text
max_exp     = max_k exp_x[n,b,k]
lambda_x[k] = sat(max_exp - exp_x[n,b,k], 0, 2^LAMBDA_W - 1)
```

Zero or all-zero element positions emit the saturated delay code. With the V1
defaults `K=32` and `LAMBDA_W=4`, the shared vector is 128 bits per activation
block. The conservative registered-fanout bound is
`OWNER_LANES * K * LAMBDA_W = 1024` bits for 8 owner lanes. This is metadata
movement into owner-lane schedulers, not a new data-plane payload route.

## Anchor 4: Incremental Storage Inventory

Source: `/home/xzj/coding/anchors/anchor4/README.md`

Parameters: `K=32`, `PATHS=2`, `OWNER_LANES=8`, `BLOCKS_PER_CH=128`,
`SHARDS=4`, `HORIZON_W=8`, `RAWEXP_W=10`, `DELAY_W=8`, `START_W=8`,
`REM_W=8`, `FIFO_DEPTH_PER_SHARD=64`.

Hybrid storage policy: structures with <=256 bits remain FF; larger structures
use an SRAM area estimate with an 8x density factor.

| Structure | Total Bits | Hybrid Area |
|---|---:|---:|
| Horizon store | 128 | 1122.254 um^2 |
| Raw-exp shadow RAM | 20480 | 21123.592 um^2 |
| Delay bank | 32768 | 33914.468 um^2 |
| Window-config bank | 18432 | 16547.328 um^2 |
| Completion metadata store | 1056 | 1095.853 um^2 |
| Payload FIFO store | 7168 | 7349.713 um^2 |
| **Total** | **80032** | **81153.208 um^2** |

Important accounting note: Anchor 4 is storage-only and should not be summed
with Anchor 0/1 storage rows unless those rows are being used only as local
sanity checks. For final area accounting, use Anchor 0/1 logic plus Anchor 4
storage to avoid double counting.

## Anchor 3: Payload Boundary Reference

Source: `/home/xzj/coding/anchors/anchor3/build/anchor3_synth_summary.txt` and
`/home/xzj/coding/anchors/anchor3/reports/anchor3_sweep_results.csv`

Default point in `anchor3_synth_summary.txt`: `PAYLOAD_W=32`, `HDR_W=48`,
`LEN_W=8`, `FIFO_DEPTH=16`.

| Metric | Value |
|---|---:|
| Packetizer logic | 566.580 um^2 |
| FIFO area | 4269.300 um^2 |
| Boundary mapped area | 4832.954 um^2 |

Use this only for stage-boundary buffering/packetization discussion. Do not
mix it into the core control-plane table unless the rebuttal explicitly
discusses payload queueing.

## Best Rebuttal Use

Replace qualitative statements like "TSS overhead is small and hidden" with:

- Scale prepass: 1 scan cycle + 1 resolve cycle per block, double-buffered; only
  exposed if it exceeds the available overlap; add one resolve-fill cycle per
  prepass instance under synchronous metadata storage.
- Window builder: 1 config write per block with two-cycle end-to-end latency
  when synchronous D/H reads are included; prepared one block ahead, proxy
  timing 1.505 GHz.
- `lambda_x` decode/fanout: explicit V1 formula rows charged through the
  external controller macro allowance, not hidden in Anchor 1 RTL.
- Runtime arithmetic: narrow integer add/subtract/max/compare only; no FP scale
  multiplication and no runtime weight-element exponent decode.
- Incremental storage: 80,032 bits for an 8-owner-lane, 128-block, 4-shard
  tile; 81,153.208 um^2 under the repo's hybrid SRAM-aware estimate.
- Methodology: use non-overlapping trace events rather than executed-digit
  ratio as the hardware model input.

## User-Provided Controller/SRAM Macro Measurements

Provided on 2026-06-11:

| Component | Delay | Area | Energy / Access or Action |
|---|---:|---:|---:|
| Controller layer 1 | 1.02 ns | - | - |
| Controller layer 2 | 0.88 ns | - | - |
| Controller total | - | 1356.9 um^2 | 1436.5 fJ |
| SRAM array, 256 x 96 kb | 0.71 ns read | 7.614 mm^2 | 488898.56 fJ/read |

SRAM read width: `8 x 1024 bit = 8192 bit`.

Derived ratios:

| Ratio | Value |
|---|---:|
| Controller area / SRAM array area | 0.0178% |
| Controller energy / SRAM read energy | 0.2938% |
| Controller energy / (controller + SRAM read energy) | 0.2930% |
| Combined controller + SRAM read energy | 490.335 pJ |
| SRAM read energy per bit | 59.68 fJ/bit |
| Total SRAM capacity | 24.0 Mibit |
| V1 TSS added area, excluding payload boundary logic | 85,648.110 um^2 |
| V1 control energy per TSS block | 1.8585 pJ |
| V1 control energy / SRAM read energy | 0.3801% |

Pipeline interpretation:

| Stage | Delay |
|---|---:|
| SRAM read | 0.71 ns |
| Controller layer 1 | 1.02 ns |
| Controller layer 2 | 0.88 ns |
| Max pipelined stage | 1.02 ns |
| Unpipelined sum | 2.61 ns |

The V3 E2E model aligns the selected setup-6 Figure 5 trace with a B=16
block-serial data-plane slot. With a three-stage control pipeline (`SRAM read ->
controller layer 1 -> controller layer 2`) and a 1.02 ns control clock, the
control configuration for the next block completes in 3 cycles while the
current block occupies the data plane for about 16 cycles. This leaves roughly
13 cycles of slack after pipeline fill. Even the earlier 10-cycle slot
convention remains a stricter sanity check: an unpipelined 2.61 ns
controller+SRAM path is shorter than 10 cycles at the 1.02 ns stage clock
(10.2 ns).

Reviewer-facing conclusion: the control path is throughput-hidden by
one-block-ahead scheduling for the modeled block-serial slot. The dominant
access energy is SRAM read energy; the controller contributes <0.3% of the
SRAM-read energy and <0.02% of the SRAM array area in this macro comparison.
The selected Qwen3-0.6B setup-6 trace now verifies
`../onlinearith/ppltest.py --figure5-layer-cycles --boundary-trace-csv` plus
`anchor3/scripts/trace_boundary_queue.py` on 10 samples / 457 scored tokens. It
emits 91,721,728 burst rows and replays to 32,860,718,903 boundary words at the
default 4-shard mapping. In E2E V3, service-rate-1 queue depth/latency are
reported as a sensitivity; `queue_exposed_cycles=0` unless an overlap policy
explicitly chooses to expose queue latency. See
`results/e2e_cost_model/rebuttal_v3/latency_ledger.json` for the split between
TSS data-plane cycles, exposed anchor cycles, and full-model projection.

Mask-baseline energy and payload accounting is now in
`results/e2e_cost_model/rebuttal_v3/mask_compare_cim_policy_v3.md`. V3
uses one later cost-model mask target: hardware-fair activation mask-compare
CIM. Optimistic compressed 2:4 and static structured mask rows are excluded
from the cost table. For activation mask-compare CIM, 2:4 reduces selected
weight reads but still pays dense activation read, compare, mask-payload/control,
dense stage-output payload, and a reduced-entry but wider-precision reduction
path.

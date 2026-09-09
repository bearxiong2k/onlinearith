# Anchor and Validation Improvement Requests

These are the follow-up runs that would most improve the rebuttal evidence on
another server. They are ordered by reviewer impact.

Execution order, artifact policy, and acceptance criteria are consolidated in
`remaining-rebuttal-roadmap.md`.

## 0. Replace Full-Model Section With Hybrid Validation

Status: implemented for Qwen3-1.7B. The profiler artifact is under
`results/hybrid_full_model_gpu/`, and the draft full-model latency section now
uses a measured full-GPU baseline, measured GPU non-FFN timing, and V4 TLM/CIM
FFN ratios applied to the derived GPU FFN slice.

Goal: replace the current source-light full-model table with a hybrid
validation path that compares against measured full GPU timing and uses
CIM-FFN TLM statistics only as FFN latency ratios.

Needed output:

- Full GPU timing for at least one representative model, preferably
  Qwen3-1.7B or Llama-3.2-3B.
- GPU timing for attention, KV-cache movement, softmax, normalization,
  residual, embedding/output, and other non-FFN terms for at least one
  representative model, preferably Qwen3-1.7B or Llama-3.2-3B.
- CIM-FFN latency ratios and energy from the TLM-style simulator for dense
  MXFP8, TSS 17 dB, TSS 30 dB, and hardware-fair activation
  2:4/mask-compare CIM.
- A combined full-model table using:

```text
T_e2e = T_gpu_attention_nonffn
       + (C_cim_ffn_method / C_cim_ffn_dense)
       * (T_gpu_full - T_gpu_attention_nonffn)
```

- Decode and prefill scenarios matching the cost-model names:
  `decode_s2048` and `prefill_s512`.
- Separate buckets in the final table: GPU full, GPU attention/non-FFN,
  derived GPU FFN, CIM FFN ratio, normalized E2E latency, and E2E gain.

Why it matters: the current rebuttal table may look like an unsupported
projection to reviewers. Measuring full GPU and GPU attention/non-FFN timing,
then applying CIM-FFN TLM ratios only to the measured GPU FFN slice, gives a
clearer source for the full-model claim.

## 1. Later: Package the TLM-Style Simulator Repo

Status: later task, after the rebuttal direction is acceptable. Do not block
the current rebuttal on packaging this repo.

Goal: wrap the TLM-style simulator, configs, and small derived artifacts as a
clean repo that can be provided anonymously if reviewers or the venue permit
it. The current rebuttal only needs to state that the reported tables come from
our TLM-style simulator and to provide clear source-status labels.

Needed output:

- A cleaned simulator repository or package that can be provided anonymously.
- README with exact commands for the rebuttal tables: quality/event-ledger
  ingestion, full-model shell generation, and mask-compare CIM policy.
- Machine-readable configs for all table rows, including dense MXFP8, TSS
  17 dB/30 dB, and hardware-fair activation 2:4.
- Source-status notes separating measured RTL/TLM rows, formula-backed rows,
  and measured full-GPU/non-FFN timing provenance.

Why it matters: this is useful supporting infrastructure after the rebuttal is
accepted as credible, but the immediate blocker is measured GPU non-FFN timing
and full-GPU timing for the full-model section.

## 2. Add Nonzero 2:4 E2E Latency Benefit

Status: implemented locally in the V4 E2E cost model as the formula-backed
`tree_depth_2_4` policy. The row keeps dense activation read and
mask/compare/payload costs, but applies a bounded adder-tree-depth benefit:
for 2-of-4, 25% of FFN service time is treated as tree-depth-sensitive and is
scaled by the selected/dense tree-depth ratio, yielding FFN latency 0.875.

Goal: replace the earlier conservative 0.0% latency placeholder for the
hardware-fair 2:4 mask row.

Needed output:

- A latency model for activation 2:4/mask-compare CIM that keeps dense
  activation read and mask/compare overheads, but includes the physically
  justified latency benefit from reduced selected entries and shallower adder
  tree depth.
- FFN and E2E latency rows for the same model/scenario grid as TSS. Done in
  `results/e2e_cost_model/rebuttal_v4/`.
- A short explanation distinguishing this from the invalid optimistic
  assumption that "2:4 halves total latency."

Why it matters: the old 0.0% E2E latency gain was too conservative and could
look artificially unfair. The current hardware-fair row is nonzero, but still
much less optimistic than a compressed sparse software kernel. A future Anchor
5 or equivalent signoff row would be needed before claiming packed 2:4 issue.

## 3. Full-Model Runtime Validation on RTX 5090

Goal: validate the hybrid full-model methodology with at least one real
end-to-end run on RTX 5090.

Needed output:

- Dense MXFP8 and TSS full-model latency for at least one representative model,
  preferably Qwen3-1.7B or Llama-3.2-3B.
- Separate attention/non-FFN and FFN timing buckets if possible.
- Decode and prefill scenarios matching the cost-model names:
  `decode_s2048` and `prefill_s512`.
- Same MXFP8/TSS operating point used in the rebuttal table, especially
  TSS 17 dB for full-model latency and TSS 30 dB for high-quality reference.

Why it matters: the current full-GPU-relative table is the immediate
replacement target. A direct RTX 5090 end-to-end method run is a follow-up
sanity check that the split timing is in the right range.

## 4. A1 Scheduler Dynamic Energy

Goal: replace `pending_zero_with_warning` for A1 scheduler dynamic energy.

Needed output:

- Activity-based pJ per configured block for the Anchor 1 integrated
  scheduler.
- Separate builder logic and active/shadow config-bank energy if practical.
- Input activity assumptions: realistic `D`, `H`, and `lambda_x` distributions
  from a TSS stats trace, not random-only toggles.
- Confirm whether `E_cfg_blk` is negligible relative to controller/SRAM read
  energy or should be added as a nonzero row.

Why it matters: current area/timing is counted, but dynamic scheduler energy is
zero with an explicit warning. This is the most visible source-status weakness.

## 5. A2 Stage-1 Engine Power Characterization

Goal: replace `rough_proxy_not_signoff_power` for the stage-1 engine.

Needed output:

- pJ per block fixed overhead and pJ per active leaf-cycle from real switching
  activity or post-synthesis power.
- Separate dense MXFP8 and TSS-gated activity cases.
- Confirm drain-cycle energy and whether OLA-tree ancestor gating is already
  captured.
- Report PVT/process assumptions and clock target.

Why it matters: A2 dominates absolute FFN energy. Reviewers may accept proxy
energy for rebuttal, but the camera-ready version should not rely on a rough
proxy for the largest energy term.

## 6. A3 Boundary FIFO and Queue Model

Goal: make payload movement and queueing credible without giant trace files.

Needed output:

- Activity-based packetizer/FIFO pJ per word and pJ per burst/header.
- Queue replay at realistic service rates and shard mappings.
- A short explanation of why `queue_exposed_cycles=0` is valid under the
  overlap policy, or a conservative exposed-queue sensitivity row if not.
- Prefer aggregate event-ledger export for 300-sample rows; do not depend on
  multi-GB per-burst CSV unless debugging queue depth.

Why it matters: V4 reports queue sensitivity, but the current replay depths are
too large to be used as a headline without careful service/overlap framing.

## 7. A4 Storage Macro Replacement

Goal: replace the hybrid SRAM-density estimate with a macro-characterized
storage inventory.

Needed output:

- Macro area for horizon store, raw-exp shadow RAM, delay bank, window-config
  bank, completion metadata, and payload FIFO.
- Read/write energy per access for each structure or for grouped macro classes.
- Confirm whether very small structures should remain FF-based.

Why it matters: A4 is the largest TSS added-area bucket. The current 1.0112
area-normalized overhead is useful, but a macro-based A4 result would be much
harder to challenge.

## 8. Larger-Model Full Event Ledgers

Goal: replace formula-backed larger-model TSS energy ledgers with full
trace-backed ledgers.

Needed output:

- `msd_perf_stats.event_ledger` or `tss_event_ledger_v1` for Qwen3-1.7B,
  Qwen3-4B, Qwen3-8B, and Llama-3.2-3B at the rebuttal headline TSS 17 dB
  operating point.
- Sample count matching the current 300-window stats rows where possible.
- Boundary aggregate counters without per-burst CSV by default.

Why it matters: larger-model latency and quality rows are strong, but their
energy rows are currently formula-backed from global stats. Full ledgers would
close this audit gap.

## 9. Control Fanout and `lambda_x` Decode Signoff

Goal: turn the formula-backed `lambda_x` decode/fanout row into a real
synthesized/macro-characterized component.

Needed output:

- Decoder/fanout area, timing, and pJ/action for K=32 and owner-lane count 8.
- Registered fanout cost for 128-bit `lambda_x` vector per activation block.
- Sensitivity for K=16 and K=64 if feasible.

Why it matters: Reviewers explicitly asked about `lambda_x` decode and
broadcast. V4 charges it through controller formula rows, but a synthesized
row would make the answer cleaner.

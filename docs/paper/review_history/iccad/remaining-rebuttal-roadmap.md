# Remaining Rebuttal Roadmap

Updated: 2026-06-17 Asia/Shanghai

This roadmap is intentionally narrow. The rebuttal needs stronger sourcing for
the full-model latency section; simulator-repo packaging is useful later, but
should not distract from the current rebuttal.

## Current State

- The V4 cost model already emits the current TLM-style latency, energy, area,
  event-ledger, queue-sensitivity, and source-status artifacts under
  `results/e2e_cost_model/rebuttal_v4/`.
- The hardware-fair activation 2:4 row already has a nonzero E2E latency gain
  through the formula-backed `tree_depth_2_4` policy. It models reduced adder
  tree depth for selected 2-of-4 entries while avoiding the unsupported claim
  that "2:4 halves everything."
- The full-model section now uses a measured full-GPU baseline, a measured GPU
  non-FFN bucket, and V4 TLM/CIM FFN ratios applied to the derived GPU FFN
  slice for Qwen3-1.7B. The generated artifacts are
  `results/hybrid_full_model_gpu/Qwen3-1.7B_gpu_nonffn_profile.json`,
  `results/hybrid_full_model_gpu/Qwen3-1.7B_hybrid_table.tsv`, and
  `results/hybrid_full_model_gpu/Qwen3-1.7B_hybrid_table.md`.

## Must Do Before Final Rebuttal

### 1. Replace Full-Model Shell With Full-GPU-Relative Timing

Use:

```text
T_gpu_ffn = T_gpu_full - T_gpu_attention_nonffn
T_e2e_method = T_gpu_attention_nonffn
             + (C_cim_ffn_method / C_cim_ffn_dense) * T_gpu_ffn
```

Required inputs:

- Full GPU timing for the dense baseline.
- GPU timing for attention, KV-cache movement, softmax, normalization,
  residuals, embedding/output, and other non-FFN terms.
- CIM/TLM FFN latency ratios from `results/e2e_cost_model/rebuttal_v4/` for
  dense MXFP8, TSS 17 dB, and hardware-fair activation 2:4/mask-compare CIM.
- One representative model first, preferably Qwen3-1.7B or Llama-3.2-3B.
- Both scenarios: `decode_s2048` and `prefill_s512`.

Status: done for Qwen3-1.7B.

Profiling command:

```bash
PYTHONPATH=/home/xzj/coding/transformers/src \
HF_HUB_DISABLE_PROGRESS_BARS=1 TRANSFORMERS_VERBOSITY=error \
/home/xzj/coding/.venv3_10/bin/python scripts/profile_gpu_nonffn.py \
  --model-path /home/xzj/coding/Qwen3-1.7B \
  --model-name Qwen3-1.7B \
  --prefill-len 512 \
  --decode-context-len 2048 \
  --warmup 1 \
  --repeat 3 \
  --output-dir results/hybrid_full_model_gpu
```

Measured medians:

- `decode_s2048`: full GPU `22.7986 ms`, GPU non-FFN `20.7103 ms`, derived
  GPU FFN `2.0882 ms`, TSS E2E gain `4.253%`, mask-compare CIM 2:4 E2E gain
  `1.145%`.
- `prefill_s512`: full GPU `24.9042 ms`, GPU non-FFN `20.6057 ms`, derived
  GPU FFN `4.2986 ms`, TSS E2E gain `8.014%`, mask-compare CIM 2:4 E2E gain
  `2.158%`.

Output table columns:

```text
model, scenario, gpu_full, gpu_attention_nonffn, gpu_dense_ffn,
cim_ffn_ratio, e2e_latency_norm, e2e_gain, source_status
```

Acceptance criteria:

- Done: at least one representative model has measured full GPU and GPU non-FFN
  timing for both decode and prefill.
- Done: the table keeps full GPU, GPU non-FFN, derived GPU FFN, and CIM/TLM
  FFN ratios separate.
- Done: the rebuttal text clearly says the full-model row is measured full GPU
  with TLM/CIM FFN ratios applied only to the measured GPU FFN slice, not an
  FFN-only extrapolation.

### 2. Keep The 2:4 Nonzero Latency Explanation

Status: done in the V4 cost model and retained in the final draft. Keep the V4
`tree_depth_2_4` row in the final text. The explanation should be:

- Activation 2:4/mask-compare CIM still pays dense activation read, compare,
  mask sideband/control, selected weight reads, and dense stage-output payload
  unless another policy is explicitly modeled.
- It gets a bounded latency benefit because selected entries reduce adder tree
  depth.
- Packed 2:4 issue remains out of the headline unless a later anchor signs it
  off.

### 3. Describe Results As TLM-Style Simulator Results

Status: done in the final draft. The rebuttal says these tables come from the
same TLM-style simulator already claimed in the main text. Keep the wording as
support for reviewer questions, not as a revised-paper submission.

## Later, After The Rebuttal Direction Is Acceptable

- Wrap the TLM-style simulator, configs, and small derived artifacts as a clean
  simulator repo, possibly anonymous if reviewers or the venue permit it.
- Improve source-status rows if time allows: larger-model event ledgers, A1
  dynamic energy, A2/A3 power quality, A4 macro characterization, and
  `lambda_x` fanout signoff.
- Optionally rerun the RTX 5090 table on an idle GPU with more repeats, but do
  not block the rebuttal on it once the full-GPU-relative table is coherent.

## Verification

Before finalizing, run:

```bash
python3 -m unittest tests/test_e2e_cost_model.py
python3 -m e2e_cost_model.run \
  --config configs/e2e_cost_model_rebuttal_v4.json \
  --out results/e2e_cost_model/rebuttal_v4
python3 -m json.tool results/e2e_cost_model/rebuttal_v4/e2e_assumptions.json >/tmp/e2e_v4_assumptions.json
python3 /home/xzj/.codex/skills/virtual-review-session/scripts/check_rebuttal_words.py final-rebuttal-draft.md --limit 2000
git diff --check
```

Current status: all non-anonymous roadmap items above are complete.

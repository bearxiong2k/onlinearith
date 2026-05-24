# Qwen3 Final Experiment Handoff

Use this short prompt for the next Codex session:

```text
Continue final Qwen3 experiment preparation in /home/xzj/coding/onlinearith.

Read first:
- AGENTS.md
- docs/qwen3_final_experiments/codex_prompt.md
- docs/qwen3_final_experiments/active_plan.md
- docs/qwen3_final_experiments/runtime_estimates.md

Read only when needed:
- docs/qwen3_final_experiments/references/evidence_log.md
- docs/qwen3_final_experiments/references/implementation_notes.md
- docs/qwen3_final_experiments/references/multigpu_sharding_plan.md

Current principles:
- Preserve PPL methodology: WikiText-2 raw test, MAX_LENGTH=4096, STRIDE=512,
  masked context labels, and weighted NLL accumulation.
- Treat MXFP8 baseline, fixed-sum calibrated MSD at target-SNR 30 dB, WANDA
  2:4, and activation N:M 2:4 as the representative single-setup experiment
  family until an explicit sweep is added.
- For MSD equivalent work, use Figure 4
  `plot_norm_digit_read = mean_effective_precision / 3.0`; do not substitute
  runtime `global_utilization`.
- `ppltest.py --nproc` is data-parallel window sharding and replicates the full
  model. It is not model sharding and should not be used as the multi-GPU OOM
  solution.
- `ppltest.py --device-map {auto,sequential,balanced}` is the explicit
  single-process model-sharding path. It records sharding metadata in the
  result JSON and must be validated with direct CUDA before timing estimates
  are accepted.

Current status:
- Qwen3-8B setup 2 MXFP8 has direct-CUDA prefix80 validation with one full
  4096-token context window. Sequential model sharding matched single-GPU
  scored tokens and PPL exactly at recorded precision.
- Qwen3-8B setup 6 uniform MSD and fixed-sum target-SNR 30 dB also have
  direct-CUDA prefix80 validation with exact scored-token and PPL parity at
  recorded precision.
- The tested sequential map used physical GPUs 4-7 as visible devices but
  placed layers on visible CUDA 0 and 1 only. It lowered per-GPU memory but did
  not improve wall time; the fixed-sum sharded prefix was 2111.13s versus
  1998.8s for the historical single-GPU prefix.

Next iteration:
1. Decide whether to test `--device-map balanced` or a manual placement policy
   for better GPU use, or treat sequential sharding as memory relief only.
2. Keep `--device-map` single-process and separate from `--nproc`; use
   visible-device IDs in `--max-memory` after `--gpus` filtering.
3. Extend explicit placement to calibration only after preserving calibration
   capture semantics and recording output metadata.
```

Do not add run logs here. Put measurements in `references/evidence_log.md` and
implementation history in `references/implementation_notes.md`.

# Qwen3 Final Experiment Handoff

Use this prompt for the next Codex session:

```text
Continue final Qwen3 experiment setup in /home/xzj/coding/onlinearith.

Read first:
- AGENTS.md
- docs/qwen3_final_experiments/active_plan.md
- docs/qwen3_final_experiments/final_run_commands.md
- docs/qwen3_final_experiments/codex_prompt.md

Read only when needed:
- docs/qwen3_final_experiments/references/evidence_log.md
- docs/qwen3_final_experiments/references/implementation_notes.md

Current state:
- The valid full all-model quality/PPL run is:
  ../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_20260528_155226/summary_full_with_stats_columns/summary_full.tsv
- That run covers Qwen3-0.6B, 1.7B, 4B, and 8B for MXFP8, fixed-sum 30 dB,
  WANDA 2:4, and activation N:M 2:4.
- It does not include fixed-sum `plot_norm_digit_read` or Figure 5 layer-cycle
  data because current `--nproc` jobs do not aggregate MSD stats from nonzero
  ranks.
- Qwen3-0.6B work-point selection found:
  17 dB -> PPL 23.7696, plot_norm_digit_read 0.485333
  18 dB -> PPL 22.8602, plot_norm_digit_read 0.515900
- Use fixed-sum target-SNR 17 dB as the conservative 50% equivalent-work point.

Next action:
- For formal full-sample fixed-sum 17 dB stats on all four models, run:
  BACKGROUND=1 scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh
- This prepares calibration artifacts, runs full WikiText-2 PPL without
  `--limit-samples`, and records `plot_norm_digit_read` plus Figure 5 cycle
  data under:
  ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/

Important rules:
- Preserve PPL methodology: WikiText-2 raw test, MAX_LENGTH=4096, STRIDE=512,
  masked context labels, and weighted NLL accumulation.
- `--limit-samples` is only for smoke or work-point selection probes.
- Use single-process `--msd-utilization-mode --figure5-layer-cycles` for MSD
  stats; use `--nproc` only for PPL/wall-time runs.
- Keep generated outputs out of commits unless explicitly requested.
```

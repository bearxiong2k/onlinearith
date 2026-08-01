# Active Qwen3 Final Experiment Plan

This file tracks the experiment setup and stats collection plan only. Detailed
measurements and historical implementation notes live under `references/`.

## Experiment Matrix

Quality/PPL sweep, already run with four-rank window sharding where applicable:

- MXFP8 baseline: `ppltest.py --setup 2`
- Fixed-sum calibrated MSD at target-SNR 30 dB:
  `ppltest.py --setup 6 --calibration <fixed_sum_30db.json>`
- WANDA structured baseline: common keep-count `2:4`
- Runtime activation N:M baseline: common keep-count `2:4`

50% equivalent-work fixed-sum run, still to complete formally:

- Fixed-sum calibrated MSD at target-SNR 17 dB
- Full WikiText-2 PPL with no `--limit-samples` and `--stats off`, using
  four-rank window sharding for wall time.
- Separate sampled accounting run with `--limit-samples 300 --stats lite
  --figure5-layer-cycles`.
- Report formal PPL from the full no-stats run. Report
  `plot_norm_digit_read` and Figure 5 layer-cycle accounting from the sampled
  stats run, clearly marked as sampled accounting.

Target-SNR 30 dB is the high-quality fixed-sum point. It is not the 50%
equivalent-work point. For equivalent-work comparisons, use
`plot_norm_digit_read = mean_effective_precision / 3.0`.

Sampled larger-model rebuttal sweep, planned next:

- Fixed-sum target-SNR summary grid: `15 17 20`, with
  `--limit-samples 300 --stats lite --figure5-layer-cycles`.
- Ordered fixed-sum best-effort phases:
  `qwen8b@17 qwen4b@17 qwen1_7b@17 qwen4b@15,20 qwen1_7b@15,20`.
- WANDA and runtime activation N:M points: `1:4 2:4 3:4`, also with
  `--limit-samples 300`.
- The sweep is for curve coverage and plotting, not formal full-PPL reporting.
  See `sparsity_norm_sweep300_handoff.md`.
- Qwen3-0.6B is excluded by default because the paper figure already covers it.
  The default rebuttal model order is Qwen3-8B, 4B, then 1.7B.

## Current Results

Valid full PPL sweep:

```text
../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_20260528_155226/summary_full_with_stats_columns/summary_full.tsv
```

That sweep has complete PPL for Qwen3-0.6B, 1.7B, 4B, and 8B across MXFP8,
fixed-sum 30 dB, WANDA 2:4, and activation N:M 2:4. It does not contain
fixed-sum work stats because current `--nproc` runs do not aggregate MSD stats
from nonzero ranks.

The Qwen3-0.6B work-point selection probe bracketed 50% normalized digit read:

| Target SNR | PPL | `plot_norm_digit_read` |
|---:|---:|---:|
| 17 dB | 23.7696 | 0.485333 |
| 18 dB | 22.8602 | 0.515900 |

Use 17 dB as the conservative fixed-sum 50% work point for the formal sweep.
Use 17.5 dB only if an exact near-0.5 point is required later.

The interrupted full-stats run showed why full-sample MSD stats are not viable
for all models: Qwen3-0.6B alone took about 19.5 hours, with PPL `19.4307` and
`plot_norm_digit_read=0.482267`. Qwen3-1.7B was interrupted during PPL stats.

## Entry Points

Formal all-model fixed-sum 17 dB PPL plus sampled stats run:

```bash
BACKGROUND=1 functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh
```

This runs models sequentially from Qwen3-0.6B to 1.7B to 4B to 8B. For each
model, it prepares or reuses the 17 dB calibration artifact, runs full
WikiText-2 PPL with `--nproc 4 --stats off`, then runs a `--limit-samples 300`
MSD/Figure 5 stats pass with explicit single-process model sharding. It writes
a summary under:

```text
../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/
```

Qwen3-8B stats300 uses smaller MSD chunks than the smaller models. The first
attempt at `--msd-chunk-target-mib 1536` OOMed; the current wrapper retries
Qwen3-8B stats with `768`, then `512`, then `384`.

Previous four-method all-model PPL sweep:

```bash
BACKGROUND=1 functional_sim/scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh
```

Use this only if the quality/PPL sweep needs to be regenerated.

Sampled sparsity/norm work-curve sweep:

```bash
BACKGROUND=1 functional_sim/scripts/run_qwen3_sparsity_norm_sweep300_4gpu.sh
```

By default this runs Qwen3-8B, 4B, and 1.7B. It writes fixed-sum stats, WANDA
sampled PPL, activation sampled PPL, and a combined summary under:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_<RUN_ID>/
```

Monitor future active runs with per-process ETA:

```bash
../.venv3_10/bin/python functional_sim/scripts/monitor_qwen3_sweep_eta.py --log-root ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_<RUN_ID> --watch 60
```

## Invariants

- Preserve PPL methodology: WikiText-2 raw test split, `MAX_LENGTH=4096`,
  `STRIDE=512`, masked context labels, and weighted NLL accumulation.
- Preserve setup IDs, result JSON schemas, calibration JSON schemas, tokenizer
  behavior, and calibration semantics.
- `--limit-samples` is only for work-point selection, smoke testing, or the
  explicit sampled accounting pass. Formal PPL scripts leave it unset.
- `ppltest.py --nproc` is data-parallel window sharding with one full model
  replica per process. It is valid for final PPL wall-time acceleration, but it
  is not a stats aggregation path.
- Use `--stats off` for formal full PPL at 17 dB. Use
  `--stats lite --figure5-layer-cycles --limit-samples 300` for sampled
  `plot_norm_digit_read` and Figure 5 latency/accounting data. Do not use
  `--msd-utilization-mode` for these formal result scripts because it defaults
  `--limit-samples` to 100 when no explicit limit is passed.
- Keep generated calibration/result artifacts out of commits unless explicitly
  requested.

## Cheap Contracts

```bash
../.venv3_10/bin/python functional_sim/ppltest.py --list
../.venv3_10/bin/python functional_sim/ppl_batch.py --list
../.venv3_10/bin/python functional_sim/calibrate.py --list
../.venv3_10/bin/python -m py_compile functional_sim/scripts/summarize_qwen3_fixed_sum17_ppl_stats.py functional_sim/scripts/summarize_fixed_sum_norm_sweep.py functional_sim/scripts/summarize_qwen3_model_sweep.py functional_sim/scripts/summarize_qwen3_sparsity_norm_sweep300.py
bash -n functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh functional_sim/scripts/run_qwen3_fixed_sum_norm_target_sweep.sh functional_sim/scripts/run_qwen3_sparsity_norm_sweep300_4gpu.sh
```

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

50% equivalent-work fixed-sum stats sweep, still to run formally:

- Fixed-sum calibrated MSD at target-SNR 17 dB
- Full WikiText-2 test split, no `--limit-samples`
- Stats PPL with `--stats lite --figure5-layer-cycles`
- Output must include PPL, `plot_norm_digit_read`, and Figure 5 layer-cycle
  accounting.

Target-SNR 30 dB is the high-quality fixed-sum point. It is not the 50%
equivalent-work point. For equivalent-work comparisons, use
`plot_norm_digit_read = mean_effective_precision / 3.0`.

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

## Entry Points

Formal all-model fixed-sum 17 dB full stats sweep:

```bash
BACKGROUND=1 scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh
```

This runs models sequentially from Qwen3-0.6B to 1.7B to 4B to 8B. For each
model, PPL stats run on GPUs 4-7 with explicit single-process model sharding
(`--device-map sequential`) so MSD stats remain collectable without `--nproc`.
Calibration defaults to projection/task parallelism across GPUs 4-7 because
that is the validated 8B strategy and keeps otherwise idle GPUs busy, but the
script supports `CALIBRATION_MODE=serial` if model-load or I/O contention makes
parallel projection jobs counterproductive for smaller models. It prepares the
17 dB calibration artifacts, runs full WikiText-2 PPL with MSD/Figure 5 stats,
and writes a summary under:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/
```

Previous four-method all-model PPL sweep:

```bash
BACKGROUND=1 scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh
```

Use this only if the quality/PPL sweep needs to be regenerated.

## Invariants

- Preserve PPL methodology: WikiText-2 raw test split, `MAX_LENGTH=4096`,
  `STRIDE=512`, masked context labels, and weighted NLL accumulation.
- Preserve setup IDs, result JSON schemas, calibration JSON schemas, tokenizer
  behavior, and calibration semantics.
- `--limit-samples` is only for work-point selection or smoke testing. Formal
  result scripts must leave it unset.
- `ppltest.py --nproc` is data-parallel window sharding with one full model
  replica per process. It is valid for final PPL wall-time acceleration, but it
  is not a stats aggregation path.
- Use `--stats lite --figure5-layer-cycles` for formal `plot_norm_digit_read`
  and Figure 5 latency/accounting data. Do not use `--msd-utilization-mode`
  for formal full-sample runs because it defaults to 100 samples when no
  explicit limit is passed.
- Keep generated calibration/result artifacts out of commits unless explicitly
  requested.

## Cheap Contracts

```bash
../.venv3_10/bin/python ppltest.py --list
../.venv3_10/bin/python ppl_batch.py --list
../.venv3_10/bin/python calibrate.py --list
../.venv3_10/bin/python -m py_compile scripts/summarize_fixed_sum_norm_sweep.py scripts/summarize_qwen3_model_sweep.py
bash -n scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh scripts/run_qwen3_fixed_sum_norm_target_sweep.sh
```

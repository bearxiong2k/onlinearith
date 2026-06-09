# Sampled Sparsity/Norm Sweep Handoff

Purpose: collect sampled larger-model rebuttal evidence for fixed-sum MSD,
WANDA, and activation N:M. Qwen3-0.6B is not rerun by default because the paper
figure already covers it.

The default schedule first prepares WANDA masks in parallel across GPUs 4-7,
then runs larger-model WANDA/activation PPL with four-rank window sharding, and
finally runs fixed-sum stats300 in ordered best-effort phases. The fixed-sum
phase is the runtime risk; 4B/8B stats300 points are multi-hour work.

This is not a final full-PPL run. Every row uses `--limit-samples 300`.

## Grid

Fixed-sum MSD summary grid:

- target SNR: `15 17 20`
- expected x-axis metric: `plot_norm_digit_read = mean_effective_precision / 3.0`
- ordered default phases: `qwen8b@17 qwen4b@17 qwen1_7b@17 qwen4b@15,20
  qwen1_7b@15,20`
- rationale: prioritize the core near-0.5 point on larger models first, then
  add adjacent norm points if the two-day budget allows.

WANDA and activation N:M:

- common keep-ratio points: `1:4 2:4 3:4`
- expected x-axis metric: keep ratio, `n / m`
- rationale: cover below-core, 50%, and above-core sparsity points while keeping
  larger-model WANDA calibration count bounded.

Default models: `qwen8b qwen4b qwen1_7b`.

## Launch

```bash
BACKGROUND=1 scripts/run_qwen3_sparsity_norm_sweep300_4gpu.sh
```

Useful overrides:

```bash
TARGET_SNRS="15 17 20" \
NM_POINTS="1:4 2:4 3:4" \
ARTIFACT_GPUS="4,5,6,7" \
BACKGROUND=1 scripts/run_qwen3_sparsity_norm_sweep300_4gpu.sh
```

To add the former 0.6B model back into the sweep:

```bash
MODEL_SPECS="qwen0_6b:../Qwen3-0.6B:float16 qwen1_7b:../Qwen3-1.7B:float16 qwen4b:../Qwen3-4B:float16 qwen8b:../Qwen3-8B:float8" \
FIXED_SUM_PHASES="qwen8b@17 qwen4b@17 qwen1_7b@17 qwen0_6b@15,17,20 qwen4b@15,20 qwen1_7b@15,20" \
BACKGROUND=1 scripts/run_qwen3_sparsity_norm_sweep300_4gpu.sh
```

## Monitor

The background wrapper prints the exact timestamped log directory, for example:

```text
[launched] driver log: ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/driver.log
[launched] nohup log : ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/nohup.out
```

Monitor active tasks with per-process ETA:

```bash
../.venv3_10/bin/python scripts/monitor_qwen3_sweep_eta.py --log-root ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS
```

Refresh it automatically:

```bash
../.venv3_10/bin/python scripts/monitor_qwen3_sweep_eta.py --log-root ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS --watch 60
```

The ETA monitor is the default monitoring method for future runs. It combines
live `ppltest.py`/`calibrate.py` processes, GPU utilization, status TSV rows,
and PPL progress lines. PPL ETAs update at evaluated-window boundaries.

Raw overall driver log:

```bash
tail -f ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/driver.log
```

Raw main task status:

```bash
tail -f ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/status.tsv
```

During the first WANDA mask-preparation phase, several calibration logs should
advance at the same time under:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/baselines/<model>/wanda/<n-m>/calibration.log
```

Monitor fixed-sum subdriver status. Each ordered phase gets its own subfolder:

```bash
tail -f ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/fixed_sum/00_qwen8b_17/status.tsv
```

Later fixed-sum phase logs are under the same `fixed_sum/` directory.

For an active WANDA or activation PPL point, inspect the point log and progress
JSON under:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/baselines/<model>/<wanda|act>/<n-m>/
```

Example:

```bash
tail -f ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/baselines/qwen8b/act/2-4/ppl_limit300.log
cat ../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/baselines/qwen8b/act/2-4/progress.json
```

## Outputs

Fixed-sum sampled stats:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/fixed_sum/<model>/snrXXdb/ppl/stats_limit300/
```

WANDA masks and sampled PPL:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/baselines/<model>/wanda_base/<n-m>/
```

Activation sampled PPL:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/baselines/<model>/act_base/<n-m>/
```

Combined summaries:

```text
../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/summary/sparsity_norm_sweep_limit300.tsv
../data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_YYYYMMDD_HHMMSS/summary/sparsity_norm_sweep_limit300.json
```

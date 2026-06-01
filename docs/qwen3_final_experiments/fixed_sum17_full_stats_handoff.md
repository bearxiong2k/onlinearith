# Fixed-Sum 17 dB Full Stats Handoff

This is the handoff for the formal 50% equivalent-work fixed-sum stats run.
Use it directly when launching or monitoring the unattended run.

## Start

Run from the repository root:

```bash
cd /home/xzj/coding/onlinearith
../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
BACKGROUND=1 scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh
```

The CUDA check should print `True 8` on this machine. The script itself uses
GPUs 4-7 by default.

If projection-parallel calibration is unstable or clearly slower because of
model-load or I/O contention, use the serial calibration fallback:

```bash
CALIBRATION_MODE=serial BACKGROUND=1 scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh
```

The background launch prints:

```text
[launched] PID: <pid>
[launched] driver log: ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/driver.log
[launched] nohup log : ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/nohup.out
```

Set the run directory from that printed path:

```bash
RUN_DIR=../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>
```

If the terminal output is gone, find the latest run with:

```bash
RUN_DIR=$(ls -td ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_* | head -1)
echo "$RUN_DIR"
```

## Monitor

Monitor with direct paths by replacing `<RUN_ID>` with the timestamp printed by
the launch command:

```bash
tail -f ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/driver.log
```

Artifact and step status:

```bash
tail -f ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/status.tsv
```

Background wrapper output:

```bash
tail -f ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/nohup.out
```

Periodic status and GPU checks:

```bash
watch -n 60 "tail -n 20 ../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/status.tsv"
watch -n 60 nvidia-smi
```

If you prefer a reusable shell variable, set:

```bash
RUN_DIR=../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>
tail -f "$RUN_DIR/driver.log"
tail -f "$RUN_DIR/status.tsv"
tail -f "$RUN_DIR/nohup.out"
```

Check the process if needed:

```bash
ps -fp <pid>
```

Check completion:

```bash
cat "$RUN_DIR/final_status.txt"
sed -n '1,20p' "$RUN_DIR/fixed_sum_stats_full.tsv"
awk -F'\t' 'NR == 1 || $5 !~ /completed|skipped_existing/' "$RUN_DIR/status.tsv"
```

`final_status.txt` should report `exit_status=0`. The `awk` command should
show only the header after a fully successful run.

## Execution Plan

The script runs models sequentially from small to large:

```text
qwen0_6b -> qwen1_7b -> qwen4b -> qwen8b
```

For each model:

- target-SNR is 17 dB;
- calibration uses projection/task parallelism across GPUs 4-7 by default;
- Qwen3-8B down-projection calibration is split into bounded layer waves;
- full WikiText-2 PPL runs with no `--limit-samples`;
- PPL stats use all GPUs 4-7 in explicit model-sharding mode:
  `--device-map sequential --max-memory 0:30GiB,1:30GiB,2:30GiB,3:30GiB`;
- stats include `--stats lite --figure5-layer-cycles`;
- `--nproc` is not used, because current multi-rank PPL does not aggregate MSD
  stats from nonzero ranks.

## Artifacts And Results

Default output root:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/
```

Run log root:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/
```

Run-level files:

```text
driver.log
nohup.out
run.env
status.tsv
final_status.txt
fixed_sum_stats_full.tsv
fixed_sum_stats_full.json
```

Per-step logs:

```text
<model_key>/calib/snr17db/fixed_sum_*.log
<model_key>/ppl/snr17db/ppl_util_fig5_full.log
```

Merged calibration artifact for each model:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/<model_key>/snr17db/calib/calibration_MXFP8_fixed_sum_<model_key>_snr17db.json
```

Partial calibration artifacts for Qwen3-0.6B, Qwen3-1.7B, and Qwen3-4B:

```text
calibration_MXFP8_fixed_sum_<model_key>_snr17db_gate.json
calibration_MXFP8_fixed_sum_<model_key>_snr17db_up.json
calibration_MXFP8_fixed_sum_<model_key>_snr17db_down.json
```

Qwen3-8B uses these partial down-projection artifacts:

```text
calibration_MXFP8_fixed_sum_qwen8b_snr17db_down_l00.json
calibration_MXFP8_fixed_sum_qwen8b_snr17db_down_l01_l12.json
calibration_MXFP8_fixed_sum_qwen8b_snr17db_down_l13_l24.json
calibration_MXFP8_fixed_sum_qwen8b_snr17db_down_l25_l35.json
```

Full PPL/stat result for each model:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/<model_key>/snr17db/ppl/util_fig5_full/ppl_results_MXFP8_fixed_sum_<model_key>_snr17db_util_fig5_full.json
```

The run summary TSV/JSON includes PPL, mean NLL, scored tokens, full-sample
marker fields, `mean_effective_precision`, `plot_norm_digit_read`,
`global_utilization`, hardware-accounting ratios, Figure 5 layer-cycle columns,
and paths back to the per-model JSON files.

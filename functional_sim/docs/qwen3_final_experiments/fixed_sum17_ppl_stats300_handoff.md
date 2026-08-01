# Fixed-Sum 17 dB PPL And Stats300 Handoff

This is the current handoff for the 50% equivalent-work fixed-sum run. It
assumes the 17 dB point is close enough to `plot_norm_digit_read ~= 0.5` for
all four model sizes.

## Start

Run from the repository root:

```bash
cd /home/xzj/coding/onlinearith
../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
BACKGROUND=1 functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh
```

The CUDA check should print `True 8`; the script uses GPUs 4-7 by default.
The launch prints:

```text
[launched] PID: <pid>
[launched] driver log: ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/driver.log
[launched] nohup log : ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/nohup.out
```

## Monitor

Monitor with direct paths by replacing `<RUN_ID>` with the timestamp printed by
the launch command:

```bash
tail -f ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/driver.log
```

Artifact and step status:

```bash
tail -f ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/status.tsv
```

The full no-stats PPL phase uses `--nproc 4` and streams clean tqdm progress
through `driver.log`, matching the previous final experiment sweep behavior.

For a clean one-screen progress view of the active step:

```bash
watch -n 30 functional_sim/scripts/monitor_qwen3_fixed_sum17_ppl_stats300.sh <RUN_ID>
```

Example:

```bash
watch -n 30 functional_sim/scripts/monitor_qwen3_fixed_sum17_ppl_stats300.sh 20260602_150000
```

For the sampled stats phase, the per-model logs are:

```bash
tail -f ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/qwen0_6b/ppl/snr17db/stats_limit300_chunk1536.log
tail -f ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/qwen1_7b/ppl/snr17db/stats_limit300_chunk1536.log
tail -f ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/qwen4b/ppl/snr17db/stats_limit300_chunk1536.log
tail -f ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/qwen8b/ppl/snr17db/stats_limit300_chunk768.log
```

Periodic status and GPU checks:

```bash
watch -n 60 "tail -n 20 ../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/status.tsv"
watch -n 60 nvidia-smi
```

Check completion:

```bash
RUN_DIR=../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>
cat "$RUN_DIR/final_status.txt"
sed -n '1,20p' "$RUN_DIR/fixed_sum17_ppl_stats_summary.tsv"
awk -F'\t' 'NR == 1 || $6 !~ /completed|skipped_existing|adopted_existing/' "$RUN_DIR/status.tsv"
```

`final_status.txt` should report `exit_status=0`. The summary TSV is the
review entry point.

## Execution Plan

The script runs models sequentially:

```text
qwen0_6b -> qwen1_7b -> qwen4b -> qwen8b
```

For each model:

- prepare or reuse fixed-sum 17 dB calibration;
- run full WikiText-2 PPL with `--stats off --nproc 4 --gpus 4,5,6,7`;
- then run sampled stats with `--limit-samples 300 --stats lite
  --figure5-layer-cycles` using single-process model sharding.

The full no-stats phase is the formal PPL result. The limit-300 stats phase is
the accounting estimate for `plot_norm_digit_read` and Figure 5 cycle columns.

## Artifacts And Results

Default output root:

```text
../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/
```

Run log root:

```text
../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_<RUN_ID>/
```

Run-level files:

```text
driver.log
nohup.out
run.env
status.tsv
final_status.txt
fixed_sum17_ppl_stats_summary.tsv
fixed_sum17_ppl_stats_summary.json
```

Merged calibration artifact for each model:

```text
../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/<model_key>/snr17db/calib/calibration_MXFP8_fixed_sum_<model_key>_snr17db.json
```

Full no-stats PPL result for each model:

```text
../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/<model_key>/snr17db/ppl/full_no_stats/ppl_results_MXFP8_fixed_sum_<model_key>_snr17db_full_no_stats.json
```

Limit-300 stats result for each model:

```text
../data/qwen3_final_experiments/fixed_sum17_ppl_stats300/<model_key>/snr17db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_<model_key>_snr17db_stats_limit300.json
```

The summary TSV/JSON joins full PPL with sampled stats columns:
`full_token_perplexity`, `full_scored_tokens`, `stats_plot_norm_digit_read`,
`stats_hw_latency_overhead`, and Figure 5 mean cycle columns.

## Qwen8B Stats Retry

The first Qwen8B stats300 attempt with `--msd-chunk-target-mib 1536` OOMed.
The wrapper now uses smaller Qwen8B stats chunks, trying `768`, then `512`,
then `384`. To resume after the failed run, rerun the same wrapper:

```bash
BACKGROUND=1 functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh
```

Existing calibration, full-PPL outputs, and completed stats outputs are skipped.
Only the missing Qwen8B stats300 artifact should run.

To run only the missing Qwen8B row:

```bash
MODEL_JOBS='qwen8b:../Qwen3-8B:float8:float8:4:256:64:768,512,384' \
BACKGROUND=1 functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh
```

## Interrupted Prior Run

The stopped full-stats run is not the formal result. It produced one useful
sanity row:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_20260601_181331/fixed_sum_stats_full.tsv
```

Qwen3-0.6B at 17 dB completed with PPL `19.4307` and
`plot_norm_digit_read=0.482267`, but it took about 19.5 hours for only the
0.6B model. Qwen3-1.7B was interrupted during PPL stats. The new script may
reuse the completed 0.6B and 1.7B calibration artifacts from that run.

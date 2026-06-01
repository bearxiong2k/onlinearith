# Final Run Commands

These are the settled commands for the representative Qwen3-8B experiment
family. They preserve the existing PPL method: WikiText-2 raw test,
`MAX_LENGTH=4096`, `STRIDE=512`, masked context labels, and weighted NLL
accumulation.

Run the CUDA visibility check before launching final work:

```bash
../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
```

Expected on the current machine: `True 8`.

## Paths

Use a shell variable block like this to avoid mixing smoke artifacts with final
outputs:

```bash
MODEL=../Qwen3-8B
GPUS=4,5,6,7
NPROC=4
FINAL_ROOT=../data/qwen3_final_experiments/qwen3_8b
MSD_DIR=$FINAL_ROOT/calib_fixed_sum_30db
MSD_CAL=$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_merged.json
WANDA_ROOT=../data/wanda_base
WANDA_HOOK=qwen8b_final
ACT_ROOT=$FINAL_ROOT/act_base
```

Do not use `../data/calib-data/30db/calibration_MXFP8_fixed_sum.json` or
`../data/wanda_base/2-4/calibration_base_MXFP8.pt` for Qwen3-8B final runs;
those existing files are shaped for smaller-model work.

## Calibration Prerequisites

### Fixed-Sum MSD

Run projection-filtered calibration jobs, preferably one projection family per
GPU. Use `--weight-cache-dtype none` for broad calibration capture.

For Qwen3-8B, `gate_proj` and `up_proj` fit as full projection-family jobs.
`down_proj` has the wider MLP intermediate input, so do not run all down
layers in one calibration process; split it into bounded layer groups and merge
the files. This keeps the same calibration corpus and avoids changing MSD math
or calibration semantics to work around the cache footprint. The down groups
can be run sequentially on one GPU by setting `DOWN_GPU`, or launched on
separate idle GPUs by giving each command a different `--gpus` value.

```bash
../.venv3_10/bin/python calibrate.py \
  --model-path "$MODEL" \
  --setup 1 \
  --optimizer fixed_sum \
  --target-snr 30 \
  --projection-filter gate_proj \
  --num-texts 20 \
  --max-length 512 \
  --batch-size 4 \
  --result-suffix qwen8b_final_gate \
  --output-dir "$MSD_DIR" \
  --mx-chunk-target-mib 256 \
  --cal-chunk-target-mib 64 \
  --weight-cache-dtype none \
  --compile-msd-truncate \
  --gpus 0

../.venv3_10/bin/python calibrate.py \
  --model-path "$MODEL" \
  --setup 1 \
  --optimizer fixed_sum \
  --target-snr 30 \
  --projection-filter up_proj \
  --num-texts 20 \
  --max-length 512 \
  --batch-size 4 \
  --result-suffix qwen8b_final_up \
  --output-dir "$MSD_DIR" \
  --mx-chunk-target-mib 256 \
  --cal-chunk-target-mib 64 \
  --weight-cache-dtype none \
  --compile-msd-truncate \
  --gpus 1

DOWN_L00=model.layers.0.mlp.down_proj
DOWN_L01_L12=model.layers.1.mlp.down_proj,model.layers.2.mlp.down_proj,model.layers.3.mlp.down_proj,model.layers.4.mlp.down_proj,model.layers.5.mlp.down_proj,model.layers.6.mlp.down_proj,model.layers.7.mlp.down_proj,model.layers.8.mlp.down_proj,model.layers.9.mlp.down_proj,model.layers.10.mlp.down_proj,model.layers.11.mlp.down_proj,model.layers.12.mlp.down_proj
DOWN_L13_L24=model.layers.13.mlp.down_proj,model.layers.14.mlp.down_proj,model.layers.15.mlp.down_proj,model.layers.16.mlp.down_proj,model.layers.17.mlp.down_proj,model.layers.18.mlp.down_proj,model.layers.19.mlp.down_proj,model.layers.20.mlp.down_proj,model.layers.21.mlp.down_proj,model.layers.22.mlp.down_proj,model.layers.23.mlp.down_proj,model.layers.24.mlp.down_proj
DOWN_L25_L35=model.layers.25.mlp.down_proj,model.layers.26.mlp.down_proj,model.layers.27.mlp.down_proj,model.layers.28.mlp.down_proj,model.layers.29.mlp.down_proj,model.layers.30.mlp.down_proj,model.layers.31.mlp.down_proj,model.layers.32.mlp.down_proj,model.layers.33.mlp.down_proj,model.layers.34.mlp.down_proj,model.layers.35.mlp.down_proj
DOWN_GPU=2

for spec in \
  "qwen8b_final_down_l00:$DOWN_L00" \
  "qwen8b_final_down_l01_l12:$DOWN_L01_L12" \
  "qwen8b_final_down_l13_l24:$DOWN_L13_L24" \
  "qwen8b_final_down_l25_l35:$DOWN_L25_L35"
do
  suffix=${spec%%:*}
  filter=${spec#*:}
  ../.venv3_10/bin/python calibrate.py \
    --model-path "$MODEL" \
    --setup 1 \
    --optimizer fixed_sum \
    --target-snr 30 \
    --projection-filter "$filter" \
    --num-texts 20 \
    --max-length 512 \
    --batch-size 4 \
    --result-suffix "$suffix" \
    --output-dir "$MSD_DIR" \
    --mx-chunk-target-mib 256 \
    --cal-chunk-target-mib 64 \
    --weight-cache-dtype none \
    --compile-msd-truncate \
    --gpus "$DOWN_GPU"
done
```

Merge the disjoint projection outputs:

```bash
../.venv3_10/bin/python tools/merge_msd_calibrations.py \
  "$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_gate.json" \
  "$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_up.json" \
  "$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_down_l00.json" \
  "$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_down_l01_l12.json" \
  "$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_down_l13_l24.json" \
  "$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_down_l25_l35.json" \
  --output "$MSD_CAL"
```

### WANDA 2:4 Mask

Generate a Qwen3-8B-shaped WANDA mask with a suffix, so it cannot collide with
the existing smaller-model mask:

```bash
../.venv3_10/bin/python wanda_base/calibrate_base.py \
  --model-path "$MODEL" \
  --results-root "$WANDA_ROOT" \
  -n 2 -m 4 \
  --setup 1 \
  --num-texts 2048 \
  --max-length 512 \
  --batch-size 4 \
  --output-hook "$WANDA_HOOK" \
  --mx-chunk-target-mib 256 \
  --weight-cache-dtype none \
  --gpus 0
```

This should create:

```text
../data/wanda_base/2-4/calibration_base_MXFP8_qwen8b_final.pt
```

## Final PPL Runs

Current GPU availability limits the final run to GPUs 4-7. Prefer the
resumable end-to-end wrapper:

```bash
GPUS=4,5,6,7 NPROC=4 scripts/run_qwen3_final_ppl_4gpu.sh
```

The wrapper runs MXFP8, fixed-sum MSD 30 dB, WANDA 2:4, and activation N:M
2:4 in order, writes one log per step under
`$FINAL_ROOT/logs/final_ppl_4gpu_<RUN_ID>/`, writes a `status.tsv` in the same
directory, skips existing outputs unless `FORCE=1`, and stops on the first
failing step. The individual commands below are the expanded form.

### MXFP8 Baseline

```bash
../.venv3_10/bin/python ppltest.py \
  --model-path "$MODEL" \
  --setup 2 \
  --nproc "$NPROC" \
  --gpus "$GPUS" \
  --stats off \
  --load-stagger-sec 8 \
  --output "$FINAL_ROOT/ppl_results_MXFP8_qwen8b_final.json" \
  --mxfp-progress-interval-sec -1
```

### Fixed-Sum MSD 30 dB

```bash
../.venv3_10/bin/python ppltest.py \
  --model-path "$MODEL" \
  --setup 6 \
  --calibration "$MSD_CAL" \
  --nproc "$NPROC" \
  --gpus "$GPUS" \
  --stats off \
  --compile-msd-truncate \
  --weight-cache-dtype float8 \
  --load-stagger-sec 8 \
  --output "$FINAL_ROOT/ppl_results_MXFP8_fixed_sum30_qwen8b_final.json" \
  --mxfp-progress-interval-sec -1
```

### WANDA 2:4

Use `--window-shard`; default baseline-runner `--nproc` shards setup IDs and
does not accelerate a single selected setup.

```bash
../.venv3_10/bin/python wanda_base/ppl_batch_base.py \
  --model-path "$MODEL" \
  --results-root "$WANDA_ROOT" \
  -n 2 -m 4 \
  --only 1 \
  --output-hook "$WANDA_HOOK" \
  --nproc "$NPROC" \
  --gpus "$GPUS" \
  --window-shard \
  --load-stagger-sec 8 \
  --mxfp-progress-interval-sec -1
```

### Activation N:M 2:4

```bash
../.venv3_10/bin/python act_base/ppl_batch_base_act.py \
  --model-path "$MODEL" \
  --results-root "$ACT_ROOT" \
  -n 2 -m 4 \
  --only 1 \
  --nproc "$NPROC" \
  --gpus "$GPUS" \
  --window-shard \
  --load-stagger-sec 8 \
  --mxfp-progress-interval-sec -1
```

## All-Model Quality/PPL Sweep

Use the unattended wrapper for the Qwen3-0.6B, Qwen3-1.7B, Qwen3-4B, and
Qwen3-8B quality/PPL sweep:

```bash
BACKGROUND=1 scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh
```

This prepares smaller-model fixed-sum 30 dB and WANDA artifacts, runs full PPL
for MXFP8, fixed-sum 30 dB, WANDA 2:4, and activation N:M 2:4, and writes:

```text
../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_<RUN_ID>/summary_full.tsv
../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_<RUN_ID>/summary_full.json
```

The valid completed run from 2026-05-28 is:

```text
../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_20260528_155226/summary_full_with_stats_columns/summary_full.tsv
```

That PPL run does not contain `plot_norm_digit_read` or Figure 5 layer-cycle
data because current `--nproc` jobs do not aggregate MSD stats from nonzero
ranks.

## Fixed-Sum 17 dB Full Stats Sweep

Run this for the formal 50% equivalent-work fixed-sum data:

```bash
BACKGROUND=1 scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh
```

This script:

- uses target-SNR 17 dB for all four models;
- prepares model-specific fixed-sum calibration artifacts;
- runs full WikiText-2 PPL with no `--limit-samples`;
- uses `--msd-utilization-mode --figure5-layer-cycles`;
- runs one single-process stats job per model on GPUs 4-7.

Outputs and summaries are written under:

```text
../data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_<RUN_ID>/
```

Use `UTIL_LIMIT_SAMPLES=120` only with
`scripts/run_qwen3_fixed_sum_norm_target_sweep.sh` for smoke or work-point
selection probes. Formal stats runs leave `UTIL_LIMIT_SAMPLES` unset.

## Expected Wall Times

- MXFP8 PPL: about 0.67 h on four workers.
- Fixed-sum MSD 30 dB PPL: about 45.1 h on four workers.
- WANDA 2:4 PPL: about 0.7 h on four workers, after mask calibration.
- Activation N:M 2:4 PPL: about 0.75 h on four workers.

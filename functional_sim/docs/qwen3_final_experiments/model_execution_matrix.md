# Model Execution Matrix

This file settles the per-model execution policy before final runs. It is a
recipe matrix, not a new methodology. PPL math, datasets, tokenizer behavior,
window constants, labels, and weighted NLL accumulation remain unchanged.
Concrete Qwen3-8B launch commands live in `final_run_commands.md`.

## Global Defaults

Use these defaults unless a model/path row below overrides them.

- PPL numerical runs: `--stats off`.
- MSD PPL runs: `--compile-msd-truncate`.
- Full-replica acceleration: `functional_sim/ppltest.py --nproc`, which shards PPL windows and
  loads one complete model replica per worker.
- Baseline-runner single-setup acceleration: `functional_sim/wanda_base/ppl_batch_base.py` and
  `functional_sim/act_base/ppl_batch_base_act.py` require `--window-shard` with `--nproc`;
  their default `--nproc` behavior shards setup IDs, not PPL windows.
- Model sharding: `functional_sim/ppltest.py --device-map ...`, single process only, memory
  relief only unless direct-CUDA timing proves speedup.
- Fixed-sum calibration: projection-filtered task-parallel full-model jobs,
  then merge metadata; do not use model sharding as the default calibration
  trick.
- Broad calibration capture: `--weight-cache-dtype none` to avoid persistent
  cache accumulation during projection-filtered runs.
- Qwen3-8B fixed-sum calibration: gate/up projections fit as full projection
  families; split down projections into bounded layer groups because selecting
  all down layers in one process OOMs from retained block-cache size.
- Smaller-model fixed-sum/WANDA artifact prep: use model-specific profiles
  instead of the Qwen3-8B recipe. The unattended wrapper runs Qwen3-0.6B on GPU
  4 with `CALIB_BATCH_SIZE=8`, `CALIB_MX_CHUNK_MIB=512`,
  `CALIB_CHUNK_MIB=128`, `WANDA_BATCH_SIZE=8`; Qwen3-1.7B on GPU 5 with
  `4/384/96/4`; and Qwen3-4B on GPU 6 with conservative `2/256/64/2`.
- Qwen3-8B multi-rank loading: use `--load-stagger-sec 8` when launching full
  replicas. Current final-run availability is GPUs 4-7 only, so use
  `--nproc 4 --gpus 4,5,6,7`.

## Final PPL Recipes

| Model | MXFP8 PPL | Fixed-sum MSD 30 dB PPL | WANDA 2:4 PPL | Activation N:M 2:4 PPL |
|---|---|---|---|---|
| Qwen3-0.6B | Use the four-GPU sweep wrapper on GPUs 4-7; prefix smoke is validated. | Use the per-model artifact prep profile on GPU 4, then PPL with default float16 cache unless prefix evidence says otherwise. | Use the per-model WANDA profile on GPU 4, then baseline runner with `--window-shard`. | Use the four-GPU sweep wrapper on GPUs 4-7; prefix smoke is validated. |
| Qwen3-1.7B | Use the four-GPU sweep wrapper on GPUs 4-7; prefix smoke is validated. | Use the per-model artifact prep profile on GPU 5, then PPL with default float16 cache unless a prefix run shows memory pressure. | Use the per-model WANDA profile on GPU 5, then baseline runner with `--window-shard`. | Use the four-GPU sweep wrapper on GPUs 4-7; prefix smoke is validated. |
| Qwen3-4B | Use the four-GPU sweep wrapper on GPUs 4-7; prefix smoke is validated. | Use the conservative per-model artifact prep profile on GPU 6; consider float8 cache only if default float16 cache is near OOM. | Use the conservative per-model WANDA profile on GPU 6, then baseline runner with `--window-shard`. | Use the four-GPU sweep wrapper on GPUs 4-7; prefix smoke is validated. |
| Qwen3-8B | Use `--nproc 4 --gpus 4,5,6,7 --load-stagger-sec 8`. | Use `--nproc 4 --gpus 4,5,6,7 --load-stagger-sec 8 --weight-cache-dtype float8`. | Use baseline runner `--nproc 4 --gpus 4,5,6,7 --window-shard --load-stagger-sec 8` with the Qwen3-8B-shaped mask. | Use baseline runner `--nproc 4 --gpus 4,5,6,7 --window-shard --load-stagger-sec 8`. |

## Validation Gates

Before committing to a final full PPL command for any model/path combination:

1. Verify direct CUDA: `../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'`.
2. Run a prefix that includes at least one 4096-token context window.
3. Confirm scored tokens and PPL match the corresponding single-process or
   smaller-worker reference for the same prefix.
4. Confirm output JSON records CUDA memory fields and the intended execution
   mode (`world_size`, `device_map`, cache dtype, calibration file, and
   `load_stagger_sec` when used).
5. For MSD, confirm the chosen cache dtype. Qwen3-8B fixed-sum MSD currently
   requires `--weight-cache-dtype float8` for full-replica multi-GPU PPL.

## Current Settled Choices

- Current execution availability is GPUs 4-7. Use the four-worker wrappers for
  Qwen3-8B final PPL and the all-model sweep until more GPUs are available.
- Smaller-model sweep smoke on GPUs 4-7 completed MXFP8 and activation N:M
  with `LIMIT_SAMPLES=120` for Qwen3-0.6B, Qwen3-1.7B, and Qwen3-4B. Review
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/sweep_20260528_144624/status.tsv`
  before removing the sample limit.
- Qwen3-8B MXFP8: full-replica `--load-stagger-sec 8` is validated; use
  `--nproc 4 --gpus 4,5,6,7` for current final MXFP8 PPL.
- Qwen3-8B fixed-sum MSD: full-replica
  `--load-stagger-sec 8 --weight-cache-dtype float8` is validated; use
  `--nproc 4 --gpus 4,5,6,7` for current final fixed-sum MSD PPL.
- Qwen3-8B WANDA 2:4: full replicas are validated through
  `functional_sim/wanda_base/ppl_batch_base.py --window-shard --load-stagger-sec 8`; use a
  Qwen3-8B-shaped mask,
  `../data/wanda_base/2-4/calibration_base_MXFP8_qwen8b_final.pt`, not the
  older 0.6B masks under `../data/wanda_base/2-4`.
- Full all-model unattended wrapper: use
  `BACKGROUND=1 functional_sim/scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh`. It
  prepares smaller-model artifacts in parallel with the profiles above, then
  writes full outputs under
  `../data/qwen3_final_experiments/model_sweep_4gpu/<model_key>/full/` and
  final summaries under `logs/full_unattended_<RUN_ID>/`.
- Qwen3-8B fixed-sum calibration metadata: use the merged final file
  `../data/qwen3_final_experiments/qwen3_8b/calib_fixed_sum_30db/calibration_MXFP8_fixed_sum_qwen8b_final_merged.json`.
- Qwen3-8B activation N:M 2:4: full replicas are validated through
  `functional_sim/act_base/ppl_batch_base_act.py --window-shard --load-stagger-sec 8`.
- Qwen3-8B model sharding: sequential `--device-map` is correctness-validated
  but slower for the tested prefix; keep it as memory relief, not final speed.
- Smaller models should not inherit Qwen3-8B-only tricks blindly. Use default
  float16 cache unless a model-specific prefix run shows memory pressure, and
  add `--load-stagger-sec` only when launch/load contention appears.

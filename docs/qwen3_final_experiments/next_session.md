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
  model. It is valid for final PPL wall-time acceleration when every selected
  GPU can fit a full replica, but it is not model sharding and should not be
  used as the multi-GPU OOM solution.
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
- Qwen3-8B `ppltest.py --nproc` full-replica data-parallel PPL is now
  prefix-validated for setup 2 MXFP8 and fixed-sum target-SNR 30 dB up to four
  workers. MXFP8 prefix80 matched prior PPL and ran in 17.02s on two workers
  versus 31.97s single-GPU; MXFP8 prefix120 ran in 33.2s on four workers.
  Fixed-sum prefix80 matched prior PPL and ran in 1120.41s on two workers with
  `--weight-cache-dtype float8`; fixed-sum prefix120 ran in 2239.0s on four
  workers with the same float8 cache.
- `ppltest.py --load-stagger-sec S` is now available and records
  `load_stagger_sec` in output metadata. It sleeps `local_rank*S` seconds before
  tokenizer/model loading, reducing transient host RAM and disk I/O spikes
  without changing PPL math.
- Qwen3-8B MXFP8 prefix120 is now validated on eight full replicas with
  `--load-stagger-sec 8`: PPL 9.8221, mean NLL 2.2846, wall 17.03s. This
  replaces the prior failed unstaggered eight-worker launch as the MXFP8 final
  speed recipe.
- Qwen3-8B fixed-sum target-SNR 30 dB prefix120 is now validated on eight full
  replicas with `--load-stagger-sec 8 --weight-cache-dtype float8`: PPL 9.8648,
  mean NLL 2.2890, wall 1120.87s. This promotes the final fixed-sum MSD PPL
  recipe from four replicas to eight replicas.
- Current final-run availability is GPUs 4-7 only, so use the four-replica
  script/commands even though eight-replica prefixes were validated earlier.
- Qwen3-8B WANDA 2:4 and activation N:M 2:4 now have explicit baseline-runner
  window sharding. Use `--window-shard` with `--nproc`; default baseline-runner
  `--nproc` shards setup IDs and does not accelerate a single selected setup.
  WANDA prefix120 on eight replicas with `--window-shard --load-stagger-sec 8`
  gave PPL 18.2443, mean NLL 2.9039, wall 17.13s. Activation N:M prefix120 on
  eight replicas with the same execution mode gave PPL 13.0141, mean NLL 2.5660,
  wall 18.26s.
- Qwen3-8B WANDA final mask generation is complete. Use
  `../data/wanda_base/2-4/calibration_base_MXFP8_qwen8b_final.pt`; the older
  unsuffixed mask is shaped for Qwen3-0.6B and fails on Qwen3-8B.
- Qwen3-8B fixed-sum target-SNR 30 dB calibration prerequisites are complete
  and merged into
  `../data/qwen3_final_experiments/qwen3_8b/calib_fixed_sum_30db/calibration_MXFP8_fixed_sum_qwen8b_final_merged.json`.
  The merged file covers 108 MLP projection layers and 1,032,192 channels.
  Gate/up fit as full projection-family calibration jobs; down projections
  need bounded layer groups because all-down retained-cache capture OOMed.
- `docs/qwen3_final_experiments/final_run_commands.md` now contains the concrete
  Qwen3-8B command sheet for fixed-sum calibration, WANDA mask generation, and
  the four final PPL runs. It uses suffixed WANDA outputs and a separate
  activation results root to avoid overwriting smaller-model artifacts.
- `scripts/run_qwen3_final_ppl_4gpu.sh` is the current end-to-end final PPL
  wrapper. It defaults to `GPUS=4,5,6,7`, `NPROC=4`, runs MXFP8, fixed-sum MSD,
  WANDA, and activation N:M in order, logs each step, skips existing outputs
  unless `FORCE=1`, and stops on first failure. Final Qwen3-8B MXFP8 and
  fixed-sum outputs keep the flat filenames in
  `../data/qwen3_final_experiments/qwen3_8b/`; logs/status are timestamped
  under `../data/qwen3_final_experiments/qwen3_8b/logs/`.
- `scripts/run_qwen3_model_experiment_sweep_4gpu.sh` is the all-model
  experiment-sweep wrapper. It covers Qwen3-0.6B, Qwen3-1.7B, Qwen3-4B, and
  Qwen3-8B on GPUs 4-7, defaults to full outputs, and defaults to
  `RUN_STEPS="mxfp8 fixed_sum wanda act"`. By default it first runs
  `scripts/prepare_qwen3_model_sweep_artifacts_4gpu.sh`, which prepares
  model-specific smaller-model fixed-sum and WANDA artifacts under
  `../data/qwen3_final_experiments/model_sweep_4gpu/<model_key>/artifacts/`;
  set `PREPARE_ARTIFACTS=0` only when those artifacts are already present and
  you want a PPL-only rerun. Use `LIMIT_SAMPLES=120` for a monitored prefix.
  Prefix and full outputs are separated under
  `../data/qwen3_final_experiments/model_sweep_4gpu/<model_key>/prefix120/`
  and `../data/qwen3_final_experiments/model_sweep_4gpu/<model_key>/full/`;
  logs plus `status.tsv` are under
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/sweep_<tag>_<RUN_ID>/`.
  Qwen3-8B fixed-sum and WANDA use the existing 8B calibration/mask.
- `scripts/prepare_qwen3_model_sweep_artifacts_4gpu.sh` prepares Qwen3-0.6B,
  Qwen3-1.7B, and Qwen3-4B artifacts. Fixed-sum calibration uses setup 1,
  target-SNR 30 dB, projection-filtered gate/up/down jobs, then merges them
  with `tools/merge_msd_calibrations.py`. WANDA uses setup 1 and keep-count
  `2:4`. It is resume-safe at the artifact-file level and writes artifact logs
  under
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/artifacts_<RUN_ID>/`.
  A one-text GPU smoke validated the prep flow on Qwen3-0.6B in `/tmp`: the
  three fixed-sum partials merged to 84 MLP projection layers / 200,704
  channels, and WANDA wrote the expected `calibration_base_MXFP8_qwen0_6b_sweep.pt`.
- `scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh` is the current
  leave-it-running entry point for the full all-model sweep. It prepares
  smaller-model artifacts with per-model profiles, runs the full
  `mxfp8 fixed_sum wanda act` sweep with `SWEEP_TAG=full` and
  `STRICT_ARTIFACTS=1`, and writes
  `summary_full.tsv`, `summary_full.json`, and `final_status.txt` under
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_<RUN_ID>/`.
  Use `BACKGROUND=1 scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh`
  to detach it from the terminal/session. The wrapper defaults to
  `CONTINUE_ON_ERROR=1`, so independent later steps can still run after an
  individual failure; inspect the summary/status files for missing or failed
  rows.
- `scripts/prepare_qwen3_model_sweep_artifacts_parallel_4gpu.sh` is used by the
  unattended wrapper by default. It runs Qwen3-0.6B artifact prep on GPU 4 with
  batch/chunk profile `8 / 512 MiB / 128 MiB`, Qwen3-1.7B on GPU 5 with
  `4 / 384 MiB / 96 MiB`, and Qwen3-4B on GPU 6 with conservative
  `2 / 256 MiB / 64 MiB`. After artifact prep, the PPL phase uses all four
  GPUs 4-7 with full-replica window sharding. Set `ARTIFACT_PREP_MODE=serial`
  only if parallel artifact prep is too memory- or I/O-heavy.
- `scripts/summarize_qwen3_model_sweep.py` summarizes expected sweep outputs
  for a tag such as `full` into TSV/JSON with PPL, mean NLL, scored tokens,
  wall time, world size, visible CUDA devices, optional MSD stats columns, and
  missing/read-error status. The refreshed full-run summary with explicit
  blank stats columns is
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_20260528_155226/summary_full_with_stats_columns/summary_full.tsv`.
- The 2026-05-28 full unattended all-model sweep completed valid PPL outputs
  for Qwen3-0.6B, 1.7B, 4B, and 8B, but it did not collect
  `plot_norm_digit_read` or Figure 5 layer-cycle data. Use separate
  single-process `--msd-utilization-mode --figure5-layer-cycles` probes for
  that accounting.
- `scripts/run_qwen3_fixed_sum_norm_target_sweep.sh` and
  `scripts/summarize_fixed_sum_norm_sweep.py` are now available for fixed-sum
  low-SNR normalized-digit-read sweeps. The Qwen3-0.6B limit-120 probe
  completed SNR 17 and 18 dB:
  `../data/qwen3_final_experiments/fixed_sum_norm_sweep/logs/qwen_fixed_sum_norm_20260601_160336/summary_limit120/fixed_sum_norm_sweep_limit120.tsv`.
  SNR 17 dB gave PPL 23.7696 and `plot_norm_digit_read=0.485333`; SNR 18 dB
  gave PPL 22.8602 and `plot_norm_digit_read=0.5159`. Therefore SNR 17 dB is
  the conservative fixed-sum 50%-work point; run 17.5 dB only if an exact
  near-0.5 point is required. For larger models, probe SNR 17 dB first and add
  a 17/18 dB bracket only if normalized digit read drifts noticeably.
- The wrapper smoke path was validated with Qwen3-1.7B using
  `SMOKE=1 FORCE=1 RUN_STEPS="mxfp8 act" GPUS=4,5,6,7 NPROC=4
  LIMIT_SAMPLES=120 scripts/run_qwen3_final_ppl_4gpu.sh`. It completed MXFP8
  PPL 17.1189 and activation N:M PPL 24.4044 with 7,192 scored tokens.
- The refactored sweep path was also validated on Qwen3-1.7B with
  `SWEEP_MODE=1 MODEL_SPECS="qwen1_7b:../Qwen3-1.7B" FORCE=1 GPUS=4,5,6,7
  NPROC=4 LIMIT_SAMPLES=120 scripts/run_qwen3_final_ppl_4gpu.sh`; it completed
  the same MXFP8 and activation N:M prefix outputs under
  `../data/qwen3_final_experiments/model_sweep_4gpu/qwen1_7b/`.
- The default smaller-model prefix sweep was then validated with
  `SWEEP_MODE=1 GPUS=4,5,6,7 NPROC=4 scripts/run_qwen3_final_ppl_4gpu.sh`.
  It completed Qwen3-0.6B and Qwen3-4B and skipped the already-present
  Qwen3-1.7B outputs. Status:
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/sweep_20260528_144624/status.tsv`.
  Prefix PPLs were: Qwen3-0.6B MXFP8 21.2746 / activation 46.3333,
  Qwen3-1.7B MXFP8 17.1189 / activation 24.4044, and Qwen3-4B MXFP8 13.7939
  / activation 19.7649, each with 7,192 scored tokens.
- `tools/merge_msd_calibrations.py` is available to merge disjoint
  projection-filtered fixed-sum calibration JSONs into one PPL-ready
  calibration file.
- The same fixed-sum `--nproc 2` run with the default float16 persistent weight
  cache OOMed on rank 1. Use `--weight-cache-dtype float8` for Qwen3-8B MSD
  full-replica multi-GPU PPL unless a newer memory fix supersedes this.
- An unstaggered eight-worker MXFP8 launch on GPUs 0-7 failed before evaluation
  with rank-0 `SIGKILL` during model loading/materialization and produced no
  output JSON. Use `--load-stagger-sec 8` for Qwen3-8B eight-replica launches.
- WikiText-2 test tokenization is 299,078 tokens and 578 PPL forward windows
  at `MAX_LENGTH=4096`, `STRIDE=512`. Runtime estimates should scale from
  forward-window count, not from scored tokens, because almost all windows feed
  a full context while scoring only 512 new tokens.
- The tested sequential map used physical GPUs 4-7 as visible devices but
  placed layers on visible CUDA 0 and 1 only. It lowered per-GPU memory but did
  not improve wall time; the fixed-sum sharded prefix was 2111.13s versus
  1998.8s for the historical single-GPU prefix.

Next iteration:
1. Run the unattended full all-model sweep if that is the next priority:
   `BACKGROUND=1 scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh`.
   When it finishes, first inspect
   `../data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_<RUN_ID>/summary_full.tsv`
   and `final_status.txt`.
2. For the fixed-sum 50%-work result, do not reuse target-SNR 30 dB. Start
   larger-model accounting at SNR 17 dB with
   `scripts/run_qwen3_fixed_sum_norm_target_sweep.sh`, using
   `MODEL_SPECS` to select the model and `TARGET_SNRS="17"` unless drift
   requires a bracket.
3. Run the end-to-end four-GPU Qwen3-8B final PPL wrapper when ready:
   `GPUS=4,5,6,7 NPROC=4 scripts/run_qwen3_final_ppl_4gpu.sh`. It uses the
   suffixed WANDA mask and merged fixed-sum calibration file above.
4. Treat `--device-map sequential` as memory relief only unless `balanced` or
   manual placement shows direct-CUDA speedup over single-GPU and `--nproc`.
5. Remember that current `--nproc` disables MSD stats on nonzero ranks; use it
   for PPL quality and wall time, not as an aggregate work-stats source unless
   stats aggregation is added.
6. Keep `--device-map` single-process and separate from `--nproc`; use
   visible-device IDs in `--max-memory` after `--gpus` filtering.
7. For future fixed-sum calibration, use projection-filtered task parallel
   full-model jobs before considering model-sharded calibration. For Qwen3-8B,
   split down projections into bounded layer groups.
8. Use `model_execution_matrix.md` to keep model-specific tricks explicit:
   smaller models should not inherit Qwen3-8B-only float8 cache or load-stagger
   settings unless their own prefix validation shows they need them.
```

Do not add run logs here. Put measurements in `references/evidence_log.md` and
implementation history in `references/implementation_notes.md`.

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
- The same wrapper now has `SWEEP_MODE=1` for the smaller-model sweep over
  Qwen3-0.6B, Qwen3-1.7B, and Qwen3-4B. It defaults to `RUN_STEPS="mxfp8 act"`
  and `LIMIT_SAMPLES=120`, writes grouped outputs under
  `../data/qwen3_final_experiments/model_sweep_4gpu/<model_key>/`, and writes
  logs plus `status.tsv` under
  `../data/qwen3_final_experiments/model_sweep_4gpu/logs/sweep_<RUN_ID>/`.
  Missing fixed-sum or WANDA artifacts are recorded as
  `skipped_missing_artifact` unless `STRICT_ARTIFACTS=1`.
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
1. Run the smaller-model prefix sweep if that is the next priority:
   `SWEEP_MODE=1 GPUS=4,5,6,7 NPROC=4 scripts/run_qwen3_final_ppl_4gpu.sh`.
   The prefix has completed once; review the timestamped `status.tsv` and
   per-step logs before setting `LIMIT_SAMPLES=""` for a full sweep.
2. Run the end-to-end four-GPU Qwen3-8B final PPL wrapper when ready:
   `GPUS=4,5,6,7 NPROC=4 scripts/run_qwen3_final_ppl_4gpu.sh`. It uses the
   suffixed WANDA mask and merged fixed-sum calibration file above.
3. Treat `--device-map sequential` as memory relief only unless `balanced` or
   manual placement shows direct-CUDA speedup over single-GPU and `--nproc`.
4. Remember that current `--nproc` disables MSD stats on nonzero ranks; use it
   for PPL quality and wall time, not as an aggregate work-stats source unless
   stats aggregation is added.
5. Keep `--device-map` single-process and separate from `--nproc`; use
   visible-device IDs in `--max-memory` after `--gpus` filtering.
6. For future fixed-sum calibration, use projection-filtered task parallel
   full-model jobs before considering model-sharded calibration. For Qwen3-8B,
   split down projections into bounded layer groups.
7. Use `model_execution_matrix.md` to keep model-specific tricks explicit:
   smaller models should not inherit Qwen3-8B-only float8 cache or load-stagger
   settings unless their own prefix validation shows they need them.
```

Do not add run logs here. Put measurements in `references/evidence_log.md` and
implementation history in `references/implementation_notes.md`.

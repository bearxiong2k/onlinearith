# Active Qwen3 OOM/Performance Plan

This is the concise active plan. Historical measurements and implementation
details live under `docs/cim_oom_harness/reference/`.

## Done

- Exact output-chunked MX-only path is implemented.
- Compact/bounded MXFP weight cache is implemented.
- Native MXFP8 `float8` weight cache is implemented and validated exact against
  float32 cache output.
- PPL/probe controls are implemented:
  - `--stats {off,lite,full}`
  - `--mx-chunk-target-mib`
  - `--msd-chunk-target-mib`
  - `--weight-cache-dtype`
  - `--compile-msd-truncate`
  - `--msd-utilization-mode`
- Tail-logits chunked loss is implemented and tested.
- `use_cache=False` is forced for PPL.
- Early `--gpus` and allocator defaults are wired through the main and baseline
  runners.
- Fixed-sum calibration capture supports projection filtering and runtime
  controls.
- Runner parity is established for WANDA and activation N:M baselines.
- WANDA and activation N:M now use common keep-count notation.
- Single-setup runtime estimate table is tracked in
  `docs/experiments_time_estimates.md`.

## Current Work

1. Keep docs and harness clean:
   - always-read files stay short;
   - detailed evidence goes to `reference/evidence_log.md`;
   - detailed design/history goes to `reference/implementation_notes.md`;
   - live scripts/tests stay at repo root.
2. Use fixed-sum target-SNR 30 dB as the representative calibrated-MSD point
   for the single-setup estimate.
3. For equivalent sparsity/work comparisons, use Figure 4
   `plot_norm_digit_read = mean_effective_precision / 3.0`. Do not substitute
   `msd_perf_stats.global.global_utilization` for that axis.
4. Continue calibrated/uniform MSD runtime optimization without changing MSD
   math or PPL methodology.

## Paper-Critical Paths

Each path should stay runnable with comparable hygiene:

- MX-only baseline: `ppltest.py --setup 2`
- Uniform MSD: `ppltest.py --setup 6`
- Fixed-sum calibrated MSD:
  - `calibrate.py --optimizer fixed_sum --target-snr ...`
  - `ppltest.py --setup 6 --calibration <fixed_sum.json>`
- WANDA structured baseline:
  - `wanda_base/calibrate_base.py`
  - `wanda_base/ppl_batch_base.py`
- Runtime activation N:M:
  - `act_base/ppl_batch_base_act.py`

## Standard Commands

Direct CUDA check:

```bash
../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
```

MSD timing/utilization probe:

```bash
python ppltest.py --nproc 1 --setup 6 \
  --calibration <calibration_MXFP8_fixed_sum.json> \
  --msd-utilization-mode \
  --output <ppl_results_MXFP8_fix_time.json> \
  --gpus <id>
```

Qwen3-8B MXFP8 memory probe:

```bash
PYTHONPATH=../transformers/src \
CUDA_VISIBLE_DEVICES=<gpu> \
../.venv3_10/bin/python tools/probe_mxfp_memory.py \
  --model-path ../Qwen3-8B --setup 6 --seq-len 4096 --stats off \
  --mx-chunk-target-mib 256 --msd-chunk-target-mib 256 \
  --weight-cache-dtype float8 --compile-msd-truncate
```

Cheap contracts:

```bash
../.venv3_10/bin/python tests/test_msd_truncate_equivalence.py
../.venv3_10/bin/python tests/test_mx_exact_chunked.py
../.venv3_10/bin/python tests/test_mxfp_weight_cache_compact.py
../.venv3_10/bin/python tests/test_ppl_tail_logits_loss.py
../.venv3_10/bin/python tests/test_nm_keep_semantics.py
../.venv3_10/bin/python test_fixed_sum_optimizer.py
../.venv3_10/bin/python ppltest.py --list
../.venv3_10/bin/python ppl_batch.py --list
../.venv3_10/bin/python calibrate.py --list
```

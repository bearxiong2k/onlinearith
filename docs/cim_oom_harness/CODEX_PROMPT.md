# Codex Prompt: Qwen3 OOM/Performance Work

Work in:

```text
/home/xzj/coding/onlinearith
../transformers/src/transformers/models/qwen3/
```

## Hard Invariants

- Preserve PPL methodology: WikiText-2 raw test split, `MAX_LENGTH=4096`,
  `STRIDE=512`, masked context labels, and weighted NLL accumulation.
- Do not change dataset, tokenizer, labels, loss weighting, `MAX_LENGTH`, or
  `STRIDE` to avoid OOM.
- Do not use `ppltest.py --nproc 8` as an OOM fix. That replicates the full
  model per GPU and only shards windows.
- Do not introduce model sharding/device-map behavior until explicitly planned
  and validated.
- Keep fixed-sum calibrated MSD, uniform MSD, MX-only, WANDA, and activation N:M
  paths on comparable runner hygiene.
- Keep paper vocabulary precise: temporal significance scheduling, local
  execution windows on aligned contribution streams, metadata-first two-plane
  micro-tile with channel-parallel, block-serial execution.

## Runtime Rules

- Before Qwen3-8B probes, PPL, calibration, or timing comparisons, verify direct
  CUDA visibility:

```bash
../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
```

- Expected output on this machine is `True 8`. If it reports `False 0`, do not
  use that environment for GPU performance/OOM conclusions.
- Valid GPU progress evidence includes `cuda_alloc_gib`, `cuda_peak_*`, and
  should be visible in `nvtop`.
- Keep generated outputs, cache dirs, model weights, calibration dumps, plots,
  and benchmark JSON out of commits unless explicitly requested.

## Current Standard Modes

- MXFP8 Qwen3-8B memory runs: prefer `--weight-cache-dtype float8`.
- Non-MXFP8 or broad calibration capture: use `float16` or `none` as appropriate.
- MSD timing/utilization probe:

```bash
python ppltest.py --setup 6 --calibration <fixed_sum.json> \
  --msd-utilization-mode --output <ppl_results_MXFP8_fix_time.json>
```

- `--msd-utilization-mode` is the maintained 100-sample lite-stat probe. Add
  `--figure5-layer-cycles` only when debugging Figure 5 accounting.
- WANDA and activation N:M use common keep-count notation: `2:4` means keep two
  values per group of four.

## File Map

- Active concise plan: `docs/cim_oom_harness/CODEX_OOM_PERF_PLAN.md`
- Detailed measurements: `docs/cim_oom_harness/reference/evidence_log.md`
- Detailed implementation history: `docs/cim_oom_harness/reference/implementation_notes.md`
- Runtime estimates: `docs/experiments_time_estimates.md`
- Live probe: `tools/probe_mxfp_memory.py`
- Live ladder: `scripts/run_qwen8b_oom_ladder.sh`
- Live contract tests: `tests/`

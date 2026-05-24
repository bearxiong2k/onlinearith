# Codex Prompt: Qwen3 Final Experiments

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

## Experiment Conventions

- Representative MSD point: fixed-sum target-SNR 30 dB.
- MSD equivalent-work axis: `plot_norm_digit_read = mean_effective_precision / 3.0`.
- WANDA and activation N:M use common keep-count notation: `2:4` means keep two
  values per group of four.
- `ppltest.py --nproc` is data-parallel window sharding, not model sharding.
  It is valid for final PPL wall-time acceleration when each selected GPU can
  fit a full replica. Any model sharding must be opt-in and recorded in output
  metadata.
- `ppltest.py --device-map {auto,sequential,balanced}` is the explicit
  single-process model-sharding entry point. Do not combine it with `--nproc`.
  `--max-memory` uses visible CUDA device IDs after `--gpus` filtering.

## File Map

- Active plan: `docs/qwen3_final_experiments/active_plan.md`
- Runtime estimates: `docs/qwen3_final_experiments/runtime_estimates.md`
- Sharding prep: `docs/qwen3_final_experiments/references/multigpu_sharding_plan.md`
- Detailed measurements: `docs/qwen3_final_experiments/references/evidence_log.md`
- Implementation history: `docs/qwen3_final_experiments/references/implementation_notes.md`

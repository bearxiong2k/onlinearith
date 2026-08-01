# Functional-simulation rules

These instructions govern the frozen harness under `functional_sim/` and the
modified sibling Transformers implementation. The repository-wide `AGENTS.md`
only routes between workstreams.

## Status and scope

The functional simulation and its numerical evidence are frozen facts. Do not
edit their behavior, numerical semantics, configuration tables, or result
schemas for the hardware redesign. Read-only inspection, documented artifact
export, and the established list/smoke checks are allowed. Reopen this scope
only when the user explicitly asks.

Use the paper-level term **temporal significance scheduling**, the algorithmic
object **local execution windows on aligned contribution streams**, and the
primary work metric **executed-digit ratio**. Do not recast the method as
generic sparsity, quantization, pruning, or masking.

## Read order

1. `functional_sim/README.md` for ownership and commands
2. `functional_sim/docs/README.md` for the evidence/documentation index
3. The shortest relevant record under
   `functional_sim/docs/qwen3_final_experiments/`
4. Detailed `references/` material only when evidence or implementation
   history is necessary

## Authoritative external implementation

The numerical model lives under
`../transformers/src/transformers/models/qwen3/`:

- `modeling_qwen3.py`: current operational Qwen3 implementation.
- `configuration_qwen3.py`: custom MXFP/MSD fields.
- `calibration_msd.py`: calibration implementation imported by `calibrate.py`.
- `msd_perf_stats.py`: frozen performance-statistics accumulator.
- `modular_qwen3.py`: reference/modular source only. Do not edit or regenerate
  the operational model from it unless explicitly requested.

## PPL and calibration invariants

- Evaluation dataset: `wikitext`, `wikitext-2-raw-v1`, `test`.
- Calibration dataset: `wikitext`, `wikitext-2-raw-v1`, `validation`.
- `MAX_LENGTH = 4096`; `STRIDE = 512`.
- Context labels are `-100`.
- Accumulate `loss * trg_len` and divide by total scored tokens; never average
  window losses directly.
- `--limit-samples` marks a non-final smoke run.
- `--lite` may reduce statistics overhead but cannot change logits, labels,
  loss, or PPL.
- Do not alter MX quantization, MSD truncation, calibration, tokenizer, setup
  IDs, default filenames, or PPL-window semantics.
- `functional_sim/ppltest.py --nproc` is data-parallel window sharding with a full model per
  rank. Explicit model sharding uses single-process `--device-map` and cannot
  be combined with `--nproc`.
- For MSD equivalent-work comparisons, retain
  `plot_norm_digit_read = mean_effective_precision / 3.0`; runtime global
  utilization is not the paper's executed-digit metric.
- N:M uses keep-count notation: keep N values per group of M.

Keep script entry points, setup IDs, result/calibration schemas, default output
locations, and import names stable. Avoid absolute machine paths; resolve the
sibling source relative to the repository. Keep `local_files_only=True` unless
download behavior is explicitly requested.

## GPU evidence hygiene

Before any requested GPU performance, OOM, or timing run, verify direct CUDA:

```bash
../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
```

The expected machine result is `True 8`. Do not treat CPU fallback or logs
without `cuda_*` allocation fields as GPU evidence. Do not run full PPL or
full calibration by default.

## Frozen-boundary rules

- The current functional code forms quantized products and truncates product
  digits. Do not rewrite it to mimic the new standard-multiplier circuit.
- The existing statistics include `gate_proj`, `up_proj`, and `down_proj` and
  contain old stage-boundary fields. Preserve them as historical facts; do not
  reinterpret old `N_leaf_exec` as a standard-multiplier count.
- Any hardware adapter must live under `hardware_sim/`, identify exact frozen
  source fields, select projection-resolved gate/up evidence where available,
  and expose its own schema version.
- Do not change the sibling Transformers fork for an RTL or cost-model task.

## Verification

Run commands from the repository root. After layout or documentation changes,
check the canonical entry points:

```bash
../.venv3_10/bin/python functional_sim/ppltest.py --list
../.venv3_10/bin/python functional_sim/ppl_batch.py --list
../.venv3_10/bin/python functional_sim/calibrate.py --list
```

Only when explicitly relevant, add:

```bash
../.venv3_10/bin/python functional_sim/test_mxfp8linear.py
../.venv3_10/bin/python functional_sim/test_fixed_sum_optimizer.py
```

Do not run full PPL, calibration, or GPU probes merely to verify a repository
layout change.

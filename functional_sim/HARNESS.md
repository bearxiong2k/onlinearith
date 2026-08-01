# Functional harness map

Status: frozen compatibility surface
Working directory: repository root

The functional harness is logically owned by `functional_sim/` but remains
physically flat at the root to preserve established commands and imports. New
hardware code must not be added to any path listed below.

## Entry points

| Root path | Role |
|---|---|
| `ppltest.py` | Single-setup WikiText-2 PPL runner |
| `ppl_batch.py` | Batch PPL runner across setup IDs |
| `calibrate.py` | MXFP/MSD calibration driver |
| `calibrate_base.py` | Structured N:M baseline calibration |
| `benchmarktest.py`, `qwen3test.py` | Historical/diagnostic runners |

## Shared implementation

| Root path | Role |
|---|---|
| `experiment_config.py` | Setup IDs and configuration source of truth |
| `dist_utils.py` | Distributed launch and reduction helpers |
| `ppl_utils.py` | Sliding-window PPL helpers |
| `runtime_paths.py` | Local source/model path bootstrap |
| `ppl_batch_base.py` | Common baseline runner support |
| `wanda_base/`, `act_base/` | Frozen WANDA and activation N:M baselines |

## Analysis, orchestration, and validation

| Root path | Role |
|---|---|
| `perf_viz.py`, `calibration_viz.py`, `visualization.py` | Functional-result plotting and diagnostics |
| `scripts/` | Existing experiment orchestration and summaries |
| `tools/` | Functional probes, artifact utilities, and quality gate |
| `tests/` and root `test_*.py` | Functional contracts and lightweight validation |

## External implementation boundary

The numerical kernels and statistics hooks live in the sibling Transformers
fork, normally under:

```text
../transformers/src/transformers/models/qwen3/
```

`modeling_qwen3.py` is authoritative. `modular_qwen3.py` is reference-only.
Neither file is part of the hardware-simulation implementation surface.

## Compatibility policy

- Keep all root command names, setup IDs, default outputs, JSON schemas, and
  import names stable.
- Run the root commands from the root; do not invent a second copy beneath
  `functional_sim/`.
- Read-only exports may translate frozen results into a documented hardware
  input artifact. They must not change the functional simulator or call the
  translation a new numerical oracle.
- Hardware tests, traces, ledgers, reports, and generated files belong under
  `hardware_sim/`.

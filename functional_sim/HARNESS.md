# Functional harness map

Status: frozen canonical subtree with root compatibility links
Working directory for established workflows: repository root

`functional_sim/` owns every functional-simulation implementation file. The
repository root contains symlinks for the former flat paths so existing
commands, imports, and orchestration continue to work without maintaining a
second copy.

## Canonical entry points

| Canonical path | Role |
|---|---|
| `functional_sim/ppltest.py` | Single-setup WikiText-2 PPL runner |
| `functional_sim/ppl_batch.py` | Batch PPL runner across setup IDs |
| `functional_sim/calibrate.py` | MXFP/MSD calibration driver |
| `functional_sim/calibrate_base.py` | Structured N:M baseline calibration |
| `functional_sim/benchmarktest.py`, `functional_sim/qwen3test.py` | Historical/diagnostic runners |

## Shared implementation

| Canonical path | Role |
|---|---|
| `functional_sim/experiment_config.py` | Setup IDs and configuration source of truth |
| `functional_sim/dist_utils.py` | Distributed launch and reduction helpers |
| `functional_sim/ppl_utils.py` | Sliding-window PPL helpers |
| `functional_sim/runtime_paths.py` | Functional/repository/workspace path boundary |
| `functional_sim/ppl_batch_base.py` | Common baseline runner support |
| `functional_sim/wanda_base/`, `functional_sim/act_base/` | Frozen WANDA and activation N:M baselines |

## Analysis, orchestration, and validation

| Canonical path | Role |
|---|---|
| `functional_sim/perf_viz.py`, `functional_sim/calibration_viz.py`, `functional_sim/visualization.py` | Result plotting and diagnostics |
| `functional_sim/scripts/` | Experiment orchestration and summaries |
| `functional_sim/tools/` | Functional probes, artifact utilities, and quality gate |
| `functional_sim/tests/` and `functional_sim/test_*.py` | Contracts and lightweight validation |

## Root compatibility surface

Every former root Python filename is a relative symlink to its canonical file.
The former `act_base`, `wanda_base`, `scripts`, `tools`, and `tests`
directories are relative symlinks to their canonical directories. Therefore:

```text
python ppltest.py --list
python functional_sim/ppltest.py --list
```

execute the same source. New documentation and internal orchestration should
prefer canonical `functional_sim/...` paths; old external commands may keep
using the root links.

`pytest.ini` points default discovery at `functional_sim/tests/` (and future
hardware tests), so root symlinks do not cause duplicate collection. The
historical `functional_sim/test_*.py` programs remain explicit standalone
checks rather than default pytest inputs.

## External implementation boundary

The numerical kernels and statistics hooks live in the sibling Transformers
fork, normally under:

```text
../transformers/src/transformers/models/qwen3/
```

`modeling_qwen3.py` is authoritative. `modular_qwen3.py` is reference-only.
Neither file is part of the hardware-simulation implementation surface.

## Compatibility policy

- Keep root symlink names, setup IDs, default output locations, JSON schemas,
  import names, and repository-root working-directory behavior stable.
- Do not replace a root symlink with a second implementation file.
- Canonical scripts must resolve `functional_sim/`, the repository root, and
  the parent workspace explicitly; they must not rely on symlink traversal.
- Read-only exports may translate frozen results into a documented hardware
  input artifact. They must not change the functional simulator or call the
  translation a new numerical oracle.
- Hardware tests, traces, ledgers, reports, and generated files belong under
  `hardware_sim/`.

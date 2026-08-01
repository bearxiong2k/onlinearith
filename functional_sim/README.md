# Frozen functional simulation

This directory is the physical and logical home of the existing numerical
simulation work. It contains the runners, shared Python modules, scripts,
tools, tests, baselines, documentation, and committed evidence. There are no
root-level wrappers or aliases; all current commands name this directory.

Nothing in the hardware reorganization changes the meaning of the recorded
functional results. The frozen simulator still evaluates MXFP/MSD Qwen3
models, calibrates local execution-window budgets, records executed-digit
statistics, and compares dense and structured-sparsity baselines.

## Start here

- [Functional working rules](AGENTS.md)
- [Documentation index](docs/README.md)
- [Committed smoke-run evidence](evidence/README.md)

## Harness map

| Path | Role |
|---|---|
| `ppltest.py` | Single-setup WikiText-2 PPL runner |
| `ppl_batch.py` | Batch PPL runner across setup IDs |
| `calibrate.py` | MXFP/MSD calibration driver |
| `calibrate_base.py` | Structured N:M baseline calibration |
| `experiment_config.py` | Setup IDs and configuration source of truth |
| `dist_utils.py`, `ppl_utils.py` | Distributed and sliding-window helpers |
| `wanda_base/`, `act_base/` | Frozen WANDA and activation N:M baselines |
| `scripts/`, `tools/` | Experiment orchestration, summaries, probes, and quality gates |
| `tests/`, `test_*.py` | Contract tests and standalone validation programs |
| `docs/`, `evidence/` | Frozen workflow documentation and committed evidence |

## Commands

Run from the repository root so historical relative model, data, and output
defaults retain their meaning:

```bash
../.venv3_10/bin/python functional_sim/ppltest.py --list
../.venv3_10/bin/python functional_sim/ppl_batch.py --list
../.venv3_10/bin/python functional_sim/calibrate.py --list
```

Use the same prefix for baselines, scripts, tools, and standalone checks:

```bash
../.venv3_10/bin/python functional_sim/wanda_base/ppl_batch_base.py --list
bash functional_sim/scripts/run_repo_quality_gate.sh
../.venv3_10/bin/python functional_sim/test_fixed_sum_optimizer.py
```

Records under `docs/qwen3_final_experiments/references/` may preserve commands
exactly as executed before this relocation. They are provenance, not current
invocation instructions.

The implementation in
`../transformers/src/transformers/models/qwen3/modeling_qwen3.py` remains the
authoritative numerical model. This workstream is frozen unless the user
explicitly asks to reopen it.

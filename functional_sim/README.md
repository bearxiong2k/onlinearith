# Frozen functional simulation

This directory is the portal for the existing numerical simulation work. The
executable harness intentionally remains at the repository root because its
entry points, imports, launch scripts, result names, and sibling-Transformers
paths form a mature compatibility surface.

Nothing in the hardware reorganization changes the meaning of the recorded
functional results. The frozen simulator still evaluates MXFP/MSD Qwen3
models, calibrates local execution-window budgets, records executed-digit
statistics, and compares dense and structured-sparsity baselines.

## Start here

- [Functional working rules](AGENTS.md)
- [Harness and ownership map](HARNESS.md)
- [Documentation index](docs/README.md)
- [Committed smoke-run evidence](evidence/README.md)

## Stable commands

Run these from the repository root:

```bash
../.venv3_10/bin/python ppltest.py --list
../.venv3_10/bin/python ppl_batch.py --list
../.venv3_10/bin/python calibrate.py --list
```

The implementation in
`../transformers/src/transformers/models/qwen3/modeling_qwen3.py` remains the
authoritative numerical model. This workstream is frozen unless the user
explicitly asks to reopen it.


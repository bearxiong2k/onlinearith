# Temporal significance scheduling simulation workspace

This repository now hosts two deliberately separate parts of the same paper:

1. a frozen functional-simulation harness for calibration, PPL, executed-digit
   statistics, and baseline analysis; and
2. an active hardware-simulation workspace for the redesigned stage-1
   datapath, trace translation, RTL verification, synthesis, and cost
   accounting.

The separation is an evidence boundary as well as a directory boundary.
Frozen numerical results remain valid under their recorded semantics. New
hardware results will use a standard fixed-point multiplier over a scheduled
target activation mantissa and an offline-aligned fixed-point weight element;
they must not reuse costs from the superseded serial digit-stream or stage-2
interface design.

## Repository map

| Path | Purpose | Status |
|---|---|---|
| Root functional names | Compatibility symlinks preserving the original commands and imports | Frozen |
| [`functional_sim/`](functional_sim/README.md) | Canonical functional source, runners, scripts, tools, tests, docs, and evidence | Frozen |
| [`hardware_sim/`](hardware_sim/README.md) | RTL/general-simulation harness and hardware documentation | Active |
| [`docs/paper/`](docs/paper/README.md) | Paper-wide revision guidance | Active |
| [`docs/archive/`](docs/archive/README.md) | Superseded paper and architecture planning | Historical |

## Functional compatibility commands

Run the established commands from the repository root exactly as before:

```bash
../.venv3_10/bin/python ppltest.py --list
../.venv3_10/bin/python ppl_batch.py --list
../.venv3_10/bin/python calibrate.py --list
```

The equivalent canonical commands use `functional_sim/ppltest.py`,
`functional_sim/ppl_batch.py`, and `functional_sim/calibrate.py`. The root
names are symlinks so there is only one maintained implementation.

Root `pytest` discovery is constrained by `pytest.ini` to
`functional_sim/tests` and future `hardware_sim/tests`, avoiding duplicate
collection through compatibility symlinks. The three historical root
`test_*.py` programs remain explicit standalone checks.

The modified Qwen3 model remains in the sibling checkout at
`../transformers/src/transformers/models/qwen3/`. No model, calibration, PPL,
or result-schema behavior changed as part of this relocation.

## Hardware starting point

Start with:

- [`hardware_sim/docs/architecture_contract.md`](hardware_sim/docs/architecture_contract.md)
- [`hardware_sim/docs/evidence_contract.md`](hardware_sim/docs/evidence_contract.md)
- [`hardware_sim/docs/development_plan.md`](hardware_sim/docs/development_plan.md)

The hardware directories intentionally contain documentation and harness
boundaries before implementation. Operand formats and the schedule-to-multiply
translation must be frozen before active RTL or circuit-reference code is
added.

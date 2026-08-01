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
| [`functional_sim/`](functional_sim/README.md) | Canonical functional source, runners, scripts, tools, tests, docs, and evidence | Frozen |
| [`hardware_sim/`](hardware_sim/README.md) | RTL/general-simulation harness and hardware documentation | Active |
| [`docs/paper/`](docs/paper/README.md) | Paper-wide revision guidance | Active |
| [`docs/archive/`](docs/archive/README.md) | Superseded paper and architecture planning | Historical |

## Functional commands

Run functional commands from the repository root through their owning
subdirectory:

```bash
../.venv3_10/bin/python functional_sim/ppltest.py --list
../.venv3_10/bin/python functional_sim/ppl_batch.py --list
../.venv3_10/bin/python functional_sim/calibrate.py --list
```

Root `pytest` discovery is constrained by `pytest.ini` to
`functional_sim/tests` and `hardware_sim/tests`. The standalone
`functional_sim/test_*.py` programs remain explicit checks rather than default
pytest inputs. Root-level aliases are intentionally not maintained.

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

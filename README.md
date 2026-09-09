# Temporal significance scheduling research and writing workspace

The writing-stage entry point is
[`docs/paper/README.md`](docs/paper/README.md). It connects the ICCAD
manuscript, reviewer feedback, curated figures and numerical evidence, and the
separately archived hardware delivery. The next venue (DATE or ISCAS) is still
undecided; no new conference template has been selected.

The [current writing direction](docs/paper/current_revision_plan.md) prioritizes
larger-model evidence in Figure 4, GPU attention/non-FFN end-to-end performance,
whole-chip area and energy overhead, and the newly supplied layout figure.
Other figure changes stay focused on what those additions require.

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
| [`TSS_ICCAD/`](TSS_ICCAD/README.md) | Original manuscript source, bibliography, and seven figures | Preserved writing baseline |
| [`functional_sim/`](functional_sim/README.md) | Canonical functional source, runners, scripts, tools, tests, docs, and evidence | Frozen |
| [`hardware_sim/`](hardware_sim/README.md) | RTL/general-simulation harness and hardware documentation | Active |
| [`docs/paper/`](docs/paper/README.md) | Author-directed revision plan, source audits, review history, figure assets, and curated evidence | Active |
| [`hardware_sim/reference/tss_delivery_20260909/`](hardware_sim/reference/tss_delivery_20260909/README.md) | Imported conventional-multiplier presentation prototype and supplied reports | Reference only; distinct arithmetic |
| [`hardware_sim/reference/layout_20260909/`](hardware_sim/reference/layout_20260909/README.md) | Newly supplied layout figure and provenance | Paper figure; design/report association to record |
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

The September `TSS` delivery is available locally as a reference snapshot.
It does not close the active design's M2 gate: its arithmetic and scheduling
differ from the frozen M1 contract. Its supplied reports are mapped/pre-route;
the original delivered files do not include a layout. The author subsequently
added [a layout image](hardware_sim/reference/layout_20260909/README.md), now
included in the paper plan. See the
[delivery audit](hardware_sim/docs/reference/tss_delivery_audit.md) for the
scope of the earlier reports.

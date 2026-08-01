# Hardware-simulation working rules

These instructions apply to every path under `hardware_sim/`.

## Method and scope

Use the paper-level term **temporal significance scheduling**. Its algorithmic
object is a **local execution window on an aligned contribution stream**. The
primary frozen algorithmic work metric is **executed-digit ratio**.

The active hardware realization is a stage-1-only design with:

- runtime formation of a scheduled target activation mantissa;
- an offline-aligned, fixed-point representation for each weight element;
- a standard fixed-point multiplier;
- reduction/accumulation and only the metadata/control/storage needed by that
  stage-1 path.

Do not introduce a runtime stream of recoded weight digits. Do not add a custom
stage-2 `down_proj` engine, stage-1/stage-2 packet interface, packetizer,
boundary header, payload FIFO, or shard queue. `down_proj` may appear only as a
common baseline term when an explicitly end-to-end FFN comparison requires it.

## Required read order

Before implementation, read completely:

1. `docs/architecture_contract.md`
2. `docs/evidence_contract.md`
3. `docs/development_plan.md`
4. `docs/decision_log.md`

Read `docs/reference/transition_audit.md` and `reference/` only for legacy
provenance or extraction work. Never infer the active design from legacy RTL.

## Frozen functional boundary

- Functional source under `functional_sim/` and the sibling Transformers model
  are read-only inputs. Do not modify them from a hardware task.
- Existing calibration, PPL, baseline, and executed-digit results retain their
  original meanings and provenance.
- A read-only trace adapter may consume explicit frozen fields. It is not a new
  functional oracle and must not alter or reinterpret the source artifact.
- Prefer projection-resolved `gate_proj`/`up_proj` inputs. Do not reconstruct a
  stage-1 ledger by evenly splitting an aggregate that also includes
  `down_proj`.
- Old `N_leaf_exec`, boundary words, bursts, queue events, and packet fields are
  legacy schema fields. They cannot be renamed into new circuit events.

## Evidence rules

Every reported quantity must carry one of these source statuses:

- `trace`: counted from a versioned transaction/ledger;
- `rtl_sim`: observed in functional RTL simulation;
- `mapped`: produced by technology-mapped synthesis or timing reports;
- `formula`: calculated from documented measured inputs;
- `proxy`: analytic activity/capacitance approximation;
- `assumption`: selected design parameter;
- `pending`: not yet measured.

Never collapse these labels in report aggregation. Icarus functional
simulation is not timing or power signoff. A Yosys/ABC mapped result is not a
post-layout result. VCD generation alone does not make an energy number
measured.

Executed-digit ratio remains the frozen algorithmic metric. Separately count
activation-target formation, activation reads, aligned-weight reads, standard
multiplier issues, reduction work, accumulation work, cycles, and storage
accesses. Any equation mapping executed digits to hardware events must be
versioned and explicit.

## Directory and dependency rules

- Put synthesizable active RTL only in `rtl/`.
- Put Python reference/trace/ledger code only in `sim/`.
- Put deterministic, small fixtures in `fixtures/`; include source and schema
  metadata.
- Put generated netlists, logs, VCD/FST files, synthesis reports, and local
  ledgers in `artifacts/`; do not commit them by default.
- `reference/legacy_candidates/` is provenance-only and excluded from active
  source lists.
- Active code must not import or read `../anchors` or `../rebuttal` at runtime.
- The cleared Nangate files under `tech/nangate45/` may be used inside this
  personal-research project. Preserve their headers and record the process,
  voltage, temperature, tool version, and exact file checksum in reports.
- Avoid absolute machine paths. Resolve repository paths from the script file
  or an explicit CLI argument.

## Local environment

Run Python commands from the repository root with
`../.venv3_10/bin/python` unless a hardware-specific environment is introduced
and documented later. The audited command-line tools on this machine are
Icarus Verilog 11.0 and Yosys 0.63+184 (`240439bdb`), with ABC invoked through
Yosys. Capture the versions again in every durable characterization manifest;
do not assume the audit version from documentation alone.

Hardware tests must not require CUDA. Do not launch model evaluation,
calibration, or dataset downloads from the hardware harness.

## Contract-first implementation

Do not add the active multiplier/reference kernel until all `OPEN-*` items in
`docs/architecture_contract.md` that affect arithmetic are resolved. Do not
emit a v2 ledger until its schema and projection boundary are frozen. Record
new decisions in `docs/decision_log.md`; update the contract rather than
leaving architectural truth only in code comments.

## Verification expectations

Each implementation phase should add the cheapest relevant checks:

- Python unit tests for encodings, saturation, rounding, and event counts;
- Icarus smoke tests for reset, handshake, corner operands, and back-to-back
  transactions;
- exact Python/RTL result and event parity on tiny fixtures;
- generic and Nangate-mapped Yosys/ABC synthesis with tool/version capture;
- report-schema tests that preserve source-status labels and provenance.

Do not run full PPL or calibration to verify hardware code. Use frozen small
fixtures and read-only exported summaries.

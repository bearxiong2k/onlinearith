# Hardware simulation

Status: active workspace; documentation and harness boundaries initialized
Numerical source: frozen functional evidence from this repository and the
sibling Transformers fork

This directory owns all new work for the redesigned hardware realization of
temporal significance scheduling. The custom scope is stage 1 only. Each
scheduled target activation mantissa is multiplied by an offline-aligned
fixed-point weight element using a standard fixed-point multiplier, followed
by the applicable reduction and accumulation path.

There is no custom stage-2 `down_proj` consumer, stage boundary, packetizer,
payload FIFO, or shard queue in this design.

## Read first

1. [Architecture contract](docs/architecture_contract.md)
2. [Evidence contract](docs/evidence_contract.md)
3. [Development plan](docs/development_plan.md)
4. [Decision log](docs/decision_log.md)

Use the [transition audit](docs/reference/transition_audit.md) only when
provenance or the old architecture is relevant. It is deliberately outside
the always-read set.

## Harness layout

| Path | Intended contents |
|---|---|
| `sim/` | Python circuit reference, frozen-trace adapter, and event-ledger generation |
| `rtl/` | Active synthesizable SystemVerilog only |
| `tests/` | Unit, RTL smoke, and Python/RTL co-simulation tests |
| `fixtures/` | Small, reviewable transactions with source provenance |
| `configs/` | Versioned architecture and characterization configurations |
| `scripts/` | Reproducible Icarus/Yosys/ABC orchestration and report generation |
| `tech/` | Cleared local technology references and provenance |
| `artifacts/` | Generated local outputs; ignored except for its policy README |
| `reference/` | Extracted legacy candidates, excluded from active filelists |

The empty implementation areas are intentional. First freeze operand widths,
offline alignment, the schedule-to-target-mantissa mapping, and ledger schema;
then add code in the phase order documented in `docs/development_plan.md`.

## Independence rule

Active scripts and tests must run without `../anchors` or `../rebuttal` being
present. Those repositories remain historical provenance. Exact legacy files
that may help a port are quarantined under `reference/` and are not active
hardware source.

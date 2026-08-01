# Hardware decision log

Status: active
Format: append durable decisions; amend with a new entry rather than erasing
the reason for an older choice

## Locked decisions

### HW-D001 — Separate functional and hardware workstreams

Date: 2026-08-01
Status: superseded in command-surface detail by HW-D009; the workstream split
remains in force
Decision: keep canonical functional source under `functional_sim/`, preserve
the old root command surface with symlinks, and place all new hardware work
under `hardware_sim/`. Functional and hardware evidence meet only through a
versioned read-only translation/reporting boundary.
Reason: the numerical simulator and redesigned circuit have genuinely
different semantics, dependencies, tests, and evidence levels.

### HW-D002 — Preserve frozen numerical evidence

Date: 2026-08-01
Decision: do not edit the `onlinearith` functional simulator or modified
Transformers implementation for the redesign. Calibration, PPL, baseline, and
executed-digit results remain facts under their recorded provenance.
Reason: the redesign changes downstream hardware realization, not the accepted
numerical experiment record.

### HW-D003 — Stage-1-only custom scope

Date: 2026-08-01
Decision: remove the custom stage-2 `down_proj` consumer and all stage-boundary
packet/payload/queue hardware from the active architecture.
Reason: the revised paper hardware no longer requires that interface.

### HW-D004 — Standard multiplier leaf

Date: 2026-08-01
Decision: use a standard fixed-point multiplier whose operands are a runtime
target activation mantissa and an offline-aligned fixed-point weight element.
There is no runtime recoded weight-digit stream.
Reason: this is the revised target hardware realization.

### HW-D005 — Keep executed-digit ratio distinct

Date: 2026-08-01
Decision: retain executed-digit ratio and
`mean_effective_precision / 3.0` as frozen algorithmic/work evidence. Count
new circuit reads, issues, cycles, and energy separately.
Reason: a standard multiplier issue is not semantically identical to an old
executed product digit.

### HW-D006 — Legacy repositories are provenance only

Date: 2026-08-01
Decision: active hardware code has no runtime dependency on `../anchors` or
`../rebuttal`. Small exact candidates may be copied into a quarantined
reference directory with origin metadata.
Reason: the old repositories encode superseded architecture and must not
silently control new results.

### HW-D007 — Preserve evidence-strength labels

Date: 2026-08-01
Decision: distinguish `trace`, `rtl_sim`, `mapped`, `formula`, `proxy`,
`assumption`, `pending`, and `unusable` throughout ledgers and reports.
Reason: old rebuttal work demonstrated that aggregation can otherwise overstate
what was measured.

### HW-D008 — Nangate source is cleared for this project

Date: 2026-08-01
Decision: reuse the existing local Nangate cell files within this same
personal-research project, preserving file headers and provenance. No new
license review is required for the reorganization.
Reason: the license check was completed in the prior project edit.

### HW-D009 — Use canonical nested functional commands only

Date: 2026-08-01
Decision: remove the temporary root compatibility symlinks. Functional code,
tests, tools, scripts, and baselines live only under `functional_sim/`, and all
current commands use that prefix from the repository root.
Reason: one explicit command surface keeps the repository root and future
hardware-development context clean without maintaining layout aliases.

## Open decisions

The authoritative blocking list is `OPEN-ARCH-001` through `OPEN-ARCH-008` in
`architecture_contract.md`. Resolve each with a new `HW-Dxxx` entry that gives
the exact equation/encoding, alternatives considered, affected schema fields,
and verification example.

Nonblocking evaluation choices that will also need records:

- target clock and parameter sweep policy;
- energy-characterization method;
- stage-1 versus FFN/model end-to-end reporting boundary;
- model-scale trace sampling and completeness criteria;
- artifact snapshot/retention policy for paper submission.

## Retired assumptions

The following are not open alternatives and must not return without an
explicit architecture-change decision:

- serial activation-digit × weight-digit leaf execution;
- Anchor-2 area, drain, latency, or energy coefficients;
- Anchor-3 packetizer, payload, FIFO, or queue replay;
- Anchor-4 completion/payload storage and old 80,032-bit total;
- v1 even-split gate/up ledgers derived from an 84-projection aggregate;
- old 4.253% decode and 8.014% prefill hybrid gains.

# Legacy source and extraction map

Status: reference only
Audit/extraction date: 2026-08-01

This map records where reusable methods and quarantined source candidates came
from. Active hardware code must not depend on the sibling repositories.

## Audited revisions

| Repository | Revision | Historical role |
|---|---:|---|
| `onlinearith` functional code | `2d07c53` | calibration, PPL, baselines, executed-digit analysis |
| `../transformers` | `3910a1596f` | authoritative numerical kernel and statistics |
| `../anchors` | `5959bb8370605710abc8200d404cc1dfee682aff` | old A0–A4 RTL and characterization |
| `../rebuttal` | `e13339c` | old ledger, cost model, artifacts, and rebuttal prose |

## Exact extracted RTL candidates

`hardware_sim/reference/legacy_candidates/anchors_5959bb8/` contains
byte-for-byte copies from the audited Anchor revision:

- Anchor 0 prepass RTL, smoke test, and generic/Liberty Yosys templates;
- Anchor 1 schedule/config RTL, smoke test, and Yosys templates;
- Anchor 4 generic synchronous RAM, horizon store, raw-exponent shadow RAM,
  and delay bank.

These are deliberately outside `hardware_sim/rtl/`. Their equations, ports,
config words, file paths, and test expectations describe the old design until
reviewed. In particular:

- Anchor 0 survives only if runtime weight metadata and `D` are unchanged;
- Anchor 1 survives only after `L` is defined for target mantissa formation;
- the old config word and counters are not active fields;
- storage modules are candidates, not an accepted bit inventory.

The extracted directory includes a `SHA256SUMS` manifest for all 25 candidate
files.

When reusing one, copy or rewrite it into active `rtl/`, cite the original path
and revision in the new file, replace stale semantics, and add a new active
test. Never compile this reference directory directly.

## Technology extraction

The Nangate files were copied byte-for-byte from
`../anchors/tech_lib/` at the audited revision into
`hardware_sim/tech/nangate45/`:

| File | SHA-256 |
|---|---|
| `stdcells.lib` | `0f936d453c0a26809975b1226cef893a02d26c6f4c3477b4acd6e9b09ec8a148` |
| `stdcells.v` | `05eefccd076e3ee557d61cf6187b162b3a05a5c6438b48a6c7cb59a270274679` |

Their original headers are unchanged. Project use was already cleared for this
same personal-research project.

## Reusable methodology not copied as active code

From `../rebuttal/e2e_cost_model/`:

- strict versioned input loaders;
- JSON-first canonical ledgers with derived CSV/Markdown views;
- component-level source-status labels;
- artifact manifests and checksums;
- unit tests for formulas, completeness, and provenance propagation.

The old package is not copied because its data model deeply embeds Anchor 2,
Anchor 3, stage 2, payloads, and v1 formulas. Reimplement only these generic
patterns against ledger v2.

## Explicit exclusions

- all Anchor-2 leaf/tree/netlist/results and energy coefficients;
- all Anchor-3 source, traces, packetization, queues, and characterization;
- Anchor-4 completion metadata, payload FIFO, old window-config store, top,
  and reported total area/bit count;
- generated build/netlist/report/result trees and the raw boundary CSV;
- v0–v4 rebuttal configs/results as active configuration;
- prose asserting serial weight digits, stage 2, or reduced payloads;
- machine-specific paths.

The full rationale and original source-path table remain in
[`transition_audit.md`](transition_audit.md).

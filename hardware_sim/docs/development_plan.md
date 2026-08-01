# Hardware simulation development plan

Status: **phase 0 complete; phase 1 next**
Last updated: 2026-08-01

The plan keeps architecture decisions, numerical translation, circuit
correctness, and cost characterization as separate gates. Full model PPL is
not part of hardware verification.

## Phase 0 — repository and provenance boundary

Deliverables:

- separate `functional_sim/` and `hardware_sim/` portals;
- canonical nested functional command surface documented;
- hardware-specific AGENT and documentation system;
- audited transition report and legacy source map;
- local cleared technology files with source/checksum metadata;
- ignored generated-artifact boundary.

Exit condition: canonical functional list commands pass; former root aliases
are absent; no functional or Transformers simulation behavior changed; no
active hardware dependency on `../anchors` or `../rebuttal`.

## Phase 1 — freeze arithmetic and transaction contracts

Resolve every arithmetic-blocking `OPEN-ARCH-*` item in
`architecture_contract.md`.

Deliverables:

- exact activation and weight encodings, binary points, widths, and examples;
- offline weight-alignment equation and file format;
- exact mapping from frozen window fields to target activation mantissa;
- product/reduction/accumulation rounding and saturation rules;
- tiny transaction schema;
- event-ledger v2 JSON schema and one hand-written fixture.

Exit condition: independent readers can calculate every expected result and
event count in the fixture without inspecting code.

## Phase 2 — circuit reference and frozen-trace adapter

Add under `sim/`:

- a bit-exact fixed-point reference;
- offline weight encoder;
- target activation-mantissa former;
- stage-1 reduction/accumulation reference;
- versioned event-ledger writer;
- read-only adapter for projection-resolved frozen inputs.

Add unit tests for sign extremes, zeros, killed windows, saturation, rounding,
block boundaries, and schema failures.

Exit condition: deterministic tiny fixtures produce reviewed results and
ledger counts; the adapter records source checksum/revision and refuses
invalid aggregate projection scope.

## Phase 3 — active RTL microblocks

Add only reviewed, active modules under `rtl/`:

1. standard fixed-point multiplier wrapper at the frozen widths;
2. target activation-mantissa/control path;
3. selected metadata/window logic after semantic review;
4. selected storage primitives;
5. reduction/accumulation datapath;
6. a small integration top for one transaction boundary.

Legacy candidates under `reference/` must be ported explicitly; do not add
that directory to an active filelist.

Exit condition: Icarus smoke tests cover reset, corner operands, kill behavior,
back-to-back inputs, and pipeline handshakes.

## Phase 4 — Python/RTL co-simulation

For every tiny fixture, compare:

- accepted transaction order;
- element products;
- accumulated outputs;
- target formation, read, multiplier, reduction, accumulation, metadata, and
  cycle counters.

Exit condition: bit-exact result and event parity with no ignored mismatches.

## Phase 5 — synthesis and characterization

Create reproducible scripts for:

- generic Yosys synthesis;
- Nangate-mapped Yosys/ABC synthesis;
- module-level area/timing reports;
- parameter sweeps for only the frozen design space;
- tool/config/source checksum capture.

Energy must use a newly selected and documented method. If it remains an
analytic proxy, label it `proxy`; VCD generation alone is insufficient.

Exit condition: multiplier, target formation/control, reduction, and retained
storage have fresh results; no Anchor-2/3 coefficient or old total is reused.

## Phase 6 — model-scale ledger and reporting

Scale the verified transaction model using projection-resolved frozen facts.
Generate versioned JSON first, then CSV/Markdown views. Join frozen quality/
executed-digit evidence only at the reporting layer with both provenances.

Exit condition:

- stage-1-only ledger is complete for the declared sample/model scope;
- full-versus-sampled scope is explicit;
- source statuses survive aggregation;
- any FFN/model end-to-end equation shows common terms and assumptions;
- no stage-2 interface, payload, queue, or old hybrid-gain term remains.

## Working discipline

- Keep fixtures small and checked in; keep generated runs under `artifacts/`.
- Add one command per reproducible flow under `scripts/` and document its
  outputs.
- Prefer JSON as the canonical machine-readable record; derive CSV/Markdown.
- Record every design/config/schema change in `decision_log.md`.
- Do not skip directly from symbolic architecture to model-scale cost claims.

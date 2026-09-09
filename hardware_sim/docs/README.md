# Hardware documentation index

The always-read set is intentionally small. It defines the active design and
evidence boundary without loading the superseded rebuttal architecture into
working context.

## Always read

1. [Architecture contract](architecture_contract.md): active scope, corrected
   frozen M1 arithmetic, binding decisions, and unresolved M2
   microarchitecture.
2. [Evidence contract](evidence_contract.md): frozen inputs, provenance labels,
   trace translation, and event-ledger v2 boundary.
3. [Development plan](development_plan.md): architecture freeze, RTL maturity,
   synthesis closure, design-freeze release, and layout-handoff gates.
4. [Decision log](decision_log.md): durable locked decisions and open items.

## Read only when needed

- [September TSS delivery audit](reference/tss_delivery_audit.md): imported
  presentation-prototype RTL and mapped/pre-route reports, missing layout and
  replay inputs, and differences from active M1. This reference does not close
  the active architecture gates.
- [Transition audit](reference/transition_audit.md): full audit of
  `onlinearith`, Transformers, `../anchors`, and `../rebuttal` at the redesign
  boundary.
- [Legacy source map](reference/legacy_source_map.md): exact source revisions,
  extracted candidates, exclusions, and technology-file provenance.

## Documentation policy

- Keep the four always-read files concise and current.
- Put measurements, long tool logs, generated ledgers, and characterization
  reports under ignored `hardware_sim/artifacts/`, with a checked-in manifest
  only when a durable evidence snapshot is explicitly requested.
- Append architectural decisions to `decision_log.md`; do not let a stale
  legacy README become an active specification.
- Use explicit statuses: `draft`, `frozen`, `implemented`, `verified`, or
  `retired`.
- Link every hardware claim to a configuration, tool version, source status,
  and artifact checksum where applicable.

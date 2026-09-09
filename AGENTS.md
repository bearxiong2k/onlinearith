# Repository guide

This repository contains two simulation workstreams for the same temporal
significance scheduling paper. Keep their code, evidence, and terminology
separate.

## Workstream routing

- **Paper writing:** begin with `docs/paper/README.md`. Preserve the supplied
  `TSS_ICCAD/` manuscript and imported source snapshots as the revision
  baseline; use the audits and claim map before reusing old figures or numbers.
  The next conference is undecided. Check provenance with
  `python3 docs/paper/tools/verify_workspace.py`.
- **Frozen functional simulation:** all canonical source, runners, scripts,
  tools, tests, baselines, documentation, and evidence live under
  `functional_sim/`. Before touching this workstream, read
  `functional_sim/AGENTS.md`; use `functional_sim/README.md` as its map.
- **Active hardware simulation:** all new RTL, circuit-reference simulation,
  trace adapters, event ledgers, synthesis flows, and hardware reports belong
  under `hardware_sim/`. Read `hardware_sim/AGENTS.md` and
  `hardware_sim/docs/README.md` before working there.
- **Paper-wide material:** shared writing guidance lives under `docs/paper/`;
  superseded planning material lives under `docs/archive/`.

The imported `hardware_sim/reference/tss_delivery_20260909/` is a separate
presentation prototype, not the active M1 implementation. Do not use its
mapped/pre-route reports as evidence of post-layout closure or frozen-model
quality. Copied review and plotting sources retain historical wording and
paths; their accompanying audits define the limits of reuse.

The repository root is a project router, not a functional command surface.
Invoke functional files through `functional_sim/...`; do not add root wrappers,
aliases, or links. Do not make the hardware simulator import from `../anchors`
or `../rebuttal`; those repositories are provenance sources, not runtime
dependencies. Do not edit the sibling Transformers simulation or the frozen
functional harness unless the user explicitly reopens that scope.

Use the paper-level term **temporal significance scheduling**, the algorithmic
term **local execution windows on aligned contribution streams**, and the
primary frozen work metric **executed-digit ratio**. Hardware event counts,
reads, latency, area, and energy are separate accounting quantities.

# Repository guide

This repository contains two simulation workstreams for the same temporal
significance scheduling paper. Keep their code, evidence, and terminology
separate.

## Workstream routing

- **Frozen functional simulation:** all canonical source, runners, scripts,
  tools, tests, and baselines live under `functional_sim/`. Root-level Python
  and directory names are compatibility symlinks only. Before touching this
  workstream, read `functional_sim/AGENTS.md` and `functional_sim/HARNESS.md`.
- **Active hardware simulation:** all new RTL, circuit-reference simulation,
  trace adapters, event ledgers, synthesis flows, and hardware reports belong
  under `hardware_sim/`. Read `hardware_sim/AGENTS.md` and
  `hardware_sim/docs/README.md` before working there.
- **Paper-wide material:** shared writing guidance lives under `docs/paper/`;
  superseded planning material lives under `docs/archive/`.

The root-level functional symlinks are a compatibility surface and must keep
working from the repository root. Do not add real functional implementation
files beside them. Do not make the hardware simulator import
from `../anchors` or `../rebuttal`; those repositories are provenance sources,
not runtime dependencies. Do not edit the sibling Transformers simulation or
the frozen functional harness unless the user explicitly reopens that scope.

Use the paper-level term **temporal significance scheduling**, the algorithmic
term **local execution windows on aligned contribution streams**, and the
primary frozen work metric **executed-digit ratio**. Hardware event counts,
reads, latency, area, and energy are separate accounting quantities.

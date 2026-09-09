# Examined source catalog

Recorded: 2026-09-09. Paths in the source column are relative to the repository
root; local links point to organized copies or audits. Original repositories
and frozen simulation code were inspected read-only.

| Source | Identity at inspection | Local organization | Selection |
|---|---|---|---|
| `TSS_ICCAD/` | User-supplied, initially untracked; per-file SHA-256 | [Manuscript baseline](../../TSS_ICCAD/README.md) | All TeX, bibliography, and seven PDF figures |
| `../rebuttal` | `e13339c996b3551deb9723567aca3e9bfc03868f`, clean | [Review history](review_history/iccad/README.md), [evidence](evidence/README.md) | Reviews, final response variants, attachment, relevant summaries and compact numerical artifacts |
| `../figure` | `40c5f10d6d4a5490dddcd88cb3b2ce6523ad204d`, clean | [Figure assets](assets/README.md) | Figure 4–7 source/export collection and guidelines; reuse status in the audit |
| `../data` | No source-control revision; per-file SHA-256 | [Numerical evidence](evidence/README.md) | Selected quality/work/calibration JSON and tables; large tensor outputs remain external |
| `../6b`, `../6c`, `../sup` | Ancillary figure/calibration/baseline sources | [Figure/data audit](figure_data_audit.md) | Follow exact figure dependencies; keep superseded or mislabeled baselines out of headline evidence |
| `../TSS` | `dd6fe890c36effd248b4d0ae56947d7dadfb7dd1`, clean | [Hardware snapshot](../../hardware_sim/reference/tss_delivery_20260909/README.md) | Presentation contracts, RTL, filelists, netlist, constraints, synthesis and power reports |
| `docs/paper`, `docs/archive` | Host starting revision `0a50e2151da5f3ef0e6806fda70d0efd6b979d3b` | Existing locations plus this index | Preserve earlier guidance and distinguish superseded plans |
| `functional_sim/` | Same host starting revision; frozen | [Functional map](../../functional_sim/README.md) | Read-only semantics and source map; no experiment rerun |
| `hardware_sim/` | Same host starting revision | [Active architecture](../../hardware_sim/docs/architecture_contract.md) | Active M1/M2 contract, kept separate from imported prototype |

The sibling `figure` and `TSS` repositories were clean. `rebuttal` was clean
as well, but its ignored local experiment outputs are not identified by its
Git revision; imported result files therefore also need their individual
hashes. Refer to snapshot manifests for exact included files, transformations,
source roots, and exclusions.

## Selection rationale

The source `data` directory occupies about 50 GiB on disk and `rebuttal` about
8.8 GiB (`du -sh` at inspection). Logical file sizes in the detailed inventory
can be larger than allocated disk space.
Copying their complete experiment trees would bring calibration tensors,
caches, repetitive outputs, and superseded hardware material into the writing
workspace. The curated collection keeps the compact evidence needed to inspect
the paper's numerical claims and plot provenance, while retaining original
source locations for deeper reproduction.

Hardware reports and RTL stay under `hardware_sim/`; paper-wide numerical
exports and figure snapshots stay under `docs/paper/`. Legacy hardware artwork
is retained only as part of an explicitly historical figure bundle. No sibling
source tree is a new runtime dependency of active hardware code.

The `TSS` repository also contains a nine-page PDF of the old paper. Its
SHA-256 is
`0cffc36586b8503321a2afaf76488bbdb7164f824018987660ecdaddda35f7ae`.
It is a different PDF export from the rebuttal's review-era copy and is not
new hardware evidence. The review-history PDF is the local reading copy; the
alternate remains external rather than creating another manuscript entry point.

## Known delivery gaps

- Editable sources for the manuscript's Figures 1–3 were not found in the
  inspected manuscript and figure collections; their PDF artwork is preserved.
- Existing plotted CSVs are not uniformly traceable to their cited raw results.
  The [figure/data audit](figure_data_audit.md) identifies specific mismatches.
- The hardware package references simulation, technology, and physical-design
  artifacts absent from the delivery. The
  [hardware audit](../../hardware_sim/docs/reference/tss_delivery_audit.md)
  lists them. No delivered GDS/DEF, extracted parasitics, or routed timing
  establishes current-layout closure.
- The original manuscript has complete local graphics and bibliography
  references, but no TeX build tool was installed during inspection.
- A new-conference working manuscript and template are intentionally deferred
  until the evidence is reviewed and DATE versus ISCAS is decided.

## Organization checks

The collection has five provenance manifests covering **423 payload files,
18,770,680 stored bytes**: nine manuscript originals, 14 review-history files,
24 figure assets/sources, 337 numerical-evidence files, and 39 hardware-delivery
files. Hardware compression preserves the original bytes and hashes.

At intake, all preserved payloads matched their original source checksums;
no curated payload was hidden by Git ignore rules. Maintained documentation
links, seven manuscript graphic references, 28 cited bibliography keys, and
manuscript labels passed static checks. The 285-row result catalog rebuilt
byte-identically from its 337 verified snapshots.

The three required functional `--list` commands passed; the frozen functional
tree has no changes. The reference hardware elaborated with Icarus 11.0 using
its synthesis SRAM black box, as documented in the hardware audit. That is a
syntax/elaboration check, not a functional memory or RTL parity test. No
LaTeX build, inference, calibration, synthesis rerun, or layout flow was
performed. The original `TSS`, `figure`, and `rebuttal` Git worktrees remained
clean after inspection.

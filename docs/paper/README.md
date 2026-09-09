# Paper writing workspace

Organized and examined: 2026-09-09. Next venue: **undecided between DATE and
ISCAS**; choose after reviewing this collection. No venue rules or page budget
are assumed here.

Start with the [author-directed revision plan](current_revision_plan.md):
expand the larger-model story around Figure 4, add GPU end-to-end context,
correct hardware overhead to the whole chip, and add the supplied layout.
Other figures change only where needed. Use the [source catalog](source_catalog.md)
and [claim map](claim_evidence_map.md) to support those edits. The manuscript remains in
[`TSS_ICCAD/`](../../TSS_ICCAD/README.md) with its original TeX, bibliography,
and seven figure PDFs preserved.

## Reading map

| Material | Local entry point | Use |
|---|---|---|
| Current writing priorities | [Revision plan](current_revision_plan.md) | Author's intended use of the organized evidence; takes precedence over older suggested rewrite orders |
| Original manuscript | [Manuscript baseline](../../TSS_ICCAD/README.md) | Existing prose, equations, bibliography, and artwork |
| Manuscript and reviewer audit | [Audit](manuscript_review_audit.md) | Specific corrections and unresolved claims |
| Reviews and rebuttal | [ICCAD review history](review_history/iccad/README.md) | Exact copies of reviews, response variants, attachment, and selected summaries |
| Figures | [Assets](assets/README.md), [figure/data audit](figure_data_audit.md) | Plotting sources, CSVs, PDFs/PNGs, and reuse defects |
| Numerical results | [Evidence](evidence/README.md) | Curated frozen quality/work/calibration data with scope and provenance |
| New hardware delivery | [Delivery audit](../../hardware_sim/docs/reference/tss_delivery_audit.md) | Presentation-prototype RTL and supplied mapped/pre-route reports |
| Added layout figure | [Layout record](../../hardware_sim/reference/layout_20260909/README.md) | Supplied layout image, provenance, and caption metadata |
| GPU component of end-to-end evaluation | [GPU profile](../../hardware_sim/reference/rebuttal_gpu_20260909/README.md) | Preserved measured full/non-FFN timing and historical ratio analysis |
| Active hardware specification | [Architecture contract](../../hardware_sim/docs/architecture_contract.md) | Corrected M1; M2 still open |
| Prior writing guidance | [Rebuttal lessons](revision_lessons_from_rebuttal.md) | August synthesis of reviewer lessons; read with the newer audits |
| Historical plans | [Archive](../archive/README.md) | Superseded planning only |

## Evidence boundaries

There are three different hardware/numerical descriptions in these sources:

1. The ICCAD manuscript and frozen functional results describe the original
   contribution-stream truncation and legacy hardware accounting.
2. The active hardware contract forms a three-bit activation fraction prefix,
   uses a four-bit significand by signed eight-bit Q6 multiply, and preserves
   exact temporal placement. Frozen model PPL does not validate this arithmetic.
3. The imported `TSS` presentation prototype uses signed 8-by-8 multiplication
   and whole-leaf enable checks. It does not implement the active target-prefix
   rule or partial-window execution. The supplied reports are pre-route; the
   delivery contains no physical-layout database.

The author supplied a layout image and confirmed its association with the
documented simplified layout phase. The phase handoff and implementation
contract are sufficient for the writing description; explain their
simplifications in the experiment text and caption. The intended hardware
area and energy reporting boundary is the complete accelerator chip; prior
per-tile/per-channel wording is to be corrected.

Use **executed-digit ratio** for frozen algorithmic work. Keep hardware event
counts, reads, latency, area, power, and energy separate, with the design ID,
measurement boundary, and source status beside every claim. A mixed table must
identify full versus sampled evaluation and cannot imply that different
evidence classes came from one run.

## Preservation and checks

Imported originals are snapshots, not editable working results. Their
manifests record source paths, revisions where available, sizes, and SHA-256
checksums. Large tensors, checkpoints, caches, and unrelated experiments stay
in their source locations; their exclusion does not make this a full experiment
reproduction bundle. New figure revisions should go in a separate working
directory with explicit inputs, after resolving the audit findings.

Run from any directory:

```bash
python3 /path/to/onlinearith/docs/paper/tools/verify_workspace.py
```

From the repository root, also verify imported data against the available
sibling originals:

```bash
python3 docs/paper/tools/verify_workspace.py --check-sources
```

The verifier checks manifests and compressed payloads, plus manuscript figure,
bibliography, and label references. It requires only Python's standard
library. It does not run model evaluation or hardware flows. A LaTeX compiler
was unavailable during this organization; source checks do not establish a
successful PDF build.

# ICCAD 2026 review and rebuttal record

Recorded: 2026-09-09. Paper #229, “Temporal Significance Scheduling for
MX-Quantized LLM FFN Inference on CIM.” This collection preserves 14 exact
copies (1,278,826 bytes) from `../rebuttal` at Git revision
`e13339c996b3551deb9723567aca3e9bfc03868f`. Original filenames, including
`reiews.txt`, are intentional. Sources remain unchanged.

Start with [the reviews](reiews.txt), [the clean response](hotcrp-rebuttal-clean.md),
and [the attachment PDF](rebuttal-attachment.pdf). These are historical records,
not the current hardware specification. The filesystem establishes the
available response versions; it does not prove which text was posted, a final
decision, or acceptance. No review scores or decision notification appear in
the copied review record.

| File | Purpose and reuse boundary |
| --- | --- |
| [reiews.txt](reiews.txt) | Five reviewer reports, #229A through #229E; authoritative record of the supplied concerns. |
| [TSS_ICCAD.pdf](TSS_ICCAD.pdf) | Legacy manuscript PDF retained with the rebuttal. The matching TEX remains under `TSS_ICCAD/`; no duplicate TEX is imported here. |
| [hotcrp-rebuttal-clean.md](hotcrp-rebuttal-clean.md) | Clean, final-named response; use for the response's narrative and stated evidence. |
| [final-rebuttal-draft.md](final-rebuttal-draft.md) | Preceding draft; retain because algorithm notation differs from the clean response. |
| [rebuttal-attachment.md](rebuttal-attachment.md), [TEX](rebuttal-attachment.tex), [PDF](rebuttal-attachment.pdf) | Tables A1–A8 and A5b. Preserve all formats; frozen model quality may be reused with its original scope, while hardware/system ratios remain legacy evidence. |
| [reviewer-coverage-checklist.md](reviewer-coverage-checklist.md) | Historical question-to-response map and caveats; “covered” does not mean independently validated or resolved for the revised paper. |
| [model_performance_results_summary.md](model_performance_results_summary.md) | Full versus sampled result scopes and original source paths. Dated 2026-06-11; its running/missing rows are stale relative to the final attachment. |
| [calibration_algorithm_summary.md](calibration_algorithm_summary.md) | Exact-MX cache, SNR search, fixed-sum redistribution and source pointers. Paths predate the `functional_sim/` reorganization; defaults are not proof of each experiment's configuration. |
| [control_plane_anchor_stats.md](control_plane_anchor_stats.md) | Legacy anchor/source accounting and proxy caveats. Serial leaves, stage-boundary FIFO, completion state, storage, timing and energy must not enter the revised active hardware as measurements. |
| [first-assessment.md](first-assessment.md) | Early editorial reasoning; subjective acceptance probabilities and its reviewer count are not evidence. |
| [remaining-rebuttal-roadmap.md](remaining-rebuttal-roadmap.md) | Historical follow-up priorities; status is not a current execution plan. |
| [anchor-and-validation-improvement-requests.md](anchor-and-validation-improvement-requests.md) | Historical validation requirements useful for identifying unresolved evidence gaps. |

## Precedence and known conflicts

- Use [the current manuscript audit](../../manuscript_review_audit.md) and
  [paper revision guidance](../../revision_lessons_from_rebuttal.md) to decide
  what is reusable. Active arithmetic and evidence rules live under
  `hardware_sim/docs/`.
- The clean response omits `d_online` in its arrival/effective-precision
  equations; the preceding draft and calibration summary retain it. The active
  M1 contract explicitly preserves the frozen two-position offset. Do not
  choose an equation by document title alone.
- Full Qwen PPL and 300-sample work statistics use different run scopes. Llama
  cross-family and block-size evidence are sampled. The abbreviated attachment
  does not restate every scope; consult the source summary and raw artifacts.
- The 4.253% decode / 8.014% prefill gains, 0.884 normalized energy, and
  1.011 normalized area in the response use the old FFN model. They are not
  results of the revised stage-1 arithmetic or the separate layout prototype.
- The response's “fully accounted” control claim coexists with formula-based
  decode/fanout, proxy energy and conditional overlap in the anchor summary.
  Preserve those evidence distinctions when rewriting.

## Provenance and exclusions

[manifest.json](manifest.json) records `source_root`, source Git revision,
source working-tree state, and one `source_path`, `destination_path`,
`size_bytes`, `sha256`, and role per copied file. Paths in the manifest are
relative to the source root or this project root as stated; it is usable after
moving the project. The README and manifest are new editorial files, not
copied source artifacts.

The old cost-model implementation, packed anchor builds, large traces and
duplicate experiment payloads are intentionally outside this review-history
collection. Their original pointers remain in the copied documents. Numerical
evidence curation and hardware evidence curation have separate project homes;
this folder adds no runtime dependency on `../rebuttal`.

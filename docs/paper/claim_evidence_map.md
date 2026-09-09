# Claim and revision map

Status: writing-stage audit, 2026-09-09. This map separates reusable evidence
from claims that require correction or new supporting work. It does not change
the frozen simulator or promote the imported prototype into the active design.

The [current revision plan](current_revision_plan.md) records the author's
subsequent priorities. Figure 4's larger-model evidence, GPU end-to-end context,
whole-chip cost reporting, and the supplied layout are the intended additions;
other figures receive only necessary changes.

| Topic | Evidence available here | Reuse decision |
|---|---|---|
| Temporal significance scheduling and local execution windows on aligned contribution streams | Original method, rebuttal explanations, active architecture contract | Retain the abstraction; state which numerical realization each experiment uses |
| Model quality across Qwen scales | Frozen full-test FP16/MXFP8/TSS and sampled quality/work results | Primary Figure 4 expansion using 1.7B/4B/8B; identify configuration and actual full/sampled scope |
| Roughly half executed-digit work | Frozen sampled statistics and separately sourced full-test PPL | Label both run scopes; do not equate executed-digit ratio with multiplier count, latency, or energy |
| Generalization beyond Qwen | Llama-3.2-3B sampled results | Describe one additional tested family, with the sample limit visible |
| Universal superiority over sparsity | Original manuscript assertion; later rebuttal comparisons | Rewrite: the tested Qwen3-8B near-half-work activation 2:4 point is stronger than TSS |
| Calibration method, runtime, and block-size sensitivity | Frozen configurations/results and rebuttal summaries | Use actual outputs over stale progress summaries; correct the manuscript's split and sample/token terminology |
| Plot provenance | Figure scripts, CSVs, exports, selected referenced raw files | Resolve reversed N:M semantics and inconsistent source/value mappings before creating new plots |
| 22–25% FFN latency reduction | Original serial-stream model and Figure 5 | Historical only; neither revised M1 nor prototype inherits it |
| Hardware area and energy overhead | Author corrects previous per-tile/per-channel attribution to whole-chip reporting | Correct experiment prose, Figure 7 and captions using chip-wide totals and explicit support/baseline denominators; distinguish power from energy |
| Standard-multiplier stage-1 arithmetic | Active M1 contract and arithmetic fixtures | Specification evidence; frozen product-truncation PPL does not validate target-prefix/Q6-weight arithmetic |
| Complete tile structure and SRAM integration | Imported presentation-prototype RTL/netlist and mapped reports | Useful structural reference for its own signed 8-by-8 design; it does not implement the active M1 arithmetic contract |
| Prototype power | Supplied PrimeTime-PX reports and summary | Label as pre-route activity-based estimates, with corner, activity window, and missing activity provenance |
| 249.5 MHz prototype estimate | Summary arithmetic from stated 4 ns constraint and −0.008 ns pre-CTS slack | Formula reported by the delivery; the cited pre-CTS source report is absent, so closure remains unverified |
| Layout figure | Newly supplied layout image, registered separately from the earlier delivery | Add physical implementation artwork; record design, dimensions and report association for its caption |
| Post-layout numerical results | Layout image supplied; physical database/extracted reports still absent | Tie any numerical layout claim to matching reports; the picture is not a timing or energy measurement |
| End-to-end LLM performance | Locally preserved Qwen3-1.7B GPU full/non-FFN profile plus legacy FFN ratio analysis | Add/adapt a figure with GPU attention and other non-FFN work, and explicitly sourced accelerated computation |

Exact file references and numerical discrepancies are in the
[manuscript/reviewer audit](manuscript_review_audit.md),
[figure/data audit](figure_data_audit.md), and
[hardware delivery audit](../../hardware_sim/docs/reference/tss_delivery_audit.md).

## Author-directed revision order

1. Select larger-model rebuttal results and enrich Figure 4. Use full-test
   quality and sampled curves with visible scope labels.
2. Add or adapt the end-to-end GPU performance figure, keeping measured GPU
   timing separate from the accelerated-component estimate.
3. Correct hardware area/energy reporting to the complete chip and prepare the
   new layout figure with matching caption/provenance information.
4. Make focused wording and necessary figure corrections. The audit's broader
   alternative rewrite suggestions are not a requirement to redraw everything
   or implement the active M1 design during writing.
5. Choose DATE or ISCAS after the content is clear, then verify its current
   template and limits.

## Practical claim rules

Use **executed-digit ratio** for the frozen algorithmic metric. For every
hardware quantity preserve its status (`trace`, `rtl_sim`, `mapped`, `formula`,
`proxy`, `assumption`, or `pending`) and specify which design produced it.
The delivery's EDA power reports are estimates, not measured silicon power.
Area from summed mapped cells is not floorplan/core area, and power in mW is
not energy. A cell-area sum, a timing constraint, and a power summary do not
jointly prove post-layout performance.

The [August rebuttal lessons](revision_lessons_from_rebuttal.md) remain useful
writing guidance. Their suggested realization and results must be read with
the more precise M1 non-equivalence statement and this delivery audit. Earlier
review-response variants also differ in the placement of the online-delay
constant; use the active contract's explicit `p_eff = max(0, H - tau - 2)`
only when describing that contract.

# Claim and revision map

Status: writing-stage audit, 2026-09-09. This map separates reusable evidence
from claims that require correction or new supporting work. It does not change
the frozen simulator or promote the imported prototype into the active design.

| Topic | Evidence available here | Reuse decision |
|---|---|---|
| Temporal significance scheduling and local execution windows on aligned contribution streams | Original method, rebuttal explanations, active architecture contract | Retain the abstraction; state which numerical realization each experiment uses |
| Model quality across Qwen scales | Frozen full-test FP16/MXFP8/TSS results in the curated evidence | Promote beyond the original 0.6B-only story; identify configuration and actual full-test scope |
| Roughly half executed-digit work | Frozen sampled statistics and separately sourced full-test PPL | Label both run scopes; do not equate executed-digit ratio with multiplier count, latency, or energy |
| Generalization beyond Qwen | Llama-3.2-3B sampled results | Describe one additional tested family, with the sample limit visible |
| Universal superiority over sparsity | Original manuscript assertion; later rebuttal comparisons | Rewrite: the tested Qwen3-8B near-half-work activation 2:4 point is stronger than TSS |
| Calibration method, runtime, and block-size sensitivity | Frozen configurations/results and rebuttal summaries | Use actual outputs over stale progress summaries; correct the manuscript's split and sample/token terminology |
| Plot provenance | Figure scripts, CSVs, exports, selected referenced raw files | Resolve reversed N:M semantics and inconsistent source/value mappings before creating new plots |
| 22–25% FFN latency reduction | Original serial-stream model and Figure 5 | Historical only; neither revised M1 nor prototype inherits it |
| 0.3% area / 2.5% power overhead | Original hybrid accounting and Figure 7 | Historical only; new overhead needs a matched baseline and explicit boundary |
| Standard-multiplier stage-1 arithmetic | Active M1 contract and arithmetic fixtures | Specification evidence; frozen product-truncation PPL does not validate target-prefix/Q6-weight arithmetic |
| Complete tile structure and SRAM integration | Imported presentation-prototype RTL/netlist and mapped reports | Useful structural reference for its own signed 8-by-8 design; it does not implement the active M1 arithmetic contract |
| Prototype power | Supplied PrimeTime-PX reports and summary | Label as pre-route activity-based estimates, with corner, activity window, and missing activity provenance |
| 249.5 MHz prototype estimate | Summary arithmetic from stated 4 ns constraint and −0.008 ns pre-CTS slack | Formula reported by the delivery; the cited pre-CTS source report is absent, so closure remains unverified |
| Post-layout area, timing, or energy | No current physical-layout artifacts in the delivery | Unsupported by this collection |
| End-to-end LLM speedup | Older GPU split and legacy FFN accounting | Retain the method/denominator only if verified; replace the hardware ratio and state unaccelerated work |

Exact file references and numerical discrepancies are in the
[manuscript/reviewer audit](manuscript_review_audit.md),
[figure/data audit](figure_data_audit.md), and
[hardware delivery audit](../../hardware_sim/docs/reference/tss_delivery_audit.md).

## Revision order after organization

1. **Set the numerical and hardware story.** Decide which implementation the
   new paper evaluates. Record the differences among frozen product-digit
   truncation, active target-prefix multiplication, and the presentation
   prototype before joining their results. This is a research-design decision,
   not a directory cleanup.
2. **Build source-backed quality/work tables.** Use final raw outputs and
   explicit full/sampled columns. Carry FP16, dense MXFP8, and the two TSS
   operating-point stories together. Repair plot mappings in new working
   sources while preserving archived originals.
3. **Rewrite the method and hardware explanation.** Give the GLU-to-block
   mapping, all metadata equations, a consistent worked example, exact weight
   encoding, target formation, and calibration procedure. Match Figure 3 to
   the actual evaluated boundary.
4. **Close hardware evidence gaps appropriate to that story.** Obtain or
   generate the missing design-matched verification, activity, baseline, and
   physical-design artifacts in a separate implementation task. This
   collection does not establish numerical equivalence or layout
   closure.
5. **Select DATE or ISCAS and open the working revision.** Verify the chosen
   venue's current official format and limits at that point; then budget
   sections and replace the historical abstract, headline claims, and figures.

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

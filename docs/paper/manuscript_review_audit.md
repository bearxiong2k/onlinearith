# Manuscript and review audit for the next submission

Recorded: 2026-09-09. Scope: inspection and organization, with no changes to the
manuscript, frozen functional harness, sibling Transformers code, or source
repositories. Venue selection remains open; this audit assumes no next-venue
template or page budget.

The current manuscript is the legacy online-arithmetic ICCAD version. Useful
numerical evidence and reviewer-driven explanations are available, but the
legacy datapath, revised arithmetic contract, and separate physical prototype
must be presented as distinct evidence. The new prototype cannot by itself
close the paper's numerical-equivalence or temporal-window performance claims.

## 1. What the current manuscript contains

[The TEX](../../TSS_ICCAD/sample-sigconf.tex) is byte-identical to
`../rebuttal/sample-sigconf.tex`: SHA256
`1bf1e7cc9173f94579080066ac978f4aaa358822f091a95ac3fd9401ce5e1f7e`.
The [legacy PDF](review_history/iccad/TSS_ICCAD.pdf) is retained with the review
history. The source is a single `acmart` manuscript with seven figure PDFs and
one bibliography. A citation-key audit found 28 cited keys, 63 bibliography
entries, and no missing keys. This is a static source check, not a successful
LaTeX rebuild.

| Part | Present story | Reuse decision |
| --- | --- | --- |
| Abstract / introduction / conclusion | Qwen3-0.6B; near-dense quality at approximately half work; 22–25% FFN latency reduction; 0.3% area and about 2.5% power overhead | Retain the scheduling motivation; replace or scope every headline number to its actual evidence. |
| Background and method, Sections 2–3 | GLU-FFN, MX metadata, arrival `tau=D+lambda_x`, calibrated horizon, windows on emitted MSD-first product streams | Retain method identity and model equation; give exact decode, calibration and arithmetic boundaries. |
| Hardware, Section 4 | Gate/up serial-parallel leaves, OLA trees, local SiLU/gate fusion, custom down-projection shards and narrow stage-boundary payload | Legacy architecture. Redraw for the chosen stage-1 evidence boundary. |
| Methodology, Section 5 | Digit/cycle-level TLM, claimed bit-exact outputs, one model, 1024 calibration tokens, 28 nm control/datapath/SRAM costs | State which code/run each assertion describes; avoid implying the new prototype produced the frozen quality results. |
| Results, Section 6 | Quality/work frontier, modeled FFN live-interval contraction, calibration ablations, per-channel cost pie charts, control-overhead comparison | Reuse frozen quality/work with source scopes; replace hardware comparisons and identify assumptions. |

Source locations: abstract line 20; contributions lines 61–65; method
`eq:tau`, `eq:sexec`, `sec:horizon`; hardware `sec:tile`, `sec:dataplane`;
methodology lines 277–325; results `sec:layer_latency`, `sec:hardware_cost`;
conclusion line 463 in the unchanged TEX.

## 2. Three different hardware/numerical records

| Record | Arithmetic and scope | What it can support |
| --- | --- | --- |
| Legacy manuscript and frozen functional evidence | Windowed original MXFP8 product contributions; paper describes serial-parallel online leaves and full GLU-FFN with local down projection | Original PPL, calibration and executed-digit ratio, plus legacy modeled hardware quantities under their original assumptions. |
| [Active M1 arithmetic contract](../../hardware_sim/docs/architecture_contract.md) | Three-bit target activation fraction with four-bit significand, signed 8-bit Q6 aligned weights, 12-bit product, 45-bit temporally aligned block sum and 52-bit accumulator; custom gate/up only | A separately specified revised arithmetic. The contract says M1 is frozen and M2 microarchitecture is open; it is not a completed physical implementation. |
| [External tile implementation contract](../../hardware_sim/reference/tss_delivery_20260909/source/stage1_tile_v1/docs/stage1_tile_architecture.md) | 8 owner-lane pairs, 16 paths, 512 signed 8×8 leaves, 16-bit products, 21-bit block sums, 28-bit accumulators, 136 SRAM macros; gate/up only | A conventional-multiplier presentation prototype and its explicitly scoped physical reports. It uses `leaf_enable = active_lane && (tau < Horizon)` and a fixed block pipeline, not partial-window target formation. |

The [prototype presentation contract](../../hardware_sim/reference/tss_delivery_20260909/source/stage1_presentation_layout_contract.md)
explicitly excludes cycle-accurate TSS, model-to-RTL bit-exact validation and
regeneration of paper/rebuttal performance data. Its older ping-pong activation
buffer description is superseded by the implementation contract's current
streamed DFF bank; do not combine their inventories.

The active M1 contract, Section 3.7, also states that the frozen simulator
NAF-truncates `q_x*q_w` using the original MXFP8 weight, whereas M1 clears low
activation fraction bits and adds offline Q6 weight rounding. These operations
are not generally numerically identical. Frozen PPL establishes the original
schedule's numerical behavior; it does not establish output quality of either
new circuit. A source-status label must accompany any table placing these
quantities together.

## 3. Claim conflicts that affect the rewrite

| Priority | Conflict and evidence | Required resolution |
| --- | --- | --- |
| P0 | Section 4/Figure 3 claim full GLU execution, local SiLU, gate multiply, down shards and reduced payload; active M1 and prototype both exclude these custom blocks | State gate/up custom scope in the abstract, model-to-hardware diagram and hardware tables. Include other projections only as declared common terms. |
| P0 | The abstract and `sec:layer_latency` attribute 22–25% improvement to live-interval contraction; prototype uses an accepted block's fixed C0–C6 pipeline | Do not translate old executed-digit reductions into new elapsed cycles. A revised latency claim needs the actual command/block ledger, prepass, reads and pipeline behavior. |
| P0 | Source Section 5 claims the TLM is bit-exact for the hardware; M1 Section 3.7 disclaims equivalence with frozen outputs, and the prototype contract excludes model equivalence | Identify separate numerical oracles and validation scope. Numerical agreement is an evidence gap, not a wording change. |
| P0 | Figure 7 and Table 1 use 45.1 square micrometers of control over 13,008 per-channel area; rebuttal and prototype use different blocks and boundaries | Rebuild hardware tables with process, corner, hierarchy, total versus incremental area, source status and denominator. Never transfer the old 0.35% fraction to the new tile. |
| P1 | Clean response uses `tau=D+lambda_x` and `p_eff=H-tau`, while the preceding draft includes `d_online`; active M1 preserves `p_eff_frozen=max(0,H-tau-2)` | Keep physical multiplier latency separate from the two-position calibration-origin constant; use one fully defined convention per evidence class. |
| P1 | The method's calibration prose calls redistribution dynamic and gives a vague quantized-versus-dense objective; the algorithm summary uses exact-MX output and fixed-sum integer swaps | Explain one-time SNR initialization, local error curves, donor/receiver swaps, exact fixed budget, bounds and stored horizon table. Report actual run configuration, not driver defaults. |
| P1 | Introduction and Figure 4 discussion imply consistent superiority over activation masks; attachment A3 gives Qwen3-8B TSS 17 dB PPL 11.5926 versus activation 2:4 10.6433 | Limit comparisons to tested models, work points and concrete hardware policies. Separate algorithmic selection quality from hardware realization. |
| P1 | Rebuttal reports 4.253% decode / 8.014% prefill gains and 0.884 normalized energy from legacy hybrid accounting | Retain as historical analysis only. Reuse the measured system denominator only with a new, scope-matched hardware ratio and explicit formula. |
| P1 | Paper treats all masks' `n:m` ratios as equivalent executed-digit ratios; reviewer C requests matched computation/dataflow and calibration | Keep executed-digit ratio as the frozen primary work metric, and separately identify baseline keep ratio, actual reads, issues, utilization, latency and energy. |

## 4. Reviewer requirements and available evidence

The supplied [review record](review_history/iccad/reiews.txt) contains five
reports, #229A–#229E, but no numeric scores or decision. The
[coverage checklist](review_history/iccad/reviewer-coverage-checklist.md) records
rebuttal coverage, not proof that all concerns are resolved for a new submission.

| Reviewer concern | Useful retained evidence | Remaining boundary or gap |
| --- | --- | --- |
| A/D: larger models and generalization | Attachment A1: full WikiText-2 Qwen3-0.6B/1.7B/4B/8B; A2: Llama-3.2-3B sampled result | Supports the tested scales and one additional family; no evidence here of broader datasets, downstream tasks or long-context quality. |
| A/E: full-model impact and FFN share | A4: measured Qwen3-1.7B GPU full/non-FFN split, decode with 2048-token cache and 512-token prefill | The hardware ratio is legacy. One measured model does not satisfy E's several-model timing distribution request. |
| B: model-to-hardware flow, operands and lowering | Clean response's GLU block dot product and static lowering sequence | Put the chosen numeric contract and actual stored formats in the main paper; do not depict the prototype as the frozen simulator's implementation. |
| B/C: frequency, pipeline overlap and control overhead | A8 and legacy anchor summary explicitly identify control work and conditional overlap | The 3-control-cycle versus 16-data-cycle claim belongs to the old model. New prepass, streaming, memory and pipeline costs require their own accounting. |
| C: stronger baselines, fair latency/energy/throughput/utilization | A3 quality comparison; A5/A5b concrete Mask-CIM 2:4 policy with dense activation reads and selected weight/tree benefits | A formula-backed policy is not a new measured competitor. Current literature review and equivalent-boundary hardware comparison remain writing/evaluation tasks. |
| C: exact lambda, weight recoding and calibration | Calibration summary; response equations; active M1 Sections 3.1–3.7 | Resolve offset, zero/subnormal, horizon width, rounding and schedule-transfer differences explicitly. |
| D/E: offline cost and block size | A6: Qwen3-1.7B K=8/16/32/64/128 sampled sweep; A7: calibration runtime examples | Report original environment and sample scope. Metadata scaling and digit work are not measured K-dependent new-hardware latency. |
| E: full precision and leaf area | A1 includes FP16; old paper separates leaf and control area | Preserve quantization-versus-scheduling loss. Replacing leaves changes the arithmetic being assessed, so physical feasibility alone does not establish the quality tradeoff. |

## 5. Numerical facts worth promoting

Use [attachment A1–A3, A6–A7](review_history/iccad/rebuttal-attachment.md) with
the original raw-result provenance, informed by
[the quality-scope summary](review_history/iccad/model_performance_results_summary.md):

- Full Qwen 30 dB PPL differs from dense MXFP8 by +0.0458, -0.1587,
  +0.0169 and +0.0213 for 0.6B, 1.7B, 4B and 8B respectively. Report
  “within 0.16 PPL at this operating point,” not “lossless” or “half work.”
- The 17 dB near-half-work point is a different operating point: full PPL
  19.4307, 14.9315, 13.7060 and 11.5926, with sampled digit-work statistics
  approximately 0.4901, 0.4728, 0.4879 and 0.4732. Mark the full-quality and
  300-sample-work scopes separately.
- Llama sampled PPL is 6.5173 dense MXFP8, 6.7859 TSS 17 dB and 6.5271
  TSS 30 dB. Do not silently describe it as full-test evidence.
- The K sweep's sampled work is about 0.465–0.474 while metadata entry count
  changes from 4× to 0.25× relative to K=32. This supports a granularity/cost
  discussion, not a measured circuit sweep.
- Calibration examples span 2802.9–2963.4 seconds for the reported Qwen3-1.7B
  cases and 5584.0–5868.7 seconds for the reported Llama cases. These are
  one-time implementation runtimes, not inference overhead.

The quality summary was last updated 2026-06-11 and retains pending Llama,
FP16 and K rows that the final attachment subsequently reports. Preserve the
historical text as-is; use final artifacts and their raw results for numbers.

## 6. Figure, source and historical-plan findings

Figures 2, 3 and 7 were rendered and inspected in addition to PDF text
extraction; all seven figure references resolve in the current source.

| Asset | Concrete finding | Next writing action |
| --- | --- | --- |
| [Figure 1](../../TSS_ICCAD/figures/figure1.pdf) | Three-way fixed-mask/flexible-mask/TSS motivation; reviewer D calls it crowded | Simplify and ensure claims are bounded by tested comparisons. |
| [Figure 2](../../TSS_ICCAD/figures/figure2.pdf) | Panel (b) computes lambda `[0,2,5,1]` plus D=2 into tau `[2,4,7,3]`, then labels plotted rows `[2,8,4,0]` | Use the same numeric example throughout; add the missing high-level dot product and a worked window example. |
| [Figure 3](../../TSS_ICCAD/figures/figure3.pdf) | Explicit SP leaves, `start_ctr/rem_ctr`, OLA, SiLU, down shards and reduced BSD payload | Replace architecture drawing; do not relabel this diagram as the prototype. |
| [Figure 4](../../TSS_ICCAD/figures/figure4.pdf) | Original single-model quality/work figure | Rebuild from preserved data with multi-model scope and full/sampled markers. |
| [Figure 5](../../TSS_ICCAD/figures/figure5.pdf) | Original modeled FFN latency and contraction decomposition | Retain as legacy only unless the corresponding datapath and cycle model remain the evaluated design. |
| [Figure 6](../../TSS_ICCAD/figures/figure6.pdf) | Calibration/metadata ablation support | Recover source data and retain the exact frozen protocol; this is not a new-hardware quality check. |
| [Figure 7](../../TSS_ICCAD/figures/figure7.pdf) | Caption says power, but total reads “Total Energy: 7.8 mW”; plotted adder power is 10.2%, prose says 10.3% | Rebuild from auditable hardware sources and distinguish energy from power. |
| Bibliography / template | All cited keys resolve; legacy PDF displays placeholder conference/DOI metadata | Audit citation accuracy and update venue metadata only after the target conference is chosen. |

[Existing paper guidance](revision_lessons_from_rebuttal.md) already captures
most reviewer lessons. Its tentative arithmetic examples are subordinate to
the corrected active M1 contract. In particular, the stored-weight reference
is fixed at exponent 8, Q6 rounding is specified, and the new versus frozen
numerical semantics are explicitly different.

[Archived plans](../archive/README.md) are provenance, not a draft skeleton to
copy verbatim. `paper_outline.md`, `paper_plan.md` and `figure_plan.md` retain
serial arithmetic, custom stage 2 and payload-reduction claims. The archived
`hardware_design.md` reflects revised M1 but remains subordinate to the active
contract. Its figure numbering also differs from the actual manuscript
(archived Figure 5 is payload; current Figure 5 is latency).

## 7. Suggested writing order

1. Freeze the paper's evidence boundary in a short claim table: original
   numerical schedule, revised arithmetic specification, physical prototype,
   and any separately derived system estimate.
2. Rebuild the model-to-hardware explanation and architecture figure around
   that boundary; expose the remaining numerical-validation gap.
3. Promote multi-model quality, FP16, sampled work, K and calibration evidence
   with exact experiment scopes and artifact identifiers.
4. Replace the hardware cost/latency section using only the available,
   explicitly classified reports and a matched baseline boundary.
5. Apply the concrete figure/equation fixes, then select venue and adapt the
   template, related work and emphasis.

This audit does not reopen functional simulation or authorize treating pending
hardware validation as completed. The organized
[review-history collection](review_history/iccad/README.md) preserves originals
and records per-file SHA256 provenance for future checking.

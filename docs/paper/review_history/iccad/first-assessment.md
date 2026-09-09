My assessment: this is **borderline but very salvageable**. I would not treat it as “likely accepted already.” I would treat it as a paper whose **core idea is liked**, but whose acceptance depends on whether the rebuttal convinces the committee that the result is not a small-model, FFN-only, assumption-heavy artifact.

The encouraging sign is that **all four reviewers recognize the central idea**: A calls the temporal scheduling perspective novel, B calls the bridge between regular CIM and irregular sparsity compelling, C says the architecture is aligned with MSD-first and CIM, and D calls the MX-exponent-as-arrival-time idea creative and non-obvious. That is a strong base. The dangerous sign is that the weaknesses converge almost perfectly: **scale, end-to-end impact, system-level cost model, missing implementation details, and overhead inclusion**. Your manuscript currently emphasizes Qwen3-0.6B, WikiText-2, FFN-only evaluation with dense attention, 22–25% FFN-layer latency reduction, and very low control-plane overhead; those are exactly the claims the reviewers are probing. 

Without seeing numeric scores, I would estimate the situation roughly like this: **pre-rebuttal: 45–55% acceptance probability**; **with a strong data-driven rebuttal: 60–70%**; with a mostly verbal rebuttal: probably below 50%. The new Qwen3-1.7B/4B/8B perplexity experiments are exactly the right ammunition. They should become the centerpiece of the rebuttal.

The main rebuttal message should be:

**TSS is not a Qwen3-0.6B heuristic; it is a metadata-driven execution mechanism whose quality-compute behavior scales across larger LLMs, whose control overhead is explicitly included, and whose FFN-layer gains translate into bounded but meaningful end-to-end latency gains.**

Do not spend much space defending novelty. The reviewers already accept that. Spend the rebuttal de-risking the evaluation.

The highest-priority response is to **lead with the larger-model results**. Put Qwen3-0.6B, 1.7B, 4B, and 8B in one compact table. Use the same protocol, same MXFP8 setup, same K=32, same calibration size if possible, and report at least one matched operating point, preferably around `ρexec ≈ 0.5`, plus maybe one higher-quality point. The columns should be:

`Model | Dense MXFP8 PPL | TSS PPL @ ρexec≈0.5 | ΔPPL | Executed-digit ratio | FFN latency reduction | Calibration tokens | Calibration runtime`

Raw perplexity alone is weaker than `ΔPPL` versus dense MXFP8. The reviewers need to see that quality degradation does not grow catastrophically with model size. If the 4B/8B results are even slightly better in relative terms, emphasize that larger models appear more tolerant to temporal truncation. If not, still emphasize stability.

However, note a subtle issue: Qwen3-1.7B/4B/8B answers **scale**, but not fully **model-family diversity**. Review A asks “larger LLMs or other model families,” and D suggests “LLaMA-7B or Qwen-7B.” Qwen3-8B should satisfy the larger-model concern, but if you can run even one non-Qwen model at one operating point, that would be disproportionately valuable. A single LLaMA/Phi/OPT-style result at `ρexec≈0.5` may be more persuasive than another fine-grained Qwen sweep. But do not risk destabilizing the rebuttal pipeline for that; the already-finished Qwen3 scale table is mandatory, the cross-family result is optional but high-impact.

The second priority is **end-to-end latency translation**. Reviewers are not rejecting the 22–25% FFN-layer number; they are asking what it means for a full LLM system. You should not claim 22–25% end-to-end speedup. That would be a mistake. Instead, use a conservative Amdahl-style model:

`Normalized end-to-end latency = (1 - f_FFN) + f_FFN · (1 - r_FFN) + overhead`

where `f_FFN` is the measured FFN share of full-token latency and `r_FFN` is the measured FFN-layer latency reduction, about 0.22–0.25 in your current paper. Then report end-to-end latency reduction for your measured or shape-derived `f_FFN`. For example, if FFN accounts for 55–65% of token latency, a 22–25% FFN reduction becomes roughly 12–16% end-to-end latency reduction before small residual overheads. Use your actual numbers.

This is important because it makes the claim more credible: “We report 22–25% FFN-layer latency reduction; under complete-system accounting this corresponds to X–Y% end-to-end decode latency reduction.” That directly answers Review A and prevents Review C from framing the current result as overclaimed.

The third priority is **non-ideal control overhead and pipelining**. Review C’s fourth question is one of the most dangerous parts of the review. They specifically ask whether scale prepass, `λx` decoding/broadcasting, window construction, and configuration switching are fully included. Your rebuttal should contain a small table like this:

`Component | Included in TLM? | Latency/cycles | Overlapped with data plane? | Residual penalty`

Rows should include:

`scale prepass`
`βx/βw metadata reads`
`Emax reduction`
`λx decode`
`λx broadcast`
`window construction`
`shadow-to-active config switch`
`horizon SRAM access`
`block kill / leaf gating decision`

The strongest answer is: “Yes, these are included; most are overlapped through double buffering; the only non-overlapped prologue is X cycles or X% of FFN latency.” If they were not included in the original latency plot, do not hide that. Add a conservative overhead-inclusive number. A slightly smaller but fully audited gain is much more convincing than an optimistic number.

Review B also asks whether TSS affects delay/frequency and whether it pipelines perfectly. Do not answer this qualitatively. Provide a timing statement:

`The adopted tile clock is set by [data-plane SP multiplier / OLA tree / accumulator], not by the TSS scheduler. The scheduler path consists of narrow integer add/sub/compare and SRAM/register access. Post-synthesis timing gives Fmax_data = ..., Fmax_sched = ..., so TSS does/does not reduce the tile clock.`

If you do not have final timing numbers, generate them quickly. “It seems not on the critical path” is not enough because the reviewer already said that.

The fourth priority is **algorithmic reproducibility**. Review C is telling you that Section 3 is too abstract. In the rebuttal, include a compact pseudocode block or deterministic lowering recipe. You need to clarify three things:

First, the exact derivation of `λx`. Do not say only “derived from MX element exponent.” Write the integer decode rule explicitly. For example, in your own exact notation:

`λx[n,b,k] = DecodeDelay(exponent_field(x[n,b,k]))`

and then define `DecodeDelay`. If it is block-local max minus element exponent, say that. If it is a lookup table from MXFP8 exponent code to delay, show the lookup logic. The key point is that reviewers need to know whether larger activation elements arrive earlier, how zeros/subnormals are handled, and whether `λx` is computed per token, per block, or per element.

Second, explain offline weight recoding and alignment. A concise answer should say: the weight block exponent participates in `E[b] = βx[b] + βw[b]`; the weight element exponent is resolved offline into the stored aligned fixed-point/serial digit representation; therefore runtime does not perform weight exponent decoding on the critical path. That directly addresses the confusion around Figure 2(a)/(b).

Third, explain horizon calibration. Give the actual algorithm:

`uniform horizon initialization → channel-wise/SNR initialization → layer-wise L2 redistribution under global budget`

and report calibration cost in wall-clock time, number of calibration tokens, and number of forward passes. Review D specifically asks about calibration runtime. The paper says calibration uses 1024 WikiText-2 training tokens; the rebuttal should add “this took X minutes on Y GPU/CPU” or “X forward passes, no backpropagation, no retraining.” That will make the method look lightweight rather than mysterious.

The fifth priority is **system-level hardware comparison**. Review C is not satisfied with Table 1 because Table 1 mainly compares control-area overhead, not latency, energy, throughput, and utilization under a common execution model. Do not simply point back to Table 1. Add a normalized comparison table, even if it is compact:

`Method | Selection policy | Spatial regularity | Metadata/routing cost | ρexec | Normalized FFN latency | Normalized energy | Utilization | Notes`

Include dense MXFP8, activation-gated 2:4, activation-gated n:32, Wanda n:m, and TSS. If you can include FlexCIM/VEGETA-style flexible n:m as modeled under your common tile assumptions, even better. The key phrase is **“under a common execution/cost model.”** That neutralizes the complaint that the hardware comparison is apples-to-oranges.

For baselines, be careful. Do not overclaim that TSS beats every recent sparsity method in all settings. Say something narrower and more defensible: “We compare against retraining-free, CIM-compatible compute suppression policies at matched executed-digit ratio. Flexible sparsity methods may recover quality but require routing/metadata support that conflicts with the regular CIM substrate; TSS preserves the regular block-serial execution model while improving the quality-compute frontier.” That is the argument reviewers are receptive to.

Reviewer B’s Figure 2(a) question needs a simple, direct answer. Say that Figure 2(a) corresponds to one block of a fully connected GLU-FFN projection. For output channel `c` and path `p ∈ {gate, up}`, the computation is a block dot product over `K=32` pairs: runtime MX activation mantissa digits are one operand, and stationary offline-recoded weight digits are the other operand. TSS does not change the matrix-vector mapping; it changes the time window over which each aligned product stream contributes to the accumulator. Then promise to add this explanation and a small numeric example after Eq. (4). This is easy and should satisfy B.

Reviewer B’s compiler-support question should be answered as a static lowering flow, not as a vague “yes.” Say the method requires a lightweight compiler/model-lowering pass that performs:

`identify GLU-FFN projections → MXFP8 quantize weights/activations → extract βw and activation metadata layout → offline recode/alignment of weight digits → calibrate per-layer/per-path/per-channel horizons H → emit tile mapping plus horizon tables`

At runtime, no dynamic compiler is needed; the control plane only reads MX metadata and horizon tables. This makes the “model to hardware” flow concrete.

Reviewer D’s K=16/32/64 request is secondary but cheap if your simulator supports it. If possible, run K sensitivity on Qwen3-0.6B or Qwen3-1.7B, not necessarily all models. Report quality, latency, and metadata/control overhead trend. The expected qualitative discussion is: smaller K gives finer scale granularity and potentially better significance ordering but more metadata; larger K reduces metadata but coarsens exponent sharing and may weaken quality/latency tradeoff. Even a small ablation will show that K=32 is not cherry-picked.

The rebuttal should be structured by concern, not by reviewer. A good order is:

1. **Scalability:** new Qwen3-1.7B/4B/8B results.
2. **End-to-end impact:** Amdahl/system latency model with measured FFN share.
3. **Overheads and pipelining:** full control-plane inclusion, timing, and overlap.
4. **Reproducibility:** `λx`, weight recoding, calibration pseudocode.
5. **Baselines and hardware comparison:** common execution/cost model.
6. **Minor fixes:** split Figure 1, add Eq. (4) example, add node sizes, fix typo.

If rebuttal space is tight, the order should be: **large-model table first, overhead-inclusive latency second, algorithm/pipeline clarification third**. Minor figure/table fixes should be one sentence.

The most important thing not to do: do not write a defensive rebuttal saying the method “is expected to generalize.” You now have larger-model data, so the rebuttal must be empirical. Also do not imply that FFN-layer speedup equals full-system speedup. The more conservative statement will be more persuasive.

A strong opening paragraph could be:

“Thank you for the constructive reviews. The main concerns are scalability beyond Qwen3-0.6B, full-system latency translation, and whether non-ideal scheduling overheads are included. We have completed additional evaluations on Qwen3-1.7B/4B/8B under the same MXFP8/TSS protocol. Across these models, TSS preserves the quality-compute trend at matched executed-digit ratios, confirming that the mechanism is not specific to the 0.6B model. We also audited the complete control path, including scale prepass, `λx` decode/broadcast, window construction, horizon access, and configuration switching; the overhead-inclusive latency remains [...]. Finally, we clarify that the reported 22–25% speedup is FFN-layer latency reduction, which translates to [...] end-to-end latency reduction under measured FFN latency share.”

The strategic objective is to convert the paper from “creative idea with limited evidence” into “creative idea with credible scaling and accounting.” If your Qwen3-1.7B/4B/8B numbers are clean, this rebuttal has a real chance to move at least A and D, keep B positive, and neutralize enough of C’s objections for acceptance.

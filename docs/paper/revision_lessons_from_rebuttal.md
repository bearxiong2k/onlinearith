# Paper Revision Lessons Extracted From the Rebuttal

Current writing scope is set by the author's
[revision plan](current_revision_plan.md): larger-model Figure 4 evidence,
GPU end-to-end context, whole-chip overhead, and the supplied layout figure.
The recommendations below are earlier guidance, not a requirement to change
every figure or replace the paper's hardware story with the M1 development plan.

Status: active writing guidance  
Recorded: 2026-08-01  
Source: the reviews, response drafts, attachment, coverage checklist, evidence
summaries, and roadmaps in `../rebuttal` at revision `e13339c`.

This document extracts what the rebuttal taught us about improving the paper.
It is not a continuation of the old rebuttal hardware design. Advice tied to
the deleted stage-2/interface path or the old serial-parallel weight-digit
datapath is explicitly excluded.

Two boundaries govern this record:

1. The existing `onlinearith` and modified-Transformers calibration, PPL,
   baseline, and executed-digit results are frozen facts. The paper should
   present them more clearly, not modify the simulator or reinterpret the
   results under altered numerical semantics.
2. Hardware claims must be rewritten for the revised stage-1 design: target
   activation mantissa multiplied by an offline-aligned fixed-point weight in a
   standard multiplier, with no custom stage 2 or stage interface.

## 1. What the reviews collectively said

The reviewers broadly accepted the core idea. The acceptance risk was not
whether temporal significance scheduling was novel; it was whether the paper
made the model-to-hardware flow, evidence scope, and hardware accounting
credible enough.

| Repeated concern | What the rebuttal established | What the revised paper should do |
|---|---|---|
| Small-model evidence | Qwen3 scale results through 8B and a Llama cross-family point were collected | Lead the evaluation with the multi-model result, not Qwen3-0.6B |
| FFN-only versus end-to-end impact | A measured full/non-FFN GPU split plus an FFN hardware ratio gives a bounded whole-model estimate | State the accelerated boundary and use a conservative scenario-specific translation |
| Missing model-to-hardware flow | The rebuttal wrote out the GLU projection, metadata equations, offline lowering, and horizon calibration | Put the complete flow in the main paper and Figure 2/3, not only in prose or an appendix |
| Coarse algorithm description | Explicit definitions for `lambda_x`, block alignment, arrival time, horizons, and fixed-sum calibration were supplied | Provide equations, pseudocode, zero/rounding rules, and one small worked example |
| Assumption-heavy hardware gains | The rebuttal separated trace, RTL, formula, proxy, and measured-GPU sources | Put source status beside every area/latency/energy claim |
| Weak system comparison | A common-boundary ledger was used to avoid giving masks unsupported “half everything” benefits | Compare methods under explicit, matched hardware policies and distinguish software upper bounds from realizable hardware rows |
| Calibration and parameter cost | One-time calibration runtime and a block-size sensitivity were reported | Include calibration cost, static inference artifact, and the `K` tradeoff |
| Presentation ambiguity | Reviewers requested a clearer Figure 1, consistent examples, a small equation example, node labels, and typo fixes | Treat these as mandatory paper edits, not cosmetic extras |

The strategic lesson is simple: do not spend the paper re-proving novelty that
reviewers already recognized. Spend the space de-risking scale,
reproducibility, hardware realism, and claim scope.

## 2. Recommended paper stance

### 2.1 Central thesis

A revision-compatible thesis is:

> Temporal significance scheduling converts existing MX metadata and static
> calibrated horizons into local execution windows. These windows preserve a
> regular channel-parallel, block-serial mapping while controlling the target
> activation mantissa presented to a conventional fixed-point multiplier with
> offline-aligned weights.

Keep the vocabulary stable:

- paper-level principle: **temporal significance scheduling**;
- algorithmic object: **local execution windows on aligned contribution
  streams**;
- revised hardware realization: **metadata-first stage-1 control with target
  activation mantissas, offline-aligned fixed-point weights, and standard
  multipliers**.

Do not recast the method as generic sparsity, generic quantization, generic
pruning, or a generic activation mask.

### 2.2 Contribution claims

The introduction should end with three narrow contributions:

1. **Scheduling abstraction.** Existing MX exponent metadata and calibrated
   horizons define local execution windows and a fine-grained quality/work
   tradeoff without introducing arbitrary spatial selection.
2. **Static/runtime split.** Weight-element alignment is performed offline;
   runtime control uses activation/block metadata and narrow integer window
   operations.
3. **Regular hardware realization and evidence.** The revised stage-1 design
   forms target activation mantissas and uses standard fixed-point
   multiplication, while the evaluation combines frozen model-quality/work
   facts with separately sourced hardware accounting.

Do not list reduced stage-boundary payload or a local `down_proj` consumer as a
contribution.

### 2.3 Claim discipline

Use these forms:

- “Across the tested Qwen3 scales and the Llama cross-family point,” not
  “across all LLMs.”
- “At the tested high-quality operating point,” not “without accuracy loss.”
- “Improves the tested hardware-realizable quality/work tradeoff,” not
  “universally dominates flexible sparsity.”
- “Executed-digit ratio,” for the frozen primary work metric; do not call it
  measured energy or latency.
- “Stage-1 hardware gain” or “scenario-specific whole-model estimate,”
  according to the actual denominator.
- “Formula-backed,” “trace-backed,” “mapped RTL,” “proxy,” or “measured,”
  whenever the evidence type changes.

## 3. Put the complete model-to-hardware flow in the main paper

Reviewer B’s “end-to-end flow” concern and Reviewer C’s reproducibility concern
point to the same missing artifact. The paper needs one diagram and adjacent
text that connect the model equation to stored bits and runtime events.

The revised flow should be:

```text
frozen model/configuration and calibrated horizons
    -> MX activation/block metadata layout
    -> offline weight-element fixed-point alignment
    -> runtime block alignment and local window
    -> target activation mantissa formation
    -> standard fixed-point activation x aligned-weight multiply
    -> local reduction and accumulation
```

The high-level computation should be stated before any microarchitecture. For
path `p` in `{gate, up}` and output channel `c`:

```text
y_p[n,c] = sum_b sum_k x[n,b,k] W_p[c,b,k]
```

Block `b` is the `K`-wide slice of the input vector and the matching slice of
one output-channel weight row. Temporal significance scheduling does not alter
this graph or matrix mapping; it controls how much activation significance is
formed and consumed for each aligned contribution.

The paper must also say where the scope ends:

- the custom hardware covers the revised stage-1 gate/up realization;
- `down_proj` remains part of the functional model but is not a custom stage 2;
- there is no claimed stage-1/stage-2 packet interface, header, FIFO, or payload
  reduction mechanism.

## 4. Method details required for reproducibility

The rebuttal showed that qualitative descriptions are insufficient. The main
paper should define the following without requiring readers to infer them from
figures.

### 4.1 MX block and arrival metadata

Define:

- block indexing and `K`;
- activation block-scale exponent `beta_x[n,b]`;
- weight block-scale exponent `beta_w[p,c,b]`;
- activation element exponent/fine code and exact `lambda_x[n,b,k]` decode;
- zero, all-zero block, subnormal, and saturation behavior;
- coarse exponent/alignment term and relative delay `D`;
- arrival index `tau`;
- per-path/per-channel horizon and local window length.

If the retained equations remain:

```text
E_raw[p,b,c] = beta_x[n,b] + beta_w[p,c,b]
E_max[p,c]   = max_b E_raw[p,b,c]
D[p,b,c]     = E_max[p,c] - E_raw[p,b,c]
tau[p,b,k,c] = D[p,b,c] + lambda_x[n,b,k]
L[p,b,k,c]   = max(0, H[p,c] - tau[p,b,k,c])
```

state them together and follow them with one numeric block example. If the new
hardware contract changes any equation, update the paper equation rather than
leaving the old figure to imply it.

### 4.2 Offline weight alignment

The paper needs an exact storage equation, not only “weights are recoded
offline.” The rebuttal proposed the useful general form:

```text
e_ref[c,b] = max_k e_w[c,b,k]
q_w[c,b,k] = round(m_w[c,b,k]
                   * 2^(e_w[c,b,k] - e_ref[c,b])
                   * 2^F)
```

with a shared block factor represented separately. Before reuse, freeze the
revised design’s actual `e_ref`, `F`, signed width, rounding, saturation,
product width, and shared scale. The important explanatory point survives:
weight-element exponent alignment is static and the runtime multiplier reads a
fixed-point aligned weight word, not a floating-point exponent and not an
online weight-digit stream.

### 4.3 Target activation mantissa

The new paper must define the operand that the standard multiplier actually
sees:

- how the local window selects/constructs the mantissa;
- sign and radix convention;
- padding or width-class behavior;
- whether multiplication issues once after target formation;
- rounding/guard/saturation rules;
- what a zero-length window does.

This is now the key bridge between the frozen executed-digit evidence and the
revised circuit. It should receive at least as much detail as the old paper gave
the online contribution stream.

### 4.4 Frozen calibration procedure

Present calibration as an established one-time, forward-only procedure:

1. capture exact-MX activation/weight blocks on the calibration split;
2. find the minimum integer channel budget meeting target SNR;
3. build local error curves around that vector;
4. move one budget unit from the lowest-loss donor to the highest-gain receiver
   while the swap reduces error;
5. store the final integer horizon table.

State that the total budget is preserved, bounds remain enforced, and no
backpropagation/fine-tuning or online optimization is used. Include calibration
data size, hardware/software environment, and measured wall time. These are
frozen facts; no new calibration run is required for the hardware revision.

### 4.5 Static lowering flow

Describe the compiler/software support as a deterministic offline flow:

```text
identify target FFN projections
    -> use the frozen MX configuration and metadata layout
    -> align stationary weight elements into fixed-point words
    -> load recorded/calibrated horizon tables
    -> emit tile mapping, widths, scales, and control metadata
```

Runtime requires no graph rewriting or dynamic compiler optimization.

## 5. Separate frozen software facts from new hardware evidence

The rebuttal’s most reusable methodological improvement is evidence
provenance. The paper should not present a mixed number without showing its
sources.

| Evidence class | Examples | Paper treatment |
|---|---|---|
| Frozen full evaluation | full WikiText-2 FP16/MXFP8/TSS/baseline PPL | quality claim; identify model, split, setup, and artifact |
| Frozen sampled evaluation | `limit-samples 300` work/PPL statistics | work/curve evidence; label as sampled and do not mix with full PPL silently |
| Frozen calibration | channel horizons, target SNR, runtime | offline algorithm fact |
| New circuit trace/ledger | activation-target work, aligned-weight reads, multiplier issues | revised hardware dynamic-count source |
| Mapped RTL | area and timing for multiplier/control/tree/storage | hardware anchor; state cell/corner/tool |
| Formula-backed accounting | derived reads, common terms, Amdahl translation | show the formula and inputs |
| Proxy estimate | assumed switching/capacitance or incomplete power | label visibly; never call measured power |
| Measured system timing | full/non-FFN GPU timing if retained | scenario-specific denominator, not CIM measurement |

The result JSONs and modified Transformers code remain read-only sources. A
new downstream ledger or report should refer to their revisions/checksums and
use only well-defined fields; it must not imply that the frozen model was
rerun with the new standard-multiplier RTL.

## 6. Frozen evidence the paper should surface

The rebuttal collected much stronger evidence than the original small-model
story. These facts should be promoted into the revised paper rather than left
in a response attachment.

### 6.1 High-quality Qwen scale result

Full WikiText-2, fixed-sum 30 dB:

| Model | Dense MXFP8 PPL | TSS PPL | Delta |
|---|---:|---:|---:|
| Qwen3-0.6B | 17.2754 | 17.3212 | +0.0458 |
| Qwen3-1.7B | 14.6248 | 14.4661 | -0.1587 |
| Qwen3-4B | 11.2757 | 11.2926 | +0.0169 |
| Qwen3-8B | 8.2964 | 8.3177 | +0.0213 |

The defensible conclusion is that the additional scheduling loss is within
0.16 PPL of dense MXFP8 across the tested Qwen3 sizes. Include FP16 beside
MXFP8 so readers can distinguish quantization loss from scheduling loss.

### 6.2 Near-equivalent-work point

The fixed-sum 17 dB point provides the roughly half-work evidence:

| Model | Full TSS PPL | Delta vs full MXFP8 | Sampled normalized digit read |
|---|---:|---:|---:|
| Qwen3-0.6B | 19.4307 | +2.1553 | 0.4901 |
| Qwen3-1.7B | 14.9315 | +0.3067 | 0.4728 |
| Qwen3-4B | 13.7060 | +2.4303 | 0.4879 |
| Qwen3-8B | 11.5926 | +3.2962 | 0.4732 |

The PPL and work columns come from different run scopes (full evaluation and a
300-sample statistics pass). Label that explicitly. Also retain the honest
result that activation 2:4 is stronger than TSS at the tested Qwen3-8B
near-half-work point. This prevents an indefensible universal-dominance claim.

### 6.3 Cross-family evidence

The Llama-3.2-3B sampled result provides a useful cross-family check:

```text
dense MXFP8: 6.5173 PPL
TSS 17 dB:   6.7859 PPL
TSS 30 dB:   6.5271 PPL
```

Use it as evidence of transfer to one additional family, not as exhaustive
generalization.

### 6.4 Block-size and calibration evidence

The Qwen3-1.7B `K=8..128` sweep found the digit-work proxy in a narrow
`0.465..0.474` range while metadata entries scale inversely with `K`. Present
the tradeoff: smaller blocks improve exponent granularity but increase
metadata/control; larger blocks reduce metadata but coarsen the shared scale.

Representative frozen calibration times range from about 2,803--2,963 seconds
for the reported Qwen3-1.7B `K` cases and 5,584--5,869 seconds for the reported
Llama-3.2-3B SNR points. Describe these as unoptimized, one-time implementation
costs dominated by exact-MX replay, not inference latency or an algorithmic
lower bound.

## 7. Evaluation organization

### 7.1 Lead with quality/work, not a hardware proxy

Use two distinct operating-point stories:

- **High quality:** 30 dB across Qwen scale, with FP16 and dense MXFP8
  references.
- **Equivalent work:** 17 dB near the 50%-equivalent executed-digit point,
  compared with WANDA 2:4 and activation N:M 2:4.

Then show a work-quality curve rather than implying one operating point is
universally best. Executed-digit ratio is the primary x-axis. Hardware energy
or latency should appear only after the revised circuit accounting exists.

### 7.2 Baseline fairness

Separate two questions:

1. **Algorithmic selection quality:** how much PPL is retained at a matched
   work definition?
2. **Hardware realization:** what reads, selection, routing, multiplication,
   reduction, utilization, and control does a concrete implementation pay?

Flexible masks may have a higher software selection upper bound. The paper
should acknowledge that. The defensible TSS claim is that it offers a regular,
hardware-realizable temporal policy with a favorable tested tradeoff.

For hardware rows, define each baseline rather than assigning generic savings.
For example, a 2:4 policy does not automatically halve dense activation reads,
fixed pipeline stages, routing, or total latency. Conversely, it should receive
real benefits that its specified implementation supports. Update the related
work with recent baselines before submission, but keep older works when they
establish the lineage of the comparison.

### 7.3 Full versus sampled evidence

Never place full-test PPL and sampled work statistics in one row without a
scope marker. Recommended columns include:

```text
quality_scope | quality_samples/tokens | work_scope | work_samples/tokens
```

If space is tight, place the scope in the caption and use a footnote on every
mixed-scope table.

### 7.4 Ablations that answer a mechanism question

Retain ablations only when they establish one of these points:

- combined activation and weight metadata matters;
- calibrated horizons improve over a uniform budget at fixed total work;
- the method is stable across `K`;
- the high-quality and near-equivalent-work points are not cherry-picked;
- static horizons generalize from calibration to held-out evaluation.

Avoid turning the paper into a tour of calibration variants.

## 8. End-to-end claims after the hardware redesign

The rebuttal’s hybrid methodology is reusable, but its numerical TSS FFN ratios
and resulting 4.253% decode/8.014% prefill gains belong to the old hardware
model. Do not carry those values into the revised paper.

After the new stage-1 cost model exists, a conservative translation can retain
the measured full/non-FFN system denominator:

```text
T_gpu_ffn = T_gpu_full - T_gpu_nonffn
T_e2e_method = T_gpu_nonffn
             + r_revised_ffn * T_gpu_ffn
```

Report separately:

- measured full-system timing;
- measured non-FFN timing;
- derived common FFN slice;
- source of the revised FFN ratio;
- normalized whole-model result;
- decode/prefill sequence conditions.

Say explicitly that attention, KV cache, softmax, normalization, and other
non-FFN work are not accelerated. If only a stage-1 hardware result is ready,
report it as stage-1 and do not manufacture an end-to-end number.

## 9. Hardware evidence required by the revised paper

The old rebuttal was strongest when it made non-ideal overheads explicit. Keep
that discipline while replacing the old datapath.

The paper should account for:

- any retained scale prepass and metadata reads;
- `lambda_x` decode/fanout if still used;
- local window/target-mantissa construction;
- configuration storage and switching;
- activation-digit reads or prefix updates;
- offline-aligned weight-word reads;
- standard-multiplier width, issue count, pipeline depth, and energy;
- reduction tree and accumulator;
- block skip, element skip, and partial-window behavior;
- minimal retained metadata storage.

For every control stage, show whether it is overlapped and what residual
prologue or throughput cost remains. Do not reuse the old “3 control cycles
inside a 16-cycle slot” statement unless the revised datapath independently
re-establishes it.

Separate common hardware from incremental TSS overhead. A standard multiplier,
common SRAM, and common reduction may belong to the shared baseline; horizon,
window-control, or extra metadata state may be incremental. Define the
comparison boundary before reporting an overhead percentage.

There is no active stage-interface payload, header, FIFO, queue, or local
`down_proj` term.

## 10. Figures and tables to revise

### Figure 1: motivation

- Reduce crowding or split the motivation and mechanism panels.
- Contrast regular-but-coarse local selection, flexible-but-irregular
  selection, and temporal significance scheduling.
- Do not imply that every mask is hardware-infeasible or that TSS is a generic
  sparsity method.

### Figure 2: method and worked example

- Start with the GLU block-dot-product equation and show how each activation
  block pairs with a weight-row block.
- Use the same numeric `tau` example in every panel.
- Show metadata-to-window computation and one small example for the main
  piecewise/window equation.
- Replace the old online weight-digit/product-stream drawing with target
  activation-mantissa formation and a standard multiplier receiving an
  offline-aligned fixed-point weight.
- Make “not a raw-input spatial mask” visually clear without overstating the
  distinction.

### Figure 3: revised hardware

- Show only the active stage-1 control and datapath boundary.
- Make offline weight preparation visually separate from runtime control.
- Label operand widths, multiplier, reduction, accumulator, and retained
  active/shadow state.
- Remove stage 2, packet interface, headers, FIFO, shard, and reduced-payload
  elements.

### Results figures

- Lead with the multi-model high-quality/equivalent-work evidence.
- Use executed-digit ratio as the primary work axis.
- Replace the old payload-reduction figure with scale/cross-family evidence or
  a revised hardware-event breakdown.
- Show `K`/calibration robustness compactly.
- Add revised hardware latency/energy only after the new ledger and anchors
  support them.

### Tables

- Put FP16, dense MXFP8, and TSS together to separate quantization and
  scheduling effects.
- Include explicit evidence scope and source status.
- For hardware comparisons, show latency, throughput, energy, utilization, and
  area only where the common boundary supports them.
- Include process node/corner and tool flow for mapped results.
- Fix the old Figure-2 caption typo and all inconsistent symbol/example uses.

## 11. Recommended paper structure

### 1. Introduction

Frame the problem as finding a better, hardware-regular significance schedule.
State the exact evaluated scope and the three contributions. Use the
multi-model evidence in the opening motivation rather than waiting until the
appendix.

### 2. Temporal significance scheduling

Define MX metadata, alignment, `lambda_x`, horizons, windows, target activation
mantissas, and the three suppression modes. Include one numeric example and
short pseudocode.

### 3. Offline preparation and revised hardware realization

Explain weight alignment, static lowering, target-mantissa control, standard
multiplication, reduction/accumulation, storage, and which terms are common or
incremental. State that stage 2/interface is outside the design because it is
not present, not merely omitted for space.

### 4. Methodology and evidence provenance

Define datasets, full versus sampled runs, frozen configurations, baselines,
executed-digit ratio, calibration protocol, hardware tools/corners, event
ledger, and evidence-status taxonomy.

### 5. Results

Use this order:

1. Qwen scale at the high-quality point;
2. near-equivalent-work quality comparison and curves;
3. Llama cross-family point;
4. calibration/`K` robustness;
5. revised stage-1 hardware cost;
6. bounded whole-model translation, only if supported.

### 6. Limitations and conclusion

State that the design targets FFN stage 1, does not accelerate attention, is
evaluated through frozen model simulation plus new RTL/cost modeling, and has a
static offline calibration policy. Conclude with the scheduling principle and
measured scope rather than adding a new claim.

## 12. What belongs in the appendix

- full calibration pseudocode and error-curve redistribution details;
- exact fixed-point bit tables and overflow proofs;
- detailed metadata-bank organization;
- full source-status and event-ledger tables;
- mapped reports and tool commands;
- extended `K`, SNR, layer, and calibration-size curves;
- baseline implementation assumptions;
- artifact revisions/checksums;
- additional model rows that do not fit the main scale table.

The main paper must still include enough detail to reproduce `lambda_x`, the
offline weight representation, horizon use, and the standard-multiplier
operands. These are not appendix-only details.

## 13. Limitations to state directly

- The custom design accelerates the stated FFN stage-1 boundary, not attention
  or the whole model indiscriminately.
- Existing quality/work evidence is simulation-based and frozen; revised
  hardware results come from a distinct RTL/trace/cost path.
- Cross-family evidence currently covers one additional family, not all LLM
  architectures or tasks.
- WikiText-2 perplexity does not establish every downstream-task behavior.
- Calibration is offline and static; lightweight online adaptation is future
  work, not part of the reported method.
- Flexible masks can be a stronger software upper bound at some points, as the
  Qwen3-8B result demonstrates.
- Proxy or formula-backed hardware quantities remain estimates until replaced
  by the stated characterization.

Admitting these boundaries makes the positive claims more credible.

## 14. Priority order for the rewrite

### P0: required before new hardware results are written

- Freeze the revised operand/window/standard-multiplier contract.
- Redraw the method and hardware figures without stage 2/interface.
- Separate frozen software evidence from new hardware provenance.
- Replace old A2/A3/A4 and hybrid-latency values in the paper-facing material.

### P1: required for a persuasive paper revision

- Promote Qwen scale, Llama, FP16, near-equivalent-work, `K`, and calibration
  evidence from the rebuttal into the main paper.
- Add the explicit model-to-hardware flow and worked example.
- Rebuild hardware-fair comparisons under the new common boundary.
- Add a limitations paragraph and evidence-status table.

### P2: presentation polish

- Simplify Figure 1.
- Keep examples and symbols consistent.
- Add node/corner/tool information where applicable.
- Correct caption/table typos.
- Move deep bank/configuration detail to the appendix.

## 15. Rebuttal content that must not be copied forward

The following belongs only to the superseded design:

- serial-parallel activation-digit by weight-digit leaf execution;
- claims that the weight is a runtime recoded digit stream;
- custom stage-2 `down_proj` consumer;
- reduced intermediate payload and stage-interface claims;
- packet headers, boundary FIFO, shard queue, and queue sensitivity;
- old Anchor-2/3 datapath area, latency, and energy coefficients;
- old Anchor-4 total containing completion/payload storage;
- the “3-cycle control versus 16-cycle data slot” result without new
  characterization;
- old TLM FFN ratios and the derived 4.253%/8.014% whole-model gains;
- any suggestion that the frozen `onlinearith`/Transformers simulator should
  be rewritten for the new circuit.

What should be copied forward is the rebuttal’s discipline: answer the exact
model-to-hardware question, show the evidence source, compare under an explicit
boundary, acknowledge where a baseline is stronger, and keep system claims
bounded by what was actually measured or modeled.

## 16. Rebuttal source map

Use these frozen files when tracing a paper-edit decision back to its evidence:

| Purpose | Source |
|---|---|
| Original reviewer concerns | `../rebuttal/reiews.txt` |
| Strategic assessment and response priority | `../rebuttal/first-assessment.md` |
| Initial mechanism/baseline reasoning | `../rebuttal/unpolished-rebuttal-direction.md` |
| Concern-to-response audit | `../rebuttal/reviewer-coverage-checklist.md` |
| Final organized response language | `../rebuttal/final-rebuttal-draft.md`, `../rebuttal/hotcrp-rebuttal-clean.md` |
| Final supporting tables | `../rebuttal/rebuttal-attachment.md` |
| Quality/work evidence provenance | `../rebuttal/model_performance_results_summary.md` |
| Calibration algorithm wording | `../rebuttal/calibration_algorithm_summary.md` |
| Hardware-evidence gaps and source status | `../rebuttal/anchor-and-validation-improvement-requests.md` |
| End-to-end accounting methodology | `../rebuttal/e2e_cost_model_roadmap.md`, `../rebuttal/remaining-rebuttal-roadmap.md` |

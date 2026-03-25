# Revised paper plan

## 0. Paper position

This should remain a **CIM paper about the FFN layer of LLMs**, not an online-arithmetic paper in disguise.

The paper's central thesis is now:

> Fine-grained FFN compute reduction can be made CIM-compatible by using checkpoint-based MSD truncation as a bounded stop schedule, while an FFN-deep BSD-stream pipeline with pipelined scatter preserves timing continuity, overlaps communication with late producer completion, and keeps `down_proj` reduction local.

The updated simulator strengthens this thesis because it now tracks **exact BSD streams** rather than an abstract float carrier with timing metadata.

## 1. The three claims the paper must prove

Every section should support one of only three claims.

### Claim 1: Calibrated checkpoint truncation improves the quality / compute frontier

At similar quality targets, calibrated static budgets should outperform:

- uniform cycle budgets
- post-quantization structured sparsity such as Wanda 2:4 after MXFP8

The point is not that every sparsity method fails. The point is that checkpoint truncation is a more natural compute-reduction primitive for a CIM-organized FFN pipeline.

### Claim 2: Pipelined scatter converts staggered completion into latency benefit

Different owner lanes finish at different cycles. The paper must show that the design does not reintroduce a barrier at the stage-1 / stage-2 boundary. Instead, ready BSD streams are scatter-issued immediately, and local `down_proj` consumers start work early.

### Claim 3: The hardware mechanism is cheap and regular

Runtime support should reduce to:

- local SRAM-stored budgets
- short down-counters
- shallow FIFOs
- local routing and local reduction

This claim is what makes the work appropriate for ICCAD and CIM, rather than only an algorithm paper with a hardware sketch.

## 2. Major updates that should be explicit in this revision

### 2.1 Exact BSD-stream simulator

Replace the old simulator description everywhere.

Old framing to remove:

- float-valued carrier plus timing metadata as the primary FFN-wide abstraction

New framing to use:

- exact BSD-stream tracking across `gate_proj`, `up_proj`, PWL SiLU, gating, scatter, and `down_proj`
- ready times and overlap metrics derived from the actual stream
- quality and hardware-facing traces produced by the same execution primitive

This should appear in the method section, the simulator section, and the paper contribution summary.

### 2.2 Two orthogonal contribution lines

Keep the architecture split clean:

1. checkpoint-based truncation decides **how much** digit work executes
2. FFN-deep pipeline plus scatter decides **how** that work is transported, overlapped, and localized

Do not let the paper drift back to a single merged mechanism.

### 2.3 No runtime dynamic-budget predictor

Be explicit that this version removes:

- runtime budget deltas
- combined-scale LUT in the runtime control path
- dynamic add path for budget adjustment

This simplification is a feature, not a weakness, because it sharpens the hardware claim.

## 3. Paper structure

A good section order is:

### 3.1 Introduction

Need to establish:

- FFN dominates compute and is difficult to sparsify cleanly under low-precision MX-style quantization
- quantization-first then sparsification-second is not a clean decomposition in LLM FFNs
- the paper instead uses checkpoint-based truncation realized through exact MSD/BSD execution inside a CIM macro
- pipelined scatter is the mechanism that turns staggered completion into overlap and local reduction

The introduction should preview the three claims explicitly.

### 3.2 Background and problem formulation

Cover:

- MX block quantization and BSD / online-arithmetic execution
- why structured sparsity interacts awkwardly with quantized FFNs
- why projection checkpoints are the right truncation locations
- why the stage-1 to stage-2 slice boundary matters for latency and scale-up

### 3.3 Algorithm: calibrated checkpoint budgets

Describe:

- uniform budget baseline
- SNR-calibrated budgets
- fixed-sum calibrated redistribution
- optional activation-only and weight-only heuristics as ablations

This section should emphasize that runtime execution uses the precomputed static budgets.

### 3.4 Architecture: FFN macro with pipelined scatter

This is the core hardware section.

Need to show:

- 32-channel detailed macro as the design unit
- stage-1 owner lanes for `gate_proj` and `up_proj`
- PWL SiLU, align, and gating multiply
- explicit scatter / reduce-scatter boundary
- local stage-2 `down_proj` consumer bank
- counter-based ET with SRAM-loaded budgets
- local ownership and scale-up across larger FFN dimensions

### 3.5 Exact BSD-stream simulator and trace methodology

This section should now be stronger and shorter than before because the modeling choice is cleaner.

Need to explain:

- exact BSD-stream propagation across the FFN
- how ready times, skew, scatter events, FIFO occupancy, and local reduction are measured
- what remains modeled at the event or hardware-estimation level
- a small validation check for scheduler / buffering fidelity

### 3.6 Results

Organize results in this order:

1. calibration predictiveness and smoothness
2. static-budget robustness
3. perplexity frontiers against baselines
4. scatter / overlap / latency evidence
5. net hardware activity and overhead

This ordering makes the logic progressive: first justify the budgets, then show quality, then show why the hardware benefits are real.

### 3.7 Discussion and limits

Use this section to clarify:

- why near-lossless points with about 1 percent zero blocks imply the main benefit is not coarse block gating
- why stage-2 ET may be optional in the mainline design
- what later work could refine without changing the core claim

## 4. Required experiment package for the main body

The main paper should include the following experiments in the core results section.

### 4.1 Calibration package

Required:

- average budget versus target SNR
- signal-power predictiveness
- timing-side predictiveness for scatter-window formation
- static-budget robustness across splits and calibration-set size

### 4.2 Quality frontiers

Required baselines:

- dense MX baseline
- Wanda 2:4 after MXFP8
- uniform-budget MSD
- SNR-calibrated budget
- fixed-sum calibrated budget

Recommended ablation:

- activation-only versus weight-only versus combined assignment signal

### 4.3 Scatter and latency package

Required metrics:

- ready-time skew
- stage-1 completion histogram
- scatter issue histogram
- FIFO occupancy
- consumer early-start fraction
- overlap ratio
- barrier-free latency reduction

### 4.4 Net-overhead package

Required table:

- stage-1 and stage-2 MAC activity
- SRAM reads
- SiLU activity
- FIFO and route-control overhead
- ET counter and metadata storage
- net latency / energy improvement

### 4.5 Small design-space sanity check

Include at least one small sweep over:

- tile shape
- FIFO depth
- or shard count

The goal is just to show that the chosen macro point is reasonable and not hiding a bottleneck.

## 5. Main figures and tables

A compact main-body package could be:

- **Figure 1:** FFN macro overview with explicit scatter boundary
- **Figure 2:** ET controller and timing example with exact BSD streams
- **Figure 3:** calibration smoothness, predictiveness, and robustness
- **Figure 4:** perplexity versus compute frontiers across baselines
- **Figure 5:** scatter / overlap / latency evidence
- **Table 1:** hardware overhead and metadata summary
- **Table 2:** near-lossless operating-point comparison

Appendix candidates:

- activation-only and weight-only details
- per-layer breakdowns
- additional tile-shape and FIFO-depth sensitivity

## 6. Reviewer questions to pre-answer in the writing

### Q1. Why is this a CIM paper rather than an online-arithmetic paper?

Answer in the intro and hardware section:

- the paper is about a CIM-style FFN macro
- the contribution is the organization of stop schedules, local routing, local reduction, and scatter overlap
- online arithmetic is the execution substrate that makes calibrated truncation practical

### Q2. Are the static budgets robust, or are they overfit to calibration data?

Answer with the robustness experiment:

- held-out evaluation split
- calibration-set-size sweep
- report both quality and trace stability

### Q3. Is scatter a real latency mechanism or only a diagramming choice?

Answer with the overlap metrics:

- consumer early-start fraction
- overlap ratio
- barrier-free latency reduction
- representative FIFO and issue traces

### Q4. Is the hardware overhead small after buffering and control are counted?

Answer with the net-overhead table:

- include FIFO, control, and metadata storage explicitly
- avoid reporting only skipped MACs

### Q5. Could the gains come from any nonuniform budget heuristic?

Answer with the assignment-signal ablation:

- activation-only
- weight-only
- combined signal
- fixed-sum redistribution

## 7. Writing guardrails

To keep the paper focused, avoid the following mistakes.

- Do not present the work as a general online-arithmetic paper detached from CIM macro design.
- Do not merge scatter and ET into one vague mechanism.
- Do not emphasize structured sparsity as a straw man; keep the comparison fair and specific.
- Do not spend too much space on optional stage-2 ET unless it materially changes the frontier.
- Do not leave the simulator description in its old float-carrier form.
- Do not claim savings only in terms of skipped blocks, because the current evidence suggests the main effect is reduced active digit work.

## 8. Compact abstract-level message

A reusable compact sentence for the abstract, intro, and conclusion is:

> We present a CIM-oriented FFN macro that uses checkpoint-based MSD truncation to realize calibrated static stop schedules, and an FFN-deep BSD-stream pipeline with pipelined scatter to overlap communication with staggered producer completion while keeping `down_proj` reduction local.

## 9. End-state the paper should reach

After revision, a reviewer should be able to summarize the paper in one line:

- calibration decides where limited cycle budget should go
- the exact BSD-stream macro shows how that policy executes in hardware
- scatter converts staggered completion into measurable latency benefit
- the added runtime mechanism is simple enough to be believable in a CIM setting

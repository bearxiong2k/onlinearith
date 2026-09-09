# ICCAD Rebuttal Draft for Paper #229

We thank the reviewers for the detailed comments. The main numerical evidence is
kept in the PDF attachment; below we map each answer to the reviewer
concerns it addresses.

## Reviewer Response Map

1. #229A/#229E/#229C: hybrid full-model latency with GPU attention/non-FFN work
   included, giving 4.253% decode and 8.014% prefill gain; the TLM-style system
   table also reports 11.6% E2E energy reduction, 4.4% throughput gain, and
   1.1% area overhead for the common-interface point. See Tables A4-A5.
2. #229A/#229D/#229E: larger Qwen models, Llama cross-family results, FP16
   reference PPL, and lower-work operating points. See Tables A1-A3.
3. #229C: mask comparison under explicit hardware assumptions, including the
   activation 2:4 nonzero latency benefit and limits of arbitrary flexible masks.
   See Tables A3, A5, and A5b.
4. #229B/#229C: GLU mapping, $\lambda_x$, calibration, weight recoding, and
   compiler lowering are stated directly in equations below.
5. #229B/#229C/#229D/#229E: non-ideal control overhead, pipelining, offline
   calibration runtime, and $K$ sensitivity. See Tables A6-A8.

## Full-Model Latency And System Cost

For #229A-Q2 and #229E, Table A4 is a measured-GPU plus TLM/CIM hybrid E2E
estimate. The measured GPU denominator includes attention, KV-cache, softmax,
norm, and output work. For the available Qwen3-1.7B split, the measured GPU FFN
share is 9.2% for `decode_s2048` and 17.3% for `prefill_s512`. Replacing only
that derived GPU FFN slice with the TSS FFN ratio gives 4.253% and 8.014%
whole-model latency gains. The replacement equation is:

$$
T_{\mathrm{hybrid}} =
T_{\mathrm{gpu,nonFFN}} +
r_{\mathrm{FFN}}\left(T_{\mathrm{gpu,full}} -
T_{\mathrm{gpu,nonFFN}}\right).
$$

This is not an attention-accelerator claim: the non-FFN path remains GPU-timed.
The decode case prepares a 2048-token KV cache before one-token decode timing,
and the prefill case uses 512 input tokens.

For #229C-Q2, Tables A5/A5b give the common-interface hardware comparison rather
than only control-area discussion. The rows report latency, throughput, energy,
and area under the same dense FFN-macro boundary, so the model graph, projection
interface, and surrounding accelerator stack are unchanged. The TLM-style
simulator counts the difference inside the macro: TSS temporal scheduling versus
the explicit Mask-CIM 2:4 policy. Table A5 makes the system-cost result explicit:
TSS gives 4.3% E2E latency gain, 4.4% throughput gain, and 11.6% E2E energy
reduction with 1.1% area overhead. Mask-CIM 2:4 gives 1.1% latency gain, 1.2%
throughput gain, 7.5% energy reduction, and 11.4% area overhead. The TSS
controller dynamic energy is still proxy-labeled, while the mask row is
formula-backed by the explicit ledger.

For #229C's mask-baseline concern, Table A5b credits activation 2:4 with nonzero
E2E latency gain under a concrete Mask-CIM model. Dense activation reads, mask
generation/control, fixed pipeline stages, output payload, and dense-lane
utilization are retained; selected weight reads and local reduction-tree work
receive the 2-of-4 benefit. We do not assign latency/energy to fully flexible
software masks without a matched CIM routing, buffering, and utilization model.
Thus the Mask-CIM row is a conservative hardware reference, not a claim that all
flexible sparsity hardware is covered. A more flexible mask may remain a stronger
software-selection upper bound; we separate that from hardware latency/energy
claims unless the corresponding CIM implementation is specified.

For #229E's data-plane area concern, the serial-parallel online arithmetic leaf is
treated as common MXFP8 CIM datapath cost rather than a TSS-only block. TSS area
overhead is reflected in the normalized area column of Table A5.

## Generalization And Quality

For #229A-Q1 and #229D-1, Table A1 shows that TSS is not a Qwen3-0.6B-specific
heuristic. In the high-quality 30 dB setting, WikiText-2 perplexity stays within
0.16 PPL of dense MXFP8 across Qwen3-0.6B/1.7B/4B/8B, with FP16, WANDA 2:4, and
activation 2:4 included for context. Table A2 gives the cross-family
Llama-3.2-3B check: dense MXFP8 is 6.5173 PPL, TSS is 6.7859 at 17 dB and 6.5271
at 30 dB, while WANDA 2:4 and activation 2:4 are 15.1917 and 11.0518.

For #229E's full-precision-baseline request, Table A1 includes the FP16 PPL
column beside MXFP8 and TSS. This separates quantization quality from the
additional scheduling effect.

For #229C's concern that flexible masks may have a higher software-level upper
bound, Table A3 states the lower-work 17 dB operating point directly. TSS has the
lowest sparse PPL on Qwen3-0.6B/1.7B/4B; on Qwen3-8B, activation 2:4 has lower
PPL, while TSS still beats WANDA 2:4 and preserves the regular CIM execution
policy. The claim is therefore not universal software dominance. The claim is a
hardware-realizable temporal policy: TSS keeps dense lanes and uses MX exponent
timing to suppress low-significance work, while arbitrary masks require
metadata, selection, routing, payload, and utilization support before assigning
CIM latency or energy.

The mechanism differs from activation-only masking. Dynamic masks usually rank
entries by activation magnitude and prune whole entries. TSS uses activation and
weight block exponents to order contribution timing, then truncates late digits
instead of dropping an entire entry.

## Algorithm, Calibration, And Lowering

For #229B-Q1, Figure 2(a) is a dense GLU-FFN projection dot product. For path
$p\in\{\mathrm{gate},\mathrm{up}\}$ and output channel $c$,

$$
y_p[n,c]=\sum_b\sum_{k=0}^{K-1}x[n,b,k]W_p[c,b,k].
$$

TSS does not change the graph or matrix-vector mapping; it changes the time
window during which aligned MSD-first product streams contribute.
Here block $b$ is the $K$-wide slice of the input vector and the matching
$K$-wide slice of one output-channel weight row.

For #229C-Q3, the runtime delay and effective precision are deterministic:

$$
\begin{aligned}
E[n,c,b] &= \beta_x[n,b]+\beta_w[c,b],\\
D[n,c,b] &= \max_{b'}E[n,c,b']-E[n,c,b],\\
\lambda_x[n,b,k] &=
  \mathrm{sat}\!\left(\max_j e_x[n,b,j]-e_x[n,b,k]\right),\\
\tau[n,c,b,k] &= D[n,c,b]+\lambda_x[n,b,k]+d_{\mathrm{online}},\\
p_{\mathrm{eff}}[n,c,b,k] &= \max(0,H[c]-\tau[n,c,b,k]).
\end{aligned}
$$

Weight block exponents participate in $D$, while stationary weight element
exponents are handled by offline recoding. Runtime control uses narrow integer
add/subtract/max/compare logic rather than floating-point scale computation.

For #229C-Q3 and #229D-2, calibration is also explicit. For each output channel,

$$
H_c=\min\{H:\mathrm{SNR}_c(H)\ge\gamma\}.
$$

Then fixed-sum redistribution moves one cycle of horizon budget from lowest-loss
donors to highest-gain receivers until no swap reduces error. The final artifact
is an integer horizon table; there is no backpropagation or fine-tuning.

For #229B-Q4, the compiler flow is static: identify FFN projections,
MXFP8-quantize, extract $\beta_w/\beta_x$ layouts, recode stationary-weight
digits, calibrate per-channel horizons, and emit tile mappings plus horizon
tables. Runtime consumes the activation/block exponent metadata and emitted
tables; no online graph rewrite is required. Relative to fully spatial sparse
issue, TSS gives up arbitrary per-entry selection in exchange for fixed dense
lanes, block-serial MSD-first timing, and a simpler macro contract.

## Control Path And Pipelining

For #229B-Q2/Q3 and #229C-Q4, the non-ideal control path is already included in
the evaluation model; Table A8 exposes the counted details. The scale prepass
computes $E=\beta_x+\beta_w$, $E_{\max}$, and $D=E_{\max}-E$; the one-block-ahead
scheduler consumes $D$, horizon $H$, and $\lambda_x$; and $\lambda_x$
decode/fanout plus configuration switching are charged through the controller
model. Timing and area are counted for the prepass, scheduler, configuration
storage, and controller rows. Dynamic energy for some controller subblocks
remains proxy-level rather than signoff power, and is labeled as such.
This control is modeled as staged service, not as an extra serial pass: the
prepass, scheduler, $\lambda_x$ decode, and configuration switching feed the
active/shadow buffers one block ahead, so they do not become the data-plane
critical path in the reported setup.

For #229B-Q3, the control is scheduled ahead of the data plane. With the modeled
SRAM/controller stages, next-block control completes within the block-serial
data-plane slot, leaving slack before the next block uses the configuration.
Active/shadow buffering lets configuration update and data execution overlap.
In the current setup, the 3-cycle control pipeline is compared with a 16-cycle
block-serial data-plane slot, leaving roughly 13 cycles of slack after fill
(Table A8). Slower boundary service is handled as a sensitivity case rather than
hidden inside the headline row.

For #229C-Q4, two details matter for source status: the MX exponent broadcast is
already required by the dense MXFP8 path, so TSS does not introduce a new
high-level metadata stream; and the calibrated horizon is a static integer
stored per output channel, not an online optimization variable.

## Calibration Runtime, $K$, And Paper-Edit Notes

For #229D-2 and #229E's offline-phase question, calibration is a one-time,
forward-only procedure per model/configuration and is not on the inference
critical path. The current implementation is not optimized for wall-clock time:
representative runtimes are 2802.9 s for Qwen3-1.7B $K=64$ 17 dB, 2963.4 s for
$K=16$ 17 dB, and 5584.0/5692.0/5868.7 s for Llama-3.2-3B at 17/20/30 dB. These
numbers are implementation costs dominated by exact-MX replay, not algorithmic
lower bounds.

For #229D-3, Table A6 gives a within-sweep Qwen3-1.7B $K$ ablation from $K=8$ to
$128$: the latency-relevant digit-work proxy ranges only 0.465-0.474, so the
block-serial work is stable while metadata scales from 4.00x to 0.25x versus
$K=32$. Smaller $K$ gives finer exponent granularity; larger $K$ reduces
metadata but coarsens the shared scale.

A lightweight per-input adaptation could add a bounded offset from the current
token/block exponent maximum to the stored horizon. This is cheap in hardware
terms because it reuses the existing exponent metadata path, but the reported
results use static offline horizons.

Because the submitted paper cannot be modified during rebuttal, these paper-edit
items are commitments for the accepted version: make the $\tau$ example
consistent, add a small Eq. (4) example, clarify Fig. 1, add process-node
information in Table 1 where known, and fix the Fig. 2 caption typo.

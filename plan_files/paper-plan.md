# paper plan

Title: Temporal Significance Scheduling for low-cost CIM LLM FFN Inference

This work studies a **CIM accelerator for the FFN layers of large language models**.

Existing CIM-oriented low-cost FFN inference is often expressed through sparsity masks or peak-sparsity claims that are either loosely defined algorithmically or difficult to execute on regular arrays. We argue that, for MX-quantized LLM FFNs, the better abstraction is not post-quantization sparsification but **temporal significance scheduling:** MX scales, element exponents, and calibrated budgets are converted directly into useful execution windows, yielding a regular hardware-executable schedule with better quality/work tradeoff.

**Temporal Significance Scheduling** consists of two parts. The first **online** part is a **hierarchical arrival time offset**, which is resolved from MX block scale factor and element exponent from activation and weight combined.The second **offline** part is a **execution window** based on calibration on activation and weight combined.

To realize this **Temporal Significance Scheduling** effectively, we implement online arithmetic in CIM which offer a MSD-first digit-pipelined stream. The MSD-first digit stream based on BSD intermediate representation enabled a stable pipeline through sequential operations, which is the proper object for the **execution window**. Also the temporal alignment from **hierarchical arrival time offset** can be correctly kept through the layers due to stable online delay.

With a **channel-parallel, block-serial** microarchitecture, we realize **temporal significance scheduling** as three level savings in hardware:

- **whole-block skip** when all elements in a block are out of **execution window**
- **element skip** when a specific element is out of **execution window**
- **partial-window execution** when part of the element is out of **execution window**

All owner lanes / channels remain aligned at the tile level, but block computation is **reused over time** instead of being fully spatially unrolled. This preserves the algorithmic behavior while fitting CIM resource constraints.

For each MLP linear layer

\[
\mathrm{out}[n,j] = \sum_b \mathrm{scale}_x[n,b] \cdot \mathrm{scale}_w[j,b] \cdot \mathrm{dot}(x_q[n,b,:], w_q[j,b,:]),
\]

we model temporal usefulness in three steps.

1. **Inter-block delay.** For block `b`, use the block-scale product to determine the coarse delay:

\[
E_i = \left\lfloor \log_2(\mathrm{scale}_x[n,b] \cdot \mathrm{scale}_w[j,b]) \right\rfloor,
\qquad
 d_{\mathrm{inter}} = E_{\max} - E_i.
\]

2. **Intra-block delay.** Within each block, per-element exponent produce a finer timing shift `d_intra`.

3. **Budget calibration.** A per-`output-channel` budget B is calibrated off-line from combined activation and weight scales:

These terms are then converted into the hardware-facing form

\[
t_{\mathrm{arr}} = d_{\mathrm{inter}} + d_{\mathrm{intra}},
\qquad
L = \max(0, B - t_{\mathrm{arr}}),
\]

and the actual executable object is the **useful execution window**

\[
W = (t_{\mathrm{arr}},\; t_{\mathrm{arr}} + L).
\]

With this formulation, the three hardware savings modes become one unified concept:

- **whole-block skip** when all elements in a block have `L = 0`
- **element skip** when a specific element has `L = 0`
- **partial-window execution** when `0 < L < B`

At the hardware level, targeting at LLM FFN, the cleanest implementation remains a **two-plane micro-tile**:

- a **control plane** that computes useful windows one block ahead from budgets, scale metadata, and digit-arrival offsets
- a **data plane** that executes only those windows with block-local serial engines, then exposes a real scatter boundary between stage-1 production and local `down_proj` consumption

Under this organization, `gate_proj` and `up_proj` act as stage-1 producer paths, the nonlinear and gating operations are explicit in-pipeline stages, and `down_proj` is a stage-2 consumer that receives both the intermediate value and its timing/control context. The nonlinear part is represented by an **8-segment PWL SiLU block** that also supports MSD-first online arithmetic. The projection weights remain locally stored. Stage-1 dot products use serial-parallel online arithmetic, while gate fusion uses serial-serial online multiplication. In this way, representation conversion only occur on boundary of FFN layer, reducing overhead introduced by online arithmetic.

This framing also clarifies the streaming story. The FFN should be presented as a **producer-consumer dataflow**, not as three disconnected kernels. Window scheduling reduces the number of digits that are actually generated, while the intermediate representation stays in a **BSD mantissa stream plus a narrow exponent/control stream**.

The simulator already supports this interpretation on top of a modified **Qwen3-0.6B** stack. It implements **MXFP block quantization** (block size 32), uniform and calibrated cycle budgeting derived from combined activation and weight scales, inter-block and intra-block delay modeling, stream/scatter tracing, and full-model perplexity evaluation. This is important because the paper’s empirical story is not only about numerical quality; it is also about whether the temporal schedule maps to a believable hardware trace.

Algorithmically, the budget system remains hierarchical. A **uniform budget** is the simplest control baseline which adopt uniform window. **SNR-calibrated budgets** solve for the minimum per-channel allocation that satisfies a target distortion bound. **Fixed-sum calibration** starts from the SNR-min solution and redistributes cycles across channels to reduce total layer error while preserving exactly the same total hardware budget.

The comparison group should now be defined directly from the motivation. The key baselines are:

- dense MX baseline
- CIM-style activation-gated baseline
- strong offline structured 2:4 baseline
- your uniform / SNR / fixed-sum useful-window methods

So the paper says:

- practice-relevant baseline: we beat the kind of low-cost sparsity mechanisms CIM papers actually use
- strong algorithmic baseline: we remain competitive against a much stronger structured baseline

The claim is that, for CIM FFN acceleration, **the problem is not how to append a sparsification step after quantization; the problem is that sparsity masks are the wrong abstraction. We instead convert existing MX metadata into temporal significance scheduling that CIM hardware can execute through online arithmetic.**.

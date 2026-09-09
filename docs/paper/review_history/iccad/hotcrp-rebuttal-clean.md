# ICCAD Rebuttal for Paper #229

We sincerely thank the reviewers for their insightful and constructive feedback. The attached PDF provides the primary numerical evidence. Below, we address the reviewers' specific concerns, categorized by topic.

## Reviewer Response Map

- **#229A/#229E, Full-model impact:** Hybrid GPU + TLM/CIM latency accounts for attention, KV-cache, softmax, norm, and output work. The resulting end-to-end gains are **4.253% (decode)** and **8.014% (prefill)**. System-level latency/energy/area comparisons for #229C are detailed in Tables A4-A5.
- **#229A/#229D/#229E, Generalization:** Evaluations on larger Qwen models, a Llama cross-family check, FP16 reference PPL, and lower-work operating points are reported in Tables A1-A3.
- **#229C, Mask baseline:** Table A5b evaluates a concrete Mask-CIM 2:4 model, crediting its nonzero latency benefits while distinguishing it from unsupported, arbitrary flexible masks.
- **#229B/#229C, Implementation details:** GLU mapping, $\lambda_x$, calibration, weight recoding, and compiler lowering are clarified below.
- **#229B/#229C/#229D/#229E, Overheads:** Non-ideal control overheads, pipelining, offline calibration runtime, and $K$ sensitivity are summarized below and detailed in Tables A6-A8.

## Full-Model and Hardware-Fair Latency

**Addressing #229A-Q2 and #229E:** Table A4 presents an end-to-end (E2E) latency estimate using a measured-GPU plus TLM/CIM hybrid model. The GPU baseline includes **attention, KV-cache, softmax, norm, and output work**. In the Qwen3-1.7B timing split, the measured GPU FFN share is **9.2%** for `decode_s2048` and **17.3%** for `prefill_s512`. Replacing only this GPU FFN slice with the TSS FFN ratio yields whole-model latency gains of **4.253%** and **8.014%**, respectively:

$$
T_{\mathrm{hybrid}} =
T_{\mathrm{gpu,nonFFN}} +
r_{\mathrm{FFN}}(T_{\mathrm{gpu,full}}-T_{\mathrm{gpu,nonFFN}}).
$$

Importantly, **we do not claim to accelerate attention**; the non-FFN path remains GPU-timed. The decode case prepares a 2048-token KV cache prior to one-token decode timing, and the prefill case uses 512 input tokens.

**Addressing #229C-Q2:** Tables A5/A5b provide a **common-interface hardware comparison** rather than just a control-area discussion. They report latency, throughput, energy, and area under the same dense FFN-macro boundary, ensuring the model graph, projection interface, and surrounding accelerator stack remain unchanged. The TLM-style simulator isolates the difference inside the macro: TSS temporal scheduling versus the explicit Mask-CIM 2:4 policy. In Table A5, TSS yields **0.957 normalized E2E latency**, **1.044 throughput**, **0.884 energy**, and **1.011 area**; Mask-CIM 2:4 yields 0.989, 1.012, 0.925, and 1.114. TSS controller dynamic energy is reported at the proxy level where noted, while the mask row is derived analytically from explicit hardware modeling.

**Addressing #229C (Mask baseline):** Table A5b credits activation 2:4 with **nonzero E2E latency gains** under a concrete Mask-CIM model. Dense activation reads, mask generation/control, fixed pipeline stages, output payload, and dense-lane utilization are retained; selected weight reads and local reduction-tree work receive the 2-of-4 benefit. We avoid assigning latency/energy improvements to fully flexible software masks unless they are paired with matched CIM routing, buffering, and utilization models. Therefore, the Mask-CIM row serves as a **conservative hardware reference**, not a claim that all flexible sparsity hardware is covered.

**Addressing #229E (Data-plane area):** The serial-parallel online arithmetic leaf is treated as a common MXFP8 CIM datapath cost rather than a TSS-exclusive block. TSS area overhead is fully reflected in the normalized area column of Table A5.

## Generalization and Quality

**Addressing #229A-Q1 and #229D-1:** Table A1 demonstrates that TSS is **not a Qwen3-0.6B-specific heuristic**. At the high-quality 30 dB operating point, the additional scheduling loss over dense MXFP8 is at most **0.16 PPL** across Qwen3-0.6B/1.7B/4B/8B (FP16, WANDA 2:4, and activation 2:4 are included for context). Table A2 provides a Llama-3.2-3B cross-family check: dense MXFP8 is 6.5173 PPL, TSS is 6.7859 at 17 dB and **6.5271 at 30 dB**, while WANDA 2:4 and activation 2:4 are 15.1917 and 11.0518, respectively.

**Addressing #229E (Full-precision baseline):** Table A1 places FP16 PPL alongside MXFP8 and TSS, clearly separating quantization loss from the additional scheduling effect.

**Addressing #229C (Flexible masks upper bound):** Table A3 evaluates the lower-work 17 dB operating point. TSS achieves the lowest sparse PPL on Qwen3-0.6B/1.7B/4B. On Qwen3-8B, activation 2:4 has lower PPL, though TSS still outperforms WANDA 2:4 while preserving the regular CIM execution policy. We do not claim universal algorithmic dominance over all software masking techniques. Rather, our core contribution is a **hardware-realizable temporal policy**: TSS maintains dense lanes and uses MX exponent timing to suppress low-significance work, whereas arbitrary masks require extensive metadata, selection, routing, payload, and utilization support before CIM latency or energy benefits can be realized.

Furthermore, our mechanism fundamentally differs from activation-only masking. Dynamic masks typically rank entries by activation magnitude and prune entire entries. In contrast, TSS uses activation and weight block exponents to order contribution timing, truncating late digits rather than dropping an entire entry.

## Algorithm, Calibration, and Lowering

**Addressing #229B-Q1:** Figure 2(a) illustrates a dense GLU-FFN projection dot product. For path $p\in\{\mathrm{gate},\mathrm{up}\}$ and output channel $c$:

$$
y_p[n,c]=\sum_b\sum_{k=0}^{K-1}x[n,b,k]W_p[c,b,k].
$$

TSS does not alter the graph or matrix-vector mapping; it only changes the time window during which aligned MSD-first product streams contribute. Here, block $b$ is the $K$-wide slice of the input vector and the corresponding $K$-wide slice of one output-channel weight row.

**Addressing #229C-Q3:** The runtime control relies entirely on **deterministic integer operations**:

- **Block exponent sum:** $E[n,c,b]=\beta_x[n,b]+\beta_w[c,b]$.
- **Relative block delay:** $D[n,c,b]=\max_{b'}E[n,c,b']-E[n,c,b]$.
- **Activation fine-delay code:** $\lambda_x[n,b,k]=\mathrm{sat}(\max_j e_x[n,b,j]-e_x[n,b,k])$.
- **Arrival time:** $\tau[n,c,b,k]=D[n,c,b]+\lambda_x[n,b,k]$.
- **Effective precision:** $p_{\mathrm{eff}}[n,c,b,k]=\max(0,H[c]-\tau[n,c,b,k])$.

Weight block exponents participate in $D$, while stationary weight element exponents are handled via offline recoding. Concretely, for each stationary weight block, the MX value is written as $w_{c,b,k}=2^{\beta_w[c,b]+e_w[c,b,k]}m_w[c,b,k]$. We select the block-local weight reference $e_w^{\max}[c,b]=\max_k e_w[c,b,k]$ and store the fixed-point aligned word:

$$
q_w[c,b,k]=\mathrm{round}\!\left(m_w[c,b,k]\,2^{e_w[c,b,k]-e_w^{\max}[c,b]}\,2^F\right).
$$

The shared factor $2^{\beta_w[c,b]+e_w^{\max}[c,b]-F}$ is represented by the block timing/scale metadata, while $q_w$ is the signed fixed-point digit stream stored in the CIM weight plane. Thus, runtime control uses narrow integer add/subtract/max/compare logic and avoids decoding per-weight floating-point exponents.

**Addressing #229C-Q3 and #229D-2:** Calibration is similarly explicit:

$$
H_c=\min\{H:\mathrm{SNR}_c(H)\ge\gamma\}.
$$

Fixed-sum redistribution then moves one cycle of horizon budget from lowest-loss donors to highest-gain receivers until no swap reduces error. The final artifact is an **integer horizon table**, requiring **no backpropagation or fine-tuning**.

**Addressing #229B-Q4:** The compiler flow is entirely **static**: identify FFN projections, MXFP8-quantize, extract $\beta_w/\beta_x$ layouts, recode stationary-weight digits, calibrate per-channel horizons, and emit tile mappings plus horizon tables. At runtime, the hardware consumes the activation/block exponent metadata and emitted tables; **no online graph rewriting is required**. Compared to fully spatial sparse scheduling, TSS trades arbitrary per-entry selection for fixed dense lanes, block-serial MSD-first timing, and a simpler macro contract.

## Control Path and Pipelining

**Addressing #229B-Q2/Q3 and #229C-Q4:** The non-ideal control path overheads are **fully accounted for in our evaluation model**; Table A8 details these metrics. The scale prepass computes $E=\beta_x+\beta_w$, $E_{\max}$, and $D=E_{\max}-E$. The one-block-ahead scheduler consumes $D$, horizon $H$, and $\lambda_x$. The $\lambda_x$ decode/fanout and configuration switching are charged through the controller model. Timing and area are counted for the prepass, scheduler, configuration storage, and controller rows. (Dynamic energy for some controller subblocks remains proxy-level rather than signoff power, and is labeled as such).

Crucially, this control is modeled as a staged pipeline rather than an extra serial pass: the prepass, scheduler, $\lambda_x$ decode, and configuration switching feed the active/shadow buffers one block ahead, ensuring they do not become the data-plane critical path.

**Addressing #229B-Q3:** Control is scheduled ahead of the data plane. With the modeled SRAM/controller stages, next-block control completes within the block-serial data-plane slot, leaving slack before the next block uses the configuration. Active/shadow buffering allows configuration updates and data execution to overlap. In the current setup, the **3-cycle control pipeline** is compared against a **16-cycle block-serial data-plane slot**, leaving roughly **13 cycles of slack after fill** (Table A8). Slower boundary service is handled as a sensitivity case rather than being hidden inside the headline results.

**Addressing #229C-Q4:** We highlight two key implementation details: (1) the MX exponent broadcast is already required by the dense MXFP8 path, meaning TSS does not introduce a new high-level metadata stream; and (2) the calibrated horizon is a static integer stored per output channel, not an online optimization variable.

## Calibration Runtime, Block Size, and Revisions

**Addressing #229D-2 and #229E (Offline phase):** Calibration is a **one-time, forward-only** procedure per model/configuration and is **not on the inference critical path**. The current implementation is not optimized for wall-clock time; representative runtimes are 2802.9 s for Qwen3-1.7B $K=64$ at 17 dB, 2963.4 s for $K=16$ at 17 dB, and 5584.0/5692.0/5868.7 s for Llama-3.2-3B at 17/20/30 dB. These represent unoptimized implementation costs dominated by exact-MX replay, not algorithmic lower bounds.

**Addressing #229D-3:** Table A6 presents an ablation study on block size $K$ (from 8 to 128) for Qwen3-1.7B. The sparsity ranges only from **0.465 to 0.474**, indicating that block-serial work is highly stable, even as metadata scales from **4.00x to 0.25x** (relative to $K=32$). The within-sweep PPL is similarly stable: TSS 17 dB PPL ranges from **13.4459 to 13.7575**, with the same-$K$ delta versus MXFP8 bounded between **-0.1165 and +0.1651**. Smaller $K$ provides finer exponent granularity, while larger $K$ reduces metadata overhead but coarsens the shared scale. 

A lightweight per-input adaptation could add a bounded offset from the current token/block exponent maximum to the stored horizon. This would be inexpensive in hardware as it reuses the existing exponent metadata path; however, the reported results rely solely on static offline horizons.

**Commitments for the Camera-Ready Version:** To address minor corrections noted by the reviewers, we commit to the following revisions upon acceptance: making the $\tau$ example consistent, adding a brief example for Eq. (4), clarifying Fig. 1, adding process-node information to Table 1 where available, and correcting the typo in the Fig. 2 caption.

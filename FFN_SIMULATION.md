# MSD-First Online Arithmetic Across the FFN Layer

Detailed technical explanation of how the simulation models MSD-first online arithmetic
through the entire Feed-Forward Network (FFN / MLP) of the Qwen3 transformer.

**Design document:** [Silu-msd_plan.md](Silu-msd_plan.md) — Hardware-perspective SiLU unit design

---

## 1. FFN Layer Structure

The Qwen3 MLP (Gated Linear Unit variant) computes:

$$\text{FFN}(x) = W_\text{down} \cdot \bigl[\text{SiLU}(W_\text{gate} \cdot x) \odot (W_\text{up} \cdot x)\bigr]$$

This decomposes into five computational stages:

| Stage | Operation | Type |
|-------|-----------|------|
| 1a | `gate_out = gate_proj(x)` | GEMM (dot-product) |
| 1b | `up_out = up_proj(x)` | GEMM (dot-product, parallel with 1a) |
| 2 | `silu_out = SiLU(gate_out)` | Nonlinear activation |
| 3 | `gating_out = silu_out ⊙ up_out` | Element-wise multiply |
| 4 | `result = down_proj(gating_out)` | GEMM (dot-product) |

In standard FP16 inference, stages 2 and 3 use exact floating-point arithmetic.
In the MSD-first simulation, **every stage** operates in the time domain with
Binary Signed-Digit (BSD) representation, tracking per-element precision throughout.

---

## 2. Representations and Key Concepts

### 2.1 MXFP Block Quantization

Before MSD truncation, activations and weights are quantized to a Microscaling (MX)
block format (MXFP8, MXFP6, or MXFP4). Each block of 32 elements shares a single
FP8 scale factor:

$$x[n, b, k] = \text{scale}_x[n, b] \cdot x_q[n, b, k]$$

where $b$ is the block index, $k$ is the element within the block, and $x_q$ is the
quantized element value.

### 2.2 BSD (NAF) Representation

The simulation uses Non-Adjacent Form (NAF) as the canonical BSD encoding. NAF has
the minimum-weight property (fewest non-zero digits) and is uniquely determined for
every integer. It is computed via:

```
x_h = x >> 1
s   = x + x_h
naf_pos = s & ~x_h    (positive digit positions)
naf_neg = x_h & ~s    (negative digit positions)
```

Key property: NAF can shift the most-significant-digit position by +1 compared to
plain binary (e.g., `7 = 0b111` in binary but `100(-1)` in NAF = 4 digit positions).
This makes BSD truncation behaviour distinct from binary truncation — the error is
**bidirectional** (can be positive or negative) rather than always rounding toward zero.

### 2.3 BSDMetadata

When BSD representation penetrates through the FFN, each intermediate value carries
per-element metadata:

```python
class BSDMetadata:
    exponent:  (N, dim) float32  # floor(log2(|value|)) per element
    precision: (N, dim) float32  # valid NAF digits remaining
```

This metadata propagates from one stage to the next, allowing downstream operations
to know exactly how many valid digits each input element has.

---

## 3. Stage-by-Stage Simulation

### 3.1 GEMM Stages: gate_proj, up_proj (Stages 1a, 1b)

Each GEMM computes a block-quantized dot-product with MSD truncation. The algorithm
for a single output element `out[n,j]` (sample $n$, output channel $j$):

$$\text{out}[n,j] = \sum_{b=0}^{n_b-1} s_x[n,b] \cdot s_w[j,b] \cdot \sum_{k=0}^{31} x_q[n,b,k] \cdot w_q[j,b,k]$$

**Step 1: Inter-block delay computation**

Each block has a combined scale exponent:

$$E_i[n,j,b] = \lfloor\log_2(s_x[n,b] \cdot s_w[j,b])\rfloor$$

The dominant block has the maximum exponent:

$$E_\text{max}[n,j] = \max_b E_i[n,j,b]$$

In the MSD-first pipeline, all blocks must be aligned to the dominant block's digit
position. Smaller blocks are delayed:

$$\text{inter\_delay}[n,j,b] = E_\text{max}[n,j] - E_i[n,j,b]$$

**Step 2: Intra-block delay computation**

Within each block, element-level activation exponents differ:

$$e_k[n,b,k] = \lfloor\log_2(|x_q[n,b,k]|)\rfloor$$

$$\text{intra\_delay}[n,b,k] = e_\text{max}[n,b] - e_k[n,b,k]$$

Elements with smaller magnitudes start producing significant digits later in the
serial BSD stream.

**Step 3: Budget resolution**

The per-(sample, channel) cycle budget is resolved through a three-tier system:

$$B_\text{final}[n,j] = B_\text{base}[j] + \Delta B[n,j]$$

where $B_\text{base}$ comes from uniform config or offline calibration, and $\Delta B$
is a runtime dynamic adjustment based on combined scale exponents.

**Step 4: Effective precision per element**

$$p_\text{eff}[n,j,b,k] = \max\bigl(0,\ B_\text{final}[n,j] - \text{inter\_delay}[n,j,b] - \text{intra\_delay}[n,b,k] - \delta\bigr)$$

where $\delta$ is the MSD online multiplier delay (default 2 cycles).

**Step 5: BSD (NAF) truncation**

Each partial product $x_q[n,b,k] \cdot w_q[j,b,k]$ is converted to NAF and truncated
to $p_\text{eff}$ most-significant digits. The truncated products are summed and
rescaled by the block scales.

**Step 6: BSD metadata extraction (when returning metadata)**

When the GEMM is asked to return BSD metadata (for use by downstream stages):

$$\text{exponent}[n,j] = \lfloor\log_2(|\text{out}[n,j]|)\rfloor$$
$$\text{precision}[n,j] = \max\bigl(0,\ B_\text{final}[n,j] - \max_b(\text{inter\_delay}[n,j,b]) - \delta\bigr)$$

This precision estimate is conservative (uses the worst-case inter-block delay).

### 3.2 SiLU Activation (Stage 2): PWL Approximation

The SiLU function $f(x) = x \cdot \sigma(x)$ is decomposed as:

$$\text{SiLU}(x) = x \cdot \sigma_\text{PWL}(x)$$

where $\sigma_\text{PWL}$ is a piecewise-linear approximation of the sigmoid function.

#### Hardware Architecture

The SiLU unit is a three-sub-module pipeline (see [Silu-msd_plan.md](Silu-msd_plan.md)):

1. **Segment Detector** (~3 cycles): Reads the first few MSDs of $x$ to determine
   which of $N$ linear segments (default 8) applies. Since $x$ arrives MSD-first,
   the integer part is available within the first 2-3 digits.

2. **Coefficient Lookup** (~0 cycles, pipelined): A small LUT provides slope $a_i$
   and intercept $b_i$ in parallel format (no serialization needed for constants).

3. **Online MAC** (~3 cycles): Computes $a_i \cdot x + b_i$ using an online
   multiplier ($\delta=2$) and online adder ($\delta=1$).

The total SiLU latency is modelled as:

$$\delta_\text{SiLU} = 6 \text{ cycles}$$

(3 detect + 1 PWL eval + 2 online multiply)

#### Simulation Implementation

The PWL sigmoid approximation divides $[-6, 6]$ into $N$ segments (default 8).
For each segment $[x_i, x_{i+1}]$:

$$\sigma_\text{PWL}(x) = a_i \cdot x + b_i$$

where $a_i$ and $b_i$ are computed by linear interpolation of the exact sigmoid at
segment boundaries. Values outside $[-6, 6]$ are saturated (0 or 1).

The simulation uses `torch.searchsorted` for segment detection (modelling the
hardware segment detector) and computes:

```python
silu_out = x * sigmoid_pwl(x)
```

**Precision propagation through SiLU:**

The output precision is the input precision minus the SiLU latency:

$$p_\text{out}[n,j] = \max\bigl(0,\ p_\text{in}[n,j] - \delta_\text{SiLU}\bigr)$$

The result is then truncated to $p_\text{out}$ BSD digits via `_msd_truncate()`.
A new `BSDMetadata` is created from the truncated output.

### 3.3 Gating Multiply (Stage 3): Element-wise `SiLU(gate) ⊙ up`

Two BSD streams — the SiLU output and the up_proj output — are multiplied
element-wise using an online multiplier.

**Precision rule:**

The output precision is limited by the *less precise* of the two inputs, minus the
online multiplier delay:

$$p_\text{gating}[n,j] = \max\bigl(0,\ \min(p_\text{silu}[n,j],\ p_\text{up}[n,j]) - \delta\bigr)$$

where $\delta$ is the online delay (default 2 cycles). The `min` reflects the hardware
constraint that the multiplier cannot produce a digit until both inputs have a digit
available at that position.

The result is truncated to $p_\text{gating}$ digits and a new `BSDMetadata` is created.

### 3.4 down_proj (Stage 4): BSD-Input GEMM

The gating multiply output feeds into `down_proj` as pre-existing BSD data (not
freshly quantized MXFP values). This requires a special GEMM variant that differs
from the standard path in two ways:

1. **No MXFP re-quantization of the input**: The BSD values are directly reshaped into
   blocks and used with unit activation scales ($s_x = 1$). Only the weights are
   MXFP-quantized.

2. **Input precision caps effective precision**: Each input element already has a known
   precision from the gating stage. The effective precision of each partial product is:

$$p_\text{eff}[n,j,b,k] = \min\bigl(p_\text{budget}[n,j,b,k],\ p_\text{input\_bsd}[n,b,k]\bigr)$$

where $p_\text{budget}$ is the standard budget-limited precision (from delays and
budget allocation) and $p_\text{input\_bsd}$ is the per-element input precision from
the gating stage. This models the hardware reality that a serial BSD stream with only
$P$ valid digits cannot contribute more than $P$ digits to a downstream product,
regardless of how many cycles the accumulator runs.

---

## 4. Two Operational Modes

The simulation supports two modes for BSD-penetration FFN, controlled by configuration flags.

### 4.1 Mode 1: BSD Penetration (`msd_bsd_penetration = true`)

**Concept:** Each GEMM stage (gate/up/down) has its own independent cycle budget from
`msd_cycle_budget`. However, data stays in BSD representation between stages — there
is no MXFP re-quantization between gate→SiLU→gating→down.

**Data flow:**

```
x (MXFP input)
├── gate_proj(x, budget=B)  → gate_out, gate_bsd     [standard MSD GEMM]
│       ↓
│   SiLU_PWL(gate_out, gate_bsd)  → silu_out, silu_bsd
│       ↓
├── up_proj(x, budget=B)    → up_out, up_bsd          [standard MSD GEMM]
│       ↓
│   gating_mul(silu_out, silu_bsd, up_out, up_bsd) → gating_out, gating_bsd
│       ↓
└── down_proj(gating_out, input_bsd=gating_bsd, budget=B)  [BSD-input GEMM]
        ↓
    result
```

**Key property:** Each GEMM runs with the full configured budget. The precision loss
through SiLU and gating is modelled explicitly but does not reduce the GEMM budgets.
The down_proj stage benefits from knowing the actual input precision (which may be less
than what a fresh MXFP quantization would provide).

**Config:**
```json
{
  "use_msd_truncation": true,
  "msd_bsd_penetration": true,
  "msd_deep_pipeline": false,
  "msd_cycle_budget": 16
}
```

### 4.2 Mode 2: Deep Pipeline (`msd_deep_pipeline = true`)

**Concept:** The gate_proj→SiLU→gating chain is treated as a single time-domain
pipeline with a unified cycle budget $B_\text{pipe}$. The pipeline budget is split
between the GEMM stages and the intermediate operations.

**Cycle allocation:**

$$T_\text{gemm} = B_\text{pipe} - \delta_\text{SiLU} - \delta_\text{online}$$

where:
- $B_\text{pipe}$ = `msd_pipeline_budget` (default 24 cycles)
- $\delta_\text{SiLU}$ = 6 cycles (PWL SiLU latency)
- $\delta_\text{online}$ = 2 cycles (gating multiplier delay)

This gives $T_\text{gemm} = 24 - 6 - 2 = 16$ cycles for each GEMM (gate and up).

**Data flow:**

```
x (MXFP input)
├── gate_proj(x, budget=T_gemm) → gate_out, gate_bsd    [budget overridden]
│       ↓
│   SiLU_PWL(gate_out, gate_bsd) → silu_out, silu_bsd   [costs δ_SiLU cycles]
│       ↓
├── up_proj(x, budget=T_gemm)   → up_out, up_bsd        [budget overridden]
│       ↓
│   gating_mul(silu_out, silu_bsd, up_out, up_bsd) → gating_out, gating_bsd
│       ↓                                               [costs δ_online cycles]
└── down_proj(gating_out, input_bsd=gating_bsd, budget=B_std)
        ↓                                               [independent budget]
    result
```

**Key property:** The pipeline budget governs the total time for the gate→SiLU→gating
chain. The down_proj stage is *not* part of the pipeline — it receives an independent
budget from `msd_cycle_budget`. This is because down_proj's input must be transposed
(the output dimension of gate/up becomes the input dimension of down), which is a
natural pipeline break point.

**Implementation detail:** The simulation temporarily overrides `config.msd_cycle_budget`
to $T_\text{gemm}$ for the gate and up projections, then restores it before down_proj.
This ensures the existing per-channel budget resolution machinery (calibration, dynamic
adjustment) applies at the reduced budget.

**Config:**
```json
{
  "use_msd_truncation": true,
  "msd_deep_pipeline": true,
  "msd_pipeline_budget": 24,
  "msd_cycle_budget": 16,
  "msd_silu_pwl_segments": 8
}
```

### 4.3 Mode Comparison

| Aspect | Mode 1 (BSD Penetration) | Mode 2 (Deep Pipeline) |
|--------|-------------------------|------------------------|
| gate/up GEMM budget | `msd_cycle_budget` (full) | $B_\text{pipe} - \delta_\text{SiLU} - \delta_\text{online}$ |
| down_proj budget | `msd_cycle_budget` (full) | `msd_cycle_budget` (independent) |
| SiLU cost | Precision loss on output only | Subtracted from pipeline budget |
| Gating cost | Precision loss on output only | Subtracted from pipeline budget |
| Total cycles per FFN | $3 \times B_\text{cycle}$ | $B_\text{pipe} + B_\text{cycle}$ (2 stages) |
| Use case | Maximum per-GEMM precision | Time-constrained pipeline |
| Hardware model | Independent GEMM engines | Single pipeline engine + separate down_proj |

---

## 5. Precision Propagation Through the FFN

The diagram below traces per-element precision through all FFN stages with concrete
numbers (Mode 2, $B_\text{pipe}=24$, $\delta=2$, $\delta_\text{SiLU}=6$):

```
gate_proj GEMM (budget = T_gemm = 16)
│
│  Typical p_eff after delays: ~12 digits (varies per element)
│  → gate_bsd.precision ≈ B_final - max_inter_delay - δ ≈ 12
│
↓ SiLU_PWL  (costs δ_SiLU = 6 cycles)
│
│  p_silu = max(0, gate_bsd.precision - 6) ≈ 6 digits
│  Truncate to 6 NAF digits
│
↓ Gating multiply  (costs δ_online = 2 cycles)
│
│  up_bsd.precision ≈ 12 (from up_proj)
│  p_gating = max(0, min(p_silu, p_up) - 2) = max(0, min(6, 12) - 2) = 4
│  Truncate to 4 NAF digits
│
↓ down_proj BSD-input GEMM (budget = B_std = 16)
│
│  Input precision = gating_bsd.precision ≈ 4
│  p_eff = min(budget_limited, input_precision) — input precision is the bottleneck
│  Effective precision capped at 4 for most elements
│
↓ result
```

This shows the precision funnel effect: the pipeline budget of 24 cycles yields
approximately 4 effective precision digits at the down_proj input. The per-element
variation comes from the actual delay profile of each channel.

---

## 6. BSD-Input GEMM: Detailed Algorithm

The BSD-input variant (`_forward_msd_truncated_bsd_input`) differs from the standard
MSD GEMM in how it handles input activations. Here is the step-by-step:

**Standard GEMM path (gate_proj, up_proj):**
1. Quantize input $x$ to MXFP → get $x_q$ (quantized) and $s_x$ (block scales)
2. Use $x_q$ and $s_x$ in the delay/budget/truncation pipeline
3. Return output + optional BSDMetadata

**BSD-input GEMM path (down_proj with `input_bsd`):**
1. Skip MXFP quantization entirely — use raw float values
2. Reshape input into blocks: $x_\text{blocks}[n, n_b, b_s]$
3. Set $s_x = 1$ for all blocks (no block scaling on input side)
4. Compute block-level exponents: $e_\text{max}[n,b] = \lfloor\log_2(\max_k |x_\text{blocks}[n,b,k]|)\rfloor$
5. Compute intra-block delays normally from element exponents
6. Compute inter-block delays from weight scales only (since $s_x = 1$)
7. Compute budget-limited precision $p_\text{budget}$ as usual
8. **Cap by input BSD precision:**

$$p_\text{eff}[n,j,b,k] = \min(p_\text{budget}[n,j,b,k],\ p_\text{input\_bsd}[n, b \cdot 32 + k])$$

9. Truncate products and accumulate as normal

The `min` in step 8 is the key difference. It models the physical constraint that a
BSD digit stream with only $P$ valid digits cannot contribute more than $P$ digits
to any downstream computation, regardless of how long the accumulator runs.

---

## 7. PWL Sigmoid: Implementation Details

### 7.1 LUT Construction

The function `_build_pwl_sigmoid_lut(n_segments, device)` constructs the lookup table:

1. Divide $[-6, 6]$ into `n_segments` equal intervals
2. Evaluate exact $\sigma(x) = 1/(1+e^{-x})$ at each boundary
3. Compute slope and intercept per segment by linear interpolation:

$$a_i = \frac{\sigma(x_{i+1}) - \sigma(x_i)}{x_{i+1} - x_i}$$
$$b_i = \sigma(x_i) - a_i \cdot x_i$$

The LUT is cached per (n_segments, device) combination.

### 7.2 Evaluation

The function `_pwl_sigmoid(x, n_segments=8)`:

1. Use `torch.searchsorted` to find segment index for each element (models the
   leading-digit segment detector in hardware)
2. Evaluate $a_i \cdot x + b_i$ (models the online MAC: multiply by parallel
   coefficient, add parallel intercept)
3. Clamp result to $[0, 1]$

### 7.3 Full SiLU with BSD Metadata

The function `_msd_silu_pwl(x, input_bsd, n_segments, online_delay)`:

1. Compute PWL sigmoid: $\sigma_\text{PWL}(x)$
2. Compute SiLU: $y = x \cdot \sigma_\text{PWL}(x)$
3. Compute output precision: $p_\text{out} = \max(0, p_\text{in} - \delta_\text{SiLU})$
4. Truncate $y$ to $p_\text{out}$ NAF digits
5. Compute output exponent from truncated result
6. Return $(y_\text{truncated}, \text{BSDMetadata}(e_\text{out}, p_\text{out}))$

---

## 8. Gating Multiply: Implementation Details

The function `_msd_gating_mul(silu_val, silu_bsd, up_val, up_bsd, online_delay)`:

1. Compute output precision:
$$p_\text{gating} = \max\bigl(0,\ \min(p_\text{silu}, p_\text{up}) - \delta\bigr)$$

2. Compute element-wise product: $y = \text{silu\_val} \times \text{up\_val}$

3. Truncate to $p_\text{gating}$ NAF digits

4. Compute output exponent from truncated result

5. Return $(y_\text{truncated}, \text{BSDMetadata}(e_\text{out}, p_\text{gating}))$

The `min(p_silu, p_up)` reflects the hardware reality that an online multiplier
cannot produce valid output digits faster than its slowest input stream.

---

## 9. Configuration Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `msd_bsd_penetration` | bool | false | Enable Mode 1: BSD representation flows through the entire FFN without MXFP re-quantization between stages |
| `msd_deep_pipeline` | bool | false | Enable Mode 2: Unified pipeline budget for gate→SiLU→gating chain |
| `msd_pipeline_budget` | int | 24 | Pipeline cycle budget $B_\text{pipe}$ (Mode 2 only). GEMM budget = $B_\text{pipe} - \delta_\text{SiLU} - \delta_\text{online}$ |
| `msd_silu_pwl_segments` | int | 8 | Number of linear segments for PWL sigmoid approximation |
| `msd_cycle_budget` | int | 16 | Standard per-GEMM cycle budget (Mode 1: all GEMMs; Mode 2: down_proj only) |
| `msd_online_delay` | int | 2 | Online multiplier delay $\delta$ (used in GEMM, SiLU, and gating) |

### Interaction between modes

- If both `msd_bsd_penetration` and `msd_deep_pipeline` are true, **Mode 2 takes priority**
- If neither is true, each GEMM (gate/up/down) runs standard MSD truncation independently, and SiLU + gating use exact FP16 arithmetic
- `msd_pipeline_precision_loss` is **deprecated** (kept for backward compatibility with old deep pipeline code)

---

## 10. Implementation Files

| File | Role |
|------|------|
| `modular_qwen3.py` | Reference implementation — edit here |
| `modeling_qwen3.py` | Production copy with output-chunked MSD for large matrices |
| `configuration_qwen3.py` | Config class with all MSD/BSD/pipeline fields |

### Key functions (both files)

| Function | Purpose |
|----------|---------|
| `_msd_truncate(value, num_digits)` | Core BSD (NAF) truncation to N most-significant digits |
| `BSDMetadata` | Per-element exponent + precision tracking |
| `_extract_bsd_metadata(output, b_final, inter_delays, online_delay)` | Extract BSD metadata from GEMM output |
| `_build_pwl_sigmoid_lut(n_segments, device)` | Construct PWL sigmoid LUT |
| `_pwl_sigmoid(x, n_segments)` | Evaluate PWL sigmoid (cached) |
| `_msd_silu_pwl(x, input_bsd, n_segments, online_delay)` | SiLU with BSD metadata propagation |
| `_msd_gating_mul(silu_val, silu_bsd, up_val, up_bsd, online_delay)` | Element-wise gating multiply |
| `_forward_msd_truncated(self, x, w_q, ...)` | Standard MSD GEMM (with optional BSD metadata return) |
| `_forward_msd_truncated_bsd_input(self, x, x_bsd, w_q, ...)` | BSD-input GEMM variant |
| `Qwen3MLP.forward(x, compute_context)` | Mode dispatch (Mode 1 / Mode 2 / standard MSD / exact) |

---

## 11. Hardware Correspondence

The simulation maps to the following hardware components:

| Simulation Operation | Hardware Unit | Cycle Cost |
|---------------------|---------------|------------|
| `_forward_msd_truncated` | MSD-first CiM dot-product array | $B_\text{budget}$ cycles per output |
| `_pwl_sigmoid` searchsorted | Segment detector (leading-digit evaluator) | ~3 cycles |
| sigmoid × input | Online multiplier (serial × parallel) | ~2 cycles |
| intercept addition | Online adder (pipelined) | ~1 cycle |
| `_msd_gating_mul` | Online element-wise multiplier | $\delta$ = 2 cycles |
| `_msd_truncate` | Hardware early termination (stop clocking after P digits) | 0 (implicit) |
| `_forward_msd_truncated_bsd_input` | CiM array with pre-existing BSD input stream | $B_\text{budget}$ cycles (capped by input precision) |
| FIFO delay buffer | up_proj result holds in buffer during SiLU | $\delta_\text{SiLU}$ = 6 entries |

The simulation does not model:
- Actual FIFO buffering between stages (assumes instant availability after delay)
- Pipeline stalls or backpressure
- Clock gating for zero-precision elements (modelled as `p_eff=0` in statistics)
- Power consumption (deferred to hardware simulation using the collected statistics)



  

Research codebase for MSD plan

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modular_qwen3.py#1-1), lines 1 to 200

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/configuration_qwen3.py#1-1), lines 1 to 200

Read [](file:///home/xzjnew/coding/transformers/AGENTS.md)

Read [](file:///home/xzjnew/coding/onlinearith/260227-proposal_summary.md)

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modular_qwen3.py#200-200), lines 200 to 490

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/configuration_qwen3.py#200-200), lines 200 to 211

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py)

Read [](file:///home/xzjnew/coding/onlinearith/ppltest.py)

Read [](file:///home/xzjnew/coding/onlinearith/benchmarktest.py)

Read [](file:///home/xzjnew/coding/onlinearith/qwen3test.py)

Read [](file:///home/xzjnew/coding/onlinearith/260223-plan.md)

Read [](file:///home/xzjnew/coding/onlinearith/260223-plan-gemini.md)

Read [](file:///home/xzjnew/coding/onlinearith/260225-claude-codes.md)

Searched for text `compute_context`, 17 results

Searched for regex `online arithmetic|msd|bsd|truncat|cycle_budget`, 20 results

Searched for regex `class LlamaAttention` (`**/llama/modeling_llama.py`), 1 result

Searched for regex `class Qwen2ForCausalLM|class Qwen2Model` (`**/qwen2/modeling_qwen2.py`), 2 results

Searched for regex `class GemmaMLP` (`**/gemma/modeling_gemma.py`), 1 result

Searched for regex `class Qwen2DecoderLayer` (`**/qwen2/modeling_qwen2.py`), 1 result

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/llama/modeling_llama.py#225-225), lines 225 to 340

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen2/modeling_qwen2.py#272-272), lines 272 to 500

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/gemma/modeling_gemma.py#69-69), lines 69 to 120

Read [](file:///home/xzjnew/coding/transformers/src/transformers/activations.py#1-1), lines 1 to 100

Read [](file:///home/xzjnew/coding/transformers/src/transformers/activations.py#100-100), lines 100 to 361

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen2/modeling_qwen2.py#500-500), lines 500 to 526

Searched for files matching `**/qwen3/modeling_qwen3.py`, 1 match

Searched for regex `class |def forward|Placeholder|MSB|bit.serial` (`**/qwen3/modeling_qwen3.py`), 20 results

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#540-540), lines 540 to 700

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#700-700), lines 700 to 873

Read [](file:///home/xzjnew/coding/onlinearith/benchmarktest.py#37-37), lines 37 to 37

Read [](file:///home/xzjnew/coding/onlinearith/visualization.py#1-1), lines 1 to 60

Read [](file:///home/xzjnew/.vscode-server/data/User/workspaceStorage/49e6463a24a579a2cff5c98e66379afe/GitHub.copilot-chat/chat-session-resources/bdb3641a-8e86-49e4-ae5f-293d8f09bd45/toolu_bdrk_01PpRaa3uVDvAQR67uA2UxoK__vscode-1772261587800/content.txt)

Good research. I have a thorough understanding of the codebase. Let me clarify a few design decisions before drafting the plan. 

Asked 4 questions (Sim fidelity, Deep pipe, Budget calib, Sim mode)

Full scope selected. Let me gather more detail on the intra-block element structure and activation function internals to make the plan precise. 

Deep dive intra-block & activation

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modular_qwen3.py#1-1), lines 1 to 300

Searched for text `class Qwen3DecoderLayer`, 1 result

Searched for text `class Qwen2DecoderLayer`, 2 results

Searched for text `class SiLUActivation`, 1 result

Searched for text `class Qwen3Attention`, 3 results

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modular_qwen3.py#300-300), lines 300 to 490

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#540-540), lines 540 to 750

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen2/modeling_qwen2.py#272-272), lines 272 to 430

Read [](file:///home/xzjnew/coding/transformers/src/transformers/activations.py#90-90), lines 90 to 130

Searched for text `class LlamaAttention`, 1 result

Searched for regex `lm_head\s*=` (`**/qwen2/modeling_qwen2.py`), 1 result

Searched for regex `lm_head\s*=` (`**/qwen3/modeling_qwen3.py`), 1 result

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/llama/modeling_llama.py#225-225), lines 225 to 310

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen2/modeling_qwen2.py#430-430), lines 430 to 525

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#750-750), lines 750 to 873

Read [](file:///home/xzjnew/.vscode-server/data/User/workspaceStorage/49e6463a24a579a2cff5c98e66379afe/GitHub.copilot-chat/chat-session-resources/bdb3641a-8e86-49e4-ae5f-293d8f09bd45/toolu_bdrk_01XsqEBSkpUbScKmXRZN8Xv9__vscode-1772261587834/content.txt)

All research complete. Here's the detailed implementation plan:

---

## Plan: MSD-First Time-Domain Truncated Dot-Product Simulation

The existing Qwen3 modular file has working MX-format block-wise linear layers (`MXFP8/6/4Linear`). We will add an MSD-first truncated dot-product simulation mode that models: (1) two-level delayed-start (inter-block from shared scales, intra-block from activation element exponents), (2) hybrid per-channel cycle budgeting with offline calibration and dynamic activation override, (3) cross-layer deep pipelining through the MLP structure. A new `use_msd_truncation` config flag selects between exact MX matmul and MSD-truncated matmul. All changes go exclusively into modular_qwen3.py and configuration_qwen3.py, per AGENTS.md rules.

**Steps**

### Step 1 — Configuration Surface

Add the following fields to `Qwen3Config` in configuration_qwen3.py:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `use_msd_truncation` | `bool` | `False` | Enable MSD-first truncated dot-product mode (only has effect when an MXFP format is also active) |
| `msd_cycle_budget` | `int` | `16` | Global default cycle budget $B_{base}$ when no per-channel calibration data exists |
| `msd_online_delay` | `int` | `2` | MSD multiplier online delay $\delta$ (digits before first valid product digit) |
| `msd_budget_dynamic_scale` | `float` | `1.0` | Scaling factor $\alpha$ for the dynamic activation override: $B_{final} = B_{base} + \alpha \cdot \max(0, E_{act} - E_{threshold})$ |
| `msd_budget_dynamic_threshold` | `float` | `0.0` | Threshold $E_{threshold}$ for dynamic budget increase — only activation blocks with $E_{act}$ above this get extra budget |
| `msd_deep_pipeline` | `bool` | `False` | Enable cross-layer MSD streaming through MLP (gate→silu→×up→down) |
| `msd_pipeline_precision_loss` | `int` | `2` | Per-stage precision loss (in digits) for each pipeline stage in deep pipelining mode |
| `msd_calibration_data` | `dict \| None` | `None` | Stores per-layer, per-channel offline $B_{base}$ values (populated by calibration utility) |

All fields are plain keyword arguments in `__init__`, assigned with plain `Assign` (not `AnnAssign`) to satisfy the modular converter.

### Step 2 — ComputeContext Data Structure

Add a new class `MSDComputeContext` in modular_qwen3.py (before `_MXFPLinearBase`):

- Fields:
  - `layer_idx` (`int`) — current decoder layer index
  - `channel_budgets` (`dict[str, Tensor]`) — maps layer name (e.g., `"layers.0.mlp.gate_proj"`) → per-output-channel $B_{base}$ tensor of shape `(out_features,)`
  - `pipeline_precision_remaining` (`Tensor | None`) — for deep pipelining: per-element precision budget carried from previous pipeline stage, shape `(batch, seq_len, hidden_size)`
  - `activation_scales` (`dict[str, Tensor]`) — cached intermediate activation shared scales for dynamic budget override

- Factory method `from_config(config, model)` — initialises from config, loading calibration data if available, or filling uniform default $B_{base}$.

- Must be a plain class (not dataclass with annotations) to survive the modular converter. Use `__init__` with plain attribute assignments.

### Step 3 — Two-Level Delay Calculation

Add two module-level helper functions in modular_qwen3.py:

**`_compute_inter_block_delays(w_scales, x_scales)`**
- Inputs: `w_scales` shape `(out, num_blocks)`, `x_scales` shape `(N, num_blocks)` — the fp32 shared scales already computed by `_quantize_to_blocks`
- Compute combined log2 scale per block: $E_i = \lfloor\log_2(w\_scales \cdot x\_scales)\rfloor$ — shape `(N, out, num_blocks)` via broadcasting
- For each (n, j) output element: $E_{max}^{n,j} = \max_i E_i^{n,j}$
- $\Delta E_i^{n,j} = E_{max}^{n,j} - E_i^{n,j}$ — shape `(N, out, num_blocks)`
- Return `inter_block_delays` of shape `(N, out, num_blocks)` and `E_max` of shape `(N, out)`

**`_compute_intra_block_delays(x_q_blocks)`**
- Input: `x_q_blocks` shape `(N, num_blocks, block_size)` — quantized activation elements (float32)
- For each element: $e_j = \lfloor\log_2(|x_{q,j}|)\rfloor$ (use -inf or large value for zeros to get max delay)
- Per-block max: $e_{max} = \max_j e_j$ within each block
- $\delta e_j = e_{max} - e_j$ — shape `(N, num_blocks, block_size)`
- For zero elements: set $\delta e_j$ to a large value (effectively infinite delay → element contributes 0)
- Return `intra_block_delays` of shape `(N, num_blocks, block_size)`
- Note: only computed for activations. Weights are offline fixed-point aligned (no intra-block delay).

### Step 4 — MSD Truncation Primitive

Add a function `_msd_truncate(value, num_digits)`:

- Input: `value` (float32 tensor, any shape), `num_digits` (int tensor, same shape or broadcastable)
- For each element: truncate to `num_digits` most significant binary digits from the MSD
- Implementation:
  ```
  If num_digits <= 0: return 0
  abs_v = |value|
  msb_pos = floor(log2(abs_v))  # position of MSB
  quantum = 2^(msb_pos - num_digits + 1)  # value of the least significant kept digit
  result = trunc(value / quantum) * quantum  # keep only top num_digits bits
  ```
- Handle zeros (return 0) and clamp `num_digits` to `[0, format_total_bits]`
- This is a vectorized operation — no loops

### Step 5 — Element-Level Truncated Dot Product

Add method `_forward_msd_truncated` to `_MXFPLinearBase`:

This replaces the inner `bmm + combined_scales.sum()` path when `use_msd_truncation` is True.

Algorithm per output element `(n, j)`:
1. Get `x_q_blocks` shape `(N, nb_x, bs)`, `x_scales` shape `(N, nb_x)` from `_prepare_blocks` (already done)
2. Get `w_q_blocks` shape `(out, nb_w, bs)`, `w_scales` shape `(out, nb_w)` from `_prepare_blocks` (already done)
3. `nb = nb_x = nb_w` (same padding applied to both)
4. Compute `inter_block_delays` from `_compute_inter_block_delays(w_scales, x_scales)` — shape `(N, out, nb)`
5. Compute `intra_block_delays` from `_compute_intra_block_delays(x_q_blocks)` — shape `(N, nb, bs)`
6. Determine `B_final` per output channel:
   - Load `B_base` per channel from `compute_context.channel_budgets[layer_name]` — shape `(out,)`, or use `config.msd_cycle_budget` as uniform default
   - Compute dynamic override from activation shared scale: $E_{act} = \lfloor\log_2(\max_i x\_scales_i)\rfloor$ per sample n — shape `(N,)`
   - $B_{final}^{n,j} = B_{base}^{j} + \alpha \cdot \max(0, E_{act}^n - E_{threshold})$ — shape `(N, out)`
7. For each block i, element j:
   - `total_delay_ij = inter_block_delays[n, out_ch, i] + intra_block_delays[n, i, j] + online_delay`
   - `P_ij = max(0, B_final[n, out_ch] - total_delay_ij)`
8. Compute element-wise products: `prod_ij = w_q[out_ch, i, j] * x_q[n, i, j]`
9. Truncate each: `prod_trunc_ij = _msd_truncate(prod_ij, P_ij)`
10. Sum within block: `block_dp_i = sum_j(prod_trunc_ij)` — shape `(N, out, nb)`
11. Apply shared scales: `result = sum_i(block_dp_i * w_scales[out_ch, i] * x_scales[n, i])` — shape `(N, out)`

**Performance note:** Step 7-10 operates on shape `(N, out, nb, bs)` which is very large. For efficiency:
- Compute all products at once: `prods = einsum("nib, oib -> noib", x_q, w_q)` — may be memory-intensive for large models
- Alternative: process blocks in a loop over `nb` (outer) to control peak memory — add a config field `msd_block_batch_size` to control this tradeoff
- For the Qwen3-0.6B model (`hidden_size=1024`, `intermediate_size=3072`, `block_size=32`): `nb = 1024/32 = 32`, so the full tensor is `(N, 3072, 32, 32)` which is manageable

### Step 6 — Modify `_MXFPLinearBase.forward()`

In modular_qwen3.py, update `_MXFPLinearBase.forward()`:

- Keep the existing code path as-is for `use_msd_truncation = False`
- After computing `x_q, x_scales, w_q, w_scales`, branch:
  - If `self.config.use_msd_truncation` (stored in `__init__`): call `self._forward_msd_truncated(x_q, x_scales, w_q, w_scales, compute_context)`
  - Else: existing `bmm + combined_scales.sum()` path
- Store `config` reference in `__init__` (currently not stored by `_MXFPLinearBase`, though subclasses access it via `_get_block_size`)
- Add `self.layer_name` attribute (set externally during model init or via a registration hook) for looking up per-channel budgets

### Step 7 — compute_context Plumbing

Thread `MSDComputeContext` through the model hierarchy. This requires overriding several classes in modular_qwen3.py:

**7a. Override `Qwen3DecoderLayer`** (currently auto-generated from Qwen2, not in modular file):
- Add it explicitly to the modular file, inheriting from `Qwen2DecoderLayer`
- Override `forward()` to extract `compute_context` from `**kwargs` and pass it to `self.mlp(hidden_states, compute_context=compute_context)`
- Signature: `forward(self, hidden_states, ..., **kwargs)` — `compute_context` arrives via `**kwargs` which are already propagated from `Qwen2Model.forward()`

**7b. Update `Qwen3MLP.forward()`**:
- Change signature: `forward(self, x, compute_context=None)`
- Pass `compute_context` to each `_make_linear`-created projection: `self.gate_proj(x, compute_context=compute_context)`, etc.
- For deep pipelining (Step 10), this is where the precision budget propagation happens

**7c. Update `Qwen3ForCausalLM.forward()`**:
- Create `MSDComputeContext.from_config(self.config, self.model)` at the start of inference
- Pass it as a kwarg to `self.model(...)` — it will propagate through `**kwargs` down the chain: `Qwen2Model.forward(**kwargs)` → `decoder_layer(**kwargs)` → extracted in `Qwen3DecoderLayer.forward()`

**7d. Layer name registration**: After `__init__` of `Qwen3ForCausalLM`, iterate `self.model.named_modules()` and for each `_MXFPLinearBase` instance, set `module.layer_name = name` (e.g., `"model.layers.0.mlp.gate_proj"`).

### Step 8 — Hybrid Glocal Budgeting

Implement the per-channel budget resolution inside `_forward_msd_truncated`:

- **Offline base budget** (`B_base`): loaded from `compute_context.channel_budgets[self.layer_name]` — a tensor of shape `(out_features,)` stored after calibration
- **Dynamic activation override**: the activation's per-block shared scales `x_scales` are used to compute $E_{act} = \lfloor\log_2(\max_i x\_scales_i)\rfloor$ for each sample. The override is a step/linear function:
  - $\Delta B_{dynamic} = \alpha \cdot \max(0, E_{act} - E_{threshold})$
  - $B_{final} = B_{base} + \Delta B_{dynamic}$
  - Clamp $B_{final}$ to `[0, max_possible_precision]`

The step function variant: $\Delta B_{dynamic} = B_{step}$ if $E_{act} > E_{threshold}$ else $0$ — selectable via a config flag `msd_budget_dynamic_mode` (`"linear"` or `"step"`).

### Step 9 — Calibration Utility

Create a new file calibration_msd.py (standalone utility, not part of the modular/modeling pair):

**`calibrate_channel_budgets(model, tokenizer, calibration_dataset, num_samples=128, target_snr_db=30.0)`**:
1. Run a forward pass with `use_msd_truncation = False` (exact MX mode) on calibration data
2. For each MXFP linear layer, hook into `_prepare_blocks` to record:
   - Per-channel activation scale distributions (histograms of `x_scales`)
   - Per-channel weight scale distributions (`w_scales`)
   - Per-channel output sensitivity (gradient of loss w.r.t. channel output, if labels available, or use output magnitude as proxy)
3. For each output channel j of each layer:
   - Compute the distribution of inter-block delays $\Delta E_i$ across calibration data
   - Compute the distribution of intra-block delays $\delta e_{ij}$
   - Find the minimum budget $B_{base}^{j}$ such that the expected truncation error (from the delay distributions) keeps the channel's SNR above `target_snr_db`
   - Alternatively: binary-search $B_{base}^{j}$ such that the fraction of zeroed-out elements stays below a target sparsity threshold
4. Store results in `config.msd_calibration_data` as `{"layer_name": [list of per-channel budgets]}`
5. Save updated config via `config.save_pretrained()`

**`apply_calibration_to_config(config, calibration_data)`**: loads the calibration dict into config fields.

### Step 10 — Deep Pipelining (Cross-Layer MSD Streaming)

When `msd_deep_pipeline = True`, the MLP operates in a streaming mode where intermediate precision is tracked:

**10a. MSD-domain SiLU approximation**:
- True MSD-first SiLU requires an online divider (for sigmoid) and an online multiplier ($x \cdot \sigma(x)$) — expensive to simulate exactly digit-by-digit.
- **Simulation approach**: apply standard `F.silu()` to the truncated intermediate tensor, then further reduce precision by `msd_pipeline_precision_loss` digits. This models the information loss from MSD streaming through a nonlinear function.
- Add a helper `_msd_silu(x, precision_digits)`: applies SiLU, then `_msd_truncate(result, precision_digits)`.
- Rationale: the MSD-first SiLU's output has the same MSBs as the true SiLU applied to the truncated input, with error growing in the LSBs — truncation after SiLU captures this.

**10b. MSD-domain element-wise multiply**:
- The product of two $P$-digit MSD values produces a $2P$-digit result, but the output stream only retains $P - \delta$ digits (where $\delta$ is the online multiplier delay).
- Helper `_msd_elementwise_mul(a, b, precision_digits)`: computes `a * b`, then `_msd_truncate(result, precision_digits)`.

**10c. Update `Qwen3MLP.forward()` for deep pipelining**:
```
if config.msd_deep_pipeline and compute_context is not None:
    # Stage 1: gate_proj and up_proj (independent, parallel)
    gate_out = self.gate_proj(x, compute_context=compute_context)  # MSD-truncated
    up_out = self.up_proj(x, compute_context=compute_context)      # MSD-truncated
    
    # Track precision: output of each dot-product has B_final effective digits
    # (stored in compute_context.pipeline_precision_remaining after forward)
    P_gate = compute_context.pipeline_precision_remaining  # set by gate_proj.forward
    P_up = compute_context.pipeline_precision_remaining    # set by up_proj.forward
    
    # Stage 2: SiLU on gate output (online delay = msd_pipeline_precision_loss)
    P_after_silu = P_gate - config.msd_pipeline_precision_loss
    silu_out = _msd_silu(gate_out, P_after_silu)
    
    # Stage 3: element-wise multiply (online multiplier delay)
    P_after_mul = min(P_after_silu, P_up) - config.msd_online_delay
    intermediate = _msd_elementwise_mul(silu_out, up_out, P_after_mul)
    
    # Stage 4: down_proj consumes the truncated intermediate
    # Adjust compute_context to reflect reduced input precision
    compute_context.pipeline_precision_remaining = P_after_mul
    result = self.down_proj(intermediate, compute_context=compute_context)
    return result
else:
    return self.down_proj(self.act_fn(self.gate_proj(x)) * self.up_proj(x))
```

**10d. Precision propagation in `_forward_msd_truncated`**:
- When `compute_context.pipeline_precision_remaining` is set (not None), the input to this linear layer is already precision-limited. The effective budget for the dot product should account for this: digits beyond the input precision are meaningless.
- Adjust: `P_ij = min(P_ij, input_precision * appropriate_factor)`
- After computation, set `compute_context.pipeline_precision_remaining` to the output precision (minimum effective precision across channels, or a per-channel tensor).

### Step 11 — Attention Projections (Optional Extension)

Currently, attention projection layers (`q_proj`, `k_proj`, `v_proj`, `o_proj`) are plain `nn.Linear` inherited from `LlamaAttention`. If MSD simulation should also cover attention:
- Override `Qwen3Attention.__init__` to optionally replace projection layers with `_make_linear(...)` (gated by a config flag like `use_mxfp_attention`)
- Thread `compute_context` through `Qwen3Attention.forward()` to the projection calls
- This is a separable concern — can be deferred without affecting MLP simulation

### Step 12 — Testing

**12a. Unit tests** — extend test_mxfp8linear.py:
- Test `_compute_inter_block_delays`: known scales → known delays
- Test `_compute_intra_block_delays`: known quantized activations → known element delays
- Test `_msd_truncate`: spot-check truncation of known values to known digit counts
- Test full `_forward_msd_truncated` with a small (4×4, block_size=2) example where the hand-computed answer is known
- Test that `B = ∞` (very large budget) reproduces the exact MX result
- Test that `B = 0` produces all-zero output

**12b. Integration test** — extend ppltest.py:
- Run PPL eval with MSD truncation at various cycle budgets (e.g., B=8, 12, 16, 20, 24, 32)
- Compare against exact-MX baseline
- Record and plot PPL vs. cycle budget curve

**12c. Calibration test**:
- Run calibration on a small WikiText-2 subset
- Verify that per-channel budgets are reasonable (no NaN, within expected range)
- Re-run PPL with calibrated budgets and verify improvement over uniform budget

**12d. Deep pipelining test**:
- Compare MLP output with `msd_deep_pipeline=True` vs `False` at same cycle budget
- Verify that deep pipelining introduces controlled additional error

### Step 13 — Run Modular Converter

After all changes to modular_qwen3.py and configuration_qwen3.py:
- Run `python utils/modular_model_converter.py qwen3` from the transformers root
- Verify the generated modeling_qwen3.py contains all new functions, classes, and the `MSDComputeContext`
- Verify all plain `Assign` variables are present (not dropped by the converter)
- Run `make style` to fix formatting

**Verification**

- `python -m pytest test_mxfp8linear.py -v` — all unit tests pass
- `python onlinearith/ppltest.py` with `use_msd_truncation=True, msd_cycle_budget=32` — PPL should match exact-MX baseline (budget equals full precision ≈ no truncation)
- `python onlinearith/ppltest.py` with `msd_cycle_budget=16` — PPL degrades measurably but model still coherent
- Calibration utility produces valid per-channel budgets; calibrated PPL < uniform-budget PPL
- Deep pipeline mode: PPL at same budget is slightly worse than non-pipeline (expected from cascading precision loss)
- `python utils/modular_model_converter.py qwen3` succeeds without errors
- `make style` passes

**Decisions**

- **Truncation modeled per-element within blocks** (not per-block aggregate) to capture intra-block sparsity from activation exponent spread
- **SiLU in deep pipeline: apply float SiLU then truncate** — simulates digit-loss from MSD nonlinear evaluation, avoids implementing a true digit-serial SiLU (which would require CORDIC-style decomposition)
- **Weight intra-block: no delay** — weights are pre-aligned to fixed-point offline per the spec; only activation elements have intra-block delays
- **Memory management**: the `(N, out, nb, bs)` product tensor can be large; provide a `msd_block_batch_size` config to process blocks in chunks if needed
- **Calibration stored in config** rather than separate weight tensors — keeps it portable and compatible with `save_pretrained`/`from_pretrained`
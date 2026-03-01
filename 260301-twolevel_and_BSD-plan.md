User: We are working on a project to implement MSD-first online arithmatic simulation on qwen3 model for inference and investigate the accuracy loss of such arithmatic behaviour. Currently we have completed the basic structure of the simulation, and realized a primitive version of MSD arithmatic in modeling.py (from a certain point on we decided to modify modeling.py regardless of the standard procedure for simplicity) and a basic framework for future deep pipelining. Now in this iteration, I want to refine our MSD arithmatic simulation to better reflect the targeted hardware behaviour. To be more specific, current model 
1. truncates the calculation in binary representation while actual MSD arithmatic runs in BSD representation, for a more accurate simulation. The truncation should be done in BSD representation.
2. decides the dynamic budget only according to activation scale, while in our design combined scale of activation and weight is already available and allow a better prediction of the scale of final result of the channel. So the dynamic budget should be decided according to combined scale.
In this iteratoin, we improve our simulation focusing on these two limitations, which are also described in the comments in modeling.py. Remember to save the verifiaction test for future examination and update the readme.md. Due to a server busy situation, now I only have access to 1 rtx4090 with 16 GB memory idle, stick to single card test if you ever need heavy tests.

GitHub Copilot: 

  

Research current MSD implementation

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#1-1), lines 1 to 200

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py#1-1), lines 1 to 200

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/configuration_qwen3.py#1-1), lines 1 to 200

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#200-200), lines 200 to 500

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py#200-200), lines 200 to 478

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/configuration_qwen3.py#200-200), lines 200 to 251

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#500-500), lines 500 to 800

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#800-800), lines 800 to 1100

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#1100-1100), lines 1100 to 1334

Searched for regex `TODO|todo|Todo|BSD|combined scale` (`**/qwen3/modular_qwen3.py`), no results

Searched for regex `TODO|todo|Todo|BSD|combined.scale` (`**/qwen3/modular_qwen3.py`), 5 results

Searched for regex `Todo|BSD|truncat` (`**/qwen3/modular_qwen3.py`), 20 results

Searched for regex `Todo:|todo:` (`**/qwen3/modular_qwen3.py`), no results

Searched for regex `Todo|todo|TODO` (`**/modeling_qwen3.py`), 3 results

Read [](file:///home/xzjnew/.vscode-server/data/User/workspaceStorage/49e6463a24a579a2cff5c98e66379afe/GitHub.copilot-chat/chat-session-resources/5921cc1e-ca1b-48c0-9a3d-310f45cd521a/toolu_bdrk_01ExjoquvjabxrrSwwva2DvT__vscode-1772261588027/content.txt#1-1), lines 1 to 200

Read [](file:///home/xzjnew/.vscode-server/data/User/workspaceStorage/49e6463a24a579a2cff5c98e66379afe/GitHub.copilot-chat/chat-session-resources/5921cc1e-ca1b-48c0-9a3d-310f45cd521a/toolu_bdrk_01ExjoquvjabxrrSwwva2DvT__vscode-1772261588027/content.txt#200-200), lines 200 to 388

Good, I have the subagent's summary. Now let me read the exact source lines for the key functions and the full test file to have precise context for creating the plan.   

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#170-170), lines 170 to 210

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#285-285), lines 285 to 460

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py#230-230), lines 230 to 460

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py#460-460), lines 460 to 478

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#440-440), lines 440 to 500

Now let me also read the MLP forward and the deep pipeline helpers more carefully: 

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modeling_qwen3.py#690-690), lines 690 to 830

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/configuration_qwen3.py#90-90), lines 90 to 251

Now I have full context on both changes. Let me verify the test runner and README structure:  

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py#1-1), lines 1 to 30

Read [](file:///home/xzjnew/coding/onlinearith/README.md#1-1), lines 1 to 50

Read [](file:///home/xzjnew/coding/onlinearith/test_mxfp8linear.py#28-28), lines 28 to 55

Searched for regex `_msd_truncate|_compute_inter_block_delays|_compute_intra_block_delays` (`**/onlinearith/test_mxfp8linear.py`), 14 results

Now let me also check the imports from modular_qwen3 vs modeling_qwen3: 

Searched for text `from transformers.models.qwen3.modular_qwen3 import` (`**/onlinearith/test_mxfp8linear.py`), 1 result

Good — tests import from `modular_qwen3`. Let me check whether both modular and modeling contain the same implementations: 

Searched for regex `def _msd_truncate|def _resolve_channel_budgets|def _forward_msd_truncated` (`**/transformers/src/transformers/models/qwen3/modular_qwen3.py`), 3 results

Both modular and modeling have the same functions. Since the user says they modify modeling_qwen3.py directly now (for simplicity), and tests import from modular_qwen3.py, I need to check if both files are kept in sync or if one is the canonical source. 

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modular_qwen3.py#260-260), lines 260 to 300

Read [](file:///home/xzjnew/coding/transformers/src/transformers/models/qwen3/modular_qwen3.py#400-400), lines 400 to 560

I now have thorough context on the entire codebase. Let me present the implementation plan.

---

## Plan: BSD Truncation & Combined-Scale Dynamic Budget

**TL;DR:** Two refinements to the MSD-first simulation:  
(1) Replace binary truncation in `_msd_truncate` with BSD/NAF-based truncation to properly model the Binary Signed-Digit hardware behavior — this changes how products are truncated under cycle budgets (e.g., `truncate(7.0, 2)` yields `8.0` in BSD vs `6.0` in binary, because NAF represents 7 as `100(-1)` i.e. 8−1).  
(2) Replace activation-only dynamic budgeting in `_resolve_channel_budgets` with combined activation+weight scale budgeting, since the hardware already computes the combined scale for inter-block delays and this gives per-output-channel budget adjustment instead of per-sample-only. Both modeling_qwen3.py and modular_qwen3.py need updates; tests import from `modular_qwen3`.

**Steps**

### 1. Implement BSD/NAF truncation — `_msd_truncate` 

Replace the function at modeling_qwen3.py (line 180) and modular_qwen3.py (line 267).

The new `_msd_truncate` will:
- Extract sign and work with `abs_v`
- Scale absolute value to a 24-bit integer mantissa (matching float32 precision)
- Convert integer to NAF (Non-Adjacent Form, the canonical BSD representation with fewest non-zero digits) using the vectorized identity: `x_h = x >> 1; s = x + x_h; naf_pos = s & ~x_h; naf_neg = x_h & ~s`
- Find the NAF MSD position (highest set bit in `naf_pos | naf_neg`), which can be **1 higher** than the binary MSB due to carry absorption
- Truncate by masking out NAF digits below position `(naf_msd - num_digits + 1)`
- Reconstruct: `result = sign * (naf_pos_trunc - naf_neg_trunc).float() / scale_up`
- Use `int32` tensors (not `int64`) since mantissa ≤ 24 bits — this keeps the memory overhead minimal within the existing output-chunked loop

Key behavioral changes from binary:
- BSD truncation error can be positive or negative (binary always rounds toward zero)
- NAF may use more digit positions than binary (e.g., 7 = `111` binary = 3 digits, but `100(-1)` NAF = 4 digits), so the same `num_digits` budget produces different results
- `truncate(7.0, 2)` → `8.0` (was `6.0`); `truncate(3.0, 2)` → `4.0` (was `3.0`); `truncate(5.0, 2)` → `4.0` (unchanged)

### 2. Implement combined-scale dynamic budget — `_resolve_channel_budgets`

Modify the method at modeling_qwen3.py (line 286) and modular_qwen3.py (line 408).

**Signature change:** Add `w_scales` parameter: `_resolve_channel_budgets(self, compute_context, x_scales, w_scales, N)`

**New logic:**
- Compute `e_combined = max_b(floor(log2(x_scale[n,b] · w_scale[j,b])))` → shape `(N, out)`, which is the per-(sample, output-channel) maximum combined log2 scale
- Use `e_combined` instead of `e_act` (activation-only) for threshold comparison and delta_b calculation
- `delta_b` is now `(N, out)` instead of `(N,)`, giving per-output-channel dynamic budget adjustment — channels with large combined scales get bigger budgets, channels with small scales get smaller budgets

The `(N, out, nb)` intermediate tensor is needed for the `amax`. For Qwen3-0.6B with N=1 (autoregressive), this is ~100 KB — trivial. For PPL evaluation (N=4096, out=3072, nb=32), it's ~1.5 GB; acceptable on 16 GB RTX 4090 since it's created and deleted immediately.

### 3. Update `_forward_msd_truncated` callers in both files

In modeling_qwen3.py (chunked version, line 349): pass `w_scales` to the updated `_resolve_channel_budgets` call at the pre-loop stage.

In modular_qwen3.py (non-chunked version, line 449): same — add `w_scales` to the `_resolve_channel_budgets` call.

Remove the stale TODO/Todos comments in both files:
- modeling_qwen3.py: "truncate on Binary representation" → update to "now uses BSD/NAF"
- modeling_qwen3.py: "dynamic budgeting currently only uses activation scales" → update
- modeling_qwen3.py: "Dynamic budget need to consider shared scale" → update
- modeling_qwen3.py: "the dynamic budget should be computed here with combined" → update
- modeling_qwen3.py: "current truncation is based on the binary representation" → update

### 4. Update `_msd_silu` and `_msd_elementwise_mul` docstrings

At modeling_qwen3.py and modular_qwen3.py: update docstrings to note they now truncate in BSD/NAF representation.

### 5. Update existing tests in test_mxfp8linear.py

- **`test_msd_truncate_basic`** ([line 250](onlinearith/test_mxfp8linear.py#L250)): Update expected values:
  - `truncate(7.0, 2)` → expect `8.0` (was `6.0`)
  - `truncate(-7.0, 2)` → expect `-8.0` (was `-6.0`)
  - Zero case, `num_digits=0` case, near-lossless case, batch shape — unchanged
- **`test_msd_budget_infinity`** ([line 370](onlinearith/test_mxfp8linear.py#L370)): Should still pass (B=999 → near-lossless)
- **`test_msd_budget_zero`** ([line 396](onlinearith/test_mxfp8linear.py#L396)): Should still pass (B=0 → zero output)
- **`test_msd_budget_sweep_monotonic`** ([line 410](onlinearith/test_mxfp8linear.py#L410)): Should still pass with possible minor threshold adjustment

### 6. Add new BSD-specific test: `test_msd_truncate_bsd_properties`

Add after the existing `test_msd_truncate_basic`. Tests:
- **NAF MSD shift:** `truncate(7.0, 3)` = 7.0 (NAF `100(-1)` has 4 digits; keep 3 → `100` = 8? No, keeping 3 means positions 3,2,1 → 1×8 + 0×4 + 0×2 = 8; keeping 4 → full value = 7). Actually let me recalculate: 7 in NAF = `1,0,0,-1` at positions 3,2,1,0. Keep 4 digits = all → 7.0. Keep 3 = positions 3,2,1 → 8.0. Keep 2 = positions 3,2 → 8.0. So: `truncate(7.0, 4)` should equal `7.0`, `truncate(7.0, 3)` should equal `8.0`.
- **Sign symmetry:** `truncate(x, p) == -truncate(-x, p)` for several test values
- **Bidirectional error:** Verify that BSD truncation error can be positive (e.g., `truncate(7.0, 2)` = 8.0, error = +1) — unlike binary which always has non-negative error for positive values
- **Binary-BSD agreement for NAF-identical values:** `truncate(5.0, 2)` = 4.0 (same as binary, because 5=`101` is already NAF)
- **Large precision = no truncation:** `truncate(v, 30)` ≈ v for various v

### 7. Add new test: `test_combined_scale_budget`

Verify the combined-scale budget logic:
- Construct an `_MXFPLinearBase` layer with weights where different output channels have very different weight scales (e.g., one channel has very large weights, another very small)
- With uniform activation input, the combined scales will differ per output channel
- Assert that `b_final[n, j]` is higher for the high-scale output channel than for the low-scale channel
- Test both `"linear"` and `"step"` modes

### 8. Update README.md

- **Section 8 (Architecture Overview) → "MSD Truncation Algorithm"**: Update step 5 from "Truncation: Each product is truncated to P most significant binary digits" to "Truncation: Each product is truncated to P most significant BSD (NAF) digits"
- **Section 8**: Add note explaining BSD truncation behavior (carry absorption, bidirectional error)
- **Section 8**: Update budget description from "activation-scale dynamic override" to "combined activation+weight scale dynamic override"
- **Section 3 (MSD Config Fields)**: Update `msd_budget_dynamic_scale` and `msd_budget_dynamic_threshold` descriptions to reference combined scale instead of activation scale
- **Section 9 (Known Limitations)**: Add item noting NAF is used as the specific BSD representation (the actual hardware digit stream may differ from NAF) and remove the completed items about binary truncation and activation-only budget
- **Section 6 (Running Unit Tests)**: Add the new BSD and combined-scale tests to the test list

**Verification**

1. Run unit tests: `cd /home/xzjnew/coding && python onlinearith/test_mxfp8linear.py` — all tests including new BSD-specific and combined-scale tests should pass on a single GPU
2. Spot-check: `test_msd_budget_infinity` (B=999) still gives SNR >60 dB, confirming BSD doesn't break near-lossless behavior
3. Spot-check: `test_msd_budget_sweep_monotonic` still shows monotonically decreasing error with increasing budget
4. Optional PPL sanity check (single RTX 4090): Run `python onlinearith/ppltest.py` with MXFP8+MSD B=16 to get a single PPL result and compare against the previous binary-truncation result

**Decisions**
- **NAF as BSD representation:** Chose Non-Adjacent Form (canonical, minimum-weight BSD) over arbitrary BSD or stochastic simulation. NAF is deterministic, uniquely defined, and captures the key hardware behavior (carry-free addition, potential MSD shift). The actual online arithmetic digit stream depends on computation order and isn't reproducible without full digit-serial simulation.
- **int32 for NAF conversion:** Chose int32 over int64 to minimize memory overhead within the output-chunked MSD loop. Product mantissas fit comfortably in 24 bits.
- **Combined scale computed inside `_resolve_channel_budgets`:** The method computes the `(N, out, nb)` intermediate internally and deletes it immediately, keeping the API change minimal (just adding `w_scales`).
- **Both files updated:** Both modeling_qwen3.py and modular_qwen3.py need changes since tests import from modular_qwen3.py and inference uses modeling_qwen3.py.
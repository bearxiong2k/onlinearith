# Deep Pipeline Mode Design

## Overview

Deep pipeline mode simulates explicit MSD (Most Significant Digit) digit timing flow through the FFN (Feed-Forward Network) stages in the Qwen3 model. Unlike the previous scalar-budget proxy implementation, this rebuild uses a **float carrier + timing metadata** model that accurately tracks when MSD digits arrive at each pipeline stage.

## Architecture

### Core Design Decision

Use explicit timing metadata (`first_cycle`) rather than persistent BSD (Binary Signed-Digit) mantissa streams. This preserves the production-ready chunked GEMM infrastructure while adding cross-stage timing ownership where it matters.

**Key principle**: The real mismatch in the previous simulator was missing **cross-stage timing ownership**, not missing BSD storage.

### Data Structures

```python
@dataclass
class PreparedFFNInput:
    """Pre-quantized FFN input shared by gate_proj and up_proj."""
    x_q: torch.Tensor        # (N, nb, bs) quantized blocks
    x_scales: torch.Tensor   # (N, nb) block scales
    x_fp32: torch.Tensor     # (N, hidden) original float32

@dataclass
class MSDFlowTensor:
    """Float carrier + timing metadata for deep pipeline."""
    value: torch.Tensor        # (N, C) float32 numeric value
    first_cycle: torch.Tensor  # (N, C) first MSD digit arrival time
```

### FFN Pipeline Flow

```
Input (N, hidden)
    ↓
[Prepare once] → PreparedFFNInput
    ↓           ↓
gate_proj    up_proj  (producer mode: exact MX + first_cycle)
    ↓           ↓
MSDFlowTensor  MSDFlowTensor
    ↓
[PWL SiLU] → MSDFlowTensor
    ↓           ↓
    [Gating Multiply] → MSDFlowTensor
            ↓
        down_proj (consumer mode: timing propagation)
            ↓
        Output (N, hidden)
```

## Budget Ownership: Two Domains

### Stage-1 Shared Owner Domain

Owner budget lives on the **intermediate channel** `i`:

```
B_stage1[n, i]
```

Governs:
- `gate_proj` output
- `SiLU` computation
- `SiLU(gate) * up` gating multiply

**Rationale**: `gate_proj` and `up_proj` share the same intermediate index, while `down_proj` transposes/fans out over hidden output channels.

### Stage-2 Consumer Domain

`down_proj` keeps its own output-channel budget:

```
B_down[n, h]
```

Governs only `down_proj` itself. Does **not** propagate backward into stage 1.

### Budget Resolution

In deep pipeline mode:
- Local `gate_proj` / `up_proj` truncation is **off by default**
- Their outputs are governed by the stage-1 shared endpoint budget instead
- `down_proj` uses its own budget with upstream timing propagation

## PWL SiLU Implementation

### Mathematical Model

```
SiLU(x) = x * sigmoid(x) ≈ x * PWL_sigmoid(x)
```

### 8-Segment PWL Approximation

**Breakpoints**: `[-∞, -4, -2, -1, 0, 1, 2, 4, ∞]`

**Segment selection**: Uses actual float `x` value (0-cycle cost in hardware simulation)

**Latency model**:
- Segment detect: 0 cycles
- PWL affine MAC: 3 cycles
- SiLU multiply: 2 cycles
- **Total fixed SiLU latency**: 5 cycles

### Configuration

```python
msd_silu_num_segments = 8
msd_silu_pwl_mac_delay = 3
msd_silu_mul_delay = 2
msd_pipeline_gate_mul_delay = 2  # gating multiply delay
```

**Coefficients**: Placeholder values in code; should be fitted during calibration for minimal SiLU error, ideally weighted by observed `up_proj` magnitude distribution.

## Stage-1 Flow Equations

Let:
- `gate_flow = gate_proj.forward_producer_flow(entry, ctx)`
- `up_flow = up_proj.forward_producer_flow(entry, ctx)`
- Shared owner budget `B_stage1[n, i]`

Then:

```python
# Gate truncation
p_gate = clamp(B_stage1 - gate_flow.first_cycle, min=0)
gate_live = _msd_truncate(gate_flow.value, p_gate)

# PWL sigmoid (3-cycle MAC delay)
sig_raw = pwl_sigmoid(gate_live)
sig_first = gate_flow.first_cycle + 3
sig_live = _msd_truncate(sig_raw, clamp(B_stage1 - sig_first, min=0))

# SiLU multiply (2-cycle delay)
silu_raw = gate_live * sig_live
silu_first = max(gate_flow.first_cycle, sig_first) + 2
silu_live = _msd_truncate(silu_raw, clamp(B_stage1 - silu_first, min=0))

# Up truncation
p_up = clamp(B_stage1 - up_flow.first_cycle, min=0)
up_live = _msd_truncate(up_flow.value, p_up)

# Gating multiply
mul_first = max(silu_first, up_flow.first_cycle) + d_gate_mul
mul_live = _msd_truncate(
    silu_live * up_live,
    clamp(B_stage1 - mul_first, min=0)
)

mid_flow = MSDFlowTensor(value=mul_live, first_cycle=mul_first)
```

**Important**: Alignment is handled by `max(...)`. The earlier path is **buffered**, not penalized. No ad hoc "subtract offset digits" rule needed.

## Consumer Mode (down_proj)

`down_proj` consumes `mid_flow` with upstream timing propagation:

```python
# Reshape mid_flow into blocks (no requantization)
x_blocks, x_scales, _ = _prepare_blocks(
    mid_flow.value, N, quantize_elements=False
)

# Compute down-proj total delay with upstream arrival
total_delay = (
    input_arrival +           # upstream first_cycle
    inter_delay +             # block-level delay
    intra_delay +             # element-level delay
    online_delay
)

# Effective precision
p_eff = clamp(B_down - total_delay, min=0)

# Truncate and sum
result = truncate_and_sum(x_blocks * w_q, p_eff, scales)
```

**Key point**: No intermediate requantization. Float32 carrier flows through the full FFN, cast back to original dtype only after FFN exit.

## Execution Modes in _MXFPLinearBase

### 1. Producer Flow Mode

- Exact MX numeric output (no local truncation by default)
- Computes `first_cycle` using delay machinery
- Returns `MSDFlowTensor`
- Used by `gate_proj` and `up_proj`

### 2. Consumer Flow Mode

- Accepts `MSDFlowTensor` input
- Propagates upstream `first_cycle`
- No intermediate numeric requantization
- Used by `down_proj`

### 3. Standalone MSD Mode

- Existing behavior (unchanged)
- Uses `_forward_msd_truncated()`
- Used when deep pipeline is disabled

## Calibration Strategy

### Two-Pass Calibration

**Pass A: Stage-1 Shared Budget**

Calibration key:
```json
"model.layers.L.mlp.pipeline_mul": [...]
```

Target:
```
m_exact = SiLU(g_exact) * u_exact
```

Binary search for budget vector over intermediate channels.

**Pass B: down_proj Budget**

Freeze the approximate stage-1 output and calibrate `down_proj` against the true final FFN output.

Calibration key:
```json
"model.layers.L.mlp.down_proj": [...]
```

### Usage in Deep Pipeline Mode

- Ignore `gate_proj` and `up_proj` local calibration entries
- Use only `pipeline_mul` + `down_proj` budgets
- For fixed-sum redistribution: operate over `pipeline_mul` channels, not separately over gate/up

## Dynamic Budgeting

**v1 policy**: Stage-1 shared dynamic adjustment is **disabled by default**.

**Rationale**: Stage-1 has two producer paths with different dynamic scales and different precision sensitivity. A bad shared dynamic rule will be noisy.

**Future extension**: If adding dynamic shared budgeting later, compute it at the **stage-1 owner endpoint**, not independently on `gate_proj` and `up_proj`. Build a shared delta:

```
ΔB_stage1 = f(max(E_up, E_silu))
```

## Performance Metrics

Extended `MSDPerfAccumulator` tracks pipeline-specific metrics:

- `producer_first_cycle_mean/max`: First digit arrival time from producers
- `stage1_budget_utilization`: Budget usage at stage-1 endpoint
- `gate_up_wait_mean/max`: Alignment delays between paths
- `silu_segment_histogram`: PWL segment selection distribution
- `down_proj_input_arrival_mean/max`: Upstream timing at down_proj input

Metrics can be recorded as:
- Pipeline subsection under each MLP layer, or
- Pseudo-layer names like `layers.L.mlp.pipeline_mul`

## Implementation Notes

### Entry Point Preparation

```python
def _prepare_ffn_input_once(x, gate_proj_layer):
    """Prepare quantized FFN input once, shared by gate_proj and up_proj."""
    rows = x.shape[0] if x.dim() == 2 else x.view(-1, x.shape[-1]).shape[0]
    x_q, x_scales, _ = gate_proj_layer._prepare_blocks(
        x.view(rows, -1), rows, quantize_elements=True
    )
    return PreparedFFNInput(x_q=x_q, x_scales=x_scales, x_fp32=x)
```

### First Cycle Computation

Conservative v1 definition:

```
t_first(n, i) = max_{b,k}(inter_delay + intra_delay + online_delay)
```

Easy to extract from existing total-delay logic. Matches "critical path is basically fixed" observation. Can be refined later if too pessimistic.

### Memory Management

- Producer mode uses chunked exact-MX path (not unchunked `torch.bmm`)
- Consumer mode derives block structure without numeric requantization
- All chunking preserves existing memory limits (~512 MiB target)

## Configuration Example

```python
config = Qwen3Config(
    # Enable deep pipeline
    msd_deep_pipeline=True,
    use_msd_truncation=True,

    # Budget settings
    msd_cycle_budget=16,
    msd_online_delay=2,

    # PWL SiLU timing
    msd_silu_num_segments=8,
    msd_silu_pwl_mac_delay=3,
    msd_silu_mul_delay=2,
    msd_pipeline_gate_mul_delay=2,

    # Calibration data (from two-pass calibration)
    msd_calibration_data={
        "model.layers.0.mlp.pipeline_mul": [...],
        "model.layers.0.mlp.down_proj": [...],
        # ... for all layers
    }
)
```

## Usage

```bash
# Enable deep pipeline in setup
python ppltest.py --setup 20 --nproc 8

# Calibrate deep pipeline budgets (two-pass)
python calibrate.py --deep-pipeline --nproc 4

# Run with calibrated budgets
python ppltest.py --setup 20 --calibration calibration_deep_pipeline.json --nproc 8

# Visualize performance stats
python perf_viz.py ppl_results_deep_pipeline.json
```

## Verification

After implementation:

1. **Unit tests**: Verify core MSD truncation still works
2. **Distributed tests**: Verify multi-GPU compatibility
3. **Light PPL test**: Quick forward pass validation
4. **Full PPL test**: Measure perplexity impact
5. **Calibration test**: Verify two-pass calibration converges
6. **Perf stats**: Check pipeline-specific metrics in output JSON

## Future Extensions

### Fixed-Sum Calibration

Redistribute cycles from high-error to low-error channels while preserving total budget. Operate over `pipeline_mul` channels (shared intermediate index) rather than separately over gate/up.

### Dynamic Shared Budgeting

Add runtime adjustment at stage-1 endpoint based on combined activation+weight scale exponents. Use conservative policy to avoid noise from dual producer paths.

### Refined First Cycle

Replace conservative max-delay with more accurate per-element arrival tracking if profiling shows significant pessimism.

## References

- Original design document: Plan provided by user
- MSD truncation: `_msd_truncate()` in `modeling_qwen3.py`
- Calibration system: `calibration_msd.py`
- Performance stats: `msd_perf_stats.py`

# Hardware design

Status: revised paper-planning description of the target architecture
Scope: custom stage-1 `gate_proj` and `up_proj` hardware only

This note gives the paper-facing hardware organization. The binding simulator
contract remains the
[active hardware architecture contract](../../../hardware_sim/docs/architecture_contract.md),
which owns exact encodings, widths, rounding, saturation, and transaction
semantics.

The vocabulary is:

- **paper-level principle:** temporal significance scheduling;
- **algorithmic object:** local execution windows on aligned contribution
  streams;
- **hardware realization:** a metadata-first control plane feeding a
  channel-parallel, block-serial fixed-point data plane.

The central dataplane decision is:

> At runtime, the schedule forms a target activation mantissa. A standard
> fixed-point multiplier multiplies that target by one offline-aligned,
> fixed-point weight element.

This is not a runtime activation-digit × weight-digit engine. There is no
recoded weight-digit stream, serial-parallel multiplier leaf, online-adder
tree, custom stage-2 `down_proj` engine, or stage-1/stage-2 packet interface.

## 1. Architecture boundary

The custom tile covers the scheduled stage-1 projection work for
`p in {gate_proj, up_proj}`:

1. metadata prepass and local-window control;
2. runtime target-activation formation;
3. reads of offline-aligned fixed-point weights;
4. standard fixed-point multiplication;
5. block reduction and per-channel accumulation.

SiLU, gate/up fusion, `down_proj`, and the rest of the model may be included as
explicit common terms in an end-to-end evaluation, but they are outside this
custom datapath. The design therefore makes no payload-compression,
packetization, boundary-buffer, shard-routing, or queueing claim.

The planning default retains block size `K = 32`. A tile has `N_lane` channel
lanes; channels execute in parallel across lanes, while input blocks for one
channel execute serially on reused arithmetic resources. Whether the two
projection paths duplicate or time-share physical multiplier lanes is an
implementation parameter to freeze before RTL.

```text
                         METADATA / CONTROL PLANE
ACT metadata ----------> scale prepass (active/shadow banks)
WEIGHT metadata ------->        |
                                 v
                         one-block-ahead window builder
                                 |
                                 v
                         target-formation configuration

                           STAGE-1 DATA PLANE
quantized activation --> target activation mantissa former ----+
                                                               |
offline-aligned weight store ----------------------------------+--> standard
                                                                    fixed-point
                                                                    multiplier
                                                                         |
                                                                         v
                                                               block reduction
                                                                         |
                                                                         v
                                                               channel accumulator
```

## 2. Hardware-visible schedule

For token `n`, projection path `p`, output channel `c`, input block `b`, and
element `k`, the existing scheduling abstraction provides:

- `beta_x[n,b]`: activation-block E8M0 exponent metadata;
- `beta_w[p,c,b]`: weight-block E8M0 exponent metadata used by scheduling;
- `lambda_x[n,b,k]`: activation-side fine-delay code;
- `H[p,c]`: calibrated path- and channel-specific horizon.

The metadata plane may retain the symbolic relations:

```text
E_raw[p,b,c] = beta_x[n,b] + beta_w[p,c,b]
E_max[p,c]   = max_b E_raw[p,b,c]
D[p,b,c]     = E_max[p,c] - E_raw[p,b,c]
tau[p,b,k,c] = D[p,b,c] + lambda_x[n,b,k]
L[p,b,k,c]   = max(0, H[p,c] - tau[p,b,k,c])
W[p,b,k,c]   = [tau[p,b,k,c], H[p,c])
```

These relations identify the local window and its useful length. They do not
mean that the new multiplier runs for `L` digit cycles. The separate arithmetic
contract must define exactly how `L` and the activation format determine the
target activation mantissa.

Weight exponent metadata may still participate in schedule construction. That
control-only use does not imply runtime shifting, recoding, or digit streaming
of the stored weight operand.

## 3. Metadata prepass and block configuration

The control plane retains the useful part of the two-timescale organization.

### 3.1 Double-buffered scale prepass

For the next token or channel assignment, the prepass scans block metadata,
forms `E_raw`, tracks `E_max`, and resolves `D` into a shadow bank while the
data plane consumes the active bank:

```text
delay_bank_active[p][b]   // current execution
delay_bank_shadow[p][b]   // next execution
rawexp_shadow[p][b]       // optional transient prepass state
```

At a safe context boundary, the shadow and active roles swap. The prepass reads
only metadata and uses narrow addition, max-reduction, and subtraction. It does
not read activation or weight payload operands.

Whether runtime `D` continues to include `beta_w` depends on the final offline
weight-alignment contract. If that relation changes, the prepass equation must
change explicitly rather than being inherited from the old datapath.

### 3.2 One-block-ahead configuration

For block `b+1`, the window builder combines `D`, `lambda_x`, and `H` and
prepares a shadow configuration while block `b` executes. At minimum, the
configuration contains:

```text
block_cfg[p,b,c] = {
    block_kill,
    active[K],
    target_desc[K]
}
```

`target_desc[k]` carries the reviewed information needed to form
`A_target[p,b,k,c]`; it may contain `L`, a retained-prefix length, or another
equivalent descriptor after the arithmetic contract is frozen.

The retired `start_ctr`, `rem_ctr`, product-digit pointers, subtree-live state,
and residual-drain state are not required by this architecture. Active/shadow
configuration buffering is retained only as an overlap mechanism.

## 4. Operand preparation

The runtime/offline split must be visible in both the data format and the
verification fixtures.

### 4.1 Runtime target activation mantissa

For an active element, the runtime target former computes symbolically:

```text
A_target[p,b,k,c] = FormTarget(
    A_quantized[n,b,k],
    L[p,b,k,c],
    activation_format,
    target_format
)
```

The target is the activation operand actually presented to the multiplier. A
zero-length window produces no active element and therefore no multiplier
issue. For `L > 0`, the target former emits one reviewed fixed-point operand.

The exact retained bits or digits, sign handling, zero encoding, width, binary
point, and rounding rule are intentionally not invented here. They must match
the active architecture contract and a bit-exact reference model.

### 4.2 Offline-aligned fixed-point weight

Before runtime, each quantized weight element is transformed and packed as:

```text
W_aligned[p,c,b,k] = OfflineAlignAndEncode(
    W_quantized[p,c,b,k],
    weight_scale_metadata[p,c,b],
    weight_format,
    aligned_weight_format
)
```

`W_aligned` is a signed fixed-point element stored in the weight array. Runtime
execution performs one element read and presents the stored word directly to
the multiplier. It does not extract an element exponent, shift or recode the
weight, walk a weight-digit pointer, or generate a weight-digit stream.

The offline alignment equation, stored width, binary point, packing, and
overflow behavior must be frozen before generating model-scale weights or RTL
fixtures.

## 5. Standard-multiplier data plane

For every active element, the arithmetic leaf is:

```text
P_element[p,b,k,c] = FixedPointMultiply(
    A_target[p,b,k,c],
    W_aligned[p,c,b,k]
)
```

This is one conventional combinational or pipelined fixed-point multiplier
issue. The selected implementation may have multiple multiplier lanes, a
pipeline depth, and an initiation interval, but it is not an online or
digit-serial multiply.

A block engine contains:

- target-activation formation logic and local activation state;
- an aligned-weight read port or bank;
- `N_mul` standard fixed-point multiplier lanes;
- a conventional fixed-point block-reduction network;
- a per-path, per-channel accumulator;
- valid/ready and clock-enable control needed by this local transaction.

Block execution is:

1. accept the reviewed `block_cfg`;
2. skip immediately if `block_kill` is set;
3. form `A_target` for each active element;
4. read one `W_aligned` word for that element;
5. issue one standard multiply;
6. reduce valid products in the specified finite-width order;
7. update the channel accumulator once for the block if any product is valid.

The block service time is determined by the number of active elements,
`N_mul`, multiplier initiation interval and latency, reduction pipeline, and
accumulator handshake. It is not `H + t_drain`, and no old online-adder drain
model may be reused.

## 6. Work suppression under the new datapath

The schedule still exposes three algorithmic cases, but their circuit effects
must be stated for a standard multiplier.

### Whole-block skip

If `L[p,b,k,c] = 0` for every `k`, the block performs no target formation,
aligned-weight reads, multiplier issues, reduction, or accumulator update. The
dispatcher may advance to the next block; any latency reduction must be
measured under the selected lane schedule.

### Element skip

If one element has `L[p,b,k,c] = 0`, that element performs no target formation,
weight read, or multiplier issue. The reduction network receives no valid
product from it.

### Partial window

If `0 < L[p,b,k,c] < H[p,c]`, the window changes the target activation
mantissa and the work needed to form it. Once the target exists, the element
still causes one aligned-weight read and one standard multiplication.

Partial windows therefore do not automatically reduce the multiplier-issue
count. They may reduce activation-target formation reads or activity, and they
may select a cheaper multiplier width class only if a width-classed design is
explicitly implemented and characterized.

The frozen **executed-digit ratio** remains the algorithmic work metric. It is
not renamed into a standard-multiplier utilization or issue ratio.

## 7. Reduction and accumulation

Multiplier outputs feed a conventional fixed-point block reduction followed
by a channel accumulator across serial blocks:

```text
block_sum[p,b,c] = Reduce_k(P_element[p,b,k,c] for valid k)
acc[p,b+1,c]     = Accumulate(acc[p,b,c], block_sum[p,b,c])
```

The reduction topology, finite-width order, product width, accumulator width,
pipeline placement, rounding, saturation, and overflow behavior remain part of
the bit-level contract. A Python reference and RTL must agree on each element
product, block sum, accumulated result, and accepted transaction order.

The accumulated `gate_proj` and `up_proj` results leave the custom stage-1
scope as ordinary fixed-point values. This design does not define a compressed
BSD payload, timing header, elastic stage boundary, or local `down_proj`
consumer.

## 8. Storage and accounting boundary

The custom storage inventory includes only state required by this stage-1
path:

- activation operand and metadata buffers;
- `H` and retained schedule metadata;
- active/shadow prepass and block-configuration banks, if selected;
- offline-aligned fixed-point weight storage;
- target-formation state;
- multiplier pipeline, reduction, and channel-accumulator state.

Completion payload stores, packet headers, boundary FIFOs, shard queues, and
stage-2 output buffers are excluded.

Hardware accounting keeps non-overlapping events:

```text
N_target_form
N_activation_read
N_aligned_weight_read
N_standard_multiply_issue
N_reduction_input
N_accumulator_update
N_block_skip
N_cycle
```

Counts must preserve projection identity and, if multiplier widths vary, the
operand-width class. Area, timing, energy, and event evidence must retain their
source labels; old serial-leaf or interface coefficients are not reusable.

## 9. Decisions required before implementation

This planning description intentionally leaves the following to the active
contract and decision log:

- exact mapping from `L` or `W` to `A_target`;
- signed activation and weight encodings, widths, and binary points;
- offline weight-alignment equation and packing;
- product, reduction, and accumulation precision rules;
- number and sharing of multiplier lanes;
- multiplier pipeline depth and initiation interval;
- reduction topology and transaction handshake;
- whether the existing runtime `D` equation remains unchanged.

No RTL datapath or model-scale ledger should silently choose these values.

## 10. Paper-facing hardware claim

> We realize temporal significance scheduling with a metadata-first stage-1
> micro-tile. A lightweight control plane translates MX metadata and calibrated
> horizons into per-element target-formation descriptors. At runtime, each
> active lane forms a target activation mantissa and multiplies it by an
> offline-aligned fixed-point weight element using a standard fixed-point
> multiplier, followed by conventional reduction and channel accumulation.
> Empty blocks and elements issue no arithmetic work; partial windows alter
> target formation rather than creating a runtime weight-digit stream. The
> custom design covers `gate_proj` and `up_proj` only and requires no stage-2
> packet interface.

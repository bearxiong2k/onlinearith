# Hardware design

Status: revised paper-planning description of the corrected target architecture
Scope: custom stage-1 `gate_proj` and `up_proj` hardware only

This note gives the paper-facing hardware organization. The binding simulator
contract remains the
[active hardware architecture contract](../../../hardware_sim/docs/architecture_contract.md),
which owns exact encodings, widths, overflow, and transaction semantics.

The vocabulary is:

- **paper-level principle:** temporal significance scheduling;
- **algorithmic object:** local execution windows on aligned contribution
  streams;
- **hardware realization:** a metadata-first control plane feeding a
  channel-parallel, block-serial fixed-point data plane.

The central dataplane decision is:

> Runtime scale and activation element exponents establish temporal arrival.
> For each active element, the schedule forms a three-bit target activation
> fraction, restores its implicit leading one, and uses a standard multiplier
> with an offline-aligned fixed-point weight element.

Only the weight element exponent is spatially folded into the fixed-point
operand. The activation element exponent remains a fine-delay code; it is not
expanded into a wide activation word. This design has no runtime
activation-digit × weight-digit engine, recoded weight-digit stream,
serial-parallel multiplier leaf, custom stage-2 `down_proj` engine, or
stage-1/stage-2 packet interface.

## 1. Architecture boundary

The custom tile covers the scheduled stage-1 projection work for
`p in {gate_proj, up_proj}`:

1. metadata prepass and local-window control;
2. runtime three-bit target-activation formation;
3. reads of offline-aligned fixed-point weights;
4. standard fixed-point multiplication;
5. temporal significance placement, block reduction, and channel
   accumulation.

SiLU, gate/up fusion, `down_proj`, and the rest of the model may be included as
explicit common terms in an end-to-end evaluation, but they are outside this
custom datapath. The design therefore makes no payload-compression,
packetization, boundary-buffer, shard-routing, or queueing claim.

M1 fixes block size `K = 32`. A tile has `N_lane` channel lanes; channels
execute in parallel across lanes, while input blocks for one channel execute
serially on reused arithmetic resources. Lane count and gate/up path sharing
remain M2 choices.

```text
                         METADATA / CONTROL PLANE
activation beta_x -----> scale prepass (active/shadow banks) <----- beta_w
                                      |
                                      v
                         one-block-ahead window builder
                           D + activation element exponent
                                      |
                                      v
                           R in {0, 1, 2, 3}

                           STAGE-1 DATA PLANE
activation sign/fraction --> three-bit target former --> restore implicit 1 --+
                                                                              |
offline-aligned signed 8-bit Q6 weight store --------------------------------+--> standard
                                                                                   multiplier
                                                                                       |
                                                               arrival tau ------------+
                                                                                       v
                                                                    time-aligned reduction
                                                                                       |
                                                                                       v
                                                                       channel accumulator
```

## 2. Hardware-visible schedule

For token `n`, projection path `p`, output channel `c`, input block `b`, and
element `k`, runtime sees:

- `beta_x[n,b]`: activation-block scale exponent;
- `beta_w[p,c,b]`: weight-block scale exponent;
- `e_x[n,b,k]`: activation element exponent, decoded as
  `floor(log2(abs(q_x)))`;
- `H[p,c]`: calibrated path- and channel-specific horizon.

The frozen MXFP8 quantizer normalizes every nonzero block maximum to `448`,
whose element exponent is `8`. That fixed reference gives:

```text
E_raw[p,b,c] = beta_x[n,b] + beta_w[p,c,b]
E_max[p,c]   = max_b E_raw[p,b,c]
D[p,b,c]     = E_max[p,c] - E_raw[p,b,c]

lambda_x[n,b,k] = 8 - e_x[n,b,k]
tau[p,b,k,c]    = D[p,b,c] + lambda_x[n,b,k]
L[p,b,k,c]      = max(0, H[p,c] - tau[p,b,k,c])
p_eff_frozen    = max(0, L[p,b,k,c] - 2)
R[p,b,k,c]      = min(3, p_eff_frozen)
W[p,b,k,c]      = [tau[p,b,k,c], H[p,c])
```

The activation and weight element-reference exponents are both fixed at 8, so
their common contribution cancels from relative block delay. There are no
runtime `rho_x`, `rho_w`, `gamma_x`, or `gamma_w` fields.

This split is binding:

- `beta_x + beta_w` creates coarse block timing;
- the activation element exponent creates fine timing through `lambda_x`;
- the weight element exponent is already represented inside the stored
  fixed-point word;
- `R` controls how many of the three activation fraction positions survive.

The constant two carries the origin of the frozen calibrated horizons. It is
not standard-multiplier latency. These equations do not mean that the standard
multiplier runs for `L` or `R` cycles; an active target causes one ordinary
multiply under the M2 issue schedule.

## 3. Metadata prepass and block configuration

The control plane retains the useful part of the two-timescale organization.

### 3.1 Double-buffered scale prepass

For the next token or channel assignment, the prepass scans only `beta_x` and
`beta_w`, forms `E_raw`, tracks `E_max`, and resolves `D` into a shadow bank
while the data plane consumes the active bank:

```text
delay_bank_active[p][b]
delay_bank_shadow[p][b]
rawexp_shadow[p][b]       // optional transient prepass state
```

At a safe context boundary, the banks exchange roles. The prepass performs
only narrow exponent addition, maximum reduction, and subtraction. It does not
read activation or weight payloads, decode a weight element exponent, or form
a floating-point product.

### 3.2 One-block-ahead configuration

For block `b+1`, the window builder combines `D`, activation exponent-derived
`lambda_x`, and `H` while block `b` executes. At minimum:

```text
block_cfg[p,b,c] = {
    block_kill,
    active[K],
    retained_fraction_count[K]  // R in [0, 3]
}
```

`R = 0` makes the element inactive. The retired product-digit pointer,
`rem_ctr`, subtree-live state, and residual-drain state are not active fields.
Whether active/shadow configuration storage is instantiated and how it is
ported are M2 decisions.

## 4. Operand preparation

### 4.1 Runtime three-bit target activation

Every nonzero E4M3FN activation can be written as:

```text
q_x = sign_x * M_x_int * 2^(e_x - 3)
M_x_int in [8, 15] = binary 1.xxx
```

Subnormals are normalized to the same representation. `M_x_int[2:0]` are the
three explicit fraction positions. For an active target, the former retains
the `R` most-significant fraction positions and clears lower positions:

```text
mask_R       = ((1 << R) - 1) << (3 - R)
frac_target  = M_x_int[2:0] & mask_R
A_sig_int    = {1'b1, frac_target}
```

The scheduled target payload is three bits. `A_sig_int` is a four-bit unsigned
UQ1.3 magnitude because a conventional numeric multiplier must include the
implicit leading one. Activation sign remains separate and is applied to the
product. `R = 0` or zero activation forms no numeric target and causes no
multiply contribution.

This target rule is binary prefix clearing, not NAF recoding. A partial target
cannot overshoot to `+2.0` and does not require a 20-bit activation input.

### 4.2 Offline-aligned fixed-point weight

Offline preparation folds each weight sign, element exponent, and element
mantissa into a word referenced to the fixed E4M3FN element exponent 8, then
rounds once into the storage format:

```text
W_aligned_value = sign(w) * m_w * 2^(e_w - 8)
W_aligned_int   = RNE(W_aligned_value * 2^6)
                = RNE_signed(decode_q9(w) / 2^11)
```

The word is signed 8-bit Q6. Rounding is nearest with ties to even, symmetric
for negative values. Every finite E4M3FN element maps into `[-112, 112]`, so
legal conversion never saturates; sufficiently small weights may round to
zero. Runtime reads the byte directly and separately reads `beta_w` for coarse
scheduling. It does not extract `e_w`, shift or recode the word, walk a digit
pointer, or generate a weight-digit stream.

The logical artifact uses exactly one byte per element with no padding.
Physical weight SRAM depth, banking, and ports remain M2 decisions.

## 5. Standard-multiplier data plane

For every active element:

```text
P_element_int = (-1)^sign_x * A_sig_int * W_aligned_int
```

The magnitude input is four-bit UQ1.3, derived from a three-bit target
fraction, and the weight input is signed 8-bit Q6. The full result is signed
12-bit Q9. This is one conventional combinational or pipelined multiplier
issue, not an online multiply and not five- or twenty-bit activation data.

The selected implementation may realize the implicit-one term inside a
four-bit multiplier or as an equivalent `W + fraction*W` structure. Either
choice must match the same full product and is not permitted to change target
semantics.

## 6. Time-domain placement and reduction

Activation exponent alignment remains temporal after multiplication. The
product belongs at arrival:

```text
tau = D + lambda_x
```

With `H <= 31`, offset two, and an active `R`, `tau <= 28`. For a bit-exact
fixed-point oracle, common tail 28 represents the same placement as:

```text
P_temporal_int = P_element_int << (28 - tau)
```

This equation specifies significance, not a mandatory runtime barrel shifter.
M2 must choose a cycle-tagged or otherwise bit-equivalent temporal
placement/reduction organization.

The corrected M1 formats are:

| Item | Format |
|---|---|
| Target fraction | 3-bit unsigned prefix |
| Active activation magnitude | 4-bit UQ1.3 plus sign |
| Offline-aligned weight | signed 8-bit Q6 |
| Element product | signed 12-bit Q9 |
| Common-tail temporal product | signed 40-bit Q37 |
| Exact 32-element block sum | signed 45-bit Q37 |
| Channel accumulator | signed 52-bit Q37 |

After the declared offline weight rounding, multiplication, temporal
placement, block reduction, and channel accumulation are exact; no additional
rounding occurs. The defensive accumulator saturates to the signed 52-bit
range and raises sticky overflow, although legal 4096-element dots cannot
overflow. The stage-1 output is interpreted as:

```text
output_value = accumulator_integer * 2^(E_max - 21)
```

M2 owns multiplier count and sharing, physical temporal placement, reduction
topology, pipeline depth, initiation interval, and update schedule.

## 7. Work suppression under the standard multiplier

### Whole-block skip

If every element has `R = 0`, the block performs no target formation,
aligned-weight reads, multiplier issues, reduction, or accumulator update.

### Element skip

If one element has `R = 0`, that element performs no target formation, weight
read, or multiplier issue.

### Partial target

If `0 < R < 3`, the target former retains only part of the three-bit activation
fraction. Once formed, the element still causes one aligned-weight read and
one standard multiplication. Partial targets may reduce activation-bit reads
or formation activity but do not automatically reduce multiplier issue count.

The frozen **executed-digit ratio** remains algorithmic evidence and is not
renamed into multiplier utilization. Hardware accounting separately counts:

```text
N_target_form
N_activation_element_read
N_activation_fraction_bit_read
N_aligned_weight_read
N_standard_multiply_issue
N_temporal_reduction_update
N_accumulator_update
N_block_skip
N_cycle
```

## 8. Storage and scope boundary

The active storage inventory may include only:

- activation source/sign/exponent/fraction and metadata buffers;
- `H`, `beta_x`, `beta_w`, `D`, and retained target descriptors;
- active/shadow prepass and configuration banks if selected;
- offline-aligned 8-bit weight storage;
- multiplier, temporal reduction, and channel-accumulator state.

Completion payload stores, headers, stage-boundary FIFOs, shard queues, and
stage-2 output buffers are excluded.

## 9. Remaining design work

Corrected M1 is frozen by
`hardware_sim/configs/operand_format_m1_v3.json`. M2 must still choose:

- multiplier lane count and gate/up sharing;
- physical temporal-placement and reduction organization;
- pipeline latency, initiation interval, and block/channel completion;
- transaction handshake, backpressure, reset, and ordering;
- storage banking and ports;
- clock, constraints, area/timing guardrails, power intent, test boundary,
  hierarchy, synthesis top, and physical handoff boundary.

No RTL datapath or model-scale ledger should silently choose these values.

## 10. Paper-facing hardware claim

> We realize temporal significance scheduling with a metadata-first stage-1
> micro-tile. Activation and weight block-scale exponents establish coarse
> arrival, while the activation element exponent supplies the fine delay. The
> weight element exponent is folded offline into a rounded signed 8-bit
> fixed-point word.
> For each active element, runtime forms a prefix over the three E4M3
> activation fraction bits, restores the implicit leading one, and performs
> one standard fixed-point multiply. The resulting product is placed at its
> scheduled temporal significance before block reduction and channel
> accumulation. Empty elements and blocks issue no arithmetic work; the
> custom design covers `gate_proj` and `up_proj` only and requires no custom
> stage-2 interface.

This claim does not transfer frozen PPL to the revised arithmetic: the frozen
quality experiment used the original MXFP8 weight elements and did not include
the new offline 8-bit weight rounding.

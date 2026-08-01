# Active hardware architecture contract

Status: **draft; binding scope decisions frozen, arithmetic parameters open**
Last updated: 2026-08-01
Implementation status: no active circuit-reference or RTL datapath yet

This document is the source of truth for the redesigned hardware simulator.
It deliberately stops short of assigning operand widths or rounding rules that
have not yet been decided.

## 1. Method identity

The paper studies **temporal significance scheduling**. The scheduled object is
a **local execution window on an aligned contribution stream**. The frozen
software metric remains **executed-digit ratio**.

The hardware realizes the schedule by forming a target activation mantissa and
using a conventional fixed-point multiplication with a weight element that was
aligned and encoded offline. It is not a generic sparsity mask and it is not a
runtime two-sided digit-serial multiplier.

## 2. Binding system boundary

The custom hardware scope covers the stage-1 `gate_proj` and `up_proj` work
needed by the revised datapath and its local metadata/control/storage.

```mermaid
flowchart LR
    F["Frozen functional evidence\nH, delays/windows, executed-digit summaries"]
    A["Read-only translation contract"]
    M["Stage-1 metadata/window control"]
    T["Target activation mantissa formation"]
    W["Offline-aligned fixed-point weight store"]
    X["Standard fixed-point multiplier"]
    R["Stage-1 reduction and accumulation"]

    F --> A --> M --> T --> X --> R
    W --> X
```

Explicitly excluded from custom scope:

- a custom stage-2 `down_proj` engine;
- a stage-1/stage-2 packet interface;
- packetization, boundary headers, payload compression, or payload FIFOs;
- shard routing, elastic queues, or queue replay;
- a runtime recoded weight-digit stream;
- old Anchor-2 serial leaf timing or energy coefficients.

`down_proj` remains part of the frozen full-model quality evidence. It may be a
common, unchanged denominator term in a declared full-FFN comparison, but it
is not part of the new custom RTL.

## 3. Symbolic operand contract

The schedule may retain the familiar symbolic control relation:

```text
tau_k = D + lambda_x[k]
L_k   = max(0, H - tau_k)
```

This relation is not yet a bit-level contract. The active arithmetic is
represented symbolically as:

```text
A_target = form_target_mantissa(A_quantized, L, activation_format)
W_aligned = offline_align_and_encode(W_quantized, alignment_metadata,
                                     weight_format)
C_element = fixed_point_multiply(A_target, W_aligned)
```

Binding properties:

- `A_target` is formed at runtime from activation information and the local
  schedule.
- `W_aligned` is prepared before runtime and read as a fixed-point element.
- the leaf arithmetic is one standard fixed-point multiplication over those
  operands, not a cycle-by-cycle activation-digit × weight-digit stream;
- runtime counters separately record target formation, activation reads,
  aligned-weight reads, multiplier issues, and downstream reduction work.

The exact bit widths, binary points, signed encodings, zero representation,
saturation, rounding, and relation between `L` and `A_target` remain open and
must be frozen before implementation.

## 4. Runtime transaction boundary

A hardware transaction must identify at least:

- source artifact and schema revision;
- model, layer, projection (`gate_proj` or `up_proj`), token/sample, output
  channel, and input block coordinates as applicable;
- activation and weight format identifiers;
- schedule metadata needed to form `A_target`;
- the offline-aligned weight element or a deterministic fixture reference;
- expected numeric result and expected event counts for verification.

The first implementation should use tiny synthetic transactions. It must not
require a full model trace, calibration run, or PPL run.

## 5. Metadata and control reuse boundary

The old scale prepass and window builder are reference candidates only.

- The `E_raw`/`E_max`/`D` prepass is reusable only if the offline weight format
  still requires the same runtime weight-scale contribution and the same `D`.
- The `tau`/`L` builder and ping-pong configuration mechanics are reusable only
  after `L` is defined for target activation formation.
- The old `rem_ctr`, product-digit pointer, `subtree_init`, and configuration
  word are not active contract fields.
- Horizon, raw-exponent, delay, and generic synchronous storage are candidates;
  completion metadata and payload storage are retired.

No extracted legacy module enters an active RTL filelist until its ports and
semantics are reviewed against this document.

## 6. Reduction and accumulation boundary

The standard multiplier output must eventually feed stage-1 reduction and
accumulation. The topology, fan-in, accumulator width, overflow policy,
pipeline placement, and cycle model are not yet frozen. Old Anchor-2 tree and
drain numbers do not fill these gaps.

The reference model and RTL must agree bit-for-bit on:

- each element product;
- reduction order where finite-width arithmetic makes it observable;
- rounding/saturation sites;
- accumulated output;
- all ledger events owned by the transaction.

## 7. Comparison boundary

Every evaluation configuration must declare one of these scopes:

- `stage1_custom`: only the redesigned gate/up custom work;
- `ffn_e2e`: revised stage-1 work plus explicitly identified common SiLU,
  gating, `down_proj`, and noncustom terms;
- `model_e2e`: full-model accounting with measured or clearly labeled common
  terms.

Do not compare a stage-1 numerator with an old full-FFN denominator without a
written decomposition. The old 4.253% decode and 8.014% prefill results are
retired hardware values, not defaults.

## 8. Open items blocking arithmetic implementation

| ID | Required decision | Why it blocks code |
|---|---|---|
| `OPEN-ARCH-001` | Exact definition of the target activation mantissa from `L`/window state | Determines reference arithmetic and runtime work |
| `OPEN-ARCH-002` | Activation signed encoding, width, and binary point | Determines multiplier operand and corner cases |
| `OPEN-ARCH-003` | Offline weight-alignment equation and metadata inputs | Determines stored representation and trace export |
| `OPEN-ARCH-004` | Weight signed encoding, width, binary point, and storage packing | Determines multiplier and read accounting |
| `OPEN-ARCH-005` | Product width, rounding, saturation, and accumulation semantics | Determines bit-exact outputs |
| `OPEN-ARCH-006` | Multiplier issue granularity and lane/block organization | Determines ledger and cycle model |
| `OPEN-ARCH-007` | Reduction topology and accumulator boundary | Determines RTL structure and characterization |
| `OPEN-ARCH-008` | Whether runtime `D` still includes weight-scale metadata | Determines whether old prepass control is reusable |

Resolve these in the decision log. Once resolved, replace symbolic text with
exact equations and mark this contract `frozen` before active datapath code is
added.

## 9. Contract freeze checklist

- One worked positive, negative, zero, maximum, and minimum operand example.
- One example for a killed/empty local window.
- Offline and runtime responsibilities labeled on every field.
- Exact relation to frozen `H`, `D`, `lambda`, `tau`, `L`, and executed-digit
  summaries documented.
- `gate_proj`/`up_proj` scope explicit; no aggregate split involving
  `down_proj`.
- No stage-boundary or payload field in the transaction schema.
- Bit-exact Python expected values suitable for an RTL smoke test.

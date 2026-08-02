# Hardware decision log

Status: active
Format: append durable decisions; amend with a new entry rather than erasing
the reason for an older choice

## Locked decisions

### HW-D001 — Separate functional and hardware workstreams

Date: 2026-08-01
Status: superseded in command-surface detail by HW-D009; the workstream split
remains in force
Decision: keep canonical functional source under `functional_sim/`, preserve
the old root command surface with symlinks, and place all new hardware work
under `hardware_sim/`. Functional and hardware evidence meet only through a
versioned read-only translation/reporting boundary.
Reason: the numerical simulator and redesigned circuit have genuinely
different semantics, dependencies, tests, and evidence levels.

### HW-D002 — Preserve frozen numerical evidence

Date: 2026-08-01
Decision: do not edit the `onlinearith` functional simulator or modified
Transformers implementation for the redesign. Calibration, PPL, baseline, and
executed-digit results remain facts under their recorded provenance.
Reason: the redesign changes downstream hardware realization, not the accepted
numerical experiment record.

### HW-D003 — Stage-1-only custom scope

Date: 2026-08-01
Decision: remove the custom stage-2 `down_proj` consumer and all stage-boundary
packet/payload/queue hardware from the active architecture.
Reason: the revised paper hardware no longer requires that interface.

### HW-D004 — Standard multiplier leaf

Date: 2026-08-01
Decision: use a standard fixed-point multiplier whose operands are a runtime
target activation mantissa and an offline-aligned fixed-point weight element.
There is no runtime recoded weight-digit stream.
Reason: this is the revised target hardware realization.

### HW-D005 — Keep executed-digit ratio distinct

Date: 2026-08-01
Decision: retain executed-digit ratio and
`mean_effective_precision / 3.0` as frozen algorithmic/work evidence. Count
new circuit reads, issues, cycles, and energy separately.
Reason: a standard multiplier issue is not semantically identical to an old
executed product digit.

### HW-D006 — Legacy repositories are provenance only

Date: 2026-08-01
Decision: active hardware code has no runtime dependency on `../anchors` or
`../rebuttal`. Small exact candidates may be copied into a quarantined
reference directory with origin metadata.
Reason: the old repositories encode superseded architecture and must not
silently control new results.

### HW-D007 — Preserve evidence-strength labels

Date: 2026-08-01
Decision: distinguish `trace`, `rtl_sim`, `mapped`, `formula`, `proxy`,
`assumption`, `pending`, and `unusable` throughout ledgers and reports.
Reason: old rebuttal work demonstrated that aggregation can otherwise overstate
what was measured.

### HW-D008 — Nangate source is cleared for this project

Date: 2026-08-01
Decision: reuse the existing local Nangate cell files within this same
personal-research project, preserving file headers and provenance. No new
license review is required for the reorganization.
Reason: the license check was completed in the prior project edit.

### HW-D009 — Use canonical nested functional commands only

Date: 2026-08-01
Decision: remove the temporary root compatibility symlinks. Functional code,
tests, tools, scripts, and baselines live only under `functional_sim/`, and all
current commands use that prefix from the repository root.
Reason: one explicit command surface keeps the repository root and future
hardware-development context clean without maintaining layout aliases.

### HW-D010 — Freeze a design-mature RTL release before layout

Date: 2026-08-01
Decision: physical-design and layout work will target one canonical
design-mature release. Before that release, arithmetic, scheduling,
microarchitecture, storage, interfaces, clock/reset, constraints, RTL,
verification, and mapped-synthesis feasibility must close through the gates in
`development_plan.md`. After the release, physical work may make only
contract-preserving implementation changes; any functional or cycle-visible
change creates a new design ID and reopens the affected gates.
Reason: layout exploration must not become an implicit continuation of hardware
architecture design or invalidate simulation and characterization evidence.

### HW-D011 — Use exact block-aligned MXFP8 Q17 operands

Date: 2026-08-01
Status: **superseded by HW-D014, HW-D015, HW-D017, and HW-D018**
Resolves: `OPEN-ARCH-002`, `OPEN-ARCH-003`, `OPEN-ARCH-004`, and
`OPEN-ARCH-008`
Decision: the canonical source is finite MXFP8 E4M3FN. For each block, use
`rho = max floor(log2(abs(q[k])))`, encode the exact aligned element as
`decode_q9(raw[k]) << (8 - rho)`, and interpret it with 17 fractional bits.
Activation full words are signed 19-bit Q17. Offline weight words are signed
19-bit Q17, stored logically as one word per element and serialized as three
little-endian bytes with five zero padding bits. Offline preparation also
stores `gamma_w = beta_w + rho_w`; runtime forms
`gamma_x = beta_x + rho_x`, so `D` uses both terms and requires no runtime
weight-element exponent decode.
Alternatives considered: a global Q9 value (less explicit block alignment), a
single per-channel reference exponent (unnecessarily wide dynamic range), and
a narrower lossy aligned weight (new quantization error). Exact per-block Q17
preserves every finite source value without a runtime shifter on the weight
path.
Affected fields: operand-format ID, source words, `rho_x`, `gamma_x`,
`gamma_w`, aligned-weight words, `E_raw`, `E_max`, and `D`.
Verification example: fixture `positive_full` maps activation `0x3c` to
`0x30000` and weight `0x3a` to `0x28000` before target selection.

### HW-D012 — Form a five-position NAF activation prefix

Date: 2026-08-01
Status: **superseded by HW-D015**
Resolves: `OPEN-ARCH-001`
Decision: retain
`L = max(0, H - D - lambda_x)` and form
`R = min(5, max(0, L - 2))`. `A_target` is the first `R` canonical NAF digit
positions of the signed Q17 aligned activation, including intervening zero
positions. `R = 0` or a zero activation yields zero. The two-position constant
comes from the frozen calibration setting `msd_online_delay = 2`; it is a
schedule-translation constant, not standard-multiplier latency. The target is
signed 20-bit Q17 because a legal one-position prefix can be `+2.0`. `H` is an
integer in `[0, 31]`; zero activations use `lambda_x = 31`, which guarantees a
zero target throughout that range.
Alternatives considered: binary-prefix formation (different from the frozen
BSD convention), using `L` without the offset (changes calibrated horizon
meaning), and product-first truncation (cannot be factored in general into an
activation-only target times a fixed offline weight).
Affected fields: `lambda_x`, `L`, `R`, target descriptor, target word, and
target-formation event semantics.
Verification example: fixture `positive_partial_prefix_overshoot` maps
activation `+1.75` with `R = 1` to target word `0x40000` (`+2.0`).

### HW-D013 — Preserve full products and round only at block alignment

Date: 2026-08-01
Status: **superseded by HW-D016**
Resolves: `OPEN-ARCH-005`
Decision: use a full signed 20-by-19 multiply producing 39-bit Q34; sum 32
products exactly in 44-bit Q34; align the block sum by `D` with
round-to-nearest, ties-to-even; and accumulate up to 128 blocks in signed
51-bit Q34. Accumulator updates saturate to the signed 51-bit range and set a
sticky overflow flag. Legal dots contain at most 4096 source elements and
cannot overflow; no final narrowing occurs in the custom stage-1 scope.
Alternatives considered: per-product rounding (order-sensitive extra error),
truncating block alignment (signed bias), modular accumulator wrap (unsafe
failure behavior), and a narrower model-specific accumulator (would not cover
the Qwen3-8B stage-1 dot length).
Affected fields: product, block-sum, aligned-block, accumulator, output-scale,
rounding, saturation, and overflow fields.
Verification example: the fixture rounds `3 / 2` to even integer `2`, rounds
`-3 / 2` to `-2`, and exercises both saturation rails.

The first M1 review exposed a representation error across HW-D011 through
HW-D013: it encoded the activation element exponent into a wide spatial Q17
operand even though that exponent is the activation fine-delay signal. The
entries remain here as rejected history; they are not active alternatives or
valid configuration provenance.

### HW-D014 — Keep activation exponent alignment temporal and fold only the weight element exponent offline

Date: 2026-08-01
Status: **partially superseded by HW-D017**; the fixed reference exponent,
temporal activation alignment, and runtime schedule remain active
Supersedes: HW-D011
Resolves: `OPEN-ARCH-003`, `OPEN-ARCH-004`, and `OPEN-ARCH-008`
Decision: use the E4M3FN format-maximum element exponent `8` as the fixed
activation and weight element reference. The frozen nonzero-block quantizer
normalizes its maximum magnitude to `448`, so the reference is a format
constant rather than per-block `rho` metadata. Runtime forms
`E_raw = beta_x + beta_w`, `D = E_max - E_raw`, and
`lambda_x = 8 - e_x`. Offline preparation encodes each weight as signed
19-bit Q17 relative to exponent 8. For E4M3FN this reduces exactly to
`W_aligned_int = decode_q9(w)`. Runtime uses `beta_w` in the coarse delay but
does not decode a weight element exponent or weight reference exponent.
The logical weight word retains the reviewed three-byte little-endian packing
with bits `23:19` zero and sign extension from bit 18.
Alternatives considered: per-block `rho_x/rho_w` plus `gamma_x/gamma_w`
(redundant for legal quantizer output and obscures the intended temporal
split), spatial Q17 activation alignment (moves `lambda_x` into the multiplier
operand), and a narrower rounded weight (adds a second quantization policy).
Affected fields: `beta_x`, `beta_w`, `E_raw`, `E_max`, `D`, `lambda_x`, weight
word, weight packing, and trace validation of the legal-block invariant.
Verification example: weight `0x3a` decodes directly to aligned integer `640`
(`0x00280`), while activation `0x3c` keeps exponent `0` as
`lambda_x = 8` rather than becoming a Q17 activation word.

### HW-D015 — Use a three-bit binary target fraction with explicit implicit-one and sign handling

Date: 2026-08-01
Status: active
Supersedes: HW-D012
Resolves: `OPEN-ARCH-001` and `OPEN-ARCH-002`
Decision: retain the schedule bridge
`p_eff_frozen = max(0, H - D - lambda_x - 2)` and set
`R = min(3, p_eff_frozen)`. Normalize every nonzero E4M3FN activation to an
exact four-bit UQ1.3 significand, retain the `R` most-significant bits of its
three-bit fraction, and clear lower fraction bits. `R = 0` forms no numeric
target. For `R > 0`, the multiplier magnitude is `{1'b1, frac_target[2:0]}`;
activation sign is a sideband applied to the product. Subnormals use the same
normalized form. The three-bit target payload is therefore distinct from the
four-bit numeric magnitude presented to a conventional multiplier.
Alternatives considered: the superseded five-position NAF prefix (introduced
a Q17 operand and `+2.0` overshoot), treating a raw three-bit fraction as the
complete number (drops the implicit leading contribution), and leaving
subnormals unnormalized (gives exponent-dependent mantissa semantics).
Affected fields: target descriptor, target fraction, implicit-one valid,
activation sign, multiplier magnitude, activation-digit accounting, and the
frozen-artifact formula bridge.
Verification example: activation `0x3b` has normalized significand `1.011`;
`R = 1` forms `1.000`, while `R = 2` forms `1.010`.

### HW-D016 — Multiply the four-bit significand by the aligned weight and preserve temporal placement exactly

Date: 2026-08-01
Status: **superseded by HW-D018**
Supersedes: HW-D013
Resolves: `OPEN-ARCH-005`
Decision: use a full four-bit UQ1.3 magnitude by signed-19-bit Q17 standard
multiply, apply activation sign, and retain the signed 23-bit Q20 result. The
activation exponent is represented only by arrival
`tau = D + lambda_x`. With `H <= 31`, offset two, and `R > 0`, the maximum
active arrival is 28. The bit-exact oracle uses common tail 28 and encodes time
placement as `P_temporal = P_element << (28 - tau)`, with no rounding. Sum 32
placed products exactly in signed 56-bit Q48 and accumulate at most 128 blocks
in signed 63-bit Q48. Accumulator updates saturate defensively to the signed
63-bit range and set sticky overflow; legal dots cannot overflow. The output
value is `acc_int * 2^(E_max - 32)`.
Alternatives considered: a signed 20-by-19 spatial multiply (the representation
error), per-element or per-block right-shift rounding (loses information and
makes order visible), and an unguarded narrower accumulator (does not retain
all legal temporal positions). M2 still chooses whether equivalent placement
is realized by cycle-tagged accumulation, a staged shift/add network, or
another bit-equivalent topology.
Affected fields: multiplier widths, product, arrival, temporal product, block
sum, accumulator, output scale, overflow, and reduction verification.
Verification example: product integer `7680` at `tau = 8` becomes
`7680 << 20 = 8053063680` in the common-tail oracle; the maximum active
`tau = 28` requires no shift.

### HW-D017 — Store each offline-aligned weight as signed 8-bit Q6

Date: 2026-08-01
Status: active
Revises: the weight precision and packing portions of HW-D014
Resolves: `OPEN-ARCH-003` and `OPEN-ARCH-004` together with the temporal split
retained from HW-D014
Decision: keep the fixed weight element-reference exponent `8`, but round its
aligned value to a signed 8-bit Q6 word:
`W_aligned_int = RNE_signed(decode_q9(w) / 2^11)`. Rounding is to nearest with
ties to even, symmetric for negative inputs. Every finite E4M3FN source value
maps into `[-112, 112]`, so saturation is not part of legal encoding. Store
exactly one byte per weight element with no padding. Runtime still uses
`beta_w` in coarse delay and does not decode the weight element exponent.
This new rounding is hardware semantics; frozen quality and executed-digit
evidence used the original MXFP8 weights and is not evidence for its quality.
Alternatives considered: the exact signed 19-bit Q17 word (more than twice the
requested storage), signed Q7 at the same reference exponent (cannot represent
the legal `+1.75` endpoint), truncation toward zero (systematic magnitude
bias), and modular overflow (invalid numeric behavior). Signed Q6 is the
highest binary precision that covers the full aligned range in eight bits.
Affected fields: operand-format ID, weight encoder, stored word, packing,
multiplier width and binary point, product/reduction widths, output scale, and
frozen-software equivalence boundary.
Verification example: source weight `0x68` has `decode_q9 = 32768` and encodes
as `+16` (`0x10`); `0x4c` is an exact half-way case and rounds to even `+2`;
the maximum finite encodings map to `+112` and `-112`.

### HW-D018 — Re-derive exact temporal accumulation around the 4-by-8 multiply

Date: 2026-08-01
Status: active
Supersedes: HW-D016
Resolves: `OPEN-ARCH-005`
Decision: multiply the four-bit unsigned UQ1.3 activation magnitude by the
signed 8-bit Q6 aligned weight, apply activation sign, and retain the full
signed 12-bit Q9 result. Preserve `tau = D + lambda_x`, maximum active arrival
28, and common tail 28. Exact placement produces a signed 40-bit Q37 temporal
product; 32 products sum exactly in signed 45-bit Q37; and at most 128 block
sums accumulate in signed 52-bit Q37. Accumulator updates saturate defensively
to `[-2^51, 2^51 - 1]` and set sticky overflow. No legal dot of at most 4096
elements overflows. The decoded output is
`acc_int * 2^(E_max - 21)`. M2 still owns the physical timing/reduction
topology but must preserve this common-tail sum exactly.
Alternatives considered: retaining the old 23/51/56/63-bit datapath (safe but
needlessly expensive and inconsistent with the new binary point), narrowing
the full product (adds another rounding point), and right-shifting products or
block sums before reduction (loses scheduled low-significance information).
Affected fields: multiplier ports, product, temporal product, block sum,
accumulator, saturation rails, output scale, and verification vectors.
Verification example: product integer `192` at `tau = 8` becomes
`192 << 20 = 201326592`; the largest legal common-tail element magnitude is
`1568 << 28 = 420906795008`, which fits signed 40 bits, and 4096 such terms fit
signed 52 bits.

## Open decisions

Corrected M1 is closed by HW-D014, HW-D015, HW-D017, and HW-D018. The
remaining authoritative blocking list is `OPEN-ARCH-006`, `OPEN-ARCH-007`,
and `OPEN-ARCH-009` through
`OPEN-ARCH-014` in `architecture_contract.md`. Resolve each with a new
`HW-Dxxx` entry that gives the exact protocol or organization, alternatives
considered, affected schema fields, and verification example.

Nonblocking evaluation choices that will also need records:

- energy-characterization method;
- stage-1 versus FFN/model end-to-end reporting boundary;
- model-scale trace sampling and completeness criteria;
- artifact snapshot/retention policy for paper submission.

## Retired assumptions

The following are not open alternatives and must not return without an
explicit architecture-change decision:

- serial activation-digit × weight-digit leaf execution;
- a Q17-spatially-aligned activation operand or five-position activation NAF
  target;
- a signed 19-bit Q17 aligned weight or three-byte weight-element packing;
- per-block `rho_x/rho_w` or `gamma_x/gamma_w` fields in the active schedule;
- Anchor-2 area, drain, latency, or energy coefficients;
- Anchor-3 packetizer, payload, FIFO, or queue replay;
- Anchor-4 completion/payload storage and old 80,032-bit total;
- v1 even-split gate/up ledgers derived from an 84-projection aggregate;
- old 4.253% decode and 8.014% prefill hybrid gains.

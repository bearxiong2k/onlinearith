# Hardware evidence and trace contract

Status: **draft schema boundary; source policy frozen**
Last updated: 2026-08-01

This document prevents frozen numerical evidence, new circuit events, mapped
RTL results, and analytic estimates from being blended into one ambiguous
measurement.

## 1. Frozen numerical sources

The functional code boundary was audited at:

| Source | Frozen revision | Reusable facts |
|---|---:|---|
| `onlinearith` functional code | `2d07c53` | setup definitions, calibration/PPL methodology, baseline results, executed-digit convention |
| `../transformers` | `3910a1596f` | authoritative Qwen3 numerical kernel, calibration oracle, layer statistics |

Later `onlinearith` commits `1780f41` and `806b419` changed planning documents,
not the frozen functional code. The sibling repositories used for legacy
hardware/rebuttal provenance were audited at `../anchors@5959bb8` and
`../rebuttal@e13339c`.

Reusable frozen facts include:

- calibration artifacts under their original optimizer and dataset protocol;
- PPL under the original full or sampled evaluation protocol;
- dense MXFP8, WANDA 2:4, activation N:M 2:4, and fixed-sum comparisons;
- executed-digit ratio using the recorded
  `mean_effective_precision / 3.0` convention;
- model/layer/projection scale and distributions when their artifact actually
  exposes those dimensions.

These facts must not be recomputed under revised arithmetic semantics merely
to resemble the circuit.

## 2. Fields that are not new hardware evidence

The frozen statistics implementation contains legacy circuit fields. The
following cannot be relabeled for the new design:

- `N_leaf_exec` as a standard-multiplier count;
- digit-stream leaf cycles or weight-digit reads;
- old block drain cycles;
- boundary payload digits/words, bursts, headers, or shard IDs;
- packetizer/FIFO/queue events;
- aggregate gate/up splits derived from a total that also includes
  `down_proj`.

If an artifact exposes only an invalid aggregate, mark it `unusable` for the
stage-1 circuit ledger. Do not repair it by silently dividing the total.

## 3. Read-only translation artifact

The new adapter will consume frozen artifacts and emit an immutable,
versioned hardware-input artifact. At minimum its envelope must contain:

```text
schema_name
schema_version
created_by_revision
source_path_or_artifact_id
source_sha256
source_repo_revision
functional_semantics_id
model_id
projection_scope
sample_scope
translation_config_id
translation_status
transactions[]
```

`translation_status` distinguishes direct field extraction from a documented
formula. The adapter may select and normalize fields; it may not modify the
source, run a changed numerical kernel, or imply numerical equivalence that
has not been validated.

For operand configuration
`tss-m1-mxfp8-m3a4w8-p12-acc52-v3`, the only schedule bridge is:

```text
p_eff_frozen = max(0, H - D - lambda_x - 2)
R_hardware   = min(3, p_eff_frozen)
```

`R_hardware` selects a binary prefix over the three normalized activation
fraction positions. The implicit leading one and activation sign are circuit
encoding details, not additional executed-digit positions. This is a
`formula`-status target descriptor. Frozen
`mean_effective_precision` and executed-digit ratio remain based on uncapped
`p_eff_frozen`; they are not replaced by `R_hardware`, target formations, or
multiplier issues. The activation-prefix multiply is also not asserted to be
numerically identical to the frozen product-first truncation. In addition,
the frozen quality evidence used the original MXFP8 weights; it does not
measure the new offline rounding to signed 8-bit Q6 aligned weights.

## 4. Event ledger v2

The first active ledger must use a new schema name/version rather than extend
the old v1 circuit ledger in place. Each event term has one owner and one unit.

Required identity/provenance fields:

- design ID and freeze status (`pre_freeze` or a design-freeze manifest ID);
- architecture-contract revision;
- operand-format and microarchitecture-config revisions;
- transaction/fixture ID;
- model/layer/projection/sample scope when derived from a model artifact;
- input artifact checksum;
- simulator revision and command;
- completeness status.

Candidate stage-1 counters, to be finalized with the transaction contract:

| Counter | Intended unit | Must remain distinct from |
|---|---|---|
| `target_mantissa_formations` | formed target activation elements | executed digits |
| `activation_element_reads` | runtime activation-element reads | target formations |
| `activation_digit_reads` | activation digit/bit-group reads, if the implementation has them | weight reads |
| `aligned_weight_element_reads` | stored offline-aligned weight elements read | old weight-digit reads |
| `standard_multiplier_issues` | accepted standard-multiplier operand pairs | old leaf cycles |
| `reduction_updates` | active reduction-node operations | multiplier issues |
| `accumulator_updates` | channel/partial-sum updates | reduction updates |
| `metadata_reads` / `metadata_writes` | metadata-store accesses by class | data-store accesses |
| `blocks_killed` | blocks suppressed by the local schedule | zero-valued products |
| `cycles_*` | cycles for an explicitly named pipeline phase | analytic work ratios |

There are no active payload, packet, boundary, shard, or stage-2 queue fields.
If a future design genuinely adds a communication structure, it requires a new
architectural decision and schema revision.

## 5. Source-status vocabulary

Every scalar or table column must carry one of:

| Status | Meaning |
|---|---|
| `trace` | Directly counted from a versioned input/ledger |
| `rtl_sim` | Observed in functional RTL simulation |
| `mapped` | From a recorded mapped synthesis/timing report |
| `formula` | Derived from cited inputs and a versioned equation |
| `proxy` | Analytic activity/capacitance or other approximation |
| `assumption` | Chosen design parameter, not measured |
| `pending` | Required but not yet available |
| `unusable` | Source exists but violates the active schema/scope |

Aggregation preserves the weakest relevant status and the component-level
statuses. A formula using a mapped area and an assumed clock remains a formula;
it does not become mapped end-to-end latency.

## 6. RTL and technology evidence

The supported open-source flow begins with:

- Icarus Verilog 11.0 for SystemVerilog functional simulation and VCD output;
- Yosys 0.63+184, git `240439bdb`, for elaboration, synthesis, and Liberty
  mapping;
- ABC through Yosys for technology mapping;
- the local Nangate Open Cell Library, typical 1.1 V and 25 °C, under
  `hardware_sim/tech/nangate45/`.

Reports must capture the actual tool versions at execution time. Icarus proves
functional behavior only. Yosys/ABC cell area and delay are mapped estimates,
not post-layout signoff. Old Anchor-2/3 energy scripts used analytic proxies
even when a VCD was generated; their coefficients are retired.

Mapped reports used by the design-mature release must also identify the exact
RTL filelist/top parameters, timing constraints, operand and microarchitecture
configs, library checksum, and design-freeze status. A report from an
exploratory parameter point cannot be substituted for the canonical layout
candidate.

## 7. Combining numerical and hardware evidence

A paper table may join:

```text
frozen quality/work row
    + explicit translation artifact
    + new event-ledger row
    + new RTL/mapped/formula cost row
```

The joined row must expose both provenances and declare whether the quality
number is full PPL, sampled PPL, calibration-only, or a work-only trace. It
must not present mixed-scope values as one end-to-end measurement.

## 8. Acceptance tests for the schema

- Reject unknown schema versions and missing checksums.
- Reject `down_proj` in a `stage1_custom` ledger.
- Reject old v1 payload/queue fields in v2.
- Reject aggregate gate/up inference from an 84-projection total.
- Preserve source statuses through JSON, CSV, and Markdown generation.
- Reproduce numeric results and event counts in Python/RTL tiny fixtures.
- Make incomplete or formula-derived fields visible, never default them to
  zero or `measured`.

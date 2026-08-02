# Hardware configurations

This directory will hold versioned machine-readable operand, microarchitecture,
ledger, and characterization configurations.

Frozen now:

- [`operand_format_m1_v3.json`](operand_format_m1_v3.json): canonical M1
  three-bit activation target, rounded signed 8-bit Q6 offline-weight
  alignment, temporal placement, arithmetic widths, and precision rules
  (`tss-m1-mxfp8-m3a4w8-p12-acc52-v3`).
- [`m1_arithmetic_freeze_v3.json`](m1_arithmetic_freeze_v3.json): checksums,
  resolved decision IDs, and independent-calculation evidence closing M1.

The superseded v1 Q17-activation/NAF interpretation and v2 19-bit aligned
weight format were removed before active implementation. Their rejection and
replacement are retained in the decision log rather than as selectable
configurations.

Configuration IDs must be immutable once used for a reported artifact. Changes
to widths, binary points, rounding, schedule mapping, lane count, or evidence
scope require a new ID and a decision-log entry.

The design-mature release will add one checked-in freeze manifest identifying
the canonical operand and microarchitecture configs, schemas, RTL filelist,
top parameters, constraints, regression evidence, mapped reports, tool
versions, and checksums. Exploratory configurations must never be mistaken for
additional layout candidates.

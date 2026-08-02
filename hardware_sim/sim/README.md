# Circuit-reference and trace simulation

This directory will contain the bit-exact Python hardware reference, offline
weight encoder, target-mantissa former, frozen-artifact adapter, and event
ledger v2 writer.

The code must be independent of the functional model implementation. It may
read versioned frozen artifacts, but it must not import the sibling
Transformers numerical kernel as its arithmetic oracle or modify functional
results.

M1 arithmetic is frozen in
`hardware_sim/configs/operand_format_m1_v3.json`. Active reference code begins
at M3, after M2 freezes the transaction and cycle-visible microarchitecture;
it must consume that operand configuration without inventing parameters.

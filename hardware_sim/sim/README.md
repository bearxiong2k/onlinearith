# Circuit-reference and trace simulation

This directory will contain the bit-exact Python hardware reference, offline
weight encoder, target-mantissa former, frozen-artifact adapter, and event
ledger v2 writer.

The code must be independent of the functional model implementation. It may
read versioned frozen artifacts, but it must not import the sibling
Transformers numerical kernel as its arithmetic oracle or modify functional
results.

No implementation should be added until the arithmetic-blocking items in
`hardware_sim/docs/architecture_contract.md` are resolved.


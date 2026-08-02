# Technology references

`nangate45/` contains the local Nangate Open Cell Library Liberty and Verilog
models used by the prior Anchor flow. Their use within this same
personal-research project was already cleared.

Preserve the original headers. Mapped reports must record exact checksums,
corner (typical), voltage (1.1 V), temperature (25 °C), and tool versions. Do
not describe Yosys/ABC results as post-layout signoff.

The current checked-in collateral is sufficient for functional cell models and
Liberty mapping, not for place-and-route. A later physical flow must inventory
and record provenance for compatible technology/cell LEF, routing-layer/RC data,
sites, vias, and any macro abstracts required by the frozen design. Missing
physical views are a flow dependency; they must not be filled by silently
redesigning the RTL.

Canonical hashes and origin revision are in
`hardware_sim/docs/reference/legacy_source_map.md`.

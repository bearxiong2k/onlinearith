# Hardware orchestration scripts

Reproducible Icarus, Yosys/ABC, co-simulation, characterization, and report
commands belong here. Scripts must resolve paths relative to the repository,
record tool versions/config checksums, fail on missing inputs, and write
generated outputs under `hardware_sim/artifacts/`.

Do not reuse a legacy script unchanged when it names old modules or event
semantics. The quarantined Yosys files are templates only.

Physical-design scripts are a post-M7 concern. They must consume the canonical
design-freeze manifest and may not select new RTL parameters or alter the
functional/cycle-visible contract.

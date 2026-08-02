# Active RTL

Place only synthesizable SystemVerilog for the frozen revised architecture in
this directory. No active modules exist yet.

M1 fixes the arithmetic widths and rules in
`hardware_sim/configs/operand_format_m1_v3.json`. RTL begins only after M2
freezes the microarchitecture that instantiates them.

Planned ownership:

- three-bit target activation-fraction formation/control, including the
  implicit leading bit and activation sign;
- standard fixed-point multiplier wrapper;
- reviewed metadata/window control;
- reviewed metadata storage;
- time-aligned reduction and accumulation;
- one small stage-1 integration top.

Do not add stage-2, packet, payload, FIFO, shard, or queue modules. Do not point
an RTL filelist at `hardware_sim/reference/legacy_candidates/`.

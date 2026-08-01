# Active RTL

Place only synthesizable SystemVerilog for the frozen revised architecture in
this directory. No active modules exist yet.

Planned ownership:

- target activation-mantissa formation/control;
- standard fixed-point multiplier wrapper;
- reviewed metadata/window control;
- reviewed metadata storage;
- reduction and accumulation;
- one small stage-1 integration top.

Do not add stage-2, packet, payload, FIFO, shard, or queue modules. Do not point
an RTL filelist at `hardware_sim/reference/legacy_candidates/`.


# Stage-1 Tile Power Summary

## Scope

- Architecture: 136 x HS128X32 SRAM macros with DFF activation storage.
- Power corner: TT, 0.90 V, 25 C.
- Netlist: current mapped netlist, `synth/results/stage1_tile_mapped.v`.
- Activity: mapped GLS VCD, 250 MHz, 100% net and leaf-cell annotation.
- This is a pre-route activity-based estimate. The existing routed netlist is
  older than the current mapped netlist and has the obsolete activation
  interface, so its SPEF/SDF must not be used for this architecture.

## Current Frequency Evidence

The current pre-CTS run uses a 4.000 ns constraint and reports all-path WNS of
-0.008 ns. The corresponding zero-slack estimate is:

```text
Tmin = 4.000 ns + 0.008 ns = 4.008 ns
Fmax = 1 / 4.008 ns = 249.5 MHz
```

The reg-to-reg subset has +0.381 ns slack, but the constrained I/O-to-SRAM
paths set the current all-path limit. Final Fmax requires CTS, route, extracted
STA, and a period sweep for the current netlist.

## Activity Windows

```text
Full operation: 20 ns to 147720 ns
  Includes configuration, beta/weight SRAM writes, and two compute datasets.

Compute only: 138520 ns to 147720 ns
  Weights are already resident. Includes SRAM reads, activation streaming,
  and MAC/reduction/accumulation.
```

## PrimeTime-PX Results At 250 MHz

| Window | Internal | Net switching | Dynamic | Leakage | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| Full operation | 16.900 mW | 0.260 mW | 17.160 mW | 2.028 mW | 19.2 mW |
| Compute only | 24.600 mW | 1.812 mW | 26.412 mW | 2.027 mW | 28.4 mW |

## Estimated Power At 249.5 MHz

Dynamic power is scaled linearly by 249.5/250. Leakage is unchanged.

| Window | Dynamic | Leakage | Total |
| --- | ---: | ---: | ---: |
| Full operation | 17.13 mW | 2.03 mW | 19.15 mW |
| Compute only | 26.36 mW | 2.03 mW | 28.39 mW |

The compute-only average is higher because the full-operation window spends
most of its time serially writing SRAM while the 512 multipliers are idle.

## Evidence

- `power/reports/stage1_tile_full_power.rpt`
- `power/reports/stage1_tile_compute_power.rpt`
- `power/logs/pt_power_full.log`
- `power/logs/pt_power_compute.log`
- `build/tile_mapped_gls/stage1_tile_power.vcd`
- `pnr/reports/prects_timing/stage1_tile_preCTS.summary.gz`

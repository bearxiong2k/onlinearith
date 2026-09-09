# TSS delivery audit for conference writing

Status: **audited reference delivery; active architecture unchanged**.
Audit date: 2026-09-09. Scope: read and organize supplied material, inspect RTL
and reports, verify copied bytes, and perform inexpensive syntax/elaboration.
No model evaluation, calibration, synthesis, power replay, or layout flow was
run.

Writing-stage addendum: the author has since supplied a
[layout image](../../reference/layout_20260909/README.md) for the new paper.
The inventory below remains an audit of the original `../TSS` package. Its
absence of a layout figure does not describe the updated writing collection;
the image's design/dimensions and report association are recorded separately.

## Finding

`../TSS` supplies a useful **Stage-1 conventional-multiplier presentation
prototype** and genuine technology-mapped synthesis reports. It does not
supply a completed layout or reproducible power/functional-verification
package. Its arithmetic and schedule differ from the corrected frozen M1
contract in this repository. It must remain a separate evidence lineage until
those differences are explicitly resolved.

The [snapshot](../../reference/tss_delivery_20260909/README.md) preserves all
useful delivered files. It does not close M2, implement the active M3/M4
design, or satisfy the M7 physical-design handoff gate.

## Provenance and inventory

| Item | Recorded value |
| --- | --- |
| Source root | `../TSS`, inspected at `/home/xzj/coding/TSS` |
| Source repository | `git@github.com:Yurunru07/TSS.git` |
| Revision | `dd6fe890c36effd248b4d0ae56947d7dadfb7dd1` |
| Author timestamp | `2026-08-18T19:26:50+08:00` |
| Committer timestamp | `2026-08-18T19:51:03+08:00` |
| Working tree | Clean, including untracked-file check |
| Tracked inventory | 40 files; 21,912,875 bytes |
| Preserved payload | 39 files; 20,758,047 original bytes; 4,032,154 stored bytes |
| Excluded tracked file | `TSS-Temporal Significance Scheduling for MX-Quantized LLM FFN Inference on CIM.pdf`, 1,154,828 bytes |
| Other exclusion | `.git` internals; no caches or other untracked delivery files were present |

The [manifest](../../reference/tss_delivery_20260909/manifest.json) records
every tracked source path, size, SHA-256, Git blob ID, destination, and
disposition. The [checksum list](../../reference/tss_delivery_20260909/SHA256SUMS)
identifies the stored payload. Two large text artifacts are losslessly
compressed: `stage1_tile_v1/synth/results/stage1_tile_mapped.v` and
`stage1_tile_v1/synth/reports/reference_hierarchy.rpt`. Both original and stored
hashes are retained. The snapshot keeps original source-relative structure
under `source/`, adding only `.gz` to those two files.

No file was imported into active `rtl/`, `sim/`, `configs/`, or `fixtures/`.
The frozen functional simulator and sibling repositories were not modified.

## What the delivered implementation represents

The delivered [implementation description](../../reference/tss_delivery_20260909/source/stage1_tile_v1/docs/stage1_tile_architecture.md)
and [path RTL](../../reference/tss_delivery_20260909/source/stage1_tile_v1/rtl/core/stage1_path_engine.sv)
describe eight owner-lane pairs, sixteen Gate/Up paths, 512 signed 8-by-8
multipliers, sixteen five-level reduction trees, and sixteen 28-bit
accumulators. Each command processes 128 blocks in tile lockstep, with input
activation stalls permitted between blocks.

There are 136 HS128X32 SRAM instances: 128 for weights, four for `beta_w`,
and four for generated delay. Activation storage is one 384-bit streamed
value/fine-code block plus a 1,024-bit resident `beta_x` DFF table. The design
uses a 16-entry, four-bit lambda LUT and sixteen eight-bit horizons. A shared
prepass forms `Emax` and delay. These are useful examples of memory banking,
stream control, macro boundaries, and hierarchy; they are not automatically
the active microarchitecture.

The earlier [presentation brief](../../reference/tss_delivery_20260909/source/stage1_presentation_layout_contract.md)
is also present under `stage1_tile_v1/docs/` with identical SHA-256
`fe8afe77ff8c7e36cbced075fc69bfa6e365f619ab7bf12f97d7d53525953ccc`.
It describes ping-pong activation buffers and per-lane start/busy/done
interfaces. The delivered implementation instead uses a single streamed
activation DFF block and a tile-level command. `activation_pingpong.sv`
remains in the source tree but is absent from both delivered filelists.
Use the implementation description and the actual filelist together when
explaining the delivered design; do not combine the two document generations.

## Conflicts with local M1 and M2

| Boundary | Frozen local contract | Delivered prototype | Consequence |
| --- | --- | --- | --- |
| Activation target | Normalized three-bit binary fraction prefix, implicit leading one, sign sideband; unsigned four-bit magnitude | External signed eight-bit operand | Missing target former and unprovided MXFP8 recode definition prevent numerical equivalence |
| Window | `R=min(3,max(0,H-D-lambda_x-2))`; no product when `R=0` | Entire signed product enabled by `D+lambda_lut[fine] < H` | No two-position offset or partial-prefix behavior |
| Temporal significance | Exact placement `P << (28-tau)` | Unshifted enabled products sum directly | Arrival controls suppression only; it does not place product significance |
| Product and sums | 12-bit product, 40-bit placed product, 45-bit block sum, 52-bit saturating accumulator | 16-bit product, 21-bit block sum, 28-bit wrapping accumulator | Different numerical contract and output scale |
| Weight preparation | Signed eight-bit Q6, explicit nearest-even `decode_q9/2^11` | Signed eight-bit value; no supplied encoder or fixed-point definition proving this mapping | Matching storage width is insufficient evidence of matching values |
| Lambda and horizon | Exact `lambda_x=8-e_x`, zero sentinel 31; `H` in `[0,31]` | Four-bit programmable lambda values, eight-bit `H`, saturated eight-bit `D` | Legal local subnormal delays can exceed 15; local zero/schedule rules are not represented |
| Microarchitecture | Eight `OPEN-ARCH-*` decisions remain open locally | Chosen lane count, SRAM banking, command protocol, pipeline and SMIC technology | These are adoption candidates, not resolutions in the local decision log |

For a concrete schedule counterexample, `tau=9, H=10` enables a nonzero
delivered leaf, while local `R=max(0,10-9-2)=0` suppresses it. Even when both
paths enable a leaf, omitting common-tail placement and fraction-prefix
formation changes the result. Frozen PPL and executed-digit ratio therefore
cannot be assigned to this prototype's RTL outputs. The existing local M1
already distinguishes its arithmetic from the frozen functional oracle;
the delivery adds a third distinct numerical interpretation.

The earlier presentation brief explicitly disclaims cycle-accurate temporal
significance scheduling, model-to-RTL bit equivalence, and regenerated paper
performance results. That scope statement must remain attached to any reuse.

## Evidence register

The following statuses follow the local [evidence contract](../evidence_contract.md).
They apply to this prototype alone. Numbers transcribed from a delivered report
were not independently regenerated.

| Quantity or claim | Value / source | Status and practical limit |
| --- | --- | --- |
| Summed mapped cell area | `887809.406578` library area units, interpreted as µm² by the delivered architecture; about `0.887809 mm²`; `synth/reports/area_hierarchy.rpt` | `mapped`; includes macros and standard cells, excludes physical die/core/routing area |
| SRAM macro count/area | 136; `768414.144531` library area units; `synth/reports/qor.rpt` | `mapped`; about `0.768414 mm²` under the same unit interpretation |
| Technology and synthesis tool | SMIC 28 nm SCC28 RVT plus HS128X32, TT 0.90 V, 25 °C; Design Compiler `W-2024.09-SP5-5`; reports dated 2026-08-14 | `mapped` provenance; actual library files/checksums are absent |
| Target period | 4.000 ns; 0.150 ns uncertainty; 0.500 ns input/output delay; `synth/constraints/stage1_tile_4ns.sdc` | `assumption`; 250 MHz is a selected target |
| DC setup | Critical-path slack `+2.36 ns`; no setup violations in `qor.rpt` | `mapped`; ideal clock and no wire-load model; not routed timing |
| DC hold | Worst hold violation `-0.21 ns`; 17,499 violating paths; `qor.rpt` | `mapped`; hold closure is not established |
| Pre-CTS all-path WNS | `-0.008 ns`, stated in `power/reports/stage1_tile_power_summary.md` | `pending` verification; cited pre-CTS report is missing |
| Estimated frequency | `1/(4.000+0.008) ns = 249.5 MHz` from that summary | `formula` over a chosen period and an unverified report transcription; not measured Fmax |
| Full-operation power | 19.2 mW total; PrimeTime-PX `stage1_tile_full_power.rpt` | `proxy`: library-based pre-route power estimate, with replay inputs absent |
| Compute-only power | 28.4 mW total; PrimeTime-PX `stage1_tile_compute_power.rpt` | `proxy`: same boundary; not chip-measured or post-route power |
| Block / command power | Each reported as 27.1 mW total in its respective report | `proxy`; activity windows and replay commands are not supplied, so preserve as distinct results |
| Power tool/corner | PrimeTime `V-2023.12-SP5-2`, TT 0.90 V, 25 °C; reports dated 2026-08-18 | Recorded provenance; no extracted parasitic model in delivery |
| 100% VCD annotation / multi-dataset GLS | Claimed by power summary | `pending` verification; VCD, testbench and power logs absent |
| Layout, CTS/route, extracted STA, DRC/LVS/antenna, SDF GLS | Described as completion gates | `pending`; no corresponding artifacts delivered |
| Frozen quality, work ratios or model-level energy/latency improvements for this RTL | No evidence bridge provided | `pending`; attribution to this prototype is unsupported |

The full-operation window is reported as 20–147720 ns, including configuration
and two compute datasets. Compute-only is 138520–147720 ns with resident
weights, streamed activations, SRAM reads, and computation. These windows
explain why the full-operation mean is lower; they are not interchangeable
energy-per-token denominators. The reported 249.5 MHz power values are
`formula` results from linear dynamic-power frequency scaling and unchanged
leakage, not an additional power run.

The power method is more specific than the retired ad hoc activity/capacitance
coefficients: real PrimeTime-PX library reports are supplied. It nevertheless
remains a pre-route estimate with unavailable activity and library inputs.
The source summary explicitly says the older routed netlist has an obsolete
activation interface and must not supply SPEF/SDF for the current netlist.

## Missing delivery inputs and unresolved report checks

Paths below are relative to source `stage1_tile_v1/` unless absolute.

- `memory/HS128X32/HS128X32.v`, required by `filelists/tile_rtl.f`, is absent.
  Only the synthesis black-box declaration and wrapper are supplied.
- The HS128X32 `.db`, LEF/GDS, timing and simulation views, and the standard-cell
  `.db` and simulation models are absent. Reports identify
  `HS128X32_tt_ctypical_0p90v_0p90v_25c` and
  `scc28nhkcp_hdc35p140_rvt_tt_v0p9_25c_basic`, but provide no library hashes.
- No standalone synthesis, formal, simulation, PnR, or power scripts are
  supplied. The DC log preserves many commands, but uses unavailable
  `/share/ScLib/smic/...` and `/share/home/ST015_YRR/...` paths. It sources
  `constraints/stage1_tile_4ns.sdc`; the delivery places that file under
  `synth/constraints/`, so even a reconstructed script needs explicit path
  reconciliation.
- No independent arithmetic reference, operand recoder, testbench, fixture,
  seed list, formal-equivalence report, or GLS log is present.
- The summary's `power/logs/pt_power_full.log`,
  `power/logs/pt_power_compute.log`, and
  `build/tile_mapped_gls/stage1_tile_power.vcd` are absent.
- The summary's
  `pnr/reports/prects_timing/stage1_tile_preCTS.summary.gz` is absent. There is
  no `pnr/` subtree and no delivered layout screenshot, GDS/OASIS, DEF,
  placement database, SPEF, SDF, or signoff report.
- DC `check_design.rpt` records 32 unloaded inputs, 569 unconnected ports,
  48 same-cell multi-pin connections, and 388 unloaded nets. Some may be
  benign unused outputs; no disposition or waived-warning record is supplied.
  The log also contains four signedness warnings and a high-fanout timing
  approximation. These must be reviewed before claiming clean synthesis
  closure.

## Checks performed

The importer inventoried all tracked files, confirmed a clean source checkout,
hashed each original and stored file, and checked lossless decompression of
the two compressed artifacts. Synthesis-filelist paths exist; the simulation
filelist has exactly the missing macro-model path listed above.

Icarus Verilog 11.0 successfully elaborated the delivered `stage1_tile` using
`-g2012 -DSYNTHESIS -s stage1_tile -c filelists/synth_rtl.f`, with output in a
temporary directory. It emitted 1,015 diagnostic lines: repeated conservative
`always_*` constant-select sensitivity messages and four warnings about
`$fatal` in assertion processes. This establishes inexpensive source parsing
and elaboration with an SRAM black box only. No simulation was run, so this
check does not establish `rtl_sim` result parity, memory behavior, or timing.

## Reuse and reconciliation

1. Use the snapshot now for source tracing, implementation illustrations, and
   explicitly scoped presentation-prototype area/power discussion. Keep the
   original conventional-multiplier label and the report limitations visible.
2. Use the subsequently supplied layout artwork in the writing plan and attach
   its design identity to the caption. Obtain matching physical, verification,
   activity, and technology reports for numerical route/signoff claims. Keep
   any older 162-macro/ping-pong implementation under a different design identity.
3. Decide the numerical hardware intended for the new paper. Adopting this
   delivery's arithmetic would require a new operand/configuration identity
   and explicit M1 change decisions. Retaining local M1 requires redesigning
   target formation, temporal placement, widths, and verification; its cost
   cannot be inferred by rescaling the delivered 8-by-8 multiplier area.
4. Review the reusable memory, prepass, configuration and stream mechanics
   against every open M2 decision. Freeze the chosen topology, protocol,
   pipeline, storage, constraints, ledger, and a cycle-annotated fixture before
   promoting code into active source lists.
5. Establish independent numerical/RTL/netlist parity and a versioned quality
   and hardware-event bridge before joining this lineage with frozen PPL or
   executed-digit ratio. Keep hardware reads, cycles, area and energy separate.
6. Complete the existing M3–M7 gates for the selected design, with exact
   source/config/tool/library/report checksums. Existing external prototype
   reports are useful prior evidence, not a substitute for those gates.

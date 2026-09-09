# Current paper revision direction

Status: author-directed writing plan, 2026-09-09. Venue remains undecided
between DATE and ISCAS. This plan takes precedence over the earlier audits'
suggested rewrite order. The audits remain references for source accuracy;
collecting an artifact does not give it equal weight in the paper.

## Agreed priorities

1. Use the larger-model results gathered during the rebuttal to strengthen the
   evidence for scalability. Figure 4 is the main candidate for expansion.
2. Change other existing figures only when needed for that story or to correct
   an affected claim, label, or data point.
3. Add or adapt a figure showing end-to-end performance with attention on the
   GPU and the accelerated computation accounted separately.
4. Correct hardware reporting to **whole-chip area and energy overhead**.
   The author identifies the previous per-tile/per-channel attribution as a
   writing mistake.
5. Add the supplied layout figure to support the hardware implementation and
   results. Keep hardware prose changes focused on the experiment and its
   reporting boundary.

The writing baseline remains the ICCAD paper. The active M1 development plan
does not automatically become a new paper outline or require a broad redraw
of its figures. This writing task does not change the frozen simulator or
launch a replacement hardware implementation.

## Figure and evidence use

| Figure/material | Planned use | Extent of change |
|---|---|---|
| Figure 4: main quality/work result | Enrich the existing comparison with Qwen3-1.7B, 4B, and 8B rebuttal results, retaining 0.6B as the original reference | Primary figure expansion; choose panels after checking page budget |
| Full-test scale table | FP16, dense MXFP8, TSS 30 dB and 17 dB, plus matched baseline comparisons | Main supporting evidence for scalability; can sit beside Figure 4 |
| Llama cross-family result | Additional family check | Compact supporting table/panel if useful; secondary to the requested scale evidence |
| Figure 5: latency | Add a GPU attention/non-FFN and accelerated-work breakdown, or attach a new end-to-end panel | Prefer adapting an existing result figure if it stays readable |
| Figure 7: hardware costs | State whole-chip total and scheduling-support area/energy contributions | Correct boundary, denominator, units, and associated prose |
| New layout figure | Use the supplied physical-layout view alongside hardware results | New figure or a paired layout/cost figure; numbering provisional |
| Figures 1–3 and 6 | Retain their role in the existing explanation and ablations | Targeted corrections only where the retained material needs them |
| Calibration/K sweeps, old plans, intermediate rebuttal results | Supporting context or reserve material | Promote only when needed to answer a specific writing question |

The [figure/data audit](figure_data_audit.md) links the larger-model full and
sampled results. The [local catalog](evidence/result_catalog.tsv) contains the
source paths and scopes. A practical Figure 4 option is a common-style panel
per Qwen scale, with full-test quality numbers in an adjacent compact table.
This is a candidate layout, not a requirement to replace every existing panel.

For curves, use comparable sampled PPL/work pairs where available. Keep full
PPL from the 30 dB and 17 dB runs visibly distinct from the 300-sample work
passes. Use **executed-digit ratio** on the algorithmic work axis. Repair the
documented N:M keep-count/source mismatches when those data points enter the
updated figure; no new model run is implied by that correction.

## End-to-end GPU figure

The [preserved GPU profile](../../hardware_sim/reference/rebuttal_gpu_20260909/README.md)
provides Qwen3-1.7B measurements on an RTX 5090, batch 1, bfloat16. The
measured non-FFN path includes attention and other remaining work; label it
**GPU attention and other non-FFN work**, since it is not an isolated attention
kernel timing.

| Scenario | Measured full GPU median | Measured GPU non-FFN median | Derived GPU FFN slice |
|---|---:|---:|---:|
| One-token decode, 2048-token KV context | 22.7986 ms | 20.7103 ms | 2.0882 ms |
| 512-token prefill | 24.9042 ms | 20.6057 ms | 4.2986 ms |

The rebuttal used a scenario estimate:

```text
T_GPU_FFN = T_GPU_full - T_GPU_nonFFN
T_estimated = T_GPU_nonFFN + r_FFN * T_GPU_FFN
```

Use a stacked breakdown with measured GPU non-FFN work and the explicitly
estimated accelerated component. State the full-GPU normalization and the
source of `r_FFN`. The supplied legacy hybrid rows remain available for
tracing the old analysis; their ratios are not measurements of the newly
illustrated layout.

If the final hardware boundary covers only gate/up, account for the remaining
FFN work separately before substituting a full-FFN ratio. For an absolute
GPU-plus-accelerator latency claim, include accelerator service time and
transfer/synchronization cost under the stated overlap policy. The current
ratio-based profile does not measure that coupled system. Its one warmup and
three repetitions should remain visible in the methodology; this is one
system scenario, separate from the multi-model quality scalability evidence.

## Whole-chip area and energy reporting

Use the complete CIM accelerator chip as the hardware accounting boundary;
the GPU is the separate system component in the end-to-end figure. State the
chip's replicated compute/memory blocks and shared peripheral/control terms.
Correct per-channel/per-tile labels in the hardware experiment text, Figure 7,
table captions, and repeated abstract/conclusion claims where the intended
quantity is chip-wide. The original manuscript snapshot retains its old text.

Distinguish the requested quantities explicitly:

| Quantity | Definition |
|---|---|
| Total chip area | Entire implemented accelerator area under a stated cell/core/die convention |
| Scheduling-support area fraction | `A_support / A_chip` |
| Total chip energy | All included chip components over the same declared inference/workload interval |
| Scheduling-support energy fraction | `E_support / E_chip` |
| Incremental overhead versus a matched baseline, if reported | `(A_TSS - A_base) / A_base` and `(E_TSS - E_base) / E_base` |

Use one denominator consistently for each percentage. Preserve a published
number only after identifying its chip-wide source total and component
numerator; changing a label alone does not derive an aggregation. Convert
power to energy using the corresponding activity duration/work unit, and keep
mW distinct from nJ or energy per token. Report energy savings separately
from the scheduling logic's energy contribution.

Candidate experiment wording:

> We evaluate the area and energy cost of temporal significance scheduling
> over the complete accelerator chip, including its replicated compute and
> memory blocks and shared scheduling support. End-to-end latency combines
> the GPU attention and other non-FFN component with the separately evaluated
> accelerated component under the stated system model. The layout figure
> illustrates the hardware implementation used for the physical evaluation.

Finalize the last sentence and numeric overheads against the layout's design
identity and matching reports. This is focused experiment wording, not a
claim that a layout image establishes model-output equivalence.

## Supplied layout figure

The author added [layout.jpg](../../layout.jpg). It is a 735-by-735 PNG image
despite its filename extension. A byte-identical
[layout.png](../../hardware_sim/reference/layout_20260909/layout.png) is now
registered under hardware reference material for reliable figure inclusion;
the original is retained.

The image supplies the previously missing layout artwork. It shows repeated
rectangular regions and interconnect/placement structure, but carries no
embedded design label, dimensional scale, legend, or report identifier.
Record the design revision and die/core dimensions in the
[layout record](../../hardware_sim/reference/layout_20260909/README.md) when
provided. Use them for the final caption and the connection to the whole-chip
cost results. The earlier statement that the `TSS` delivery had no layout
figure describes that original package, not the now-updated project.

## Next writing pass

Prepare the Figure 4 data selection and multi-model presentation first. Then
draft the end-to-end panel and whole-chip hardware wording together with the
layout caption. Apply any necessary small corrections to retained figures.
Select DATE or ISCAS and adapt the template once the resulting content is
clear. Avoid expanding this into a general replacement of every result figure.

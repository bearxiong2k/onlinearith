# Reviewer Coverage Checklist

This checklist maps reviewer comments/questions to the current rebuttal draft.
It is intended as an audit aid before compressing the final submission.

## Review #229A

| Concern | Coverage |
|---|---|
| Larger LLMs / other model families | Qwen3-0.6B/1.7B/4B/8B full-PPL table; Llama-3.2-3B sampled attachment table |
| FFN-layer speedup to full-model latency | Hybrid Qwen3-1.7B table uses measured full GPU timing, measured GPU non-FFN timing, and V4 TLM/CIM FFN ratios for decode and prefill |

## Review #229B

| Concern | Coverage |
|---|---|
| Figure 2(a) high-level computation | Algorithm/compiler-flow section explains GLU-FFN block dot product, gate/up paths, activation and stationary weight operands |
| TSS delay/frequency overhead | Control-plane section reports A0/A1 timing, controller/SRAM stages, and slack |
| Whether execution can be pipelined | Added precise "control is throughput-hidden, stage movement uses boundary model" paragraph |
| Compiler/SW support | Static lowering flow: identify FFN projections, MXFP8 quantization, weight recoding, horizon tables |

## Review #229C

| Concern | Coverage |
|---|---|
| Stronger/recent flexible sparsity and CIM baselines | Added baseline-framing paragraph; hardware-fair activation mask-compare model; older citations framed as lineage |
| System-level hardware comparison beyond control area | Full-model latency/energy/area table with TSS and mask-compare CIM; mask 2:4 latency now uses formula-backed tree-depth benefit |
| Algorithmic detail: `lambda_x`, block quantization, recoding, calibration | Deterministic delay recipe, block quantization paragraph, offline weight recoding, calibration algorithm |
| Non-ideal overhead inclusion | Control-plane section plus source-status attachment; A0/A1/A3/A4 rows and exposed-cycle policy |
| Conceptual mask-vs-TSS misunderstanding | Scalability/quality section explains software upper bound vs hardware-realizable temporal schedule |

## Review #229D

| Concern | Coverage |
|---|---|
| Larger model | Qwen3 scale and Llama cross-family rows |
| Calibration runtime | Calibration-cost section reports Qwen and Llama wall-clock times |
| Online/lightweight adaptation discussion | Added static-horizon and possible bounded metadata-offset future-work paragraph |
| K=16/64 variation | Qwen3-1.7B K=8/16/32/64/128 table |
| Minor figure/table issues | Final paragraph promises Fig. 1, Eq. (4), Table 1 node, and caption fixes |

## Review #229E

| Concern | Coverage |
|---|---|
| FFN-only bottleneck / attention and KV cache | Measured full GPU is the denominator; Qwen3-1.7B decode/prefill table keeps GPU full, GPU non-FFN, derived GPU FFN, and CIM FFN ratio buckets separate |
| Time distribution of FFN in several LLMs | The shape-derived multi-model distribution is retained only as internal sensitivity; reviewer-facing latency uses the measured Qwen3-1.7B hybrid table |
| Full-precision PPL | FP16 column in Qwen3 full-PPL table |
| Same tau example in Fig. 2(b) | Minor-fixes paragraph promises consistency |
| Data-plane leaf area | Added paragraph distinguishing common MXFP8 data-plane leaf area from incremental TSS overhead |
| Offline phase overhead | Calibration-cost section |
| Overall language-model latency | Full-model decode/prefill latency table |

## Remaining Caveats To Keep Explicit

- ICCAD rebuttal constraints: keep the response focused on reviewer questions,
  stay within 2000 words, avoid revised-manuscript framing, and use any
  attachment only as support for the response rather than as a revised paper.
- Larger-model TSS energy rows are formula-backed from MSD global stats until
  full 300-sample event ledgers are exported.
- Current full-model latency rows use measured full GPU timing, measured GPU
  non-FFN timing, and TLM/CIM FFN ratios applied to the derived GPU FFN slice
  for Qwen3-1.7B. Additional models would strengthen the evidence but are no
  longer required by the narrowed roadmap.
- The hardware-fair activation 2:4 mask row now uses a nonzero
  tree-depth/selected-reduction latency benefit while still avoiding the
  unrealistic "2:4 halves everything" model. Packed 2:4 issue would still need
  a separate Anchor 5 or equivalent signoff row.
- The rebuttal should describe the latency/energy rows as coming from the
  TLM-style simulator already claimed in the main text. Packaging that simulator
  as an anonymous repo is later work after the rebuttal direction is acceptable.
- A1 scheduler dynamic energy is still pending activity-based power.
- A2/A3 dynamic energy is a rough proxy, not signoff power.
- Qwen3-8B near-half-work sampled PPL is not a universal software win over
  activation 2:4; the rebuttal should frame TSS as the hardware-realizable
  regular point, not as a universal software-selection upper bound.
- An idle-GPU rerun with more repeats is a follow-up validation item, after
  the full-GPU-relative replacement.

# Model Performance Results Summary

Updated: 2026-06-11 18:49 Asia/Shanghai.

This file separates confirmed full-WikiText-2 results from sampled rebuttal
evidence. Use full-PPL rows for quality claims; use sampled rows for work,
latency, and curve-shape evidence.

## Confirmed Full-PPL Scale Table

Source:
`/home/xzj/coding/data/qwen3_final_experiments/model_sweep_4gpu/logs/full_unattended_20260528_155226/summary_full_with_stats_columns/summary_full.tsv`

Protocol: WikiText-2 raw test split, full scoring, MXFP8, K=32. TSS is the
fixed-sum 30 dB operating point.

| Model | MXFP8 PPL | TSS 30 dB PPL | Delta vs MXFP8 | WANDA 2:4 PPL | Act. N:M 2:4 PPL |
|---|---:|---:|---:|---:|---:|
| Qwen3-0.6B | 17.2754 | 17.3212 | +0.0458 | 40.3042 | 37.5716 |
| Qwen3-1.7B | 14.6248 | 14.4661 | -0.1587 | 27.2134 | 20.9451 |
| Qwen3-4B | 11.2757 | 11.2926 | +0.0169 | 18.7089 | 16.5446 |
| Qwen3-8B | 8.2964 | 8.3177 | +0.0213 | 12.4731 | 10.6433 |

Interpretation: at the high-quality operating point, TSS remains essentially on
the MXFP8 baseline across Qwen3 scales from 0.6B to 8B. The two 2:4 spatial
baselines degrade substantially more under the same full-PPL protocol.

## Confirmed Near-50% Qwen3 Evidence

Primary full-PPL source:
`/home/xzj/coding/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/logs/ppl_stats300_20260602_144534/fixed_sum17_ppl_stats_summary.tsv`

Qwen3-8B sampled stats source:
`/home/xzj/coding/data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_20260609_resume_fixed_missing/summary/sparsity_norm_sweep_limit300.tsv`

Protocol: TSS fixed-sum 17 dB. Full PPL rows use the full WikiText-2 test
split with stats disabled. Work columns come from the explicit `limit-samples
300` stats pass, so they should be described as sampled accounting.

| Model | TSS 17 dB Full PPL | Delta vs MXFP8 Full PPL | Sampled TSS PPL | Sampled `plot_norm_digit_read` |
|---|---:|---:|---:|---:|
| Qwen3-0.6B | 19.4307 | +2.1553 | 17.9080 | 0.4901 |
| Qwen3-1.7B | 14.9315 | +0.3067 | 13.7575 | 0.4728 |
| Qwen3-4B | 13.7060 | +2.4303 | 12.5480 | 0.4879 |
| Qwen3-8B | 11.5926 | +3.2962 | 10.5974 | 0.4732 |

Interpretation: the 17 dB point is close to a half-work operating point by
normalized digit read. It is useful for showing that TSS scales beyond Qwen3-0.6B,
but the Qwen3-8B 17 dB point should not be overclaimed because activation N:M
2:4 is stronger at the sampled 50% point.

## Sampled Work-Quality Curves

Source:
`/home/xzj/coding/data/qwen3_final_experiments/sparsity_norm_sweep300/logs/sweep300_20260609_resume_fixed_missing/summary/sparsity_norm_sweep_limit300.tsv`

All rows use `limit-samples 300`.

| Model | Method | Work Metric | Work Value | Sampled PPL |
|---|---|---:|---:|---:|
| Qwen3-1.7B | TSS 15 dB | digit-read | 0.4037 | 36.5666 |
| Qwen3-1.7B | TSS 17 dB | digit-read | 0.4728 | 13.7575 |
| Qwen3-1.7B | TSS 20 dB | digit-read | 0.5627 | 13.2780 |
| Qwen3-1.7B | WANDA 2:4 | keep ratio | 0.5000 | 25.6875 |
| Qwen3-1.7B | Act. N:M 2:4 | keep ratio | 0.5000 | 19.5281 |
| Qwen3-4B | TSS 15 dB | digit-read | 0.4205 | 16.2169 |
| Qwen3-4B | TSS 17 dB | digit-read | 0.4879 | 12.5480 |
| Qwen3-4B | TSS 20 dB | digit-read | 0.5781 | 10.9776 |
| Qwen3-4B | WANDA 2:4 | keep ratio | 0.5000 | 18.0816 |
| Qwen3-4B | Act. N:M 2:4 | keep ratio | 0.5000 | 15.1895 |
| Qwen3-8B | TSS 17 dB | digit-read | 0.4732 | 10.5974 |
| Qwen3-8B | WANDA 2:4 | keep ratio | 0.5000 | 11.4819 |
| Qwen3-8B | Act. N:M 2:4 | keep ratio | 0.5000 | 9.9869 |

Pending: Qwen3-8B TSS 15 dB and 20 dB sampled rows are running on GPUs 5 and 7.
At 2026-06-11 18:49, both were at 33/37 windows, about 89.2%, with ETA about
2 h 45 min.

## Cross-Family Llama-3.2-3B Status

Source root:
`/home/xzj/coding/data/rebuttal_experiments/llama32_3b`

All rows are sampled with `limit-samples 300`.

| Method | Status | Sampled PPL | Notes |
|---|---|---:|---|
| MXFP8 | complete | 6.5173 | baseline |
| WANDA 2:4 | complete | 15.1917 | sampled baseline |
| Act. N:M 2:4 | complete | 11.0518 | sampled baseline |
| TSS 15 dB | running | TBD | optional low-work point |
| TSS 17 dB | running | TBD | near-50% cross-family row |
| TSS 20 dB | running | TBD | quality-recovery row |
| TSS 30 dB | running | TBD | high-quality row |

Completed calibration times:

| Calibration | Wall Time |
|---|---:|
| Llama TSS 17 dB | 5584.0 s |
| Llama TSS 20 dB | 5692.0 s |
| Llama TSS 30 dB | 5868.7 s |
| Llama WANDA 2:4 | 769.1 s |

## Qwen3-1.7B K Sensitivity Status

Source root:
`/home/xzj/coding/data/rebuttal_experiments/qwen1_7b_k_sweep`

All rows are sampled with `limit-samples 300`.

| K | MXFP8 PPL | TSS 17 dB PPL | Delta vs MXFP8 | `plot_norm_digit_read` | Status |
|---:|---:|---:|---:|---:|---|
| 16 | 13.5906 | TBD | TBD | TBD | TSS row running |
| 32 | 13.5924 | 13.7575 | +0.1651 | 0.4728 | complete |
| 64 | 13.6242 | 13.7191 | +0.0949 | 0.4738 | complete |

Use qualitative framing: smaller K gives finer scale granularity and more
metadata/control entries; larger K reduces metadata but coarsens significance
ordering. The completed K=32/64 rows show the method is not singularly tied to
K=32, but K=16 is still needed for the reviewer-requested triad.

## Full-Precision Baseline Gap

Reviewer E asked for full-precision LLM perplexity rather than only the MXFP8
frontier. I found one aligned full WikiText-2 FP16 row for Qwen3-0.6B:

| Model | Precision | PPL | Source |
|---|---|---:|---|
| Qwen3-0.6B | FP16 | 17.3443 | `/home/xzj/coding/data/ppl_results_baseline.json` |

I did not find aligned full-PPL FP16 rows for Qwen3-1.7B/4B/8B or a valid
Llama-3.2-3B FP16 row. The only Llama FP16 JSON currently found is a
`limit-samples 2` smoke test with 9 scored tokens, so it should not be reported
as a baseline. If rebuttal space permits, add a compact FP16/MXFP8 comparison
only after aligned rows are generated or located.

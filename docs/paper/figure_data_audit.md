# Figure and numerical evidence audit

Examined and organized on 2026-09-09. The source repositories and the frozen
functional harness were read-only. Source evidence is now available as exact
local snapshots; neither numerical semantics nor manuscript figures were
changed.

For how these sources will enter the paper, follow the author's
[current revision plan](current_revision_plan.md). Larger-model rebuttal
results are the primary Figure 4 addition; other figures receive necessary
changes rather than equal expansion.

## What is ready for writing

The strongest numerical foundation is the completed Qwen3 full-test scale
sweep, its separate 17 dB full-PPL/sampled-work pair, and the completed
rebuttal sensitivity results. June status prose is stale in several places:
full FP16 baselines, Llama sampled TSS points, Qwen3-1.7B K sensitivity, and
Qwen3-8B 15/20 dB sampled points now have completed result JSONs.

Use **temporal significance scheduling** for the method and **local execution
windows on aligned contribution streams** for its algorithmic object. The
primary frozen work metric is **executed-digit ratio**. None of the work
ratios below is an independently measured hardware read, latency, energy,
or area reduction.

Each linked numeric cell below points to the exact JSON containing
`metrics.token_perplexity`. A work cell's source is its row's linked sampled
result and the field `msd_perf_stats.global.mean_effective_precision / 3.0`.

### Full-test quality across Qwen3 scales

All rows use WikiText-2 raw test, maximum context 4096, stride 512, and
299,078 scored tokens. MXFP8/TSS use K=32. TSS here is the 30 dB calibration.
Full FP16 baselines found after the June-11 summary close its recorded gap.

| Model | FP16 | Dense MXFP8 | TSS 30 dB | WANDA 2:4 | Activation 2:4 |
|---|---:|---:|---:|---:|---:|
| Qwen3-0.6B | [17.3443](evidence/snapshots/data/rebuttal_experiments/full_precision_baselines_full/qwen0_6b/ppl_results_FP16_qwen0_6b_full.json) | [17.2754](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen0_6b/full/ppl/mxfp8/ppl_results_MXFP8_qwen0_6b_sweep_full.json) | [17.3212](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen0_6b/full/ppl/fixed_sum30/ppl_results_MXFP8_fixed_sum30_qwen0_6b_sweep_full.json) | [40.3042](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen0_6b/full/wanda_base/2-4/ppl_results_MXFP8_qwen0_6b_sweep_full.json) | [37.5716](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen0_6b/full/act_base/2-4/ppl_results_MXFP8.json) |
| Qwen3-1.7B | [14.6644](evidence/snapshots/data/rebuttal_experiments/full_precision_baselines_full/qwen1_7b/ppl_results_FP16_qwen1_7b_full.json) | [14.6248](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen1_7b/full/ppl/mxfp8/ppl_results_MXFP8_qwen1_7b_sweep_full.json) | [14.4661](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen1_7b/full/ppl/fixed_sum30/ppl_results_MXFP8_fixed_sum30_qwen1_7b_sweep_full.json) | [27.2134](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen1_7b/full/wanda_base/2-4/ppl_results_MXFP8_qwen1_7b_sweep_full.json) | [20.9451](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen1_7b/full/act_base/2-4/ppl_results_MXFP8.json) |
| Qwen3-4B | [11.2364](evidence/snapshots/data/rebuttal_experiments/full_precision_baselines_full/qwen4b/ppl_results_FP16_qwen4b_full.json) | [11.2757](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen4b/full/ppl/mxfp8/ppl_results_MXFP8_qwen4b_sweep_full.json) | [11.2926](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen4b/full/ppl/fixed_sum30/ppl_results_MXFP8_fixed_sum30_qwen4b_sweep_full.json) | [18.7089](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen4b/full/wanda_base/2-4/ppl_results_MXFP8_qwen4b_sweep_full.json) | [16.5446](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen4b/full/act_base/2-4/ppl_results_MXFP8.json) |
| Qwen3-8B | [8.2722](evidence/snapshots/data/rebuttal_experiments/full_precision_baselines_full/qwen8b/ppl_results_FP16_qwen8b_full.json) | [8.2964](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen8b/full/ppl/mxfp8/ppl_results_MXFP8_qwen8b_sweep_full.json) | [8.3177](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen8b/full/ppl/fixed_sum30/ppl_results_MXFP8_fixed_sum30_qwen8b_sweep_full.json) | [12.4731](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen8b/full/wanda_base/2-4/ppl_results_MXFP8_qwen8b_sweep_full.json) | [10.6433](evidence/snapshots/data/qwen3_final_experiments/model_sweep_4gpu/qwen8b/full/act_base/2-4/ppl_results_MXFP8.json) |

### Full 17 dB quality with separately sampled work

The full PPL pass disables statistics. The work pass sets `limit_samples=300`,
uses 37 windows, and scores 22,336 tokens for each Qwen3 model. These are two
separate measurements with separate source links. Near-half work is useful
evidence; the corresponding quality cost differs substantially by model.

| Model | Full TSS 17 dB PPL | Sampled TSS PPL | Sampled executed-digit ratio |
|---|---:|---:|---:|
| Qwen3-0.6B | [19.4307](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen0_6b/snr17db/ppl/full_no_stats/ppl_results_MXFP8_fixed_sum_qwen0_6b_snr17db_full_no_stats.json) | [17.9080](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen0_6b/snr17db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen0_6b_snr17db_stats_limit300.json) | 0.4901 |
| Qwen3-1.7B | [14.9315](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen1_7b/snr17db/ppl/full_no_stats/ppl_results_MXFP8_fixed_sum_qwen1_7b_snr17db_full_no_stats.json) | [13.7575](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen1_7b/snr17db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen1_7b_snr17db_stats_limit300.json) | 0.4728 |
| Qwen3-4B | [13.7060](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen4b/snr17db/ppl/full_no_stats/ppl_results_MXFP8_fixed_sum_qwen4b_snr17db_full_no_stats.json) | [12.5480](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen4b/snr17db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen4b_snr17db_stats_limit300.json) | 0.4879 |
| Qwen3-8B | [11.5926](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_ppl_stats300/qwen8b/snr17db/ppl/full_no_stats/ppl_results_MXFP8_fixed_sum_qwen8b_snr17db_full_no_stats.json) | [10.5974](evidence/snapshots/data/qwen3_final_experiments/sparsity_norm_sweep300/fixed_sum/qwen8b/snr17db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen8b_snr17db_stats_limit300.json) | 0.4732 |

Qwen3-8B's original 17 dB stats file is absent from `fixed_sum17_ppl_stats300`;
the completed companion result above comes from `sparsity_norm_sweep300`.
The old [full-stats summary](evidence/snapshots/data/qwen3_final_experiments/fixed_sum17_full_stats/logs/full_stats_20260601_181331/fixed_sum_stats_full.tsv)
contains a completed 0.6B sanity row but is an interrupted experiment, not the
chosen four-model full-PPL/sampled-work protocol.

### Completed sampled evidence that supersedes pending statuses

Qwen3-8B's neighboring work/quality points now exist. All use the same
300-sample, 22,336-token scope.

| Point | Sampled PPL | Executed-digit ratio |
|---|---:|---:|
| TSS 15 dB | [12.5639](evidence/snapshots/data/qwen3_final_experiments/sparsity_norm_sweep300/fixed_sum/qwen8b/snr15db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen8b_snr15db_stats_limit300.json) | 0.4061 |
| TSS 17 dB | [10.5974](evidence/snapshots/data/qwen3_final_experiments/sparsity_norm_sweep300/fixed_sum/qwen8b/snr17db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen8b_snr17db_stats_limit300.json) | 0.4732 |
| TSS 20 dB | [8.4387](evidence/snapshots/data/qwen3_final_experiments/sparsity_norm_sweep300/fixed_sum/qwen8b/snr20db/ppl/stats_limit300/ppl_results_MXFP8_fixed_sum_qwen8b_snr20db_stats_limit300.json) | 0.5650 |

At the 17 dB point, Qwen3-8B TSS sampled PPL 10.5974 is higher than
[activation 2:4 PPL 9.9869](evidence/snapshots/data/qwen3_final_experiments/sparsity_norm_sweep300/baselines/qwen8b/act_base/2-4/ppl_results_MXFP8.json).
Do not describe TSS as dominating every model at approximately half work.

Llama-3.2-3B now has complete sampled comparisons. The table uses
`limit_samples=300`, 21,226 scored tokens; the independently measured
[full FP16 PPL 6.7423](evidence/snapshots/data/rebuttal_experiments/full_precision_baselines_full/llama32_3b/ppl_results_FP16_llama32_3b_full.json)
scores 289,077 tokens and belongs to a different comparison.

| Llama method | Sampled PPL | Executed-digit ratio (TSS only) |
|---|---:|---:|
| FP16 | [6.4944](evidence/snapshots/data/rebuttal_experiments/full_precision_baselines/llama32_3b/ppl_results_FP16_llama32_3b_limit300.json) | — |
| Dense MXFP8 | [6.5173](evidence/snapshots/data/rebuttal_experiments/llama32_3b/ppl/ppl_results_MXFP8_limit300.json) | — |
| WANDA 2:4 | [15.1917](evidence/snapshots/data/rebuttal_experiments/llama32_3b/wanda_base/2-4/ppl_results_MXFP8_llama32_3b.json) | — |
| Activation 2:4 | [11.0518](evidence/snapshots/data/rebuttal_experiments/llama32_3b/act_base/2-4/ppl_results_MXFP8.json) | — |
| TSS 15 dB | [6.9891](evidence/snapshots/data/rebuttal_experiments/llama32_3b/ppl/ppl_results_MXFP8_fixed_sum_llama32_3b_snr15db_stats_limit300.json) | 0.5248 |
| TSS 17 dB | [6.7859](evidence/snapshots/data/rebuttal_experiments/llama32_3b/ppl/ppl_results_MXFP8_fixed_sum_llama32_3b_snr17db_stats_limit300.json) | 0.5965 |
| TSS 20 dB | [6.6523](evidence/snapshots/data/rebuttal_experiments/llama32_3b/ppl/ppl_results_MXFP8_fixed_sum_llama32_3b_snr20db_stats_limit300.json) | 0.6809 |
| TSS 30 dB | [6.5271](evidence/snapshots/data/rebuttal_experiments/llama32_3b/ppl/ppl_results_MXFP8_fixed_sum_llama32_3b_snr30db_stats_limit300.json) | 0.8777 |

The `_msd1024` Llama files are also archived. Their recorded PPL and
`mean_effective_precision` equal their corresponding unsuffixed results;
they are retry/configuration evidence, not additional independent quality
observations. Llama 17 dB uses roughly 0.60 executed-digit ratio, so the old
“near-50% cross-family row” status label is inaccurate for the completed run.

Qwen3-1.7B K sensitivity is complete for five block sizes (300-sample scope).

| K | Dense MXFP8 PPL | TSS 17 dB PPL | Executed-digit ratio |
|---:|---:|---:|---:|
| 8 | [13.6369](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_k8_limit300.json) | [13.5499](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_fixed_sum_qwen1_7b_k8_snr17db_stats_limit300.json) | 0.4655 |
| 16 | [13.5906](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_k16_limit300.json) | [13.5840](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_fixed_sum_qwen1_7b_k16_snr17db_stats_limit300.json) | 0.4697 |
| 32 | [13.5924](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_k32_limit300.json) | [13.7575](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_fixed_sum_qwen1_7b_k32_snr17db_stats_limit300.json) | 0.4728 |
| 64 | [13.6242](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_k64_limit300.json) | [13.7191](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_fixed_sum_qwen1_7b_k64_snr17db_stats_limit300.json) | 0.4738 |
| 128 | [13.5624](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_k128_limit300.json) | [13.4459](evidence/snapshots/data/rebuttal_experiments/qwen1_7b_k_sweep/ppl/ppl_results_MXFP8_fixed_sum_qwen1_7b_k128_snr17db_stats_limit300.json) | 0.4738 |

Qwen3-4B has dense MXFP8 K=8/16/32/64/128 outputs, but only the K=32 TSS
output was found. Its wider K sweep is incomplete; the complete 1.7B table
must not be relabeled as 4B.

## Figure audit and reuse decisions

### Figure 4: retain design and source, rebuild evidence before reuse

The archived [preparer](assets/snapshots/figure/figure4/prepare_figure4_plot_data.py)
explicitly says N:M means N pruned and sets work to `(M-N)/M`. The frozen
harness defines N:M as **keep N**, requiring N/M for that baseline work
fraction. This affects non-half ratios; 2:4 happens to be unchanged. The
[plotting CSV](assets/snapshots/figure/figure4/figure4_plot_data.csv) and
rendered annotations carry the old convention. The upstream
`figure4_data.csv` named by the preparer is missing from `../figure`.

Numerical correspondence is also incomplete. For example, the CSV's 12 dB
fixed-sum row uses PPL **33.1887**, while the `cap100` result identified by
its [data-location note](assets/snapshots/figure/figure4/datalocation.md)
records [35.8778](evidence/snapshots/data/calib-data/12db/ppl_results_MXFP8_fix_cap.json).
The latter scores only 5,503 tokens. The CSV's source labels are categories,
not exact file paths, and its preparation allows manual row editing. This
is a verified disagreement with the documented candidate source, not a
conclusion about how the plotted value was produced. Use the leaf results
for new comparisons rather than treating the old curve as validated data.

### Figure 5: preserve as legacy functional cycle accounting

The [plan](assets/snapshots/figure/figure5/figure5plan.md) assumes channels
parallel, blocks serial, gate/up parallel, and a sum of up/down projection
cycles. The [CSV](assets/snapshots/figure/figure5/figure5_plot_data.csv)
contains 28-model-layer/56-projection aggregation, dense maximum/mean cycle
estimates, and a decomposition into zero-block and partial-window terms.
This describes the historical functional model. It is not a measured
standard-multiplier count, routed circuit latency, or full-system speedup.
The plotting schema has no per-row source path; the raw extraction program
is absent. Historical `*_time.json` results are retained for provenance.

### Figure 6: useful questions, several unvalidated plot inputs

[figure6_source_audit.tsv](evidence/figure6_source_audit.tsv) checks the 34
rows in panels A/B against their explicit `eval_file` paths. It finds one
PPL mismatch and 15 stored work-column mismatches against the frozen
executed-digit formula (rounding tolerance 0.0001).

- **Panel A:** 19 of 20 work rows match the cited source after division by
  three. The `24db` row points to a **23 dB** file, whose mean effective
  precision is 2.0180 (ratio 0.672667), while the CSV writes 0.702667. These
  legacy timing/PPL sources score 5,503 tokens, not the full test corpus.
- **Panel B:** the first two rows cite the same `p10` evaluation, but the
  first plots PPL **27.7255**, whereas the named source records
  [18.7255](evidence/snapshots/6b/atob_seed0_capscan_v2/cap2x_full/evals-test/ppl_AtoB_p10_seed0.json).
  All 14 stored `norm_digit_reads` values differ from the required
  `mean_effective_precision / 3.0`. This column is not an axis in panel B,
  but it cannot be reused as executed-digit evidence. Calibration-token
  labels were not independently reconstructed from tokenization.
- **Panel C:** its [four-row CSV](assets/snapshots/figure/figure6/figure6_panel_c_data.csv)
  gives no source paths. The weight-only value **1451.3346** matches
  [the eval_B subset result](evidence/snapshots/6c/evals/ppl_fig6c_weight_only.json)
  with **131,209** scored tokens. Layerwise **18.2600** and channelwise
  **19.8995** match the respective
  [19 dB fixed-sum](evidence/snapshots/data/calib-data/19db/ppl_results_MXFP8_calibration_fix.json)
  and [19 dB target-SNR](evidence/snapshots/data/calib-data/19db/ppl_results_MXFP8_calibration_snr.json)
  full-test results with **299,078** tokens. These are value matches rather
  than a verified construction history. The named `../6c` uniform results
  give **24.6614** on eval_B or **23.1028** on the capped subset, not the
  CSV's **18.5029**. A like-for-like four-method comparison is not established.

### Figure 7: historical hardware artwork

The [plot source](assets/snapshots/figure/figure7/plot_figure7.py) hard-codes
area values `[45.1, 7996.6, 2489.0, 2477.0]` and energy values
`[23.7, 328.0, 96.0, 488.9]` for controller, leaf, adder, and weight SRAM.
No report path or experiment ID is attached to these arrays. Preserve the
old PDF/source as artwork provenance. The separately organized `hardware_sim/`
delivery has mapped/pre-route prototype reports, whose limits are detailed in
the [hardware audit](../../hardware_sim/docs/reference/tss_delivery_audit.md).
At the initial audit no layout image was supplied; the author has since
added the [layout figure](../../hardware_sim/reference/layout_20260909/README.md)
for the hardware results.

## Provenance and excluded originals

[Assets](assets/README.md) contain **24 exact copies, 1,645,466 bytes**.
[Numerical evidence](evidence/README.md) contains **337 exact copies,
11,142,439 bytes**, including **285** PPL result files; generated catalogs,
audit tables, and metadata extracts are additional files. Each exact copy
is size/SHA256 checked in the local manifest. The copy roots preserve
`figure/`, `data/`, `6b/`, `6c/`, and the original packed rebuttal manifest.

The packed rebuttal manifest records an older 143-file package of 147,350,754
bytes, including anchor reports and selected trace results. Only that index
is copied here; its hardware payloads do not become functional quality or
current hardware evidence. Original `../rebuttal/results/e2e_traces`
contains approximately 8.7 GiB of historical traces; hardware ownership
remains separate.

The [external inventory](evidence/external_inventory.tsv) records 1,571
`../data` files (68,521,363,133 logical bytes), 236 `../6b` files, 11 `../6c`
files, and four `../sup` files. Only compact relevant evidence is copied.
Large tensor/checkpoint files and full calibration arrays remain in their
original locations; 21 referenced calibration JSONs have explicit,
hash-identified [metadata extracts](evidence/calibration_metadata.json).
The extracts preserve global summaries and configuration fields, not an
executable replacement for the calibration.

`../sup` repeats the later full FP16 quality values for Qwen3-1.7B/4B/8B.
Its `8Bbasaeline_mxfp8_test.json` has `use_mxfp8=false`, so its filename is
misleading. These files add no distinct quality point and are inventoried
without importing another baseline copy.

No model inference, calibration, simulation, or figure regeneration was
performed. Verification consisted of JSON/CSV inspection, explicit source
comparisons, snapshot SHA256 checks, and local catalog generation.

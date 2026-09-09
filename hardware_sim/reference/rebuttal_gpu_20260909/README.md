# Rebuttal GPU timing source for the end-to-end figure

This collection preserves four files from the rebuttal repository, with
revision, source paths, sizes and SHA-256 in [manifest.json](manifest.json):

- [Raw profile](source/results/hybrid_full_model_gpu/Qwen3-1.7B_gpu_nonffn_profile.json)
- [Historical hybrid table](source/results/hybrid_full_model_gpu/Qwen3-1.7B_hybrid_table.md)
- [Historical table TSV](source/results/hybrid_full_model_gpu/Qwen3-1.7B_hybrid_table.tsv)
- [Original profiling script](source/scripts/profile_gpu_nonffn.py)

These are source snapshots; the profiling script was inspected but not run.
Its original paths and legacy V4 ratio dependency are retained for provenance.

## Fields to use

The JSON's `timing_rows` contains the measured full-GPU and GPU non-FFN
samples and summaries. Use the medians for the proposed breakdown:

| Scenario | Full GPU | GPU non-FFN | Full minus non-FFN |
|---|---:|---:|---:|
| decode_s2048 | 22.7985591888 ms | 20.7103366852 ms | 2.0882225037 ms |
| prefill_s512 | 24.9042243958 ms | 20.6056632996 ms | 4.2985610962 ms |

The first two columns are recorded GPU timings; the last is a formula using
two separately measured medians. The non-FFN path replaces all 28 decoder MLP
forwards with zero outputs. It retains attention and other model work,
including the final-token language-model head. Label it **GPU attention and
other non-FFN work**, rather than isolated attention time.

Recorded environment: Qwen3-1.7B, RTX 5090, batch 1, bfloat16,
PyTorch 2.10.0+cu130 / CUDA 13.0, Transformers 5.2.0.dev0, driver 580.95.05.
The timing-only input is random token IDs. One warmup and three repeats were
used. Decode KV preparation is outside the timed CUDA-event interval.
These metadata describe the historical run, not the current local environment.

The file's `hybrid_rows` and the Markdown/TSV tables additionally apply the
old V4 TLM FFN cycle ratios. Keep these as the historical formula result.
Neither those rows nor their `Dense MXFP8` method label establishes that the
full-GPU timing is a direct measurement of a new CIM chip or a coupled
GPU/CIM system. The actual timing metadata says bfloat16.

The [current writing plan](../../../docs/paper/current_revision_plan.md)
uses this measured GPU component to support a new or adapted end-to-end
figure. Associate the accelerated component with its own design, ratio or
absolute timing source, and transfer/overlap assumptions. No new GPU timing,
energy measurement, or model-quality experiment was performed for this import.

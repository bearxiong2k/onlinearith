# Paper quality and figure evidence

This writing bundle contains selected frozen numerical evidence and historical
figure support, imported on 2026-09-09. It does not change the functional
simulator or define hardware accounting. Use the [audit](../figure_data_audit.md)
for verified quality tables and the limitations of old figures.

## Entry points

| File or directory | Purpose |
|---|---|
| [result_catalog.tsv](result_catalog.tsv) | 285 PPL result rows with exact snapshot paths, scope, scored tokens, source hashes and executed-digit ratio |
| [manifest.json](manifest.json) | 337 byte-identical copies, 11,142,439 bytes, with source roots/revisions and SHA256 |
| [calibration_metadata.json](calibration_metadata.json) | Explicit metadata extracts from 21 referenced calibration JSONs; original size/hash and field names retained |
| [figure6_source_audit.tsv](figure6_source_audit.tsv) | Row-by-row check of Figure 6A/B CSV PPL and work columns against their named source files |
| [external_inventory.tsv](external_inventory.tsv) | File-level inventory of `../data`, `../6b`, `../6c`, and `../sup`, including unimported large originals |
| [snapshots/data/qwen3_final_experiments](snapshots/data/qwen3_final_experiments/) | Full scale/17 dB PPL, sampled work sweeps, and original summary tables |
| [snapshots/data/rebuttal_experiments](snapshots/data/rebuttal_experiments/) | Completed full FP16 baselines, sampled Llama and K sensitivity results |
| [snapshots/data/calib-data](snapshots/data/calib-data/) and [uniform_budget](snapshots/data/uniform_budget/) | Legacy figure support with original filenames; not the preferred new-submission quality table |
| [snapshots/6b](snapshots/6b/) and [snapshots/6c](snapshots/6c/) | Dependency-linked Figure 6 evaluations and experiment context |
| [snapshots/rebuttal/packed_rebuttal_artifacts/manifest.json](snapshots/rebuttal/packed_rebuttal_artifacts/manifest.json) | Original package index for provenance only; its listed hardware payloads are not part of this numerical bundle |

## Scope rules

Formal Qwen3 full-test PPL rows score 299,078 tokens using WikiText-2 raw test,
`max_length=4096`, and `stride=512`. The separate `limit_samples=300` pass
scores 22,336 Qwen3 tokens; it is sampled accounting, not a full-test PPL
replacement. Llama uses a different tokenizer: its full FP16 row scores
289,077 tokens and sampled rows score 21,226 tokens. Do not compare the full
Llama FP16 number directly against its sampled MXFP8/TSS numbers.

The executed-digit ratio in `result_catalog.tsv` is derived only as
`msd_perf_stats.global.mean_effective_precision / 3.0`. It is not runtime
global utilization. N:M keeps N values from M, so a baseline work fraction
is N/M, a separate quantity from the measured executed-digit ratio. The
catalog leaves work blank when the frozen result lacks the required field.
Stored source precision is already rounded; catalog divisions do not add
measurement precision.

Historical summaries are snapshots of their creation time. Some report
missing/running jobs that now have completed leaf JSONs; use the leaf result
and its protocol fields. Files under `calib-data`, `uniform_budget`, `6b`,
and `6c` can have subset evaluation even without a `limit_samples` field.
They are conservatively marked `historical_scope_requires_review`.

The calibration extract copies named metadata fields without recalibration or
budget-array changes. Its original source hashes support provenance, but
the full calibration arrays remain external. `global_summary.wall_time_sec`
is the frozen file's recorded value; merged projection timings do not by
themselves establish end-to-end calibration latency. These extracts are not
executable configurations.

The raw `../data` inventory contains 1,571 files totaling 68,521,363,133
logical bytes; 313 compact files were selected. Tensor/checkpoint files,
bulk calibration arrays, most logs, and old exploratory datasets remain
external. The inventory records file sizes without hashing gigabytes of
unselected tensors. `../sup` duplicates later baseline metrics and includes
a misleading MXFP8 filename; it is inventoried rather than copied.

Old hardware trace ledgers, anchor outputs, cost-model reports and GPU timing
results are not imported as current paper hardware evidence. Route hardware
claims through `hardware_sim/` and its imported implementation reports.

## Local verification

From the repository root:

```bash
python docs/paper/evidence/build_result_catalog.py
```

This checks every numerical snapshot against its size/SHA256 and rebuilds
only the catalog. It uses local files and Python's standard library; it does
not run inference, access sibling repositories, or regenerate figures.

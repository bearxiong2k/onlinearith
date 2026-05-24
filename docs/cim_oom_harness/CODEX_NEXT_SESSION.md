# Qwen3 OOM/Performance Handoff

Use this short prompt for the next Codex session:

```text
Continue the Qwen3 OOM/performance and experiment-estimation work in
/home/xzj/coding/onlinearith.

Read first:
- AGENTS.md
- docs/cim_oom_harness/CODEX_PROMPT.md
- docs/cim_oom_harness/CODEX_OOM_PERF_PLAN.md
- docs/experiments_time_estimates.md

Read only when needed:
- docs/cim_oom_harness/reference/evidence_log.md
- docs/cim_oom_harness/reference/implementation_notes.md

Current state:
- Single-GPU OOM feasibility and runner hygiene are established for MX-only,
  uniform MSD setup 6, fixed-sum calibrated MSD, WANDA, and activation N:M.
- Qwen3-8B MXFP8 `--weight-cache-dtype float8` is the preferred cache mode for
  memory headroom. Use `float16` or `none` for non-MXFP8 paths.
- WANDA and activation N:M use common keep-count notation: `N:M` means keep N
  values per group of M; internally this prunes `(M-N):M`.
- MSD timing/utilization probes should use
  `ppltest.py --msd-utilization-mode`. This is the maintained 100-sample
  lite-stat mode and excludes Figure 5 cycle collection unless
  `--figure5-layer-cycles` is explicitly requested.
- The focused experiment estimate is intentionally single-setup per path:
  MXFP8 baseline, fixed-sum calibrated MSD at target-SNR 30 dB, WANDA 2:4, and
  activation 2:4. Sweeps and multi-GPU estimates are deferred.
- For MSD equivalent sparsity/work, use the Figure 4 `plot_norm_digit_read`
  convention, not `msd_perf_stats.global.global_utilization`. The MSD formula
  is `plot_norm_digit_read = mean_effective_precision / 3.0`; fixed-sum 30 dB
  has `plot_norm_digit_read = 0.87`, close to dense digit-read work.
- Latest runtime cleanup: stats-off MSD inference no longer materializes a
  separate full 4D `total_delay` tensor, and a small equivalence test covers
  stats-off output against the stats-on path.

Immediate direction:
1. Keep the repo structure clean: live scripts/tests stay at repo root; long
   historical evidence stays under docs/cim_oom_harness/reference/.
2. Continue calibrated-MSD runtime optimization at the fixed-sum 30 dB
   representative point. Preserve PPL and MSD math.
```

Do not expand this file with detailed run logs. Add measurements to
`reference/evidence_log.md` and design/history notes to
`reference/implementation_notes.md`.

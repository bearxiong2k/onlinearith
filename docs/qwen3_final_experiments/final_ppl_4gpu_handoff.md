# Four-GPU Final PPL Handoff

Current availability: use GPUs 4-7 only.

Run from `/home/xzj/coding/onlinearith`:

```bash
GPUS=4,5,6,7 NPROC=4 scripts/run_qwen3_final_ppl_4gpu.sh
```

The script runs, in order:

1. MXFP8 baseline
2. fixed-sum MSD 30 dB with the merged Qwen3-8B calibration
3. WANDA 2:4 with the Qwen3-8B suffixed mask
4. activation N:M 2:4

It writes logs under:

```text
../data/qwen3_final_experiments/qwen3_8b/logs/
```

It appends step status to:

```text
../data/qwen3_final_experiments/qwen3_8b/final_ppl_4gpu_status.tsv
```

Expected final outputs:

```text
../data/qwen3_final_experiments/qwen3_8b/ppl_results_MXFP8_qwen8b_final.json
../data/qwen3_final_experiments/qwen3_8b/ppl_results_MXFP8_fixed_sum30_qwen8b_final.json
../data/wanda_base/2-4/ppl_results_MXFP8_qwen8b_final.json
../data/qwen3_final_experiments/qwen3_8b/act_base/2-4/ppl_results_MXFP8.json
```

Resume behavior:

- Existing outputs are skipped by default.
- Set `FORCE=1` to rerun completed outputs.
- The script stops at the first failing step and records `failed:<code>` in the
  status TSV.

Expected wall time on four workers is dominated by fixed-sum MSD PPL: about
45.1 hours, plus under two hours for the other three PPL jobs.

Smoke validation already completed:

```bash
SMOKE=1 FORCE=1 RUN_STEPS="mxfp8 act" GPUS=4,5,6,7 NPROC=4 LIMIT_SAMPLES=120 scripts/run_qwen3_final_ppl_4gpu.sh
```

The Qwen3-1.7B smoke wrote outputs under
`../data/qwen3_final_experiments/smoke_qwen3_1_7b_4gpu/` and completed both
MXFP8 and activation N:M steps.

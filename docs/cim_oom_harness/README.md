# CIM OOM Harness Docs

This directory is the lightweight entry point for the Qwen3 OOM/performance
iteration. Keep always-read files short. Put long evidence, command history, and
historical implementation notes under `reference/`.

## Always-Read

- `CODEX_NEXT_SESSION.md`: short handoff prompt and current next steps.
- `CODEX_PROMPT.md`: durable constraints and development rules for this effort.
- `CODEX_OOM_PERF_PLAN.md`: current active plan, not a full history.

## Read When Needed

- `reference/evidence_log.md`: direct-CUDA measurements and old artifact notes.
- `reference/implementation_notes.md`: implementation history and design details
  that do not need to be reread every session.
- `../experiments_time_estimates.md`: single-setup runtime estimates for the
  focused Qwen3 model family.

## Live Files

The live scripts and tests are at repo root. Do not keep duplicate executable
copies under `docs/`.

- `scripts/run_qwen8b_oom_ladder.sh`
- `tools/probe_mxfp_memory.py`
- `tests/test_mx_exact_chunked.py`
- `tests/test_mxfp_weight_cache_compact.py`
- `tests/test_msd_truncate_equivalence.py`
- `tests/test_ppl_tail_logits_loss.py`
- `tests/test_nm_keep_semantics.py`

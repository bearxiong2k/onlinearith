# Qwen3 Final Experiment Docs

This directory is the lightweight entry point for the Qwen3 final experiment
setup. Keep always-read files short. Put evidence, command history, and
implementation history under `references/`.

## Always-Read

- `active_plan.md`: current experiment matrix, outputs, and stats collection
  rules.
- `final_run_commands.md`: concrete entry points for the full PPL sweep and the
  fixed-sum 17 dB stats sweep.
- `next_session.md`: short handoff prompt for resuming work.
- `codex_prompt.md`: durable invariants for future Codex sessions.

## Read When Needed

- `references/evidence_log.md`: measured results and artifact locations.
- `references/implementation_notes.md`: implementation details needed to
  interpret result JSONs and scripts.
- `runtime_estimates.md`, `model_execution_matrix.md`, and
  `references/multigpu_sharding_plan.md`: historical planning notes. Read only
  when debugging execution strategy.

## Live Files

The live scripts and tests are at repo root. Do not keep duplicate executable
copies under `docs/`.

- `scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh`
- `scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh`
- `scripts/run_qwen3_fixed_sum_norm_target_sweep.sh`
- `scripts/summarize_qwen3_model_sweep.py`
- `scripts/summarize_fixed_sum_norm_sweep.py`
- `tools/probe_mxfp_memory.py`
- `tools/merge_msd_calibrations.py`
- `tests/test_mx_exact_chunked.py`
- `tests/test_mxfp_weight_cache_compact.py`
- `tests/test_msd_truncate_equivalence.py`
- `tests/test_ppl_device_map_utils.py`
- `tests/test_ppl_tail_logits_loss.py`
- `tests/test_nm_keep_semantics.py`
- `tests/test_merge_msd_calibrations.py`

# Qwen3 Final Experiment Docs

Status: frozen experiment record. The filenames retain their historical
`active_plan`/handoff names so old references remain understandable; they are
not the active hardware-development plan.

This directory is the lightweight entry point for the Qwen3 final experiment
setup. Keep always-read files short. Put evidence, command history, and
implementation history under `references/`.

## Always-Read

- `active_plan.md`: current experiment matrix, outputs, and stats collection
  rules.
- `final_run_commands.md`: concrete entry points for the full PPL sweep and the
  fixed-sum 17 dB stats sweep.
- `fixed_sum17_ppl_stats300_handoff.md`: start, monitor, and artifact layout
  for the fixed-sum 17 dB full-PPL plus sampled-stats run.
- `codex_prompt.md`: durable invariants for future Codex sessions.

## Read When Needed

- `references/evidence_log.md`: measured results and artifact locations.
- `references/implementation_notes.md`: implementation details needed to
  interpret result JSONs and scripts.
- `runtime_estimates.md`, `model_execution_matrix.md`, and
  `references/multigpu_sharding_plan.md`: historical planning notes. Read only
  when debugging execution strategy.

## Frozen executable surface

The scripts and tests live only under `functional_sim/`. Invoke them from the
repository root with that prefix; do not add duplicate root entry points or
edit them for hardware-simulation work.

- `functional_sim/scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh`
- `functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh`
- `functional_sim/scripts/run_qwen3_fixed_sum_norm_target_sweep.sh`
- `functional_sim/scripts/summarize_qwen3_model_sweep.py`
- `functional_sim/scripts/summarize_qwen3_fixed_sum17_ppl_stats.py`
- `functional_sim/scripts/summarize_fixed_sum_norm_sweep.py`
- `functional_sim/tools/probe_mxfp_memory.py`
- `functional_sim/tools/merge_msd_calibrations.py`
- `functional_sim/tests/test_mx_exact_chunked.py`
- `functional_sim/tests/test_mxfp_weight_cache_compact.py`
- `functional_sim/tests/test_msd_truncate_equivalence.py`
- `functional_sim/tests/test_ppl_device_map_utils.py`
- `functional_sim/tests/test_ppl_tail_logits_loss.py`
- `functional_sim/tests/test_nm_keep_semantics.py`
- `functional_sim/tests/test_merge_msd_calibrations.py`

# Functional-simulation documentation

This documentation records the frozen numerical experiment workflow and its
evidence. It is not the starting point for hardware development.

## Experiment context

- [Qwen3 final experiments](qwen3_final_experiments/README.md): active-plan
  history, run commands, handoffs, runtime estimates, and detailed references.
- [Structured-sparsity baselines](baselines/structured_sparsity_baselines.md):
  WANDA and activation N:M conventions.
- [Fixed-sum calibration](calibration/fixed_sum_calibration.md): calibration
  behavior and artifact interpretation.

## Development history

- [Repository quality gate](codex/README.md)
- [Modular converter guide](dev/modular_converter_guide.md)

Canonical implementation paths begin with `functional_sim/`. Historical
records may retain pre-relocation command spellings as provenance, but current
commands must use the `functional_sim/` prefix. New RTL, circuit traces, and
hardware cost documents belong under `hardware_sim/`.

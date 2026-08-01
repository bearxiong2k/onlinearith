# Codex Quality Gates

Reusable repo checks live in normal repo paths:

```text
onlinearith/
  functional_sim/tools/repo_quality_gate.py
  functional_sim/tools/compare_ppl_math.py
  functional_sim/tests/test_config_contract.py
  functional_sim/tests/test_ppl_window_contract.py
  functional_sim/tests/test_qwen3_public_api_contract.py
  functional_sim/tests/test_repository_layout.py
  functional_sim/scripts/run_repo_quality_gate.sh
```

Verification:

```bash
bash functional_sim/scripts/run_repo_quality_gate.sh
```

The contract tests intentionally avoid loading a real Qwen3 model. They are
contract and structure checks, not PPL benchmarks. If `pytest` is not installed
in the project environment, `run_repo_quality_gate.sh` runs them directly.

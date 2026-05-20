#!/usr/bin/env bash
set -euo pipefail

python tools/repo_quality_gate.py --strict
python tools/compare_ppl_math.py
python -m pytest -q \
  tests/test_config_contract.py \
  tests/test_ppl_window_contract.py \
  tests/test_qwen3_public_api_contract.py

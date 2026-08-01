#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FUNCTIONAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$FUNCTIONAL_ROOT/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "${PYTHON:-}" ]]; then
  PYTHON_BIN="${PYTHON}"
elif [[ -x "../.venv3_10/bin/python" ]]; then
  PYTHON_BIN="../.venv3_10/bin/python"
else
  PYTHON_BIN="python"
fi

"${PYTHON_BIN}" "$FUNCTIONAL_ROOT/tools/repo_quality_gate.py" --strict
"${PYTHON_BIN}" "$FUNCTIONAL_ROOT/tools/compare_ppl_math.py"

if ! "${PYTHON_BIN}" -c "import pytest" >/dev/null 2>&1; then
  echo "[INFO] pytest is not installed for ${PYTHON_BIN}; running contract tests directly."
  "${PYTHON_BIN}" "$FUNCTIONAL_ROOT/tests/test_config_contract.py"
  "${PYTHON_BIN}" "$FUNCTIONAL_ROOT/tests/test_ppl_window_contract.py"
  "${PYTHON_BIN}" "$FUNCTIONAL_ROOT/tests/test_qwen3_public_api_contract.py"
  exit 0
fi

"${PYTHON_BIN}" -m pytest -q \
  "$FUNCTIONAL_ROOT/tests/test_config_contract.py" \
  "$FUNCTIONAL_ROOT/tests/test_ppl_window_contract.py" \
  "$FUNCTIONAL_ROOT/tests/test_qwen3_public_api_contract.py"

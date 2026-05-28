#!/usr/bin/env bash
# Run the all-model Qwen3 experiment sweep on the currently available GPUs 4-7.
#
# Defaults are intentionally full-run outputs, not prefix/smoke outputs. Set
# LIMIT_SAMPLES=120 for a monitored prefix. Existing outputs are skipped unless
# FORCE=1. By default, missing small-model fixed-sum and WANDA artifacts are
# prepared first under the sweep artifacts directory.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export SWEEP_MODE=1
export GPUS="${GPUS:-4,5,6,7}"
export NPROC="${NPROC:-4}"
export MODEL_SPECS="${MODEL_SPECS:-qwen0_6b:../Qwen3-0.6B qwen1_7b:../Qwen3-1.7B qwen4b:../Qwen3-4B qwen8b:../Qwen3-8B}"
export RUN_STEPS="${RUN_STEPS:-mxfp8 fixed_sum wanda act}"
export PREPARE_ARTIFACTS="${PREPARE_ARTIFACTS:-1}"
export RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"

if [[ -z "${LIMIT_SAMPLES+x}" ]]; then
  export LIMIT_SAMPLES=""
fi

if [[ "$PREPARE_ARTIFACTS" == "1" ]]; then
  "$SCRIPT_DIR/prepare_qwen3_model_sweep_artifacts_4gpu.sh"
fi

exec "$SCRIPT_DIR/run_qwen3_final_ppl_4gpu.sh"

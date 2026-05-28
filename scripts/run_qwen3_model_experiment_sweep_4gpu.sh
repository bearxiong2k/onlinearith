#!/usr/bin/env bash
# Run the all-model Qwen3 experiment sweep on the currently available GPUs 4-7.
#
# Defaults are intentionally full-run outputs, not prefix/smoke outputs. Set
# LIMIT_SAMPLES=120 for a monitored prefix. Existing outputs are skipped unless
# FORCE=1.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export SWEEP_MODE=1
export GPUS="${GPUS:-4,5,6,7}"
export NPROC="${NPROC:-4}"
export MODEL_SPECS="${MODEL_SPECS:-qwen0_6b:../Qwen3-0.6B qwen1_7b:../Qwen3-1.7B qwen4b:../Qwen3-4B qwen8b:../Qwen3-8B}"
export RUN_STEPS="${RUN_STEPS:-mxfp8 fixed_sum wanda act}"

if [[ -z "${LIMIT_SAMPLES+x}" ]]; then
  export LIMIT_SAMPLES=""
fi

exec "$SCRIPT_DIR/run_qwen3_final_ppl_4gpu.sh"

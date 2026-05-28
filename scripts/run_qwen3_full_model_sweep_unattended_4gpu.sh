#!/usr/bin/env bash
# Unattended full Qwen3 all-model sweep on GPUs 4-7.
#
# This is the "leave it running for days" entry point:
#   1. prepare smaller-model fixed-sum and WANDA artifacts with per-model
#      profiles, in parallel across GPUs 4-6 by default;
#   2. run full, non-prefix PPL for 0.6B/1.7B/4B/8B across all four methods;
#   3. write a final summary TSV/JSON for quick review.
#
# To detach from a terminal/session:
#   BACKGROUND=1 scripts/run_qwen3_full_model_sweep_unattended_4gpu.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/model_sweep_4gpu}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
DRIVER_ROOT="${DRIVER_ROOT:-$SWEEP_ROOT/logs/full_unattended_${RUN_ID}}"

if [[ "${BACKGROUND:-0}" == "1" && "${QWEN_SWEEP_BACKGROUND_CHILD:-0}" != "1" ]]; then
  mkdir -p "$DRIVER_ROOT"
  export QWEN_SWEEP_BACKGROUND_CHILD=1
  export RUN_ID SWEEP_ROOT DRIVER_ROOT
  nohup "$0" "$@" > "$DRIVER_ROOT/nohup.out" 2>&1 &
  echo "[launched] PID: $!"
  echo "[launched] driver log: $DRIVER_ROOT/driver.log"
  echo "[launched] nohup log : $DRIVER_ROOT/nohup.out"
  exit 0
fi

mkdir -p "$DRIVER_ROOT"
exec > >(tee -a "$DRIVER_ROOT/driver.log") 2>&1

SUMMARY_WRITTEN=0
write_summary() {
  "$PYTHON" "$SCRIPT_DIR/summarize_qwen3_model_sweep.py" \
    --sweep-root "$SWEEP_ROOT" \
    --tag full \
    --model-specs "$MODEL_SPECS" \
    --output-dir "$DRIVER_ROOT" || true
  SUMMARY_WRITTEN=1
}

finish() {
  local status=$?
  if [[ "$SUMMARY_WRITTEN" != "1" ]]; then
    write_summary
  fi
  {
    echo "finished_at=$(date -Is)"
    echo "exit_status=$status"
    echo "run_id=$RUN_ID"
    echo "driver_root=$DRIVER_ROOT"
    echo "artifact_status=$SWEEP_ROOT/logs/artifacts_${RUN_ID}/status.tsv"
    echo "sweep_status=$SWEEP_ROOT/logs/sweep_full_${RUN_ID}/status.tsv"
    echo "summary_tsv=$DRIVER_ROOT/summary_full.tsv"
    echo "summary_json=$DRIVER_ROOT/summary_full.json"
  } > "$DRIVER_ROOT/final_status.txt"
  echo "[driver] final status written to $DRIVER_ROOT/final_status.txt"
}
trap finish EXIT

export GPUS="${GPUS:-4,5,6,7}"
export NPROC="${NPROC:-4}"
export MODEL_SPECS="${MODEL_SPECS:-qwen0_6b:../Qwen3-0.6B qwen1_7b:../Qwen3-1.7B qwen4b:../Qwen3-4B qwen8b:../Qwen3-8B}"
export RUN_STEPS="${RUN_STEPS:-mxfp8 fixed_sum wanda act}"
export PREP_STEPS="${PREP_STEPS:-fixed_sum wanda}"
export ARTIFACT_PREP_MODE="${ARTIFACT_PREP_MODE:-parallel}"
export PREPARE_ARTIFACTS=0
export SWEEP_MODE=1
export SWEEP_TAG=full
export LIMIT_SAMPLES=""
export STRICT_ARTIFACTS=1
export CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-1}"
export LOAD_STAGGER_SEC="${LOAD_STAGGER_SEC:-8}"
export FORCE="${FORCE:-0}"
export DRY_RUN="${DRY_RUN:-0}"
export OUTPUT_LAYOUT="${OUTPUT_LAYOUT:-grouped}"
export ARTIFACT_LOG_ROOT="${ARTIFACT_LOG_ROOT:-$SWEEP_ROOT/logs/artifacts_${RUN_ID}}"
export ARTIFACT_STATUS_FILE="${ARTIFACT_STATUS_FILE:-$ARTIFACT_LOG_ROOT/status.tsv}"
export LOG_ROOT="${LOG_ROOT:-$SWEEP_ROOT/logs/sweep_full_${RUN_ID}}"
export STATUS_FILE="${STATUS_FILE:-$LOG_ROOT/status.tsv}"

{
  echo "run_id=$RUN_ID"
  echo "started_at=$(date -Is)"
  echo "gpus=$GPUS"
  echo "nproc=$NPROC"
  echo "model_specs=$MODEL_SPECS"
  echo "run_steps=$RUN_STEPS"
  echo "prep_steps=$PREP_STEPS"
  echo "artifact_prep_mode=$ARTIFACT_PREP_MODE"
  echo "sweep_root=$SWEEP_ROOT"
  echo "driver_root=$DRIVER_ROOT"
  echo "continue_on_error=$CONTINUE_ON_ERROR"
} > "$DRIVER_ROOT/run.env"

echo "[driver] run id: $RUN_ID"
echo "[driver] logs: $DRIVER_ROOT"
echo "[driver] artifact status: $ARTIFACT_STATUS_FILE"
echo "[driver] sweep status: $STATUS_FILE"

echo
echo "[driver] phase 1/2: preparing smaller-model artifacts"
if [[ "$ARTIFACT_PREP_MODE" == "parallel" ]]; then
  "$SCRIPT_DIR/prepare_qwen3_model_sweep_artifacts_parallel_4gpu.sh"
elif [[ "$ARTIFACT_PREP_MODE" == "serial" ]]; then
  "$SCRIPT_DIR/prepare_qwen3_model_sweep_artifacts_4gpu.sh"
else
  echo "ERROR: unsupported ARTIFACT_PREP_MODE=$ARTIFACT_PREP_MODE; use parallel or serial" >&2
  exit 2
fi

echo
echo "[driver] phase 2/2: running full model sweep"
"$SCRIPT_DIR/run_qwen3_final_ppl_4gpu.sh"

echo
echo "[driver] writing final summary"
write_summary

echo "[driver] complete"

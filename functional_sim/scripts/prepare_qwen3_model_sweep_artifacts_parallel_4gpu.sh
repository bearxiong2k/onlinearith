#!/usr/bin/env bash
# Parallel artifact preparation for the all-model Qwen3 sweep.
#
# This wrapper assigns smaller-model artifact jobs to separate physical GPUs and
# gives each model its own calibration profile. Qwen3-8B artifacts are reused
# from the final 8B experiment and are not regenerated here.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FUNCTIONAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$FUNCTIONAL_ROOT/.." && pwd)"
cd "$ROOT_DIR"

SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/model_sweep_4gpu}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
ARTIFACT_LOG_ROOT="${ARTIFACT_LOG_ROOT:-$SWEEP_ROOT/logs/artifacts_${RUN_ID}}"
ARTIFACT_STATUS_FILE="${ARTIFACT_STATUS_FILE:-$ARTIFACT_LOG_ROOT/status.tsv}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"

mkdir -p "$ARTIFACT_LOG_ROOT"
if [[ ! -f "$ARTIFACT_STATUS_FILE" ]]; then
  echo "timestamp	model	step	status	output	log" > "$ARTIFACT_STATUS_FILE"
fi

record_status() {
  local model_key="$1"
  local step="$2"
  local status="$3"
  local output="$4"
  local log="$5"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$model_key" "$step" "$status" "$output" "$log" >> "$ARTIFACT_STATUS_FILE"
}

launch_model() {
  local model_key="$1"
  local model_path="$2"
  local gpu="$3"
  local calib_batch="$4"
  local calib_mx_chunk="$5"
  local calib_chunk="$6"
  local wanda_batch="$7"
  local wanda_mx_chunk="$8"
  local worker_log="$ARTIFACT_LOG_ROOT/$model_key/worker.log"

  mkdir -p "$(dirname "$worker_log")"
  echo "[artifact-parallel] launch $model_key on GPU $gpu; worker log: $worker_log"
  record_status "$model_key" artifact_worker "started" "" "$worker_log"
  (
    export SWEEP_ROOT RUN_ID ARTIFACT_LOG_ROOT ARTIFACT_STATUS_FILE CONTINUE_ON_ERROR
    export MODEL_SPECS="$model_key:$model_path"
    export ARTIFACT_GPU="$gpu"
    export CALIB_BATCH_SIZE="$calib_batch"
    export CALIB_MX_CHUNK_MIB="$calib_mx_chunk"
    export CALIB_CHUNK_MIB="$calib_chunk"
    export WANDA_BATCH_SIZE="$wanda_batch"
    export WANDA_MX_CHUNK_MIB="$wanda_mx_chunk"
    "$SCRIPT_DIR/prepare_qwen3_model_sweep_artifacts_4gpu.sh"
  ) > "$worker_log" 2>&1 &
  pids+=("$!")
  names+=("$model_key")
}

pids=()
names=()

# Per-model profiles:
# - 0.6B uses larger batches/chunks to reduce overhead.
# - 1.7B keeps moderate chunks and batch size.
# - 4B uses smaller batches/chunks for headroom during fixed-sum capture and
#   WANDA metric construction.
launch_model qwen0_6b ../Qwen3-0.6B 4 8 512 128 8 512
launch_model qwen1_7b ../Qwen3-1.7B 5 4 384 96 4 384
launch_model qwen4b ../Qwen3-4B 6 2 256 64 2 256

failed=0
for idx in "${!pids[@]}"; do
  pid="${pids[$idx]}"
  name="${names[$idx]}"
  if wait "$pid"; then
    echo "[artifact-parallel] complete $name"
    record_status "$name" artifact_worker "completed" "" "$ARTIFACT_LOG_ROOT/$name/worker.log"
  else
    status=$?
    echo "[artifact-parallel] FAILED $name with exit code $status"
    record_status "$name" artifact_worker "failed:$status" "" "$ARTIFACT_LOG_ROOT/$name"
    failed=1
  fi
done

record_status qwen8b artifacts "skipped_reuses_final_8b" "" ""

if [[ "$failed" != "0" && "$CONTINUE_ON_ERROR" != "1" ]]; then
  exit 1
fi

echo "[artifact-parallel] status: $ARTIFACT_STATUS_FILE"

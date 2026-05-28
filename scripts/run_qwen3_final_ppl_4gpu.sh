#!/usr/bin/env bash
# Run the representative Qwen3 final PPL jobs end to end on GPUs 4-7.
#
# Defaults are for the Qwen3-8B final run. Set SMOKE=1 to validate the script
# mechanics on Qwen3-1.7B with a prefix-limited MXFP8 + activation run.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SMOKE="${SMOKE:-0}"
GPUS="${GPUS:-4,5,6,7}"
NPROC="${NPROC:-4}"
LOAD_STAGGER_SEC="${LOAD_STAGGER_SEC:-8}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"

if [[ "$SMOKE" == "1" ]]; then
  MODEL="${MODEL:-../Qwen3-1.7B}"
  RUN_LABEL="${RUN_LABEL:-qwen1_7b_smoke}"
  FINAL_ROOT="${FINAL_ROOT:-../data/qwen3_final_experiments/smoke_qwen3_1_7b_4gpu}"
  LIMIT_SAMPLES="${LIMIT_SAMPLES:-120}"
  RUN_STEPS="${RUN_STEPS:-mxfp8 act}"
else
  MODEL="${MODEL:-../Qwen3-8B}"
  RUN_LABEL="${RUN_LABEL:-qwen8b_final}"
  FINAL_ROOT="${FINAL_ROOT:-../data/qwen3_final_experiments/qwen3_8b}"
  LIMIT_SAMPLES="${LIMIT_SAMPLES:-}"
  RUN_STEPS="${RUN_STEPS:-mxfp8 fixed_sum wanda act}"
fi

MSD_DIR="${MSD_DIR:-$FINAL_ROOT/calib_fixed_sum_30db}"
MSD_CAL="${MSD_CAL:-$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_merged.json}"
WANDA_ROOT="${WANDA_ROOT:-../data/wanda_base}"
WANDA_HOOK="${WANDA_HOOK:-$RUN_LABEL}"
ACT_ROOT="${ACT_ROOT:-$FINAL_ROOT/act_base}"
LOG_ROOT="${LOG_ROOT:-$FINAL_ROOT/logs/final_ppl_4gpu_$(date +%Y%m%d_%H%M%S)}"
STATUS_FILE="${STATUS_FILE:-$FINAL_ROOT/final_ppl_4gpu_status.tsv}"

MXFP8_OUT="${MXFP8_OUT:-$FINAL_ROOT/ppl_results_MXFP8_${RUN_LABEL}.json}"
FIXED_SUM_OUT="${FIXED_SUM_OUT:-$FINAL_ROOT/ppl_results_MXFP8_fixed_sum30_${RUN_LABEL}.json}"
WANDA_OUT="${WANDA_OUT:-$WANDA_ROOT/2-4/ppl_results_MXFP8_${WANDA_HOOK}.json}"
ACT_OUT="${ACT_OUT:-$ACT_ROOT/2-4/ppl_results_MXFP8.json}"

IFS=',' read -r -a GPU_ARRAY <<< "$GPUS"
if [[ "${#GPU_ARRAY[@]}" -ne "$NPROC" ]]; then
  echo "ERROR: GPUS has ${#GPU_ARRAY[@]} entries but NPROC=$NPROC: $GPUS" >&2
  exit 2
fi

if [[ ! -x "$PYTHON" ]]; then
  echo "ERROR: Python executable not found or not executable: $PYTHON" >&2
  exit 2
fi

if [[ ! -d "$MODEL" ]]; then
  echo "ERROR: model path not found: $MODEL" >&2
  exit 2
fi

mkdir -p "$FINAL_ROOT" "$LOG_ROOT" "$(dirname "$STATUS_FILE")"

if [[ ! -f "$STATUS_FILE" ]]; then
  echo "timestamp	step	status	output	log" > "$STATUS_FILE"
fi

echo "[preflight] CUDA visibility through selected GPUs: $GPUS"
CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" - <<'PY'
import torch
print(torch.cuda.is_available(), torch.cuda.device_count())
if not torch.cuda.is_available() or torch.cuda.device_count() == 0:
    raise SystemExit("CUDA is not visible to the selected GPU set")
PY

has_step() {
  local needle="$1"
  local step
  for step in $RUN_STEPS; do
    [[ "$step" == "$needle" ]] && return 0
  done
  return 1
}

append_limit_args() {
  if [[ -n "$LIMIT_SAMPLES" ]]; then
    printf '%s\n' "--limit-samples" "$LIMIT_SAMPLES"
  fi
}

require_file_for_step() {
  local step="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    echo "ERROR: required artifact for $step is missing: $path" >&2
    exit 2
  fi
}

record_status() {
  local step="$1"
  local status="$2"
  local output="$3"
  local log="$4"
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$step" "$status" "$output" "$log" >> "$STATUS_FILE"
}

run_step() {
  local step="$1"
  local output="$2"
  shift 2
  local log="$LOG_ROOT/${step}.log"

  if [[ -f "$output" && "$FORCE" != "1" ]]; then
    echo "[$step] output exists; skipping: $output"
    record_status "$step" "skipped_existing" "$output" "$log"
    return 0
  fi

  mkdir -p "$(dirname "$output")"
  echo "[$step] command log: $log"
  printf '[%s] start %s\n' "$(date -Is)" "$step" | tee "$log"
  printf '[%s] command:' "$(date -Is)" | tee -a "$log"
  printf ' %q' "$@" | tee -a "$log"
  printf '\n' | tee -a "$log"
  record_status "$step" "started" "$output" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[$step] DRY_RUN=1; not executing"
    record_status "$step" "dry_run" "$output" "$log"
    return 0
  fi

  set +e
  "$@" 2>&1 | tee -a "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "[$step] FAILED with exit code $status"
    record_status "$step" "failed:$status" "$output" "$log"
    exit "$status"
  fi

  if [[ ! -f "$output" ]]; then
    echo "[$step] FAILED: command exited 0 but output is missing: $output" >&2
    record_status "$step" "missing_output" "$output" "$log"
    exit 1
  fi

  printf '[%s] complete %s\n' "$(date -Is)" "$step" | tee -a "$log"
  record_status "$step" "completed" "$output" "$log"
}

common_ppl_args=(
  --model-path "$MODEL"
  --nproc "$NPROC"
  --gpus "$GPUS"
  --stats off
  --load-stagger-sec "$LOAD_STAGGER_SEC"
  --mxfp-progress-interval-sec -1
)

if has_step mxfp8; then
  limit_args=($(append_limit_args))
  run_step mxfp8 "$MXFP8_OUT" \
    "$PYTHON" ppltest.py \
      --setup 2 \
      "${common_ppl_args[@]}" \
      "${limit_args[@]}" \
      --output "$MXFP8_OUT"
fi

if has_step fixed_sum; then
  if [[ "$SMOKE" == "1" ]]; then
    echo "ERROR: fixed_sum smoke is disabled because Qwen3-8B calibration metadata is shape-specific." >&2
    echo "       Use SMOKE=0 for the final 8B run, or provide a matching MSD_CAL for the smoke model." >&2
    exit 2
  fi
  require_file_for_step fixed_sum "$MSD_CAL"
  limit_args=($(append_limit_args))
  run_step fixed_sum "$FIXED_SUM_OUT" \
    "$PYTHON" ppltest.py \
      --setup 6 \
      --calibration "$MSD_CAL" \
      "${common_ppl_args[@]}" \
      --compile-msd-truncate \
      --weight-cache-dtype float8 \
      "${limit_args[@]}" \
      --output "$FIXED_SUM_OUT"
fi

if has_step wanda; then
  require_file_for_step wanda "$WANDA_ROOT/2-4/calibration_base_MXFP8_${WANDA_HOOK}.pt"
  limit_args=($(append_limit_args))
  run_step wanda "$WANDA_OUT" \
    "$PYTHON" wanda_base/ppl_batch_base.py \
      --model-path "$MODEL" \
      --results-root "$WANDA_ROOT" \
      -n 2 -m 4 \
      --only 1 \
      --output-hook "$WANDA_HOOK" \
      --nproc "$NPROC" \
      --gpus "$GPUS" \
      --window-shard \
      --load-stagger-sec "$LOAD_STAGGER_SEC" \
      --mxfp-progress-interval-sec -1 \
      "${limit_args[@]}"
fi

if has_step act; then
  limit_args=($(append_limit_args))
  run_step act "$ACT_OUT" \
    "$PYTHON" act_base/ppl_batch_base_act.py \
      --model-path "$MODEL" \
      --results-root "$ACT_ROOT" \
      -n 2 -m 4 \
      --only 1 \
      --nproc "$NPROC" \
      --gpus "$GPUS" \
      --window-shard \
      --load-stagger-sec "$LOAD_STAGGER_SEC" \
      --mxfp-progress-interval-sec -1 \
      "${limit_args[@]}"
fi

echo "[done] status: $STATUS_FILE"
echo "[done] logs: $LOG_ROOT"

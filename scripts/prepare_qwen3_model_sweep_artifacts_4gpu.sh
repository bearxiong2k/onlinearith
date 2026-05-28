#!/usr/bin/env bash
# Prepare model-specific fixed-sum MSD calibration JSONs and WANDA 2:4 masks
# for the Qwen3 all-model sweep.
#
# Outputs are stored under:
#   ../data/qwen3_final_experiments/model_sweep_4gpu/<model>/artifacts/
#
# The script is resume-safe at the artifact-file level. Existing final artifacts
# are skipped unless FORCE=1. It deliberately skips qwen8b because the final 8B
# artifacts are already tracked by the Qwen3-8B experiment plan and are reused by
# the PPL sweep.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/model_sweep_4gpu}"
MODEL_SPECS="${MODEL_SPECS:-qwen0_6b:../Qwen3-0.6B qwen1_7b:../Qwen3-1.7B qwen4b:../Qwen3-4B}"
PREP_STEPS="${PREP_STEPS:-fixed_sum wanda}"
ARTIFACT_GPU="${ARTIFACT_GPU:-4}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
LOG_ROOT="${ARTIFACT_LOG_ROOT:-$SWEEP_ROOT/logs/artifacts_${RUN_ID}}"
STATUS_FILE="${ARTIFACT_STATUS_FILE:-$LOG_ROOT/status.tsv}"

CALIB_NUM_TEXTS="${CALIB_NUM_TEXTS:-20}"
CALIB_MAX_LENGTH="${CALIB_MAX_LENGTH:-512}"
CALIB_BATCH_SIZE="${CALIB_BATCH_SIZE:-4}"
CALIB_MX_CHUNK_MIB="${CALIB_MX_CHUNK_MIB:-256}"
CALIB_CHUNK_MIB="${CALIB_CHUNK_MIB:-64}"
CALIB_PROJECTION_FILTERS="${CALIB_PROJECTION_FILTERS:-gate_proj up_proj down_proj}"

WANDA_NUM_TEXTS="${WANDA_NUM_TEXTS:-2048}"
WANDA_MAX_LENGTH="${WANDA_MAX_LENGTH:-512}"
WANDA_BATCH_SIZE="${WANDA_BATCH_SIZE:-4}"
WANDA_MX_CHUNK_MIB="${WANDA_MX_CHUNK_MIB:-256}"

if [[ ! -x "$PYTHON" ]]; then
  echo "ERROR: Python executable not found or not executable: $PYTHON" >&2
  exit 2
fi

echo "[preflight] CUDA visibility through artifact GPU: $ARTIFACT_GPU"
CUDA_VISIBLE_DEVICES="$ARTIFACT_GPU" "$PYTHON" - <<'PY'
import torch
print(torch.cuda.is_available(), torch.cuda.device_count())
if not torch.cuda.is_available() or torch.cuda.device_count() == 0:
    raise SystemExit("CUDA is not visible to the selected artifact GPU")
PY

has_step() {
  local needle="$1"
  local step
  for step in $PREP_STEPS; do
    [[ "$step" == "$needle" ]] && return 0
  done
  return 1
}

status_init() {
  mkdir -p "$(dirname "$STATUS_FILE")"
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "timestamp	model	step	status	output	log" > "$STATUS_FILE"
  fi
}

record_status() {
  local model_key="$1"
  local step="$2"
  local status="$3"
  local output="$4"
  local log="$5"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$model_key" "$step" "$status" "$output" "$log" >> "$STATUS_FILE"
}

run_artifact_step() {
  local model_key="$1"
  local step="$2"
  local output="$3"
  shift 3
  local log="$MODEL_LOG_ROOT/${step}.log"

  if [[ -f "$output" && "$FORCE" != "1" ]]; then
    echo "[$model_key/$step] artifact exists; skipping: $output"
    record_status "$model_key" "$step" "skipped_existing" "$output" "$log"
    return 0
  fi

  mkdir -p "$(dirname "$output")" "$MODEL_LOG_ROOT"
  echo "[$model_key/$step] command log: $log"
  printf '[%s] start %s/%s\n' "$(date -Is)" "$model_key" "$step" | tee "$log"
  printf '[%s] command:' "$(date -Is)" | tee -a "$log"
  printf ' %q' "$@" | tee -a "$log"
  printf '\n' | tee -a "$log"
  record_status "$model_key" "$step" "started" "$output" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[$model_key/$step] DRY_RUN=1; not executing"
    record_status "$model_key" "$step" "dry_run" "$output" "$log"
    return 0
  fi

  set +e
  "$@" 2>&1 | tee -a "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "[$model_key/$step] FAILED with exit code $status"
    record_status "$model_key" "$step" "failed:$status" "$output" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return "$status"
    fi
    exit "$status"
  fi

  if [[ ! -f "$output" ]]; then
    echo "[$model_key/$step] FAILED: command exited 0 but output is missing: $output" >&2
    record_status "$model_key" "$step" "missing_output" "$output" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return 1
    fi
    exit 1
  fi

  printf '[%s] complete %s/%s\n' "$(date -Is)" "$model_key" "$step" | tee -a "$log"
  record_status "$model_key" "$step" "completed" "$output" "$log"
}

prepare_fixed_sum() {
  local model_key="$1"
  local model_path="$2"
  local artifact_root="$3"
  local cal_dir="$artifact_root/calib_fixed_sum_30db"
  local final_json="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_sweep.json"
  local merge_log="$MODEL_LOG_ROOT/fixed_sum_merge.log"

  if [[ -f "$final_json" && "$FORCE" != "1" ]]; then
    echo "[$model_key/fixed_sum] artifact exists; skipping: $final_json"
    record_status "$model_key" fixed_sum "skipped_existing" "$final_json" "$merge_log"
    return 0
  fi

  local projection
  local inputs=()
  local ok=1
  for projection in $CALIB_PROJECTION_FILTERS; do
    local suffix="${projection%_proj}"
    local partial="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_sweep_${suffix}.json"
    inputs+=("$partial")
    if ! run_artifact_step "$model_key" "fixed_sum_${suffix}" "$partial" \
      "$PYTHON" calibrate.py \
        --model-path "$model_path" \
        --setup 1 \
        --optimizer fixed_sum \
        --target-snr 30 \
        --projection-filter "$projection" \
        --num-texts "$CALIB_NUM_TEXTS" \
        --max-length "$CALIB_MAX_LENGTH" \
        --batch-size "$CALIB_BATCH_SIZE" \
        --output-dir "$cal_dir" \
        --result-suffix "${model_key}_sweep_${suffix}" \
        --mx-chunk-target-mib "$CALIB_MX_CHUNK_MIB" \
        --cal-chunk-target-mib "$CALIB_CHUNK_MIB" \
        --weight-cache-dtype none \
        --compile-msd-truncate \
        --gpus "$ARTIFACT_GPU"; then
      ok=0
    fi
  done

  if [[ "$ok" != "1" ]]; then
    echo "[$model_key/fixed_sum] skipping merge because one or more partial calibrations failed"
    record_status "$model_key" fixed_sum "skipped_partial_failure" "$final_json" "$merge_log"
    return 1
  fi

  run_artifact_step "$model_key" fixed_sum "$final_json" \
    "$PYTHON" tools/merge_msd_calibrations.py \
      "${inputs[@]}" \
      --output "$final_json"
}

prepare_wanda() {
  local model_key="$1"
  local model_path="$2"
  local artifact_root="$3"
  local wanda_root="$artifact_root/wanda_base"
  local mask="$wanda_root/2-4/calibration_base_MXFP8_${model_key}_sweep.pt"

  run_artifact_step "$model_key" wanda "$mask" \
    "$PYTHON" wanda_base/calibrate_base.py \
      --model-path "$model_path" \
      --results-root "$wanda_root" \
      -n 2 -m 4 \
      --setup 1 \
      --num-texts "$WANDA_NUM_TEXTS" \
      --max-length "$WANDA_MAX_LENGTH" \
      --batch-size "$WANDA_BATCH_SIZE" \
      --output-hook "${model_key}_sweep" \
      --mx-chunk-target-mib "$WANDA_MX_CHUNK_MIB" \
      --weight-cache-dtype none \
      --gpus "$ARTIFACT_GPU"
}

status_init

for spec in $MODEL_SPECS; do
  model_key="${spec%%:*}"
  model_path="${spec#*:}"

  if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
    echo "[$model_key] skipping artifact prep; sweep reuses final Qwen3-8B artifacts"
    record_status "$model_key" artifacts "skipped_reuses_final_8b" "" ""
    continue
  fi

  if [[ ! -d "$model_path" ]]; then
    echo "ERROR: [$model_key] model path not found: $model_path" >&2
    exit 2
  fi

  artifact_root="$SWEEP_ROOT/$model_key/artifacts"
  MODEL_LOG_ROOT="$LOG_ROOT/$model_key"

  echo
  echo "================================================================"
  echo "Artifact model: $model_key"
  echo "Path          : $model_path"
  echo "Artifact root : $artifact_root"
  echo "Prep steps    : $PREP_STEPS"
  echo "GPU           : $ARTIFACT_GPU"
  echo "Calib profile : batch=$CALIB_BATCH_SIZE mx_chunk_mib=$CALIB_MX_CHUNK_MIB cal_chunk_mib=$CALIB_CHUNK_MIB projections=$CALIB_PROJECTION_FILTERS"
  echo "WANDA profile : batch=$WANDA_BATCH_SIZE mx_chunk_mib=$WANDA_MX_CHUNK_MIB"
  echo "================================================================"

  if has_step fixed_sum; then
    if ! prepare_fixed_sum "$model_key" "$model_path" "$artifact_root"; then
      [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
    fi
  fi
  if has_step wanda; then
    if ! prepare_wanda "$model_key" "$model_path" "$artifact_root"; then
      [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
    fi
  fi
done

echo
echo "[done] artifact status: $STATUS_FILE"
echo "[done] artifact logs: $LOG_ROOT"

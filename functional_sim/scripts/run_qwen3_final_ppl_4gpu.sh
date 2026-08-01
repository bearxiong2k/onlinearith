#!/usr/bin/env bash
# Run representative Qwen3 PPL jobs on GPUs 4-7.
#
# Modes:
#   default: Qwen3-8B final run, all four representative paths
#   SMOKE=1: Qwen3-1.7B prefix smoke, MXFP8 + activation N:M
#   SWEEP_MODE=1: model sweep over 0.6B/1.7B/4B/8B
#
# The script is resume-safe at the output-file level: existing outputs are
# skipped unless FORCE=1. Each run gets a timestamped log directory and a TSV
# status file that records model, step, output, and log path.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FUNCTIONAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$FUNCTIONAL_ROOT/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
GPUS="${GPUS:-4,5,6,7}"
NPROC="${NPROC:-4}"
LOAD_STAGGER_SEC="${LOAD_STAGGER_SEC:-8}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"
SMOKE="${SMOKE:-0}"
SWEEP_MODE="${SWEEP_MODE:-0}"
STRICT_ARTIFACTS="${STRICT_ARTIFACTS:-0}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"

IFS=',' read -r -a GPU_ARRAY <<< "$GPUS"
if [[ "${#GPU_ARRAY[@]}" -ne "$NPROC" ]]; then
  echo "ERROR: GPUS has ${#GPU_ARRAY[@]} entries but NPROC=$NPROC: $GPUS" >&2
  exit 2
fi

if [[ ! -x "$PYTHON" ]]; then
  echo "ERROR: Python executable not found or not executable: $PYTHON" >&2
  exit 2
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

skip_or_fail_missing_artifact() {
  local model_key="$1"
  local step="$2"
  local artifact="$3"
  local output="$4"
  local log="$5"
  if [[ -f "$artifact" ]]; then
    return 1
  fi

  local msg="missing required artifact: $artifact"
  if [[ "$STRICT_ARTIFACTS" == "1" ]]; then
    echo "ERROR: [$model_key/$step] $msg" >&2
    record_status "$model_key" "$step" "missing_artifact" "$output" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return 0
    fi
    exit 2
  fi

  echo "[$model_key/$step] skipping; $msg"
  record_status "$model_key" "$step" "skipped_missing_artifact" "$output" "$log"
  return 0
}

ensure_file_alias() {
  local source="$1"
  local dest="$2"

  if [[ -z "$source" || "$source" == "$dest" || -e "$dest" ]]; then
    return 0
  fi
  if [[ ! -f "$source" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  if ! ln -s "$(cd "$(dirname "$source")" && pwd)/$(basename "$source")" "$dest" 2>/dev/null; then
    cp "$source" "$dest"
  fi
}

run_step() {
  local model_key="$1"
  local step="$2"
  local output="$3"
  shift 3
  local log="$MODEL_LOG_ROOT/${step}.log"

  if [[ -f "$output" && "$FORCE" != "1" ]]; then
    echo "[$model_key/$step] output exists; skipping: $output"
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
      return 0
    fi
    exit "$status"
  fi

  if [[ ! -f "$output" ]]; then
    echo "[$model_key/$step] FAILED: command exited 0 but output is missing: $output" >&2
    record_status "$model_key" "$step" "missing_output" "$output" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return 0
    fi
    exit 1
  fi

  printf '[%s] complete %s/%s\n' "$(date -Is)" "$model_key" "$step" | tee -a "$log"
  record_status "$model_key" "$step" "completed" "$output" "$log"
}

run_model() {
  local model_key="$1"
  local model_path="$2"
  local run_label="$3"
  local final_root="$4"
  local wanda_root="$5"
  local wanda_hook="$6"
  local act_root="$7"
  local msd_cal="$8"
  local fixed_sum_cache_dtype="$9"
  local wanda_mask="${10:-}"

  if [[ ! -d "$model_path" ]]; then
    echo "ERROR: [$model_key] model path not found: $model_path" >&2
    exit 2
  fi

  MODEL_LOG_ROOT="$LOG_ROOT/$model_key"
  mkdir -p "$final_root" "$MODEL_LOG_ROOT"

  local output_layout="${OUTPUT_LAYOUT:-grouped}"
  local mxfp8_out="$final_root/ppl/mxfp8/ppl_results_MXFP8_${run_label}.json"
  local fixed_sum_out="$final_root/ppl/fixed_sum30/ppl_results_MXFP8_fixed_sum30_${run_label}.json"
  local wanda_out="$wanda_root/2-4/ppl_results_MXFP8_${wanda_hook}.json"
  local act_out="$act_root/2-4/ppl_results_MXFP8.json"

  if [[ "$output_layout" == "flat" ]]; then
    mxfp8_out="$final_root/ppl_results_MXFP8_${run_label}.json"
    fixed_sum_out="$final_root/ppl_results_MXFP8_fixed_sum30_${run_label}.json"
  elif [[ "$output_layout" != "grouped" ]]; then
    echo "ERROR: unsupported OUTPUT_LAYOUT=$output_layout; use grouped or flat" >&2
    exit 2
  fi

  local common_ppl_args=(
    --model-path "$model_path"
    --nproc "$NPROC"
    --gpus "$GPUS"
    --stats off
    --load-stagger-sec "$LOAD_STAGGER_SEC"
    --mxfp-progress-interval-sec -1
  )

  local limit_args=()

  echo
  echo "================================================================"
  echo "Model: $model_key"
  echo "Path : $model_path"
  echo "Root : $final_root"
  echo "Steps: $RUN_STEPS"
  echo "================================================================"

  if has_step mxfp8; then
    limit_args=($(append_limit_args))
    run_step "$model_key" mxfp8 "$mxfp8_out" \
      "$PYTHON" "$FUNCTIONAL_ROOT/ppltest.py" \
        --setup 2 \
        "${common_ppl_args[@]}" \
        "${limit_args[@]}" \
        --output "$mxfp8_out"
  fi

  if has_step fixed_sum; then
    local log="$MODEL_LOG_ROOT/fixed_sum.log"
    if skip_or_fail_missing_artifact "$model_key" fixed_sum "$msd_cal" "$fixed_sum_out" "$log"; then
      :
    else
      limit_args=($(append_limit_args))
      run_step "$model_key" fixed_sum "$fixed_sum_out" \
        "$PYTHON" "$FUNCTIONAL_ROOT/ppltest.py" \
          --setup 6 \
          --calibration "$msd_cal" \
          "${common_ppl_args[@]}" \
          --compile-msd-truncate \
          --weight-cache-dtype "$fixed_sum_cache_dtype" \
          "${limit_args[@]}" \
          --output "$fixed_sum_out"
    fi
  fi

  if has_step wanda; then
    local mask="$wanda_root/2-4/calibration_base_MXFP8_${wanda_hook}.pt"
    local log="$MODEL_LOG_ROOT/wanda.log"
    ensure_file_alias "$wanda_mask" "$mask"
    if skip_or_fail_missing_artifact "$model_key" wanda "$mask" "$wanda_out" "$log"; then
      :
    else
      limit_args=($(append_limit_args))
      run_step "$model_key" wanda "$wanda_out" \
        "$PYTHON" "$FUNCTIONAL_ROOT/wanda_base/ppl_batch_base.py" \
          --model-path "$model_path" \
          --results-root "$wanda_root" \
          -n 2 -m 4 \
          --only 1 \
          --output-hook "$wanda_hook" \
          --nproc "$NPROC" \
          --gpus "$GPUS" \
          --window-shard \
          --load-stagger-sec "$LOAD_STAGGER_SEC" \
          --mxfp-progress-interval-sec -1 \
          "${limit_args[@]}"
    fi
  fi

  if has_step act; then
    limit_args=($(append_limit_args))
    run_step "$model_key" act "$act_out" \
      "$PYTHON" "$FUNCTIONAL_ROOT/act_base/ppl_batch_base_act.py" \
        --model-path "$model_path" \
        --results-root "$act_root" \
        -n 2 -m 4 \
        --only 1 \
        --nproc "$NPROC" \
        --gpus "$GPUS" \
        --window-shard \
        --load-stagger-sec "$LOAD_STAGGER_SEC" \
        --mxfp-progress-interval-sec -1 \
        "${limit_args[@]}"
  fi
}

if [[ "$SWEEP_MODE" == "1" ]]; then
  SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/model_sweep_4gpu}"
  MODEL_SPECS="${MODEL_SPECS:-qwen0_6b:../Qwen3-0.6B qwen1_7b:../Qwen3-1.7B qwen4b:../Qwen3-4B qwen8b:../Qwen3-8B}"
  RUN_STEPS="${RUN_STEPS:-mxfp8 act}"
  if [[ -z "${LIMIT_SAMPLES+x}" ]]; then
    LIMIT_SAMPLES=120
  fi
  if [[ -z "${SWEEP_TAG+x}" ]]; then
    if [[ -n "$LIMIT_SAMPLES" ]]; then
      SWEEP_TAG="prefix${LIMIT_SAMPLES}"
    else
      SWEEP_TAG="full"
    fi
  fi
  OUTPUT_LAYOUT="${OUTPUT_LAYOUT:-grouped}"
  LOG_ROOT="${LOG_ROOT:-$SWEEP_ROOT/logs/sweep_${SWEEP_TAG}_${RUN_ID}}"
  STATUS_FILE="${STATUS_FILE:-$LOG_ROOT/status.tsv}"
  status_init

  for spec in $MODEL_SPECS; do
    model_key="${spec%%:*}"
    model_path="${spec#*:}"
    model_root="$SWEEP_ROOT/$model_key/$SWEEP_TAG"
    artifact_root="$SWEEP_ROOT/$model_key/artifacts"
    run_label="${model_key}_sweep_${SWEEP_TAG}"
    wanda_root="$model_root/wanda_base"
    wanda_hook="$run_label"
    wanda_mask="$artifact_root/wanda_base/2-4/calibration_base_MXFP8_${model_key}_sweep.pt"
    msd_cal="$artifact_root/calib_fixed_sum_30db/calibration_MXFP8_fixed_sum_${model_key}_sweep.json"
    fixed_sum_cache_dtype="float16"

    if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
      msd_cal="../data/qwen3_final_experiments/qwen3_8b/calib_fixed_sum_30db/calibration_MXFP8_fixed_sum_qwen8b_final_merged.json"
      wanda_mask="../data/wanda_base/2-4/calibration_base_MXFP8_qwen8b_final.pt"
      fixed_sum_cache_dtype="float8"
    fi

    run_model \
      "$model_key" \
      "$model_path" \
      "$run_label" \
      "$model_root" \
      "$wanda_root" \
      "$wanda_hook" \
      "$model_root/act_base" \
      "$msd_cal" \
      "$fixed_sum_cache_dtype" \
      "$wanda_mask"
  done
elif [[ "$SMOKE" == "1" ]]; then
  MODEL="${MODEL:-../Qwen3-1.7B}"
  RUN_LABEL="${RUN_LABEL:-qwen1_7b_smoke}"
  FINAL_ROOT="${FINAL_ROOT:-../data/qwen3_final_experiments/smoke_qwen3_1_7b_4gpu}"
  RUN_STEPS="${RUN_STEPS:-mxfp8 act}"
  if [[ -z "${LIMIT_SAMPLES+x}" ]]; then
    LIMIT_SAMPLES=120
  fi
  OUTPUT_LAYOUT="${OUTPUT_LAYOUT:-grouped}"
  LOG_ROOT="${LOG_ROOT:-$FINAL_ROOT/logs/smoke_${RUN_ID}}"
  STATUS_FILE="${STATUS_FILE:-$LOG_ROOT/status.tsv}"
  status_init
  run_model \
    "$RUN_LABEL" \
    "$MODEL" \
    "$RUN_LABEL" \
    "$FINAL_ROOT" \
    "$FINAL_ROOT/wanda_base" \
    "$RUN_LABEL" \
    "$FINAL_ROOT/act_base" \
    "$FINAL_ROOT/calib_fixed_sum_30db/calibration_MXFP8_fixed_sum_${RUN_LABEL}.json" \
    "float16"
else
  MODEL="${MODEL:-../Qwen3-8B}"
  RUN_LABEL="${RUN_LABEL:-qwen8b_final}"
  FINAL_ROOT="${FINAL_ROOT:-../data/qwen3_final_experiments/qwen3_8b}"
  RUN_STEPS="${RUN_STEPS:-mxfp8 fixed_sum wanda act}"
  LIMIT_SAMPLES="${LIMIT_SAMPLES:-}"
  MSD_DIR="${MSD_DIR:-$FINAL_ROOT/calib_fixed_sum_30db}"
  MSD_CAL="${MSD_CAL:-$MSD_DIR/calibration_MXFP8_fixed_sum_qwen8b_final_merged.json}"
  WANDA_ROOT="${WANDA_ROOT:-../data/wanda_base}"
  WANDA_HOOK="${WANDA_HOOK:-$RUN_LABEL}"
  ACT_ROOT="${ACT_ROOT:-$FINAL_ROOT/act_base}"
  OUTPUT_LAYOUT="${OUTPUT_LAYOUT:-flat}"
  LOG_ROOT="${LOG_ROOT:-$FINAL_ROOT/logs/final_ppl_4gpu_${RUN_ID}}"
  STATUS_FILE="${STATUS_FILE:-$LOG_ROOT/status.tsv}"
  status_init
  run_model \
    "$RUN_LABEL" \
    "$MODEL" \
    "$RUN_LABEL" \
    "$FINAL_ROOT" \
    "$WANDA_ROOT" \
    "$WANDA_HOOK" \
    "$ACT_ROOT" \
    "$MSD_CAL" \
    "float8"
fi

echo
echo "[done] status: $STATUS_FILE"
echo "[done] logs: $LOG_ROOT"

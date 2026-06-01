#!/usr/bin/env bash
# Generate fixed-sum target-SNR calibration artifacts plus stats/PPL accounting
# for equivalent digit-read targeting.
#
# This is the single-model worker used by
# run_qwen3_fixed_sum17_full_stats_4gpu.sh. Defaults run Qwen3-0.6B at 17 dB
# with full samples. Set UTIL_LIMIT_SAMPLES=120 and TARGET_SNRS="17 18" only
# for work-point selection probes.

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/fixed_sum17_full_stats}"
MODEL_SPECS="${MODEL_SPECS:-qwen0_6b:../Qwen3-0.6B:float16}"
TARGET_SNRS="${TARGET_SNRS:-17}"
ARTIFACT_GPU="${ARTIFACT_GPU:-4}"
PPL_GPU="${PPL_GPU:-4}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
RUN_CALIBRATION="${RUN_CALIBRATION:-1}"
RUN_PPL_PROBE="${RUN_PPL_PROBE:-1}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
LOG_ROOT="${LOG_ROOT:-$SWEEP_ROOT/logs/fixed_sum_stats_${RUN_ID}}"
STATUS_FILE="${STATUS_FILE:-$LOG_ROOT/status.tsv}"

CALIB_NUM_TEXTS="${CALIB_NUM_TEXTS:-20}"
CALIB_MAX_LENGTH="${CALIB_MAX_LENGTH:-512}"
CALIB_BATCH_SIZE="${CALIB_BATCH_SIZE:-4}"
CALIB_MX_CHUNK_MIB="${CALIB_MX_CHUNK_MIB:-256}"
CALIB_CHUNK_MIB="${CALIB_CHUNK_MIB:-64}"
CALIB_PROJECTION_FILTERS="${CALIB_PROJECTION_FILTERS:-gate_proj up_proj down_proj}"

UTIL_LIMIT_SAMPLES="${UTIL_LIMIT_SAMPLES:-}"
PPL_MX_CHUNK_MIB="${PPL_MX_CHUNK_MIB:-256}"
PPL_MSD_CHUNK_MIB="${PPL_MSD_CHUNK_MIB:-1536}"

if [[ ! -x "$PYTHON" ]]; then
  echo "ERROR: Python executable not found or not executable: $PYTHON" >&2
  exit 2
fi

snr_label() {
  local snr="$1"
  printf 'snr%sdb' "${snr//./p}"
}

ppl_sample_label() {
  if [[ -n "$UTIL_LIMIT_SAMPLES" ]]; then
    printf 'limit%s' "$UTIL_LIMIT_SAMPLES"
  else
    printf 'full'
  fi
}

calibration_tasks() {
  local model_key="$1"
  if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
    printf '%s\n' \
      "gate:gate_proj" \
      "up:up_proj" \
      "down_l00:model.layers.0.mlp.down_proj" \
      "down_l01_l12:model.layers.1.mlp.down_proj,model.layers.2.mlp.down_proj,model.layers.3.mlp.down_proj,model.layers.4.mlp.down_proj,model.layers.5.mlp.down_proj,model.layers.6.mlp.down_proj,model.layers.7.mlp.down_proj,model.layers.8.mlp.down_proj,model.layers.9.mlp.down_proj,model.layers.10.mlp.down_proj,model.layers.11.mlp.down_proj,model.layers.12.mlp.down_proj" \
      "down_l13_l24:model.layers.13.mlp.down_proj,model.layers.14.mlp.down_proj,model.layers.15.mlp.down_proj,model.layers.16.mlp.down_proj,model.layers.17.mlp.down_proj,model.layers.18.mlp.down_proj,model.layers.19.mlp.down_proj,model.layers.20.mlp.down_proj,model.layers.21.mlp.down_proj,model.layers.22.mlp.down_proj,model.layers.23.mlp.down_proj,model.layers.24.mlp.down_proj" \
      "down_l25_l35:model.layers.25.mlp.down_proj,model.layers.26.mlp.down_proj,model.layers.27.mlp.down_proj,model.layers.28.mlp.down_proj,model.layers.29.mlp.down_proj,model.layers.30.mlp.down_proj,model.layers.31.mlp.down_proj,model.layers.32.mlp.down_proj,model.layers.33.mlp.down_proj,model.layers.34.mlp.down_proj,model.layers.35.mlp.down_proj"
  else
    local projection
    for projection in $CALIB_PROJECTION_FILTERS; do
      printf '%s:%s\n' "${projection%_proj}" "$projection"
    done
  fi
}

status_init() {
  mkdir -p "$(dirname "$STATUS_FILE")"
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "timestamp	model	target_snr_db	step	status	output	log" > "$STATUS_FILE"
  fi
}

record_status() {
  local model_key="$1"
  local snr="$2"
  local step="$3"
  local status="$4"
  local output="$5"
  local log="$6"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$model_key" "$snr" "$step" "$status" "$output" "$log" >> "$STATUS_FILE"
}

run_step() {
  local model_key="$1"
  local snr="$2"
  local step="$3"
  local output="$4"
  local log="$5"
  shift 5

  if [[ -f "$output" && "$FORCE" != "1" ]]; then
    echo "[$model_key/$snr/$step] exists; skipping: $output"
    record_status "$model_key" "$snr" "$step" "skipped_existing" "$output" "$log"
    return 0
  fi

  mkdir -p "$(dirname "$output")" "$(dirname "$log")"
  printf '[%s] start %s/%s/%s\n' "$(date -Is)" "$model_key" "$snr" "$step" | tee "$log"
  printf '[%s] command:' "$(date -Is)" | tee -a "$log"
  printf ' %q' "$@" | tee -a "$log"
  printf '\n' | tee -a "$log"
  record_status "$model_key" "$snr" "$step" "started" "$output" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[$model_key/$snr/$step] DRY_RUN=1; not executing"
    record_status "$model_key" "$snr" "$step" "dry_run" "$output" "$log"
    return 0
  fi

  set +e
  "$@" 2>&1 | tee -a "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "[$model_key/$snr/$step] FAILED with exit code $status" >&2
    record_status "$model_key" "$snr" "$step" "failed:$status" "$output" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return "$status"
    fi
    exit "$status"
  fi

  if [[ ! -f "$output" ]]; then
    echo "[$model_key/$snr/$step] FAILED: command exited 0 but output is missing: $output" >&2
    record_status "$model_key" "$snr" "$step" "missing_output" "$output" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return 1
    fi
    exit 1
  fi

  printf '[%s] complete %s/%s/%s\n' "$(date -Is)" "$model_key" "$snr" "$step" | tee -a "$log"
  record_status "$model_key" "$snr" "$step" "completed" "$output" "$log"
}

prepare_calibration() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local label="$4"
  local model_snr_root="$5"
  local log_dir="$6"
  local cal_dir="$model_snr_root/calib"
  local final_json="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local merge_log="$log_dir/fixed_sum_merge.log"
  local inputs=()
  local task
  local ok=1

  if [[ -f "$final_json" && "$FORCE" != "1" ]]; then
    echo "[$model_key/$snr/fixed_sum] exists; skipping: $final_json"
    record_status "$model_key" "$snr" "fixed_sum" "skipped_existing" "$final_json" "$merge_log"
    return 0
  fi

  while IFS= read -r task; do
    local suffix="${task%%:*}"
    local projection="${task#*:}"
    local partial="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}_${suffix}.json"
    local log="$log_dir/fixed_sum_${suffix}.log"
    inputs+=("$partial")
    if ! run_step "$model_key" "$snr" "fixed_sum_${suffix}" "$partial" "$log" \
      env CUDA_VISIBLE_DEVICES="$ARTIFACT_GPU" "$PYTHON" calibrate.py \
        --model-path "$model_path" \
        --setup 1 \
        --optimizer fixed_sum \
        --target-snr "$snr" \
        --projection-filter "$projection" \
        --num-texts "$CALIB_NUM_TEXTS" \
        --max-length "$CALIB_MAX_LENGTH" \
        --batch-size "$CALIB_BATCH_SIZE" \
        --output-dir "$cal_dir" \
        --result-suffix "${model_key}_${label}_${suffix}" \
        --mx-chunk-target-mib "$CALIB_MX_CHUNK_MIB" \
        --cal-chunk-target-mib "$CALIB_CHUNK_MIB" \
        --weight-cache-dtype none \
        --compile-msd-truncate \
        --gpus "$ARTIFACT_GPU"; then
      ok=0
    fi
  done < <(calibration_tasks "$model_key")

  if [[ "$ok" != "1" ]]; then
    echo "[$model_key/$snr/fixed_sum] skipping merge because one or more partial calibrations failed" >&2
    record_status "$model_key" "$snr" "fixed_sum" "skipped_partial_failure" "$final_json" "$merge_log"
    return 1
  fi

  run_step "$model_key" "$snr" "fixed_sum" "$final_json" "$merge_log" \
    "$PYTHON" tools/merge_msd_calibrations.py "${inputs[@]}" --output "$final_json"
}

run_ppl_probe() {
  local model_key="$1"
  local model_path="$2"
  local cache_dtype="$3"
  local snr="$4"
  local label="$5"
  local model_snr_root="$6"
  local log_dir="$7"
  local cal="$model_snr_root/calib/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local sample_label
  sample_label="$(ppl_sample_label)"
  local ppl_dir="$model_snr_root/ppl/util_fig5_${sample_label}"
  local out="$ppl_dir/ppl_results_MXFP8_fixed_sum_${model_key}_${label}_util_fig5_${sample_label}.json"
  local log="$log_dir/ppl_util_fig5_${sample_label}.log"
  local limit_args=()

  if [[ -n "$UTIL_LIMIT_SAMPLES" ]]; then
    limit_args=(--limit-samples "$UTIL_LIMIT_SAMPLES")
  fi

  if [[ ! -f "$cal" ]]; then
    echo "[$model_key/$snr/ppl] missing calibration: $cal" >&2
    record_status "$model_key" "$snr" "ppl_util_fig5" "missing_calibration" "$out" "$log"
    if [[ "$CONTINUE_ON_ERROR" == "1" ]]; then
      return 0
    fi
    exit 2
  fi

  run_step "$model_key" "$snr" "ppl_util_fig5" "$out" "$log" \
    env CUDA_VISIBLE_DEVICES="$PPL_GPU" "$PYTHON" ppltest.py \
      --model-path "$model_path" \
      --setup 6 \
      --calibration "$cal" \
      --msd-utilization-mode \
      --figure5-layer-cycles \
      "${limit_args[@]}" \
      --mx-chunk-target-mib "$PPL_MX_CHUNK_MIB" \
      --msd-chunk-target-mib "$PPL_MSD_CHUNK_MIB" \
      --weight-cache-dtype "$cache_dtype" \
      --compile-msd-truncate \
      --gpus "$PPL_GPU" \
      --output "$out"
}

if [[ "$DRY_RUN" != "1" ]]; then
  echo "[preflight] CUDA visibility through artifact GPU: $ARTIFACT_GPU"
  CUDA_VISIBLE_DEVICES="$ARTIFACT_GPU" "$PYTHON" - <<'PY'
import torch
print(torch.cuda.is_available(), torch.cuda.device_count())
if not torch.cuda.is_available() or torch.cuda.device_count() == 0:
    raise SystemExit("CUDA is not visible to the artifact GPU")
PY

  echo "[preflight] CUDA visibility through PPL GPU: $PPL_GPU"
  CUDA_VISIBLE_DEVICES="$PPL_GPU" "$PYTHON" - <<'PY'
import torch
print(torch.cuda.is_available(), torch.cuda.device_count())
if not torch.cuda.is_available() or torch.cuda.device_count() == 0:
    raise SystemExit("CUDA is not visible to the PPL GPU")
PY
fi

status_init
mkdir -p "$LOG_ROOT"

echo "Sweep root        : $SWEEP_ROOT"
echo "Log root          : $LOG_ROOT"
echo "Model specs       : $MODEL_SPECS"
echo "Target SNRs       : $TARGET_SNRS"
echo "Artifact/PPL GPUs : $ARTIFACT_GPU / $PPL_GPU"
echo "Sample mode       : $(ppl_sample_label)"

for spec in $MODEL_SPECS; do
  IFS=':' read -r model_key model_path cache_dtype <<< "$spec"
  cache_dtype="${cache_dtype:-float16}"
  if [[ -z "$model_key" || -z "$model_path" ]]; then
    echo "ERROR: invalid MODEL_SPECS entry: $spec" >&2
    exit 2
  fi
  if [[ ! -d "$model_path" ]]; then
    echo "ERROR: model path not found for $model_key: $model_path" >&2
    exit 2
  fi

  for snr in $TARGET_SNRS; do
    label="$(snr_label "$snr")"
    model_snr_root="$SWEEP_ROOT/$model_key/$label"
    log_dir="$LOG_ROOT/$model_key/$label"
    if [[ "$RUN_CALIBRATION" == "1" ]]; then
      if ! prepare_calibration "$model_key" "$model_path" "$snr" "$label" "$model_snr_root" "$log_dir"; then
        [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
        continue
      fi
    fi
    if [[ "$RUN_PPL_PROBE" == "1" ]]; then
      if ! run_ppl_probe "$model_key" "$model_path" "$cache_dtype" "$snr" "$label" "$model_snr_root" "$log_dir"; then
        [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
      fi
    fi
  done
done

summary_args=(
  --root "$SWEEP_ROOT"
  --models "$(printf '%s\n' $MODEL_SPECS | awk -F: '{print $1}' | xargs)"
  --target-snrs "$TARGET_SNRS"
  --output-dir "$LOG_ROOT"
)
if [[ -n "$UTIL_LIMIT_SAMPLES" ]]; then
  summary_args+=(--limit-samples "$UTIL_LIMIT_SAMPLES")
fi

"$PYTHON" scripts/summarize_fixed_sum_norm_sweep.py \
  "${summary_args[@]}"

echo "Status file: $STATUS_FILE"

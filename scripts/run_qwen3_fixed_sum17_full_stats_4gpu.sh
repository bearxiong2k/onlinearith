#!/usr/bin/env bash
# Formal fixed-sum 17 dB full-sample stats sweep for Qwen3 models on GPUs 4-7.
#
# This collects the data missing from the four-rank final PPL sweep:
# full WikiText-2 PPL, plot_norm_digit_read, and Figure 5 layer-cycle inputs.
# It runs models sequentially from small to large. For each model, calibration
# uses projection/task parallelism across the available GPUs, then PPL stats use
# explicit single-process model sharding over GPUs 4-7. This avoids --nproc
# because current multi-rank PPL does not aggregate MSD stats from nonzero ranks.
#
# To detach:
#   BACKGROUND=1 scripts/run_qwen3_fixed_sum17_full_stats_4gpu.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/fixed_sum17_full_stats}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
DRIVER_ROOT="${DRIVER_ROOT:-$SWEEP_ROOT/logs/full_stats_${RUN_ID}}"
TARGET_SNRS="${TARGET_SNRS:-17}"
GPUS="${GPUS:-4,5,6,7}"
PPL_DEVICE_MAP="${PPL_DEVICE_MAP:-sequential}"
PPL_MAX_MEMORY="${PPL_MAX_MEMORY:-0:30GiB,1:30GiB,2:30GiB,3:30GiB}"
CALIBRATION_MODE="${CALIBRATION_MODE:-parallel}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"

# key:model_path:ppl_cache_dtype:calib_batch:calib_mx_chunk_mib:calib_chunk_mib:ppl_msd_chunk_mib
MODEL_JOBS="${MODEL_JOBS:-qwen0_6b:../Qwen3-0.6B:float16:8:512:128:1536 qwen1_7b:../Qwen3-1.7B:float16:4:384:96:1536 qwen4b:../Qwen3-4B:float16:2:256:64:1536 qwen8b:../Qwen3-8B:float8:4:256:64:1536}"

if [[ "${BACKGROUND:-0}" == "1" && "${QWEN_FIXED_SUM17_BACKGROUND_CHILD:-0}" != "1" ]]; then
  mkdir -p "$DRIVER_ROOT"
  export QWEN_FIXED_SUM17_BACKGROUND_CHILD=1
  export RUN_ID SWEEP_ROOT DRIVER_ROOT TARGET_SNRS GPUS PPL_DEVICE_MAP PPL_MAX_MEMORY CALIBRATION_MODE
  export CONTINUE_ON_ERROR FORCE DRY_RUN MODEL_JOBS
  nohup "$0" "$@" > "$DRIVER_ROOT/nohup.out" 2>&1 &
  echo "[launched] PID: $!"
  echo "[launched] driver log: $DRIVER_ROOT/driver.log"
  echo "[launched] nohup log : $DRIVER_ROOT/nohup.out"
  exit 0
fi

mkdir -p "$DRIVER_ROOT"
exec > >(tee -a "$DRIVER_ROOT/driver.log") 2>&1

STATUS_FILE="$DRIVER_ROOT/status.tsv"
SUMMARY_WRITTEN=0

model_keys_arg() {
  local job
  for job in $MODEL_JOBS; do
    printf '%s\n' "${job%%:*}"
  done | xargs
}

write_summary() {
  "$PYTHON" "$SCRIPT_DIR/summarize_fixed_sum_norm_sweep.py" \
    --root "$SWEEP_ROOT" \
    --models "$(model_keys_arg)" \
    --target-snrs "$TARGET_SNRS" \
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
    echo "target_snrs=$TARGET_SNRS"
    echo "gpus=$GPUS"
    echo "ppl_device_map=$PPL_DEVICE_MAP"
    echo "ppl_max_memory=$PPL_MAX_MEMORY"
    echo "calibration_mode=$CALIBRATION_MODE"
    echo "sweep_root=$SWEEP_ROOT"
    echo "driver_root=$DRIVER_ROOT"
    echo "summary_tsv=$DRIVER_ROOT/fixed_sum_stats_full.tsv"
    echo "summary_json=$DRIVER_ROOT/fixed_sum_stats_full.json"
    echo "status_tsv=$STATUS_FILE"
  } > "$DRIVER_ROOT/final_status.txt"
  echo "[driver] final status written to $DRIVER_ROOT/final_status.txt"
}
trap finish EXIT

record_status() {
  local model_key="$1"
  local snr="$2"
  local step="$3"
  local status="$4"
  local output="$5"
  local log="$6"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$model_key" "$snr" "$step" "$status" "$output" "$log" >> "$STATUS_FILE"
}

snr_label() {
  local snr="$1"
  printf 'snr%sdb' "${snr//./p}"
}

gpu_by_index() {
  local index="$1"
  IFS=',' read -r -a gpu_list <<< "$GPUS"
  printf '%s' "${gpu_list[$index]}"
}

calibration_tasks() {
  local model_key="$1"
  if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
    printf '%s\t%s\t%s\t%s\n' "gate" "gate_proj" "$(gpu_by_index 0)" "1"
    printf '%s\t%s\t%s\t%s\n' "up" "up_proj" "$(gpu_by_index 1)" "1"
    printf '%s\t%s\t%s\t%s\n' "down_l00" "model.layers.0.mlp.down_proj" "$(gpu_by_index 2)" "1"
    printf '%s\t%s\t%s\t%s\n' "down_l01_l12" "model.layers.1.mlp.down_proj,model.layers.2.mlp.down_proj,model.layers.3.mlp.down_proj,model.layers.4.mlp.down_proj,model.layers.5.mlp.down_proj,model.layers.6.mlp.down_proj,model.layers.7.mlp.down_proj,model.layers.8.mlp.down_proj,model.layers.9.mlp.down_proj,model.layers.10.mlp.down_proj,model.layers.11.mlp.down_proj,model.layers.12.mlp.down_proj" "$(gpu_by_index 3)" "1"
    printf '%s\t%s\t%s\t%s\n' "down_l13_l24" "model.layers.13.mlp.down_proj,model.layers.14.mlp.down_proj,model.layers.15.mlp.down_proj,model.layers.16.mlp.down_proj,model.layers.17.mlp.down_proj,model.layers.18.mlp.down_proj,model.layers.19.mlp.down_proj,model.layers.20.mlp.down_proj,model.layers.21.mlp.down_proj,model.layers.22.mlp.down_proj,model.layers.23.mlp.down_proj,model.layers.24.mlp.down_proj" "$(gpu_by_index 0)" "2"
    printf '%s\t%s\t%s\t%s\n' "down_l25_l35" "model.layers.25.mlp.down_proj,model.layers.26.mlp.down_proj,model.layers.27.mlp.down_proj,model.layers.28.mlp.down_proj,model.layers.29.mlp.down_proj,model.layers.30.mlp.down_proj,model.layers.31.mlp.down_proj,model.layers.32.mlp.down_proj,model.layers.33.mlp.down_proj,model.layers.34.mlp.down_proj,model.layers.35.mlp.down_proj" "$(gpu_by_index 1)" "2"
  else
    printf '%s\t%s\t%s\t%s\n' "gate" "gate_proj" "$(gpu_by_index 0)" "1"
    printf '%s\t%s\t%s\t%s\n' "up" "up_proj" "$(gpu_by_index 1)" "1"
    printf '%s\t%s\t%s\t%s\n' "down" "down_proj" "$(gpu_by_index 2)" "1"
  fi
}

run_calibration_task() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local label="$4"
  local suffix="$5"
  local projection_filter="$6"
  local gpu="$7"
  local calib_batch="$8"
  local calib_mx_chunk="$9"
  local calib_chunk="${10}"
  local cal_dir="$SWEEP_ROOT/$model_key/$label/calib"
  local log_dir="$DRIVER_ROOT/$model_key/calib/$label"
  local partial="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}_${suffix}.json"
  local log="$log_dir/fixed_sum_${suffix}.log"

  if [[ -f "$partial" && "$FORCE" != "1" ]]; then
    echo "[driver][$model_key/$snr/$suffix] calibration exists; skipping: $partial"
    record_status "$model_key" "$snr" "fixed_sum_${suffix}" "skipped_existing" "$partial" "$log"
    return 0
  fi

  mkdir -p "$cal_dir" "$log_dir"
  echo "[driver][$model_key/$snr/$suffix] start calibration on GPU $gpu; log: $log"
  printf '[%s] start %s/%s/fixed_sum_%s on GPU %s\n' "$(date -Is)" "$model_key" "$snr" "$suffix" "$gpu" > "$log"
  printf '[%s] command:' "$(date -Is)" >> "$log"
  printf ' %q' env "CUDA_VISIBLE_DEVICES=$gpu" "$PYTHON" calibrate.py \
    --model-path "$model_path" \
    --setup 1 \
    --optimizer fixed_sum \
    --target-snr "$snr" \
    --projection-filter "$projection_filter" \
    --num-texts 20 \
    --max-length 512 \
    --batch-size "$calib_batch" \
    --output-dir "$cal_dir" \
    --result-suffix "${model_key}_${label}_${suffix}" \
    --mx-chunk-target-mib "$calib_mx_chunk" \
    --cal-chunk-target-mib "$calib_chunk" \
    --weight-cache-dtype none \
    --compile-msd-truncate \
    --gpus "$gpu" >> "$log"
  printf '\n' >> "$log"
  record_status "$model_key" "$snr" "fixed_sum_${suffix}" "started" "$partial" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[driver][$model_key/$snr/$suffix] DRY_RUN=1; not executing" >> "$log"
    record_status "$model_key" "$snr" "fixed_sum_${suffix}" "dry_run" "$partial" "$log"
    return 0
  fi

  if env CUDA_VISIBLE_DEVICES="$gpu" "$PYTHON" calibrate.py \
    --model-path "$model_path" \
    --setup 1 \
    --optimizer fixed_sum \
    --target-snr "$snr" \
    --projection-filter "$projection_filter" \
    --num-texts 20 \
    --max-length 512 \
    --batch-size "$calib_batch" \
    --output-dir "$cal_dir" \
    --result-suffix "${model_key}_${label}_${suffix}" \
    --mx-chunk-target-mib "$calib_mx_chunk" \
    --cal-chunk-target-mib "$calib_chunk" \
    --weight-cache-dtype none \
    --compile-msd-truncate \
    --gpus "$gpu" >> "$log" 2>&1; then
    record_status "$model_key" "$snr" "fixed_sum_${suffix}" "completed" "$partial" "$log"
  else
    local status=$?
    record_status "$model_key" "$snr" "fixed_sum_${suffix}" "failed:$status" "$partial" "$log"
    return "$status"
  fi
}

run_calibration_wave() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local label="$4"
  local wave="$5"
  local calib_batch="$6"
  local calib_mx_chunk="$7"
  local calib_chunk="$8"
  local suffix projection_filter gpu task_wave
  local pids=()
  local names=()

  while IFS=$'\t' read -r suffix projection_filter gpu task_wave; do
    [[ "$task_wave" == "$wave" ]] || continue
    if [[ "$CALIBRATION_MODE" == "parallel" ]]; then
      run_calibration_task "$model_key" "$model_path" "$snr" "$label" "$suffix" "$projection_filter" "$gpu" "$calib_batch" "$calib_mx_chunk" "$calib_chunk" &
      pids+=("$!")
      names+=("$suffix")
    elif [[ "$CALIBRATION_MODE" == "serial" ]]; then
      if run_calibration_task "$model_key" "$model_path" "$snr" "$label" "$suffix" "$projection_filter" "$gpu" "$calib_batch" "$calib_mx_chunk" "$calib_chunk"; then
        echo "[driver][$model_key/$snr] complete calibration $suffix"
      else
        local status=$?
        echo "[driver][$model_key/$snr] FAILED calibration $suffix with exit code $status"
        return "$status"
      fi
    else
      echo "ERROR: unsupported CALIBRATION_MODE=$CALIBRATION_MODE; use parallel or serial" >&2
      return 2
    fi
  done < <(calibration_tasks "$model_key")

  if [[ "$CALIBRATION_MODE" == "serial" ]]; then
    return 0
  fi

  local failed=0
  for idx in "${!pids[@]}"; do
    if wait "${pids[$idx]}"; then
      echo "[driver][$model_key/$snr] complete calibration ${names[$idx]}"
    else
      local status=$?
      echo "[driver][$model_key/$snr] FAILED calibration ${names[$idx]} with exit code $status"
      failed=1
    fi
  done
  return "$failed"
}

prepare_calibration() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local calib_batch="$4"
  local calib_mx_chunk="$5"
  local calib_chunk="$6"
  local label
  label="$(snr_label "$snr")"
  local cal_dir="$SWEEP_ROOT/$model_key/$label/calib"
  local final_json="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local merge_log="$DRIVER_ROOT/$model_key/calib/$label/fixed_sum_merge.log"
  local inputs=()
  local suffix projection_filter gpu task_wave

  if [[ -f "$final_json" && "$FORCE" != "1" ]]; then
    echo "[driver][$model_key/$snr] merged calibration exists; skipping: $final_json"
    record_status "$model_key" "$snr" "fixed_sum" "skipped_existing" "$final_json" "$merge_log"
    return 0
  fi

  echo "[driver][$model_key/$snr] calibration wave 1"
  if ! run_calibration_wave "$model_key" "$model_path" "$snr" "$label" "1" "$calib_batch" "$calib_mx_chunk" "$calib_chunk"; then
    return 1
  fi
  if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
    echo "[driver][$model_key/$snr] calibration wave 2"
    if ! run_calibration_wave "$model_key" "$model_path" "$snr" "$label" "2" "$calib_batch" "$calib_mx_chunk" "$calib_chunk"; then
      return 1
    fi
  fi

  while IFS=$'\t' read -r suffix projection_filter gpu task_wave; do
    inputs+=("$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}_${suffix}.json")
  done < <(calibration_tasks "$model_key")

  mkdir -p "$(dirname "$merge_log")"
  printf '[%s] command:' "$(date -Is)" | tee "$merge_log"
  printf ' %q' "$PYTHON" tools/merge_msd_calibrations.py "${inputs[@]}" --output "$final_json" | tee -a "$merge_log"
  printf '\n' | tee -a "$merge_log"
  record_status "$model_key" "$snr" "fixed_sum" "started" "$final_json" "$merge_log"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[driver][$model_key/$snr] DRY_RUN=1; not merging" | tee -a "$merge_log"
    record_status "$model_key" "$snr" "fixed_sum" "dry_run" "$final_json" "$merge_log"
    return 0
  fi

  if "$PYTHON" tools/merge_msd_calibrations.py "${inputs[@]}" --output "$final_json" >> "$merge_log" 2>&1; then
    record_status "$model_key" "$snr" "fixed_sum" "completed" "$final_json" "$merge_log"
  else
    local status=$?
    record_status "$model_key" "$snr" "fixed_sum" "failed:$status" "$final_json" "$merge_log"
    return "$status"
  fi
}

run_ppl_stats() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local cache_dtype="$4"
  local ppl_msd_chunk="$5"
  local label
  label="$(snr_label "$snr")"
  local cal="$SWEEP_ROOT/$model_key/$label/calib/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local ppl_dir="$SWEEP_ROOT/$model_key/$label/ppl/util_fig5_full"
  local out="$ppl_dir/ppl_results_MXFP8_fixed_sum_${model_key}_${label}_util_fig5_full.json"
  local log="$DRIVER_ROOT/$model_key/ppl/$label/ppl_util_fig5_full.log"
  local device_map_args=(--device-map "$PPL_DEVICE_MAP")

  if [[ "$PPL_DEVICE_MAP" != "none" && -n "$PPL_MAX_MEMORY" ]]; then
    device_map_args+=(--max-memory "$PPL_MAX_MEMORY")
  fi

  if [[ -f "$out" && "$FORCE" != "1" ]]; then
    echo "[driver][$model_key/$snr/ppl] output exists; skipping: $out"
    record_status "$model_key" "$snr" "ppl_util_fig5" "skipped_existing" "$out" "$log"
    return 0
  fi

  if [[ ! -f "$cal" && "$DRY_RUN" != "1" ]]; then
    echo "[driver][$model_key/$snr/ppl] missing calibration: $cal" >&2
    record_status "$model_key" "$snr" "ppl_util_fig5" "missing_calibration" "$out" "$log"
    return 2
  fi

  mkdir -p "$ppl_dir" "$(dirname "$log")"
  printf '[%s] start %s/%s/ppl_util_fig5\n' "$(date -Is)" "$model_key" "$snr" | tee "$log"
  printf '[%s] command:' "$(date -Is)" | tee -a "$log"
  printf ' %q' env "CUDA_VISIBLE_DEVICES=$GPUS" "$PYTHON" ppltest.py \
    --model-path "$model_path" \
    --setup 6 \
    --calibration "$cal" \
    --stats lite \
    --figure5-layer-cycles \
    "${device_map_args[@]}" \
    --mx-chunk-target-mib 256 \
    --msd-chunk-target-mib "$ppl_msd_chunk" \
    --weight-cache-dtype "$cache_dtype" \
    --compile-msd-truncate \
    --gpus "$GPUS" \
    --output "$out" | tee -a "$log"
  printf '\n' | tee -a "$log"
  record_status "$model_key" "$snr" "ppl_util_fig5" "started" "$out" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[driver][$model_key/$snr/ppl] DRY_RUN=1; not executing" | tee -a "$log"
    record_status "$model_key" "$snr" "ppl_util_fig5" "dry_run" "$out" "$log"
    return 0
  fi

  if env CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" ppltest.py \
    --model-path "$model_path" \
    --setup 6 \
    --calibration "$cal" \
    --stats lite \
    --figure5-layer-cycles \
    "${device_map_args[@]}" \
    --mx-chunk-target-mib 256 \
    --msd-chunk-target-mib "$ppl_msd_chunk" \
    --weight-cache-dtype "$cache_dtype" \
    --compile-msd-truncate \
    --gpus "$GPUS" \
    --output "$out" >> "$log" 2>&1; then
    record_status "$model_key" "$snr" "ppl_util_fig5" "completed" "$out" "$log"
  else
    local status=$?
    record_status "$model_key" "$snr" "ppl_util_fig5" "failed:$status" "$out" "$log"
    return "$status"
  fi
}

if [[ ! -x "$PYTHON" ]]; then
  echo "ERROR: Python executable not found or not executable: $PYTHON" >&2
  exit 2
fi

if [[ "$DRY_RUN" != "1" ]]; then
  echo "[preflight] CUDA visibility through GPUs: $GPUS"
  CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" - <<'PY'
import torch
print(torch.cuda.is_available(), torch.cuda.device_count())
if not torch.cuda.is_available() or torch.cuda.device_count() == 0:
    raise SystemExit("CUDA is not visible")
PY
fi

{
  echo "run_id=$RUN_ID"
  echo "started_at=$(date -Is)"
  echo "target_snrs=$TARGET_SNRS"
  echo "gpus=$GPUS"
  echo "ppl_device_map=$PPL_DEVICE_MAP"
  echo "ppl_max_memory=$PPL_MAX_MEMORY"
  echo "calibration_mode=$CALIBRATION_MODE"
  echo "sweep_root=$SWEEP_ROOT"
  echo "driver_root=$DRIVER_ROOT"
  echo "continue_on_error=$CONTINUE_ON_ERROR"
  echo "force=$FORCE"
  echo "dry_run=$DRY_RUN"
  echo "model_jobs=$MODEL_JOBS"
} > "$DRIVER_ROOT/run.env"

echo "[driver] run id: $RUN_ID"
echo "[driver] target SNRs: $TARGET_SNRS"
echo "[driver] GPUs: $GPUS"
echo "[driver] PPL device map: $PPL_DEVICE_MAP"
echo "[driver] calibration mode: $CALIBRATION_MODE"
echo "[driver] sweep root: $SWEEP_ROOT"
echo "[driver] logs: $DRIVER_ROOT"
echo "[driver] sample mode: full WikiText-2, no --limit-samples"
echo "[driver] schedule: sequential models from small to large; each PPL uses all GPUs"
echo "timestamp	model	target_snr_db	step	status	output	log" > "$STATUS_FILE"

failed=0
for job in $MODEL_JOBS; do
  IFS=':' read -r model_key model_path cache_dtype calib_batch calib_mx_chunk calib_chunk ppl_msd_chunk <<< "$job"
  cache_dtype="${cache_dtype:-float16}"
  calib_batch="${calib_batch:-4}"
  calib_mx_chunk="${calib_mx_chunk:-256}"
  calib_chunk="${calib_chunk:-64}"
  ppl_msd_chunk="${ppl_msd_chunk:-1536}"

  if [[ ! -d "$model_path" ]]; then
    echo "ERROR: [$model_key] model path not found: $model_path" >&2
    exit 2
  fi

  echo
  echo "================================================================"
  echo "Model        : $model_key"
  echo "Path         : $model_path"
  echo "Cache dtype  : $cache_dtype"
  echo "Calib profile: batch=$calib_batch mx_chunk_mib=$calib_mx_chunk cal_chunk_mib=$calib_chunk"
  echo "PPL profile  : gpus=$GPUS device_map=$PPL_DEVICE_MAP msd_chunk_mib=$ppl_msd_chunk"
  echo "================================================================"

  for snr in $TARGET_SNRS; do
    if ! prepare_calibration "$model_key" "$model_path" "$snr" "$calib_batch" "$calib_mx_chunk" "$calib_chunk"; then
      failed=1
      [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
      continue
    fi
    if ! run_ppl_stats "$model_key" "$model_path" "$snr" "$cache_dtype" "$ppl_msd_chunk"; then
      failed=1
      [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
    fi
  done

  write_summary
done

if [[ "$failed" != "0" && "$CONTINUE_ON_ERROR" != "1" ]]; then
  exit 1
fi

echo "[driver] complete"

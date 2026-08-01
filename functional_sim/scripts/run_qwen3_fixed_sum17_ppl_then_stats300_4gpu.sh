#!/usr/bin/env bash
# Fixed-sum 17 dB all-model run on GPUs 4-7:
#   1. prepare/reuse calibration artifacts;
#   2. run full WikiText-2 PPL with stats disabled using four-rank sharding;
#   3. run a sampled MSD-stat pass with --limit-samples=300.
#
# To detach:
#   BACKGROUND=1 functional_sim/scripts/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FUNCTIONAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$FUNCTIONAL_ROOT/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/fixed_sum17_ppl_stats300}"
CALIB_REUSE_ROOT="${CALIB_REUSE_ROOT:-../data/qwen3_final_experiments/fixed_sum17_full_stats}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
DRIVER_ROOT="${DRIVER_ROOT:-$SWEEP_ROOT/logs/ppl_stats300_${RUN_ID}}"
TARGET_SNRS="${TARGET_SNRS:-17}"
GPUS="${GPUS:-4,5,6,7}"
NPROC="${NPROC:-4}"
LOAD_STAGGER_SEC="${LOAD_STAGGER_SEC:-8}"
STATS_LIMIT_SAMPLES="${STATS_LIMIT_SAMPLES:-300}"
STATS_DEVICE_MAP="${STATS_DEVICE_MAP:-sequential}"
STATS_MAX_MEMORY="${STATS_MAX_MEMORY:-0:30GiB,1:30GiB,2:30GiB,3:30GiB}"
STATS_PROGRESS_INTERVAL_SEC="${STATS_PROGRESS_INTERVAL_SEC:-300}"
CALIBRATION_MODE="${CALIBRATION_MODE:-parallel}"
RUN_FULL_PPL="${RUN_FULL_PPL:-1}"
RUN_STATS_PPL="${RUN_STATS_PPL:-1}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
FORCE="${FORCE:-0}"
FORCE_CALIBRATION="${FORCE_CALIBRATION:-0}"
DRY_RUN="${DRY_RUN:-0}"

# key:model_path:full_cache_dtype:stats_cache_dtype:calib_batch:calib_mx_chunk_mib:calib_chunk_mib:stats_msd_chunk_mib[,retry...]
MODEL_JOBS="${MODEL_JOBS:-qwen0_6b:../Qwen3-0.6B:float16:float16:8:512:128:1536 qwen1_7b:../Qwen3-1.7B:float16:float16:4:384:96:1536 qwen4b:../Qwen3-4B:float16:float16:2:256:64:1536 qwen8b:../Qwen3-8B:float8:float8:4:256:64:768,512,384}"

if [[ "${BACKGROUND:-0}" == "1" && "${QWEN_FIXED_SUM17_PPL_STATS_CHILD:-0}" != "1" ]]; then
  mkdir -p "$DRIVER_ROOT"
  export QWEN_FIXED_SUM17_PPL_STATS_CHILD=1
  export PYTHON RUN_ID SWEEP_ROOT CALIB_REUSE_ROOT DRIVER_ROOT TARGET_SNRS GPUS NPROC LOAD_STAGGER_SEC
  export STATS_LIMIT_SAMPLES STATS_DEVICE_MAP STATS_MAX_MEMORY STATS_PROGRESS_INTERVAL_SEC
  export CALIBRATION_MODE RUN_FULL_PPL RUN_STATS_PPL CONTINUE_ON_ERROR FORCE FORCE_CALIBRATION DRY_RUN MODEL_JOBS
  nohup "$0" "$@" > "$DRIVER_ROOT/nohup.out" 2>&1 &
  echo "[launched] PID: $!"
  echo "[launched] driver log: $DRIVER_ROOT/driver.log"
  echo "[launched] nohup log : $DRIVER_ROOT/nohup.out"
  echo "[launched] ETA monitor: $PYTHON $SCRIPT_DIR/monitor_qwen3_sweep_eta.py --log-root $DRIVER_ROOT --watch 60"
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
  "$PYTHON" "$SCRIPT_DIR/summarize_qwen3_fixed_sum17_ppl_stats.py" \
    --root "$SWEEP_ROOT" \
    --models "$(model_keys_arg)" \
    --target-snrs "$TARGET_SNRS" \
    --stats-limit "$STATS_LIMIT_SAMPLES" \
    --output-dir "$DRIVER_ROOT" || true
  SUMMARY_WRITTEN=1
}

finish() {
  local status=$?
  write_summary
  {
    echo "finished_at=$(date -Is)"
    echo "exit_status=$status"
    echo "run_id=$RUN_ID"
    echo "target_snrs=$TARGET_SNRS"
    echo "gpus=$GPUS"
    echo "nproc=$NPROC"
    echo "stats_limit_samples=$STATS_LIMIT_SAMPLES"
    echo "stats_device_map=$STATS_DEVICE_MAP"
    echo "stats_max_memory=$STATS_MAX_MEMORY"
    echo "calibration_mode=$CALIBRATION_MODE"
    echo "run_full_ppl=$RUN_FULL_PPL"
    echo "run_stats_ppl=$RUN_STATS_PPL"
    echo "sweep_root=$SWEEP_ROOT"
    echo "calib_reuse_root=$CALIB_REUSE_ROOT"
    echo "driver_root=$DRIVER_ROOT"
    echo "summary_tsv=$DRIVER_ROOT/fixed_sum17_ppl_stats_summary.tsv"
    echo "summary_json=$DRIVER_ROOT/fixed_sum17_ppl_stats_summary.json"
    echo "status_tsv=$STATUS_FILE"
  } > "$DRIVER_ROOT/final_status.txt"
  echo "[driver] final status written to $DRIVER_ROOT/final_status.txt"
}
trap finish EXIT

record_status() {
  local model_key="$1"
  local snr="$2"
  local phase="$3"
  local step="$4"
  local status="$5"
  local output="$6"
  local log="$7"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$model_key" "$snr" "$phase" "$step" "$status" "$output" "$log" >> "$STATUS_FILE"
}

artifact_complete() {
  local path="$1"
  [[ -s "$path" ]] || return 1
  if [[ "$path" == *.json ]]; then
    "$PYTHON" - "$path" >/dev/null 2>&1 <<'PY' || return 1
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    json.load(f)
PY
  fi
}

snr_label() {
  local snr="$1"
  printf 'snr%sdb' "${snr//./p}"
}

gpu_by_index() {
  local index="$1"
  IFS=',' read -r -a gpu_list <<< "$GPUS"
  local count="${#gpu_list[@]}"
  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: GPUS is empty" >&2
    return 2
  fi
  printf '%s' "${gpu_list[$((index % count))]}"
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

adopt_existing_calibration() {
  local model_key="$1"
  local snr="$2"
  local label="$3"
  local cal_dir="$SWEEP_ROOT/$model_key/$label/calib"
  local final_json="$cal_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local reuse_dir="$CALIB_REUSE_ROOT/$model_key/$label/calib"
  local reuse_final="$reuse_dir/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local log="$DRIVER_ROOT/$model_key/calib/$label/adopt_existing_calibration.log"

  if [[ "$FORCE_CALIBRATION" == "1" || "$FORCE" == "1" ]]; then
    return 1
  fi
  if artifact_complete "$final_json"; then
    record_status "$model_key" "$snr" "calibration" "fixed_sum" "skipped_existing" "$final_json" "$log"
    return 0
  fi
  if ! artifact_complete "$reuse_final"; then
    return 1
  fi

  mkdir -p "$cal_dir" "$(dirname "$log")"
  cp "$reuse_dir"/calibration_MXFP8_fixed_sum_"$model_key"_"$label"*.json "$cal_dir"/
  {
    echo "adopted_at=$(date -Is)"
    echo "from=$reuse_dir"
    echo "to=$cal_dir"
  } > "$log"
  record_status "$model_key" "$snr" "calibration" "fixed_sum" "adopted_existing" "$final_json" "$log"
  return 0
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

  if [[ "$FORCE_CALIBRATION" != "1" && "$FORCE" != "1" ]] && artifact_complete "$partial"; then
    echo "[driver][$model_key/$snr/$suffix] calibration exists; skipping: $partial"
    record_status "$model_key" "$snr" "calibration" "fixed_sum_${suffix}" "skipped_existing" "$partial" "$log"
    return 0
  fi

  mkdir -p "$cal_dir" "$log_dir"
  echo "[driver][$model_key/$snr/$suffix] start calibration on GPU $gpu; log: $log"
  printf '[%s] command:' "$(date -Is)" > "$log"
  printf ' %q' env "CUDA_VISIBLE_DEVICES=$gpu" "$PYTHON" "$FUNCTIONAL_ROOT/calibrate.py" \
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
  record_status "$model_key" "$snr" "calibration" "fixed_sum_${suffix}" "started" "$partial" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    record_status "$model_key" "$snr" "calibration" "fixed_sum_${suffix}" "dry_run" "$partial" "$log"
    return 0
  fi

  if env CUDA_VISIBLE_DEVICES="$gpu" "$PYTHON" "$FUNCTIONAL_ROOT/calibrate.py" \
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
    record_status "$model_key" "$snr" "calibration" "fixed_sum_${suffix}" "completed" "$partial" "$log"
  else
    local status=$?
    record_status "$model_key" "$snr" "calibration" "fixed_sum_${suffix}" "failed:$status" "$partial" "$log"
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
      run_calibration_task "$model_key" "$model_path" "$snr" "$label" "$suffix" "$projection_filter" "$gpu" "$calib_batch" "$calib_mx_chunk" "$calib_chunk"
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

  if adopt_existing_calibration "$model_key" "$snr" "$label"; then
    return 0
  fi
  if [[ "$FORCE_CALIBRATION" != "1" && "$FORCE" != "1" ]] && artifact_complete "$final_json"; then
    record_status "$model_key" "$snr" "calibration" "fixed_sum" "skipped_existing" "$final_json" "$merge_log"
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
  printf ' %q' "$PYTHON" "$FUNCTIONAL_ROOT/tools/merge_msd_calibrations.py" "${inputs[@]}" --output "$final_json" | tee -a "$merge_log"
  printf '\n' | tee -a "$merge_log"
  record_status "$model_key" "$snr" "calibration" "fixed_sum" "started" "$final_json" "$merge_log"

  if [[ "$DRY_RUN" == "1" ]]; then
    record_status "$model_key" "$snr" "calibration" "fixed_sum" "dry_run" "$final_json" "$merge_log"
    return 0
  fi

  if "$PYTHON" "$FUNCTIONAL_ROOT/tools/merge_msd_calibrations.py" "${inputs[@]}" --output "$final_json" >> "$merge_log" 2>&1; then
    record_status "$model_key" "$snr" "calibration" "fixed_sum" "completed" "$final_json" "$merge_log"
  else
    local status=$?
    record_status "$model_key" "$snr" "calibration" "fixed_sum" "failed:$status" "$final_json" "$merge_log"
    return "$status"
  fi
}

run_logged_step() {
  local model_key="$1"
  local snr="$2"
  local phase="$3"
  local step="$4"
  local output="$5"
  local log="$6"
  shift 6

  if [[ "$FORCE" != "1" ]] && artifact_complete "$output"; then
    echo "[driver][$model_key/$snr/$step] output exists; skipping: $output"
    record_status "$model_key" "$snr" "$phase" "$step" "skipped_existing" "$output" "$log"
    return 0
  fi

  mkdir -p "$(dirname "$output")" "$(dirname "$log")"
  printf '[%s] start %s/%s/%s\n' "$(date -Is)" "$model_key" "$snr" "$step" | tee "$log"
  printf '[%s] command:' "$(date -Is)" | tee -a "$log"
  printf ' %q' "$@" | tee -a "$log"
  printf '\n' | tee -a "$log"
  record_status "$model_key" "$snr" "$phase" "$step" "started" "$output" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    record_status "$model_key" "$snr" "$phase" "$step" "dry_run" "$output" "$log"
    return 0
  fi

  set +e
  "$@" 2>&1 | tee -a "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    record_status "$model_key" "$snr" "$phase" "$step" "failed:$status" "$output" "$log"
    return "$status"
  fi
  if ! artifact_complete "$output"; then
    record_status "$model_key" "$snr" "$phase" "$step" "missing_output" "$output" "$log"
    return 2
  fi
  record_status "$model_key" "$snr" "$phase" "$step" "completed" "$output" "$log"
}

run_full_ppl() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local cache_dtype="$4"
  local label
  label="$(snr_label "$snr")"
  local cal="$SWEEP_ROOT/$model_key/$label/calib/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local out="$SWEEP_ROOT/$model_key/$label/ppl/full_no_stats/ppl_results_MXFP8_fixed_sum_${model_key}_${label}_full_no_stats.json"
  local log="$DRIVER_ROOT/$model_key/ppl/$label/full_no_stats.log"

  if ! artifact_complete "$cal" && [[ "$DRY_RUN" != "1" ]]; then
    record_status "$model_key" "$snr" "full_ppl" "full_no_stats" "missing_calibration" "$out" "$log"
    return 2
  fi

  run_logged_step "$model_key" "$snr" "full_ppl" "full_no_stats" "$out" "$log" \
    env CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" "$FUNCTIONAL_ROOT/ppltest.py" \
      --model-path "$model_path" \
      --setup 6 \
      --calibration "$cal" \
      --nproc "$NPROC" \
      --gpus "$GPUS" \
      --stats off \
      --compile-msd-truncate \
      --weight-cache-dtype "$cache_dtype" \
      --load-stagger-sec "$LOAD_STAGGER_SEC" \
      --mxfp-progress-interval-sec -1 \
      --output "$out"
}

run_stats_ppl() {
  local model_key="$1"
  local model_path="$2"
  local snr="$3"
  local cache_dtype="$4"
  local stats_msd_chunks="$5"
  local label
  label="$(snr_label "$snr")"
  local cal="$SWEEP_ROOT/$model_key/$label/calib/calibration_MXFP8_fixed_sum_${model_key}_${label}.json"
  local out="$SWEEP_ROOT/$model_key/$label/ppl/stats_limit${STATS_LIMIT_SAMPLES}/ppl_results_MXFP8_fixed_sum_${model_key}_${label}_stats_limit${STATS_LIMIT_SAMPLES}.json"
  local missing_log="$DRIVER_ROOT/$model_key/ppl/$label/stats_limit${STATS_LIMIT_SAMPLES}_missing_calibration.log"
  local device_map_args=(--device-map "$STATS_DEVICE_MAP")

  if [[ "$STATS_DEVICE_MAP" != "none" && -n "$STATS_MAX_MEMORY" ]]; then
    device_map_args+=(--max-memory "$STATS_MAX_MEMORY")
  fi
  if ! artifact_complete "$cal" && [[ "$DRY_RUN" != "1" ]]; then
    record_status "$model_key" "$snr" "stats_limit" "stats_limit${STATS_LIMIT_SAMPLES}" "missing_calibration" "$out" "$missing_log"
    return 2
  fi

  local chunk_candidates
  chunk_candidates="${stats_msd_chunks//,/ }"
  local chunk
  local failed=0
  for chunk in $chunk_candidates; do
    local step="stats_limit${STATS_LIMIT_SAMPLES}_chunk${chunk}"
    local log="$DRIVER_ROOT/$model_key/ppl/$label/${step}.log"
    if run_logged_step "$model_key" "$snr" "stats_limit" "$step" "$out" "$log" \
      env CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" "$FUNCTIONAL_ROOT/ppltest.py" \
        --model-path "$model_path" \
        --setup 6 \
        --calibration "$cal" \
        --limit-samples "$STATS_LIMIT_SAMPLES" \
        --stats lite \
        --figure5-layer-cycles \
        "${device_map_args[@]}" \
        --mx-chunk-target-mib 256 \
        --msd-chunk-target-mib "$chunk" \
        --weight-cache-dtype "$cache_dtype" \
        --compile-msd-truncate \
        --gpus "$GPUS" \
        --mxfp-progress-interval-sec "$STATS_PROGRESS_INTERVAL_SEC" \
        --output "$out"; then
      return 0
    fi
    failed=1
    if artifact_complete "$out"; then
      return 0
    fi
    echo "[driver][$model_key/$snr/stats] chunk $chunk failed; trying next chunk if available"
  done
  return "$failed"
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
  echo "nproc=$NPROC"
  echo "load_stagger_sec=$LOAD_STAGGER_SEC"
  echo "stats_limit_samples=$STATS_LIMIT_SAMPLES"
  echo "stats_device_map=$STATS_DEVICE_MAP"
  echo "stats_max_memory=$STATS_MAX_MEMORY"
  echo "stats_progress_interval_sec=$STATS_PROGRESS_INTERVAL_SEC"
  echo "calibration_mode=$CALIBRATION_MODE"
  echo "run_full_ppl=$RUN_FULL_PPL"
  echo "run_stats_ppl=$RUN_STATS_PPL"
  echo "sweep_root=$SWEEP_ROOT"
  echo "calib_reuse_root=$CALIB_REUSE_ROOT"
  echo "driver_root=$DRIVER_ROOT"
  echo "continue_on_error=$CONTINUE_ON_ERROR"
  echo "force=$FORCE"
  echo "force_calibration=$FORCE_CALIBRATION"
  echo "dry_run=$DRY_RUN"
  echo "model_jobs=$MODEL_JOBS"
} > "$DRIVER_ROOT/run.env"

echo "[driver] run id: $RUN_ID"
echo "[driver] target SNRs: $TARGET_SNRS"
echo "[driver] GPUs: $GPUS"
echo "[driver] full PPL: enabled=$RUN_FULL_PPL nproc=$NPROC stats=off"
echo "[driver] stats PPL: enabled=$RUN_STATS_PPL limit=$STATS_LIMIT_SAMPLES device_map=$STATS_DEVICE_MAP"
echo "[driver] calibration mode: $CALIBRATION_MODE"
echo "[driver] sweep root: $SWEEP_ROOT"
echo "[driver] calibration reuse root: $CALIB_REUSE_ROOT"
echo "[driver] logs: $DRIVER_ROOT"
echo "timestamp	model	target_snr_db	phase	step	status	output	log" > "$STATUS_FILE"

failed=0
for job in $MODEL_JOBS; do
  IFS=':' read -r model_key model_path full_cache_dtype stats_cache_dtype calib_batch calib_mx_chunk calib_chunk stats_msd_chunk <<< "$job"
  full_cache_dtype="${full_cache_dtype:-float16}"
  stats_cache_dtype="${stats_cache_dtype:-$full_cache_dtype}"
  calib_batch="${calib_batch:-4}"
  calib_mx_chunk="${calib_mx_chunk:-256}"
  calib_chunk="${calib_chunk:-64}"
  stats_msd_chunk="${stats_msd_chunk:-1536}"

  if [[ ! -d "$model_path" ]]; then
    echo "ERROR: [$model_key] model path not found: $model_path" >&2
    exit 2
  fi

  echo
  echo "================================================================"
  echo "Model        : $model_key"
  echo "Path         : $model_path"
  echo "Full PPL     : nproc=$NPROC cache=$full_cache_dtype stats=off"
  echo "Stats PPL    : limit=$STATS_LIMIT_SAMPLES cache=$stats_cache_dtype msd_chunk_mib=$stats_msd_chunk"
  echo "Calib profile: batch=$calib_batch mx_chunk_mib=$calib_mx_chunk cal_chunk_mib=$calib_chunk"
  echo "================================================================"

  for snr in $TARGET_SNRS; do
    if ! prepare_calibration "$model_key" "$model_path" "$snr" "$calib_batch" "$calib_mx_chunk" "$calib_chunk"; then
      failed=1
      [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
      continue
    fi
    if [[ "$RUN_FULL_PPL" == "1" ]]; then
      if ! run_full_ppl "$model_key" "$model_path" "$snr" "$full_cache_dtype"; then
        failed=1
        [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
        continue
      fi
    else
      record_status "$model_key" "$snr" "full_ppl" "full_no_stats" "skipped_disabled" "" ""
    fi
    if [[ "$RUN_STATS_PPL" == "1" ]]; then
      if ! run_stats_ppl "$model_key" "$model_path" "$snr" "$stats_cache_dtype" "$stats_msd_chunk"; then
        failed=1
        [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
      fi
    else
      record_status "$model_key" "$snr" "stats_limit" "stats_limit${STATS_LIMIT_SAMPLES}" "skipped_disabled" "" ""
    fi
  done

  write_summary
done

if [[ "$failed" != "0" && "$CONTINUE_ON_ERROR" != "1" ]]; then
  exit 1
fi

echo "[driver] complete"

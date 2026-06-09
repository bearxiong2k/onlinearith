#!/usr/bin/env bash
# Sampled rebuttal work/quality sweep on GPUs 4-7:
#   - fixed-sum MSD target-SNR points with --limit-samples=300 stats;
#   - WANDA common N:M keep-ratio points with --limit-samples=300 PPL;
#   - activation common N:M keep-ratio points with --limit-samples=300 PPL.
#
# To detach:
#   BACKGROUND=1 scripts/run_qwen3_sparsity_norm_sweep300_4gpu.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/sparsity_norm_sweep300}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
LOG_ROOT="${LOG_ROOT:-$SWEEP_ROOT/logs/sweep300_${RUN_ID}}"
STATUS_FILE="${STATUS_FILE:-$LOG_ROOT/status.tsv}"
GPUS="${GPUS:-4,5,6,7}"
NPROC="${NPROC:-4}"
ARTIFACT_GPU="${ARTIFACT_GPU:-4}"
ARTIFACT_GPUS="${ARTIFACT_GPUS:-$GPUS}"
LOAD_STAGGER_SEC="${LOAD_STAGGER_SEC:-8}"
LIMIT_SAMPLES="${LIMIT_SAMPLES:-300}"
TARGET_SNRS="${TARGET_SNRS:-15 17 20}"
NM_POINTS="${NM_POINTS:-1:4 2:4 3:4}"
RUN_FIXED_SUM="${RUN_FIXED_SUM:-1}"
RUN_WANDA="${RUN_WANDA:-1}"
RUN_WANDA_CALIBRATION="${RUN_WANDA_CALIBRATION:-1}"
RUN_ACT="${RUN_ACT:-1}"
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"

# key:model_path:cache_dtype. The default is the rebuttal-oriented larger-model
# set; Qwen3-0.6B is already covered by the paper figure.
MODEL_SPECS="${MODEL_SPECS:-qwen8b:../Qwen3-8B:float8 qwen4b:../Qwen3-4B:float16 qwen1_7b:../Qwen3-1.7B:float16}"

FIXED_DRIVER="$SCRIPT_DIR/run_qwen3_fixed_sum17_ppl_then_stats300_4gpu.sh"
FIXED_ROOT="$SWEEP_ROOT/fixed_sum"
FIXED_LOG_ROOT="$LOG_ROOT/fixed_sum"
# Ordered best-effort fixed-sum phases. Syntax: model_key@comma_separated_snrs.
# The defaults spend the first budget on the larger-model core 17 dB point,
# then add adjacent norm points if time remains.
FIXED_SUM_PHASES="${FIXED_SUM_PHASES:-qwen8b@17 qwen4b@17 qwen1_7b@17 qwen4b@15,20 qwen1_7b@15,20}"
FIXED_MSD_CHUNKS="${FIXED_MSD_CHUNKS:-768,512,384}"
FIXED_STATS_DEVICE_MAP="${FIXED_STATS_DEVICE_MAP:-sequential}"
FIXED_STATS_MAX_MEMORY="${FIXED_STATS_MAX_MEMORY:-0:30GiB,1:30GiB,2:30GiB,3:30GiB}"
FIXED_STATS_PROGRESS_INTERVAL_SEC="${FIXED_STATS_PROGRESS_INTERVAL_SEC:-300}"

WANDA_NUM_TEXTS="${WANDA_NUM_TEXTS:-2048}"
WANDA_MAX_LENGTH="${WANDA_MAX_LENGTH:-512}"
WANDA_BATCH_SIZE="${WANDA_BATCH_SIZE:-4}"
WANDA_MX_CHUNK_MIB="${WANDA_MX_CHUNK_MIB:-256}"
BASELINE_MX_CHUNK_MIB="${BASELINE_MX_CHUNK_MIB:-256}"
BASELINE_PROGRESS_INTERVAL_SEC="${BASELINE_PROGRESS_INTERVAL_SEC:-120}"

if [[ "${BACKGROUND:-0}" == "1" && "${QWEN_SPARSITY_NORM_SWEEP_CHILD:-0}" != "1" ]]; then
  mkdir -p "$LOG_ROOT"
  export QWEN_SPARSITY_NORM_SWEEP_CHILD=1
  export PYTHON SWEEP_ROOT RUN_ID LOG_ROOT STATUS_FILE GPUS NPROC ARTIFACT_GPU ARTIFACT_GPUS LOAD_STAGGER_SEC LIMIT_SAMPLES
  export TARGET_SNRS NM_POINTS RUN_FIXED_SUM RUN_WANDA RUN_WANDA_CALIBRATION RUN_ACT CONTINUE_ON_ERROR FORCE DRY_RUN MODEL_SPECS
  export FIXED_SUM_PHASES FIXED_MSD_CHUNKS FIXED_STATS_DEVICE_MAP FIXED_STATS_MAX_MEMORY FIXED_STATS_PROGRESS_INTERVAL_SEC
  export WANDA_NUM_TEXTS WANDA_MAX_LENGTH WANDA_BATCH_SIZE WANDA_MX_CHUNK_MIB BASELINE_MX_CHUNK_MIB
  export BASELINE_PROGRESS_INTERVAL_SEC
  nohup "$0" "$@" > "$LOG_ROOT/nohup.out" 2>&1 &
  echo "[launched] PID: $!"
  echo "[launched] driver log: $LOG_ROOT/driver.log"
  echo "[launched] nohup log : $LOG_ROOT/nohup.out"
  echo "[launched] ETA monitor: $PYTHON scripts/monitor_qwen3_sweep_eta.py --log-root $LOG_ROOT --watch 60"
  exit 0
fi

mkdir -p "$LOG_ROOT"
exec > >(tee -a "$LOG_ROOT/driver.log") 2>&1

model_keys_arg() {
  local spec
  for spec in $MODEL_SPECS; do
    printf '%s\n' "${spec%%:*}"
  done | xargs
}

fixed_model_jobs_arg() {
  local spec model_key model_path cache_dtype
  for spec in $MODEL_SPECS; do
    IFS=':' read -r model_key model_path cache_dtype <<< "$spec"
    cache_dtype="${cache_dtype:-float16}"
    if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
      printf '%s:%s:%s:%s:4:256:64:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
    elif [[ "$model_key" == "qwen4b" ]]; then
      printf '%s:%s:%s:%s:2:256:64:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
    elif [[ "$model_key" == "qwen1_7b" ]]; then
      printf '%s:%s:%s:%s:4:384:96:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
    else
      printf '%s:%s:%s:%s:8:512:128:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
    fi
  done | xargs
}

model_spec_by_key() {
  local wanted="$1"
  local spec model_key
  for spec in $MODEL_SPECS; do
    model_key="${spec%%:*}"
    if [[ "$model_key" == "$wanted" ]]; then
      printf '%s\n' "$spec"
      return 0
    fi
  done
  return 1
}

fixed_model_job_for_spec() {
  local spec="$1"
  local model_key model_path cache_dtype
  IFS=':' read -r model_key model_path cache_dtype <<< "$spec"
  cache_dtype="${cache_dtype:-float16}"
  if [[ "$model_key" == "qwen8b" || "$model_key" == "qwen8b_final" ]]; then
    printf '%s:%s:%s:%s:4:256:64:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
  elif [[ "$model_key" == "qwen4b" ]]; then
    printf '%s:%s:%s:%s:2:256:64:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
  elif [[ "$model_key" == "qwen1_7b" ]]; then
    printf '%s:%s:%s:%s:4:384:96:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
  else
    printf '%s:%s:%s:%s:8:512:128:%s\n' "$model_key" "$model_path" "$cache_dtype" "$cache_dtype" "$FIXED_MSD_CHUNKS"
  fi
}

record_status() {
  local phase="$1"
  local model_key="$2"
  local point="$3"
  local step="$4"
  local status="$5"
  local output="$6"
  local log="$7"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -Is)" "$phase" "$model_key" "$point" "$step" "$status" "$output" "$log" >> "$STATUS_FILE"
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

parse_nm() {
  local token="$1"
  if [[ "$token" != *:* ]]; then
    echo "ERROR: invalid N:M token: $token" >&2
    return 2
  fi
  local n="${token%%:*}"
  local m="${token#*:}"
  if [[ -z "$n" || -z "$m" || "$m" -le 0 || "$n" -lt 0 || "$n" -gt "$m" ]]; then
    echo "ERROR: invalid N:M token: $token" >&2
    return 2
  fi
  printf '%s %s\n' "$n" "$m"
}

artifact_gpu_count() {
  local gpus="${ARTIFACT_GPUS//,/ }"
  local count=0
  local gpu
  for gpu in $gpus; do
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

artifact_gpu_by_index() {
  local index="$1"
  IFS=',' read -r -a gpu_list <<< "$ARTIFACT_GPUS"
  local count="${#gpu_list[@]}"
  if [[ "$count" -eq 0 ]]; then
    echo "ERROR: ARTIFACT_GPUS is empty" >&2
    return 2
  fi
  printf '%s\n' "${gpu_list[$((index % count))]}"
}

run_logged() {
  local phase="$1"
  local model_key="$2"
  local point="$3"
  local step="$4"
  local output="$5"
  local log="$6"
  shift 6

  if [[ "$FORCE" != "1" ]] && artifact_complete "$output"; then
    echo "[$phase/$model_key/$point/$step] exists; skipping: $output"
    record_status "$phase" "$model_key" "$point" "$step" "skipped_existing" "$output" "$log"
    return 0
  fi

  mkdir -p "$(dirname "$output")" "$(dirname "$log")"
  printf '[%s] start %s/%s/%s/%s\n' "$(date -Is)" "$phase" "$model_key" "$point" "$step" | tee "$log"
  printf '[%s] command:' "$(date -Is)" | tee -a "$log"
  printf ' %q' "$@" | tee -a "$log"
  printf '\n' | tee -a "$log"
  record_status "$phase" "$model_key" "$point" "$step" "started" "$output" "$log"

  if [[ "$DRY_RUN" == "1" ]]; then
    record_status "$phase" "$model_key" "$point" "$step" "dry_run" "$output" "$log"
    return 0
  fi

  set +e
  "$@" 2>&1 | tee -a "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    record_status "$phase" "$model_key" "$point" "$step" "failed:$status" "$output" "$log"
    return "$status"
  fi
  if ! artifact_complete "$output"; then
    record_status "$phase" "$model_key" "$point" "$step" "missing_output" "$output" "$log"
    return 2
  fi
  record_status "$phase" "$model_key" "$point" "$step" "completed" "$output" "$log"
}

run_fixed_sum_phase() {
  mkdir -p "$FIXED_LOG_ROOT"
  local failed=0
  local index=0
  local max_jobs
  max_jobs="$(artifact_gpu_count)"
  local pids=()
  local names=()
  local phase model_key snrs_csv snrs spec job phase_label phase_log_root log status gpu

  wait_fixed_batch() {
    local i status
    for i in "${!pids[@]}"; do
      if wait "${pids[$i]}"; then
        echo "[fixed_sum] completed ${names[$i]}"
      else
        status=$?
        echo "[fixed_sum] FAILED ${names[$i]} exit=$status" >&2
        failed=1
      fi
    done
    pids=()
    names=()
  }

  for phase in $FIXED_SUM_PHASES; do
    if [[ "$phase" != *@* ]]; then
      echo "ERROR: invalid FIXED_SUM_PHASES entry: $phase (expected model@snr[,snr])" >&2
      return 2
    fi
    model_key="${phase%@*}"
    snrs_csv="${phase#*@}"
    snrs="${snrs_csv//,/ }"
    if ! spec="$(model_spec_by_key "$model_key")"; then
      echo "[fixed_sum] skipping phase for model not in MODEL_SPECS: $model_key"
      record_status fixed_sum "$model_key" "$snrs_csv" driver skipped_model_not_selected "" ""
      continue
    fi
    job="$(fixed_model_job_for_spec "$spec")"
    phase_label="$(printf '%02d_%s_%s' "$index" "$model_key" "${snrs_csv//,/p}")"
    phase_log_root="$FIXED_LOG_ROOT/$phase_label"
    log="$phase_log_root/driver.log"
    gpu="$(artifact_gpu_by_index "$index")"
    mkdir -p "$phase_log_root"
    record_status fixed_sum "$model_key" "$snrs_csv" driver started "$FIXED_ROOT/$model_key" "$log"

    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[fixed_sum] DRY_RUN=1; would launch $model_key snrs=$snrs on GPU $gpu through $FIXED_DRIVER"
      record_status fixed_sum "$model_key" "$snrs_csv" driver dry_run "$FIXED_ROOT/$model_key" "$log"
      index=$((index + 1))
      continue
    fi

    echo "[fixed_sum] launch $model_key snrs=$snrs on GPU $gpu"
    (
      set +e
      RUN_FULL_PPL=0 \
      RUN_STATS_PPL=1 \
      SWEEP_ROOT="$FIXED_ROOT" \
      DRIVER_ROOT="$phase_log_root" \
      TARGET_SNRS="$snrs" \
      STATS_LIMIT_SAMPLES="$LIMIT_SAMPLES" \
      STATS_DEVICE_MAP=none \
      STATS_MAX_MEMORY="" \
      STATS_PROGRESS_INTERVAL_SEC="$FIXED_STATS_PROGRESS_INTERVAL_SEC" \
      GPUS="$gpu" \
      NPROC=1 \
      LOAD_STAGGER_SEC=0 \
      CALIBRATION_MODE=serial \
      MODEL_JOBS="$job" \
      CONTINUE_ON_ERROR="$CONTINUE_ON_ERROR" \
      FORCE="$FORCE" \
      "$FIXED_DRIVER"
      status=$?
      if [[ "$status" -eq 0 ]]; then
        record_status fixed_sum "$model_key" "$snrs_csv" driver completed "$FIXED_ROOT/$model_key" "$log"
      else
        record_status fixed_sum "$model_key" "$snrs_csv" driver "failed:$status" "$FIXED_ROOT/$model_key" "$log"
      fi
      exit "$status"
    ) &
    pids+=("$!")
    names+=("$model_key@$snrs_csv/gpu$gpu")

    index=$((index + 1))
    if [[ "${#pids[@]}" -ge "$max_jobs" ]]; then
      wait_fixed_batch
      [[ "$failed" == "0" || "$CONTINUE_ON_ERROR" == "1" ]] || return 1
    fi
  done

  if [[ "${#pids[@]}" -gt 0 ]]; then
    wait_fixed_batch
  fi
  return "$failed"
}

run_wanda_calibration_point() {
  local model_key="$1"
  local model_path="$2"
  local n="$3"
  local m="$4"
  local gpu="$5"
  local point="${n}:${m}"
  local nm_dir="${n}-${m}"
  local root="$SWEEP_ROOT/baselines/$model_key/wanda_base"
  local hook="${model_key}_sweep300"
  local mask="$root/$nm_dir/calibration_base_MXFP8_${hook}.pt"
  local log_dir="$LOG_ROOT/baselines/$model_key/wanda/$nm_dir"

  run_logged wanda "$model_key" "$point" calibration "$mask" "$log_dir/calibration.log" \
    env CUDA_VISIBLE_DEVICES="$gpu" "$PYTHON" wanda_base/calibrate_base.py \
      --model-path "$model_path" \
      --only 1 \
      -n "$n" \
      -m "$m" \
      --num-texts "$WANDA_NUM_TEXTS" \
      --max-length "$WANDA_MAX_LENGTH" \
      --batch-size "$WANDA_BATCH_SIZE" \
      --results-root "$root" \
      --output-hook "$hook" \
      --mx-chunk-target-mib "$WANDA_MX_CHUNK_MIB" \
      --weight-cache-dtype none \
      --gpus "$gpu" || return $?
}

run_wanda_ppl_point() {
  local model_key="$1"
  local model_path="$2"
  local cache_dtype="$3"
  local n="$4"
  local m="$5"
  local point="${n}:${m}"
  local nm_dir="${n}-${m}"
  local root="$SWEEP_ROOT/baselines/$model_key/wanda_base"
  local hook="${model_key}_sweep300"
  local out="$root/$nm_dir/ppl_results_MXFP8_${hook}.json"
  local log_dir="$LOG_ROOT/baselines/$model_key/wanda/$nm_dir"

  run_logged wanda "$model_key" "$point" ppl_limit "$out" "$log_dir/ppl_limit${LIMIT_SAMPLES}.log" \
    env CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" wanda_base/ppl_batch_base.py \
      --model-path "$model_path" \
      --only 1 \
      -n "$n" \
      -m "$m" \
      --limit-samples "$LIMIT_SAMPLES" \
      --window-shard \
      --nproc "$NPROC" \
      --gpus "$GPUS" \
      --load-stagger-sec "$LOAD_STAGGER_SEC" \
      --results-root "$root" \
      --output-hook "$hook" \
      --mx-chunk-target-mib "$BASELINE_MX_CHUNK_MIB" \
      --weight-cache-dtype "$cache_dtype" \
      --mxfp-progress-interval-sec "$BASELINE_PROGRESS_INTERVAL_SEC" \
      --mxfp-progress-file "$log_dir/progress.json" || return $?
}

run_wanda_point() {
  local model_key="$1"
  local model_path="$2"
  local cache_dtype="$3"
  local n="$4"
  local m="$5"

  if [[ "$RUN_WANDA_CALIBRATION" == "1" ]]; then
    run_wanda_calibration_point "$model_key" "$model_path" "$n" "$m" "$ARTIFACT_GPU" || return $?
  fi
  run_wanda_ppl_point "$model_key" "$model_path" "$cache_dtype" "$n" "$m" || return $?
}

prepare_wanda_masks_parallel() {
  [[ "$RUN_WANDA" == "1" && "$RUN_WANDA_CALIBRATION" == "1" ]] || return 0

  local max_jobs
  max_jobs="$(artifact_gpu_count)"
  if [[ "$max_jobs" -le 0 ]]; then
    echo "ERROR: ARTIFACT_GPUS is empty" >&2
    return 2
  fi

  echo
  echo "================================================================"
  echo "WANDA mask preparation"
  echo "Artifact GPUs : $ARTIFACT_GPUS"
  echo "Parallel jobs  : $max_jobs"
  echo "N:M points     : $NM_POINTS"
  echo "================================================================"

  local pids=()
  local names=()
  local idx=0
  local failed=0
  local spec model_key model_path cache_dtype nm n m gpu

  wait_batch() {
    local i status
    for i in "${!pids[@]}"; do
      if wait "${pids[$i]}"; then
        echo "[wanda/calibration] completed ${names[$i]}"
      else
        status=$?
        echo "[wanda/calibration] FAILED ${names[$i]} exit=$status" >&2
        failed=1
      fi
    done
    pids=()
    names=()
  }

  for spec in $MODEL_SPECS; do
    IFS=':' read -r model_key model_path cache_dtype <<< "$spec"
    if [[ -z "$model_key" || -z "$model_path" || ! -d "$model_path" ]]; then
      echo "ERROR: invalid or missing model spec during WANDA prep: $spec" >&2
      return 2
    fi
    for nm in $NM_POINTS; do
      read -r n m < <(parse_nm "$nm")
      gpu="$(artifact_gpu_by_index "$idx")"
      echo "[wanda/calibration] launch $model_key $nm on GPU $gpu"
      run_wanda_calibration_point "$model_key" "$model_path" "$n" "$m" "$gpu" &
      pids+=("$!")
      names+=("$model_key/$nm/gpu$gpu")
      idx=$((idx + 1))
      if [[ "${#pids[@]}" -ge "$max_jobs" ]]; then
        wait_batch
        [[ "$failed" == "0" || "$CONTINUE_ON_ERROR" == "1" ]] || return 1
      fi
    done
  done

  if [[ "${#pids[@]}" -gt 0 ]]; then
    wait_batch
  fi
  [[ "$failed" == "0" || "$CONTINUE_ON_ERROR" == "1" ]]
}

run_act_point() {
  local model_key="$1"
  local model_path="$2"
  local cache_dtype="$3"
  local n="$4"
  local m="$5"
  local point="${n}:${m}"
  local nm_dir="${n}-${m}"
  local root="$SWEEP_ROOT/baselines/$model_key/act_base"
  local out="$root/$nm_dir/ppl_results_MXFP8.json"
  local log_dir="$LOG_ROOT/baselines/$model_key/act/$nm_dir"

  run_logged act "$model_key" "$point" ppl_limit "$out" "$log_dir/ppl_limit${LIMIT_SAMPLES}.log" \
    env CUDA_VISIBLE_DEVICES="$GPUS" "$PYTHON" act_base/ppl_batch_base_act.py \
      --model-path "$model_path" \
      --only 1 \
      -n "$n" \
      -m "$m" \
      --limit-samples "$LIMIT_SAMPLES" \
      --window-shard \
      --nproc "$NPROC" \
      --gpus "$GPUS" \
      --load-stagger-sec "$LOAD_STAGGER_SEC" \
      --results-root "$root" \
      --mx-chunk-target-mib "$BASELINE_MX_CHUNK_MIB" \
      --weight-cache-dtype "$cache_dtype" \
      --mxfp-progress-interval-sec "$BASELINE_PROGRESS_INTERVAL_SEC" \
      --mxfp-progress-file "$log_dir/progress.json" || return $?
}

write_summary() {
  "$PYTHON" scripts/summarize_qwen3_sparsity_norm_sweep300.py \
    --root "$SWEEP_ROOT" \
    --models "$(model_keys_arg)" \
    --target-snrs "$TARGET_SNRS" \
    --nm "$NM_POINTS" \
    --limit-samples "$LIMIT_SAMPLES" \
    --output-dir "$LOG_ROOT/summary" || true
}

finish() {
  local status=$?
  write_summary
  {
    echo "finished_at=$(date -Is)"
    echo "exit_status=$status"
    echo "run_id=$RUN_ID"
    echo "sweep_root=$SWEEP_ROOT"
    echo "log_root=$LOG_ROOT"
    echo "driver_log=$LOG_ROOT/driver.log"
    echo "status_tsv=$STATUS_FILE"
    echo "fixed_sum_logs=$FIXED_LOG_ROOT"
    echo "summary_tsv=$LOG_ROOT/summary/sparsity_norm_sweep_limit${LIMIT_SAMPLES}.tsv"
    echo "summary_json=$LOG_ROOT/summary/sparsity_norm_sweep_limit${LIMIT_SAMPLES}.json"
    echo "target_snrs=$TARGET_SNRS"
    echo "nm_points=$NM_POINTS"
    echo "models=$(model_keys_arg)"
    echo "gpus=$GPUS"
    echo "artifact_gpus=$ARTIFACT_GPUS"
    echo "limit_samples=$LIMIT_SAMPLES"
  } > "$LOG_ROOT/final_status.txt"
  echo "[driver] final status written to $LOG_ROOT/final_status.txt"
}
trap finish EXIT

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
  echo "sweep_root=$SWEEP_ROOT"
  echo "log_root=$LOG_ROOT"
  echo "gpus=$GPUS"
  echo "nproc=$NPROC"
  echo "artifact_gpu=$ARTIFACT_GPU"
  echo "artifact_gpus=$ARTIFACT_GPUS"
  echo "limit_samples=$LIMIT_SAMPLES"
  echo "target_snrs=$TARGET_SNRS"
  echo "nm_points=$NM_POINTS"
  echo "run_fixed_sum=$RUN_FIXED_SUM"
  echo "run_wanda=$RUN_WANDA"
  echo "run_wanda_calibration=$RUN_WANDA_CALIBRATION"
  echo "run_act=$RUN_ACT"
  echo "model_specs=$MODEL_SPECS"
  echo "fixed_sum_phases=$FIXED_SUM_PHASES"
  echo "fixed_msd_chunks=$FIXED_MSD_CHUNKS"
  echo "fixed_stats_device_map=$FIXED_STATS_DEVICE_MAP"
  echo "fixed_stats_max_memory=$FIXED_STATS_MAX_MEMORY"
  echo "wanda_num_texts=$WANDA_NUM_TEXTS"
  echo "force=$FORCE"
  echo "dry_run=$DRY_RUN"
  echo "continue_on_error=$CONTINUE_ON_ERROR"
} > "$LOG_ROOT/run.env"

echo "timestamp	phase	model	point	step	status	output	log" > "$STATUS_FILE"

echo "[driver] run id: $RUN_ID"
echo "[driver] sweep root: $SWEEP_ROOT"
echo "[driver] logs: $LOG_ROOT"
echo "[driver] fixed-sum target SNRs: $TARGET_SNRS"
echo "[driver] fixed-sum ordered phases: $FIXED_SUM_PHASES"
echo "[driver] WANDA/act N:M points: $NM_POINTS"
echo "[driver] limit samples: $LIMIT_SAMPLES"
echo "[driver] GPUs: $GPUS"
echo "[driver] artifact GPUs: $ARTIFACT_GPUS"

failed=0
if ! prepare_wanda_masks_parallel; then
  failed=1
  [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
fi

for spec in $MODEL_SPECS; do
  IFS=':' read -r model_key model_path cache_dtype <<< "$spec"
  cache_dtype="${cache_dtype:-float16}"
  if [[ -z "$model_key" || -z "$model_path" || ! -d "$model_path" ]]; then
    echo "ERROR: invalid or missing model spec: $spec" >&2
    exit 2
  fi

  echo
  echo "================================================================"
  echo "Baseline model : $model_key"
  echo "Path           : $model_path"
  echo "Cache dtype    : $cache_dtype"
  echo "N:M points     : $NM_POINTS"
  echo "================================================================"

  for nm in $NM_POINTS; do
    read -r n m < <(parse_nm "$nm")
    if [[ "$RUN_WANDA" == "1" ]]; then
      if ! run_wanda_ppl_point "$model_key" "$model_path" "$cache_dtype" "$n" "$m"; then
        failed=1
        [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
      fi
    fi
    if [[ "$RUN_ACT" == "1" ]]; then
      if ! run_act_point "$model_key" "$model_path" "$cache_dtype" "$n" "$m"; then
        failed=1
        [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
      fi
    fi
    write_summary
  done
done

if [[ "$RUN_FIXED_SUM" == "1" ]]; then
  if ! run_fixed_sum_phase; then
    failed=1
    [[ "$CONTINUE_ON_ERROR" == "1" ]] || exit 1
  fi
fi

write_summary

if [[ "$failed" != "0" && "$CONTINUE_ON_ERROR" != "1" ]]; then
  exit 1
fi

echo "[driver] complete"

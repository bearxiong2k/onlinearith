#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
FUNCTIONAL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$FUNCTIONAL_ROOT/.." && pwd)"
PY="$ROOT/../.venv3_10/bin/python"
PYTHONPATH_VALUE="$ROOT/../transformers/src:${PYTHONPATH:-}"

LLAMA_ROOT="/home/xzj/coding/data/rebuttal_experiments/llama32_3b"
LLAMA_LOG="$LLAMA_ROOT/logs/launch_20260612_next12h"
QWEN1_ROOT="/home/xzj/coding/data/rebuttal_experiments/qwen1_7b_k_sweep"
QWEN1_LOG="$QWEN1_ROOT/logs/launch_20260611_023133"
QWEN4_ROOT="/home/xzj/coding/data/rebuttal_experiments/qwen4b_k_sweep"
QWEN4_LOG="$QWEN4_ROOT/logs/launch_20260612_next12h"
WATCH_ROOT="/home/xzj/coding/data/rebuttal_experiments/watchdog_20260612_next12h"
WATCH_LOG="$WATCH_ROOT/watchdog.log"

mkdir -p "$LLAMA_ROOT/ppl" "$LLAMA_LOG" "$QWEN1_ROOT/ppl" "$QWEN4_ROOT/ppl" "$QWEN4_ROOT/calib_fixed_sum" "$QWEN4_LOG" "$WATCH_ROOT"

RUN_SECONDS="${RUN_SECONDS:-43200}"
SLEEP_SECONDS="${SLEEP_SECONDS:-120}"
START_EPOCH="$(date +%s)"
STOP_EPOCH="$((START_EPOCH + RUN_SECONDS))"

log_msg() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$WATCH_LOG"
}

gpu_free() {
  local gpu="$1" mem
  mem="$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i "$gpu" 2>/dev/null | tr -dc '0-9')"
  [[ -n "$mem" && "$mem" -lt 1024 ]]
}

pid_alive() {
  local pid_file="$1" pid
  [[ -f "$pid_file" ]] || return 1
  pid="$(tr -dc '0-9' < "$pid_file")"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

pid_alive_any() {
  local pattern pid_file
  for pattern in "$@"; do
    for pid_file in $pattern; do
      pid_alive "$pid_file" && return 0
    done
  done
  return 1
}

any_file_done() {
  local file
  for file in "$@"; do
    [[ -s "$file" ]] && return 0
  done
  return 1
}

launch_task() {
  local name="$1" gpu="$2" pid_file="$3" log_file="$4"
  shift 4

  if pid_alive "$pid_file"; then
    log_msg "skip $name on gpu$gpu: pid already alive"
    return 1
  fi

  log_msg "launch $name on gpu$gpu"
  (
    cd "$ROOT" || exit 1
    export PYTHONPATH="$PYTHONPATH_VALUE"
    export CUDA_VISIBLE_DEVICES="$gpu"
    "$@"
  ) > "$log_file" 2>&1 &
  echo "$!" > "$pid_file"
  log_msg "launched $name pid $(cat "$pid_file") log $log_file"
  return 0
}

launch_llama_fast_ppl() {
  local snr="$1" gpu="$2"
  local cal="$LLAMA_ROOT/calib_fixed_sum/calibration_MXFP8_fixed_sum_llama32_3b_snr${snr}db.json"
  local canonical="$LLAMA_ROOT/ppl/ppl_results_MXFP8_fixed_sum_llama32_3b_snr${snr}db_stats_limit300.json"
  local out="$LLAMA_ROOT/ppl/ppl_results_MXFP8_fixed_sum_llama32_3b_snr${snr}db_stats_limit300_msd1024.json"
  local pid="$LLAMA_LOG/llama_snr${snr}_ppl_msd1024_gpu${gpu}.pid"
  local log="$LLAMA_LOG/llama_snr${snr}_ppl_msd1024_gpu${gpu}.log"
  [[ -s "$cal" ]] || return 1
  any_file_done "$canonical" "$out" && return 1
  pid_alive_any "$LLAMA_LOG/llama_snr${snr}_ppl_msd1024_gpu*.pid" && return 1
  launch_task "llama_snr${snr}_ppl_msd1024" "$gpu" "$pid" "$log" \
    "$PY" "$FUNCTIONAL_ROOT/ppltest.py" --model-path ../Llama-3.2-3B --setup 6 \
      --calibration "$cal" --limit-samples 300 --stats lite \
      --figure5-layer-cycles --gpus "$gpu" \
      --mx-chunk-target-mib 512 --msd-chunk-target-mib 1024 \
      --weight-cache-dtype float8 --compile-msd-truncate \
      --mxfp-progress-interval-sec 1800 \
      --mxfp-progress-file "$LLAMA_LOG/llama_snr${snr}_msd1024_progress.json" \
      --output "$out"
}

launch_qwen1_snr_ppl() {
  local k="$1" gpu="$2"
  local cal="$QWEN1_ROOT/calib_fixed_sum/calibration_MXFP8_fixed_sum_qwen1_7b_k${k}_snr17db.json"
  local out="$QWEN1_ROOT/ppl/ppl_results_MXFP8_fixed_sum_qwen1_7b_k${k}_snr17db_stats_limit300.json"
  local pid="$QWEN1_LOG/qwen17b_k${k}_snr17_ppl_gpu${gpu}.pid"
  local log="$QWEN1_LOG/qwen17b_k${k}_snr17_ppl_gpu${gpu}.log"
  [[ -s "$cal" ]] || return 1
  any_file_done "$out" && return 1
  pid_alive_any "$QWEN1_LOG/qwen17b_k${k}_snr17_ppl_gpu*.pid" && return 1
  launch_task "qwen1_7b_k${k}_snr17_ppl" "$gpu" "$pid" "$log" \
    "$PY" "$FUNCTIONAL_ROOT/ppltest.py" --model-path ../Qwen3-1.7B --setup 6 \
      --calibration "$cal" --limit-samples 300 --stats lite \
      --figure5-layer-cycles --gpus "$gpu" --mxfp8-block-size "$k" \
      --mx-chunk-target-mib 256 --msd-chunk-target-mib 256 \
      --weight-cache-dtype float8 --compile-msd-truncate \
      --mxfp-progress-interval-sec 1800 \
      --mxfp-progress-file "$QWEN1_LOG/qwen17b_k${k}_snr17_progress.json" \
      --output "$out"
}

qwen4_cal_path() {
  local k="$1"
  if [[ "$k" == "32" ]]; then
    printf '%s\n' "/home/xzj/coding/data/qwen3_final_experiments/sparsity_norm_sweep300/fixed_sum/qwen4b/snr17db/calib/calibration_MXFP8_fixed_sum_qwen4b_snr17db.json"
  else
    printf '%s\n' "$QWEN4_ROOT/calib_fixed_sum/calibration_MXFP8_fixed_sum_qwen4b_k${k}_snr17db.json"
  fi
}

launch_qwen4_mxfp_ppl() {
  local k="$1" gpu="$2"
  local out="$QWEN4_ROOT/ppl/ppl_results_MXFP8_qwen4b_k${k}_limit300.json"
  local pid="$QWEN4_LOG/qwen4b_k${k}_mxfp8_ppl_gpu${gpu}.pid"
  local log="$QWEN4_LOG/qwen4b_k${k}_mxfp8_ppl_gpu${gpu}.log"
  any_file_done "$out" && return 1
  pid_alive_any "$QWEN4_LOG/qwen4b_k${k}_mxfp8_ppl_gpu*.pid" && return 1
  launch_task "qwen4b_k${k}_mxfp8_ppl" "$gpu" "$pid" "$log" \
    "$PY" "$FUNCTIONAL_ROOT/ppltest.py" --model-path ../Qwen3-4B --setup 2 \
      --limit-samples 300 --stats off --gpus "$gpu" \
      --mxfp8-block-size "$k" --mx-chunk-target-mib 256 \
      --weight-cache-dtype float8 --mxfp-progress-interval-sec 1800 \
      --mxfp-progress-file "$QWEN4_LOG/qwen4b_k${k}_mxfp8_progress.json" \
      --output "$out"
}

launch_qwen4_cal() {
  local k="$1" gpu="$2"
  [[ "$k" == "32" ]] && return 1
  local cal pid log
  cal="$(qwen4_cal_path "$k")"
  pid="$QWEN4_LOG/qwen4b_k${k}_cal_gpu${gpu}.pid"
  log="$QWEN4_LOG/qwen4b_k${k}_cal_gpu${gpu}.log"
  any_file_done "$cal" && return 1
  pid_alive_any "$QWEN4_LOG/qwen4b_k${k}_cal_gpu*.pid" && return 1
  launch_task "qwen4b_k${k}_snr17_cal" "$gpu" "$pid" "$log" \
    "$PY" "$FUNCTIONAL_ROOT/calibrate.py" --model-path ../Qwen3-4B --setup 1 \
      --optimizer fixed_sum --target-snr 17 --num-texts 20 \
      --max-length 512 --batch-size 4 \
      --result-suffix qwen4b_k${k}_snr17db \
      --output-dir "$QWEN4_ROOT/calib_fixed_sum" \
      --mxfp8-block-size "$k" --mx-chunk-target-mib 256 \
      --cal-chunk-target-mib 256 --weight-cache-dtype float8 \
      --compile-msd-truncate --gpus "$gpu" --force
}

launch_qwen4_snr_ppl() {
  local k="$1" gpu="$2" cal
  cal="$(qwen4_cal_path "$k")"
  local out="$QWEN4_ROOT/ppl/ppl_results_MXFP8_fixed_sum_qwen4b_k${k}_snr17db_stats_limit300.json"
  local pid="$QWEN4_LOG/qwen4b_k${k}_snr17_ppl_gpu${gpu}.pid"
  local log="$QWEN4_LOG/qwen4b_k${k}_snr17_ppl_gpu${gpu}.log"
  [[ -s "$cal" ]] || return 1
  any_file_done "$out" && return 1
  pid_alive_any "$QWEN4_LOG/qwen4b_k${k}_snr17_ppl_gpu*.pid" && return 1
  launch_task "qwen4b_k${k}_snr17_ppl" "$gpu" "$pid" "$log" \
    "$PY" "$FUNCTIONAL_ROOT/ppltest.py" --model-path ../Qwen3-4B --setup 6 \
      --calibration "$cal" --limit-samples 300 --stats lite \
      --figure5-layer-cycles --gpus "$gpu" --mxfp8-block-size "$k" \
      --mx-chunk-target-mib 256 --msd-chunk-target-mib 512 \
      --weight-cache-dtype float8 --compile-msd-truncate \
      --mxfp-progress-interval-sec 1800 \
      --mxfp-progress-file "$QWEN4_LOG/qwen4b_k${k}_snr17_progress.json" \
      --output "$out"
}

schedule_one() {
  local gpu="$1"

  launch_llama_fast_ppl 17 "$gpu" && return 0
  launch_llama_fast_ppl 20 "$gpu" && return 0
  launch_llama_fast_ppl 30 "$gpu" && return 0
  launch_llama_fast_ppl 15 "$gpu" && return 0

  launch_qwen1_snr_ppl 128 "$gpu" && return 0

  launch_qwen4_mxfp_ppl 16 "$gpu" && return 0
  launch_qwen4_mxfp_ppl 32 "$gpu" && return 0
  launch_qwen4_mxfp_ppl 64 "$gpu" && return 0
  launch_qwen4_snr_ppl 32 "$gpu" && return 0
  launch_qwen4_cal 16 "$gpu" && return 0
  launch_qwen4_cal 64 "$gpu" && return 0
  launch_qwen4_snr_ppl 16 "$gpu" && return 0
  launch_qwen4_snr_ppl 64 "$gpu" && return 0

  launch_qwen4_mxfp_ppl 8 "$gpu" && return 0
  launch_qwen4_mxfp_ppl 128 "$gpu" && return 0
  launch_qwen4_cal 8 "$gpu" && return 0
  launch_qwen4_cal 128 "$gpu" && return 0
  launch_qwen4_snr_ppl 8 "$gpu" && return 0
  launch_qwen4_snr_ppl 128 "$gpu" && return 0

  return 1
}

log_msg "watchdog start; stop launching after $(date -d "@$STOP_EPOCH" '+%F %T')"

while [[ "$(date +%s)" -lt "$STOP_EPOCH" ]]; do
  for gpu in 0 1 2 3 4 5 6 7; do
    if gpu_free "$gpu"; then
      schedule_one "$gpu" || log_msg "gpu$gpu free but no eligible queued task"
    fi
  done
  sleep "$SLEEP_SECONDS"
done

log_msg "watchdog launch window ended; existing experiment processes left running"

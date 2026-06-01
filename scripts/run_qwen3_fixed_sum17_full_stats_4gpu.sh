#!/usr/bin/env bash
# Formal fixed-sum 17 dB full-sample stats sweep for Qwen3 models on GPUs 4-7.
#
# This collects the data missing from the four-rank final PPL sweep:
# full WikiText-2 PPL, plot_norm_digit_read, and Figure 5 layer-cycle inputs.
# It intentionally runs each model as a single-process stats job because current
# --nproc PPL disables MSD stats on nonzero ranks.
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
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-0}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"

# key:model_path:gpu:ppl_cache_dtype:calib_batch:calib_mx_chunk_mib:calib_chunk_mib:ppl_msd_chunk_mib
MODEL_JOBS="${MODEL_JOBS:-qwen0_6b:../Qwen3-0.6B:4:float16:8:512:128:1536 qwen1_7b:../Qwen3-1.7B:5:float16:4:384:96:1536 qwen4b:../Qwen3-4B:6:float16:2:256:64:1536 qwen8b:../Qwen3-8B:7:float8:4:256:64:1536}"

if [[ "${BACKGROUND:-0}" == "1" && "${QWEN_FIXED_SUM17_BACKGROUND_CHILD:-0}" != "1" ]]; then
  mkdir -p "$DRIVER_ROOT"
  export QWEN_FIXED_SUM17_BACKGROUND_CHILD=1
  export RUN_ID SWEEP_ROOT DRIVER_ROOT TARGET_SNRS CONTINUE_ON_ERROR FORCE DRY_RUN MODEL_JOBS
  nohup "$0" "$@" > "$DRIVER_ROOT/nohup.out" 2>&1 &
  echo "[launched] PID: $!"
  echo "[launched] driver log: $DRIVER_ROOT/driver.log"
  echo "[launched] nohup log : $DRIVER_ROOT/nohup.out"
  exit 0
fi

mkdir -p "$DRIVER_ROOT"
exec > >(tee -a "$DRIVER_ROOT/driver.log") 2>&1

SUMMARY_WRITTEN=0

model_keys() {
  local job
  for job in $MODEL_JOBS; do
    printf '%s\n' "${job%%:*}"
  done | xargs
}

write_summary() {
  "$PYTHON" "$SCRIPT_DIR/summarize_fixed_sum_norm_sweep.py" \
    --root "$SWEEP_ROOT" \
    --models "$(model_keys)" \
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
    echo "sweep_root=$SWEEP_ROOT"
    echo "driver_root=$DRIVER_ROOT"
    echo "summary_tsv=$DRIVER_ROOT/fixed_sum_stats_full.tsv"
    echo "summary_json=$DRIVER_ROOT/fixed_sum_stats_full.json"
    echo "status_tsv=$DRIVER_ROOT/status.tsv"
  } > "$DRIVER_ROOT/final_status.txt"
  echo "[driver] final status written to $DRIVER_ROOT/final_status.txt"
}
trap finish EXIT

{
  echo "run_id=$RUN_ID"
  echo "started_at=$(date -Is)"
  echo "target_snrs=$TARGET_SNRS"
  echo "sweep_root=$SWEEP_ROOT"
  echo "driver_root=$DRIVER_ROOT"
  echo "continue_on_error=$CONTINUE_ON_ERROR"
  echo "force=$FORCE"
  echo "dry_run=$DRY_RUN"
  echo "model_jobs=$MODEL_JOBS"
} > "$DRIVER_ROOT/run.env"

echo "[driver] run id: $RUN_ID"
echo "[driver] target SNRs: $TARGET_SNRS"
echo "[driver] sweep root: $SWEEP_ROOT"
echo "[driver] logs: $DRIVER_ROOT"
echo "[driver] sample mode: full WikiText-2, no --limit-samples"
echo "timestamp	model	status	worker_status	worker_log" > "$DRIVER_ROOT/status.tsv"

pids=()
names=()

launch_job() {
  local model_key="$1"
  local model_path="$2"
  local gpu="$3"
  local cache_dtype="$4"
  local calib_batch="$5"
  local calib_mx_chunk="$6"
  local calib_chunk="$7"
  local ppl_msd_chunk="$8"
  local worker_root="$DRIVER_ROOT/$model_key"
  local worker_log="$worker_root/worker.log"

  if [[ ! -d "$model_path" ]]; then
    echo "ERROR: [$model_key] model path not found: $model_path" >&2
    return 2
  fi

  mkdir -p "$worker_root"
  echo "[driver] launch $model_key on GPU $gpu; log: $worker_log"
  (
    export SWEEP_ROOT RUN_ID FORCE DRY_RUN CONTINUE_ON_ERROR TARGET_SNRS
    export MODEL_SPECS="$model_key:$model_path:$cache_dtype"
    export ARTIFACT_GPU="$gpu"
    export PPL_GPU="$gpu"
    export UTIL_LIMIT_SAMPLES=""
    export CALIB_BATCH_SIZE="$calib_batch"
    export CALIB_MX_CHUNK_MIB="$calib_mx_chunk"
    export CALIB_CHUNK_MIB="$calib_chunk"
    export PPL_MSD_CHUNK_MIB="$ppl_msd_chunk"
    export LOG_ROOT="$worker_root/steps"
    export STATUS_FILE="$worker_root/status.tsv"
    "$SCRIPT_DIR/run_qwen3_fixed_sum_norm_target_sweep.sh"
  ) > "$worker_log" 2>&1 &
  pids+=("$!")
  names+=("$model_key")
}

for job in $MODEL_JOBS; do
  IFS=':' read -r model_key model_path gpu cache_dtype calib_batch calib_mx_chunk calib_chunk ppl_msd_chunk <<< "$job"
  cache_dtype="${cache_dtype:-float16}"
  calib_batch="${calib_batch:-4}"
  calib_mx_chunk="${calib_mx_chunk:-256}"
  calib_chunk="${calib_chunk:-64}"
  ppl_msd_chunk="${ppl_msd_chunk:-1536}"
  launch_job "$model_key" "$model_path" "$gpu" "$cache_dtype" "$calib_batch" "$calib_mx_chunk" "$calib_chunk" "$ppl_msd_chunk"
done

failed=0
for idx in "${!pids[@]}"; do
  pid="${pids[$idx]}"
  name="${names[$idx]}"
  if wait "$pid"; then
    echo "[driver] complete $name"
    printf '%s\t%s\tcompleted\t%s\t%s\n' "$(date -Is)" "$name" "$DRIVER_ROOT/$name/status.tsv" "$DRIVER_ROOT/$name/worker.log" >> "$DRIVER_ROOT/status.tsv"
  else
    status=$?
    echo "[driver] FAILED $name with exit code $status"
    printf '%s\t%s\tfailed:%s\t%s\t%s\n' "$(date -Is)" "$name" "$status" "$DRIVER_ROOT/$name/status.tsv" "$DRIVER_ROOT/$name/worker.log" >> "$DRIVER_ROOT/status.tsv"
    failed=1
  fi
done

echo "[driver] writing summary"
write_summary

if [[ "$failed" != "0" && "$CONTINUE_ON_ERROR" != "1" ]]; then
  exit 1
fi

echo "[driver] complete"

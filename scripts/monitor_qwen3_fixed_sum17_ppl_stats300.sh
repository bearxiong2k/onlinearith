#!/usr/bin/env bash
# Print a clean one-shot status view for the fixed-sum 17 dB PPL/stats300 run.
#
# Usage:
#   scripts/monitor_qwen3_fixed_sum17_ppl_stats300.sh
#   scripts/monitor_qwen3_fixed_sum17_ppl_stats300.sh 20260602_150000
#   scripts/monitor_qwen3_fixed_sum17_ppl_stats300.sh ppl_stats300_20260602_150000
#   scripts/monitor_qwen3_fixed_sum17_ppl_stats300.sh ../data/.../logs/ppl_stats300_...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PYTHON="${PYTHON:-../.venv3_10/bin/python}"
SWEEP_ROOT="${SWEEP_ROOT:-../data/qwen3_final_experiments/fixed_sum17_ppl_stats300}"
LOG_ROOT="$SWEEP_ROOT/logs"

resolve_run_dir() {
  local arg="${1:-}"
  if [[ -z "$arg" ]]; then
    ls -td "$LOG_ROOT"/ppl_stats300_* 2>/dev/null | head -1
  elif [[ -d "$arg" ]]; then
    printf '%s\n' "$arg"
  elif [[ "$arg" == ppl_stats300_* ]]; then
    printf '%s/%s\n' "$LOG_ROOT" "$arg"
  else
    printf '%s/ppl_stats300_%s\n' "$LOG_ROOT" "$arg"
  fi
}

RUN_DIR="$(resolve_run_dir "${1:-}")"
if [[ -z "$RUN_DIR" || ! -d "$RUN_DIR" ]]; then
  echo "ERROR: run directory not found: ${RUN_DIR:-<none>}" >&2
  exit 2
fi

"$PYTHON" - "$RUN_DIR" <<'PY'
import csv
import json
import re
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
status_path = run_dir / "status.tsv"

print(f"run_dir: {run_dir}")
print()

if not status_path.exists():
    print(f"status: missing {status_path}")
    raise SystemExit(0)

with status_path.open(newline="") as f:
    rows = list(csv.DictReader(f, delimiter="\t"))

print("last status rows:")
for row in rows[-10:]:
    print(
        f"  {row['timestamp']}  {row['model']}  {row['phase']}  "
        f"{row['step']}  {row['status']}"
    )
print()

state = {}
for row in rows:
    key = (row["model"], row["target_snr_db"], row["phase"], row["step"])
    state[key] = row

active = [row for row in state.values() if row["status"] == "started"]
if active:
    row = active[-1]
    label = "active"
elif rows:
    row = rows[-1]
    label = "latest"
else:
    print("no steps recorded")
    raise SystemExit(0)

log_path = Path(row["log"])
print(
    f"{label} step: {row['model']} snr{row['target_snr_db']} "
    f"{row['phase']}/{row['step']} status={row['status']}"
)
print(f"log: {log_path}")

if not log_path.exists():
    print("progress: log file not found yet")
    raise SystemExit(0)

size = log_path.stat().st_size
with log_path.open("rb") as f:
    f.seek(max(0, size - 64 * 1024 * 1024))
    text = f.read().decode("utf-8", "replace")

matches = re.findall(r"\[rank 0\] PPL windows:[^\r\n]*", text)
if matches:
    progress = matches[-1].split("PROGRESS ", 1)[0].strip()
    print()
    print("ppl progress:")
    print(progress)
else:
    print()
    print("ppl progress: no tqdm line found in recent log tail")

progress_events = re.findall(r"PROGRESS (\{[^\n]*\})", text)
if progress_events:
    try:
        event = json.loads(progress_events[-1])
    except json.JSONDecodeError:
        event = None
    if event:
        print()
        print(
            "latest chunk: "
            f"{event.get('layer_name')} "
            f"{event.get('phase')} "
            f"{event.get('chunk_idx')}/{event.get('total_chunks')} "
            f"({event.get('percent')}%), "
            f"elapsed={event.get('elapsed_sec')}s, "
            f"alloc={event.get('cuda_alloc_gib')}GiB, "
            f"peak={event.get('cuda_peak_alloc_gib')}GiB"
        )
PY

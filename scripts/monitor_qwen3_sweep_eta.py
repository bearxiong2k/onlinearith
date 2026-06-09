#!/usr/bin/env python3
"""Monitor Qwen3 sweep runs with per-task ETA.

The sweep runners write status TSV files and PPL logs. This monitor combines
those files with the live process table and GPU utilization so long unattended
runs have a single ETA-oriented status view.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


TERMINAL_STATUSES = {
    "completed",
    "dry_run",
    "skipped_disabled",
    "skipped_existing",
    "skipped_model_not_selected",
}

PPL_RE = re.compile(
    r"PPL windows:\s*(?P<pct>\d+)%\|.*?\|\s*"
    r"(?P<done>\d+)/(?P<total>\d+)\s*"
    r"\[(?P<elapsed>[^<\],]+)(?:<(?P<eta>[^,\]]+))?"
)
PROGRESS_RE = re.compile(r"PROGRESS\s+({.*})")


@dataclass
class StatusRow:
    timestamp: str
    model: str
    point: str
    phase: str
    step: str
    status: str
    output: str
    log: str
    status_file: Path


@dataclass
class ProcRow:
    pid: int
    etime: str
    elapsed_sec: int | None
    cmd: str
    output: str | None
    gpu: str | None
    model_path: str | None


def rel(path: str | Path, root: Path) -> str:
    if not path:
        return ""
    try:
        return str(Path(path).resolve().relative_to(root.resolve()))
    except Exception:
        return str(path)


def parse_duration(text: str | None) -> int | None:
    if not text:
        return None
    text = text.strip()
    if not text:
        return None
    days = 0
    if "-" in text:
        day_s, text = text.split("-", 1)
        try:
            days = int(day_s)
        except ValueError:
            return None
    parts = text.split(":")
    try:
        nums = [int(p) for p in parts]
    except ValueError:
        return None
    if len(nums) == 3:
        h, m, s = nums
    elif len(nums) == 2:
        h = 0
        m, s = nums
    elif len(nums) == 1:
        h = 0
        m = 0
        s = nums[0]
    else:
        return None
    return days * 86400 + h * 3600 + m * 60 + s


def fmt_duration(seconds: float | int | None) -> str:
    if seconds is None:
        return "unknown"
    seconds = max(0, int(seconds))
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, secs = divmod(rem, 60)
    if days:
        return f"{days}d{hours:02d}h{minutes:02d}m"
    if hours:
        return f"{hours}h{minutes:02d}m"
    if minutes:
        return f"{minutes}m{secs:02d}s"
    return f"{secs}s"


def latest_log_root(base: Path) -> Path:
    roots = sorted((p for p in base.glob("sweep300_*") if p.is_dir()), key=lambda p: p.stat().st_mtime)
    if not roots:
        raise SystemExit(f"no sweep log roots found under {base}")
    return roots[-1]


def read_status_rows(log_root: Path) -> list[StatusRow]:
    rows: list[StatusRow] = []
    for status_file in sorted(log_root.rglob("status.tsv")):
        try:
            with status_file.open("r", encoding="utf-8", newline="") as f:
                reader = csv.DictReader(f, delimiter="\t")
                for raw in reader:
                    phase = raw.get("phase", "")
                    # Top-level sweep status: phase/model/point/step/status/output/log.
                    # Fixed-sum sub-status: model/target_snr_db/phase/step/status/output/log.
                    if "target_snr_db" in raw:
                        model = raw.get("model", "")
                        point = raw.get("target_snr_db", "")
                    else:
                        model = raw.get("model", "")
                        point = raw.get("point", "")
                    rows.append(
                        StatusRow(
                            timestamp=raw.get("timestamp", ""),
                            model=model,
                            point=point,
                            phase=phase,
                            step=raw.get("step", ""),
                            status=raw.get("status", ""),
                            output=raw.get("output", ""),
                            log=raw.get("log", ""),
                            status_file=status_file,
                        )
                    )
        except FileNotFoundError:
            continue
    return rows


def status_is_terminal(status: str) -> bool:
    return status in TERMINAL_STATUSES or status.startswith("failed:")


def active_status_rows(rows: Iterable[StatusRow]) -> list[StatusRow]:
    by_key: dict[tuple[str, str, str, str, str], StatusRow] = {}
    for row in rows:
        if not row.output and not row.log:
            continue
        key = (row.model, row.point, row.phase, row.step, row.output or row.log)
        by_key[key] = row
    return [row for row in by_key.values() if not status_is_terminal(row.status)]


def complete_json(path: str) -> bool:
    if not path:
        return False
    p = Path(path)
    if p.is_dir():
        return True
    if not p.is_file() or p.stat().st_size == 0:
        return False
    if p.suffix == ".json":
        try:
            with p.open("r", encoding="utf-8") as f:
                json.load(f)
        except Exception:
            return False
    return True


def run_text(args: list[str]) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return ""


def arg_value(argv: list[str], name: str) -> str | None:
    if name not in argv:
        return None
    idx = argv.index(name)
    if idx + 1 < len(argv):
        return argv[idx + 1]
    return None


def parse_processes() -> list[ProcRow]:
    out = run_text(["ps", "-eo", "pid=,etime=,cmd="])
    rows: list[ProcRow] = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 2)
        if len(parts) != 3:
            continue
        pid_s, etime, cmd = parts
        if "ppltest.py" not in cmd and "calibrate.py" not in cmd:
            continue
        if "monitor_qwen3_sweep_eta.py" in cmd:
            continue
        try:
            pid = int(pid_s)
        except ValueError:
            continue
        try:
            argv = shlex.split(cmd)
        except ValueError:
            argv = cmd.split()
        output = arg_value(argv, "--output")
        gpu = arg_value(argv, "--gpus")
        model_path = arg_value(argv, "--model-path")
        rows.append(
            ProcRow(
                pid=pid,
                etime=etime,
                elapsed_sec=parse_duration(etime),
                cmd=cmd,
                output=output,
                gpu=gpu,
                model_path=model_path,
            )
        )
    return rows


def parse_gpu_snapshot() -> dict[str, dict[str, str]]:
    out = run_text(["nvidia-smi", "--query-gpu=index,utilization.gpu,memory.used", "--format=csv,noheader,nounits"])
    gpus: dict[str, dict[str, str]] = {}
    for line in out.splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) >= 3:
            gpus[parts[0]] = {"util": parts[1], "mem_mib": parts[2]}
    return gpus


def tail_bytes(path: Path, max_bytes: int = 2_000_000) -> str:
    try:
        size = path.stat().st_size
        with path.open("rb") as f:
            if size > max_bytes:
                f.seek(size - max_bytes)
            data = f.read()
        return data.decode("utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def parse_log_progress(path: str) -> dict[str, object]:
    if not path:
        return {"source": "none"}
    p = Path(path)
    text = tail_bytes(p)
    age = None
    try:
        age = time.time() - p.stat().st_mtime
    except FileNotFoundError:
        pass

    last_tqdm = None
    for m in PPL_RE.finditer(text.replace("\r", "\n")):
        last_tqdm = m

    last_progress = None
    for m in PROGRESS_RE.finditer(text):
        try:
            last_progress = json.loads(m.group(1))
        except json.JSONDecodeError:
            continue

    if last_tqdm is not None:
        done = int(last_tqdm.group("done"))
        total = int(last_tqdm.group("total"))
        elapsed = parse_duration(last_tqdm.group("elapsed"))
        eta = parse_duration(last_tqdm.group("eta"))
        pct = 100.0 * done / total if total else None
        if eta is None and elapsed is not None and done > 0 and total > done:
            eta = elapsed / done * (total - done)
        return {
            "source": "ppl_windows",
            "done": done,
            "total": total,
            "pct": pct,
            "elapsed_sec": elapsed,
            "eta_sec": eta,
            "log_age_sec": age,
            "msd_layer": last_progress.get("layer_name") if isinstance(last_progress, dict) else None,
        }

    if isinstance(last_progress, dict):
        return {
            "source": "mxfp_progress",
            "pct": last_progress.get("percent"),
            "eta_sec": None,
            "elapsed_sec": last_progress.get("elapsed_sec"),
            "log_age_sec": age,
            "msd_layer": last_progress.get("layer_name"),
            "chunk_idx": last_progress.get("chunk_idx"),
            "total_chunks": last_progress.get("total_chunks"),
        }

    return {"source": "none", "log_age_sec": age}


def find_row_for_proc(proc: ProcRow, rows: list[StatusRow]) -> StatusRow | None:
    if proc.output:
        for row in reversed(rows):
            if row.output == proc.output:
                return row
    return None


def command_label(proc: ProcRow) -> str:
    cmd = proc.cmd
    if "ppltest.py" in cmd:
        return "ppltest"
    if "calibrate.py" in cmd:
        return "calibrate"
    return "process"


def print_report(log_root: Path, all_rows: list[StatusRow], procs: list[ProcRow]) -> None:
    gpus = parse_gpu_snapshot()
    now = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    print(f"Qwen3 sweep ETA monitor at {now}")
    print(f"log_root: {log_root}")
    print("")
    if not procs:
        print("No active ppltest.py/calibrate.py processes found.")
    for proc in sorted(procs, key=lambda p: (p.gpu or "", p.pid)):
        row = find_row_for_proc(proc, all_rows)
        log_path = row.log if row else ""
        progress = parse_log_progress(log_path)
        gpu_info = gpus.get(proc.gpu or "", {})
        model = row.model if row else rel(proc.model_path or "", Path.cwd())
        point = row.point if row else ""
        step = row.step if row else command_label(proc)
        status = row.status if row else "running"
        eta = fmt_duration(progress.get("eta_sec")) if isinstance(progress, dict) else "unknown"
        elapsed = fmt_duration(progress.get("elapsed_sec") if progress.get("elapsed_sec") is not None else proc.elapsed_sec)
        pct = progress.get("pct") if isinstance(progress, dict) else None
        if isinstance(pct, (float, int)):
            pct_s = f"{pct:.1f}%"
        else:
            pct_s = "unknown"
        if progress.get("source") == "ppl_windows":
            detail = f"windows {progress.get('done')}/{progress.get('total')}"
        elif progress.get("source") == "mxfp_progress":
            detail = f"msd {progress.get('chunk_idx')}/{progress.get('total_chunks')} {progress.get('msd_layer') or ''}".strip()
        else:
            detail = "no progress line yet"
        log_age = fmt_duration(progress.get("log_age_sec")) if progress.get("log_age_sec") is not None else "unknown"
        print(
            f"PID {proc.pid} GPU {proc.gpu or '?'} "
            f"util={gpu_info.get('util', '?')}% mem={gpu_info.get('mem_mib', '?')}MiB "
            f"{model} {point} {step} [{status}]"
        )
        print(f"  progress={pct_s} eta={eta} elapsed={elapsed} last_log={log_age} ago; {detail}")
        if log_path:
            print(f"  log: {log_path}")
        if proc.output:
            print(f"  output: {proc.output}")
    print("")
    active = active_status_rows(all_rows)
    incomplete_outputs = [
        row
        for row in active
        if row.output
        and not Path(row.output).is_dir()
        and not complete_json(row.output)
        and not any(proc.output == row.output for proc in procs)
    ]
    if incomplete_outputs:
        print("Started rows without a matching live process and without complete output:")
        for row in incomplete_outputs[-12:]:
            print(f"  {row.model} {row.point} {row.step} status={row.status} output={row.output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--log-root",
        type=Path,
        default=None,
        help="Sweep log root. Defaults to latest ../data/.../sweep300_* root.",
    )
    parser.add_argument(
        "--logs-base",
        type=Path,
        default=Path("../data/qwen3_final_experiments/sparsity_norm_sweep300/logs"),
        help="Base directory used when --log-root is omitted.",
    )
    parser.add_argument("--watch", type=float, default=0, help="Refresh interval in seconds.")
    args = parser.parse_args()

    log_root = args.log_root or latest_log_root(args.logs_base)
    while True:
        rows = read_status_rows(log_root)
        procs = parse_processes()
        print_report(log_root, rows, procs)
        if args.watch <= 0:
            break
        sys.stdout.flush()
        time.sleep(args.watch)
        print("\033[2J\033[H", end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Summarize Qwen3 model sweep outputs into TSV and JSON files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_MODEL_SPECS = (
    "qwen0_6b:../Qwen3-0.6B "
    "qwen1_7b:../Qwen3-1.7B "
    "qwen4b:../Qwen3-4B "
    "qwen8b:../Qwen3-8B"
)
STEPS = ("mxfp8", "fixed_sum", "wanda", "act")


def parse_model_keys(model_specs: str) -> list[str]:
    keys = []
    for spec in model_specs.split():
        key = spec.split(":", 1)[0].strip()
        if key:
            keys.append(key)
    return keys


def expected_output(sweep_root: Path, model_key: str, tag: str, step: str) -> Path:
    model_root = sweep_root / model_key / tag
    run_label = f"{model_key}_sweep_{tag}"
    if step == "mxfp8":
        return model_root / "ppl" / "mxfp8" / f"ppl_results_MXFP8_{run_label}.json"
    if step == "fixed_sum":
        return model_root / "ppl" / "fixed_sum30" / f"ppl_results_MXFP8_fixed_sum30_{run_label}.json"
    if step == "wanda":
        return model_root / "wanda_base" / "2-4" / f"ppl_results_MXFP8_{run_label}.json"
    if step == "act":
        return model_root / "act_base" / "2-4" / "ppl_results_MXFP8.json"
    raise ValueError(f"unsupported step: {step}")


def load_result(path: Path) -> dict[str, Any]:
    with path.open() as f:
        data = json.load(f)
    metrics = data.get("metrics", {})
    performance = data.get("performance", {})
    reliability = data.get("reliability", {})
    config = data.get("config", {})
    msd_global = data.get("msd_perf_stats", {}).get("global", {})
    mean_eff = msd_global.get("mean_effective_precision")
    return {
        "status": "ok",
        "token_perplexity": metrics.get("token_perplexity"),
        "mean_nll_nats": metrics.get("mean_nll_nats"),
        "scored_tokens": reliability.get("scored_tokens"),
        "wall_time_sec": performance.get("wall_time_sec"),
        "world_size": config.get("world_size"),
        "visible_cuda_devices": ",".join(config.get("visible_cuda_devices", []) or []),
        "stats": config.get("stats"),
        "msd_utilization_mode": config.get("msd_utilization_mode"),
        "figure5_layer_cycles": config.get("figure5_layer_cycles"),
        "mean_effective_precision": mean_eff,
        "plot_norm_digit_read": round(float(mean_eff) / 3.0, 6) if mean_eff is not None else None,
        "global_utilization": msd_global.get("global_utilization"),
        "hw_latency_overhead": msd_global.get("hw_latency_overhead"),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sweep-root", type=Path, default=Path("../data/qwen3_final_experiments/model_sweep_4gpu"))
    parser.add_argument("--tag", default="full")
    parser.add_argument("--model-specs", default=DEFAULT_MODEL_SPECS)
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    sweep_root = args.sweep_root
    rows: list[dict[str, Any]] = []
    for model_key in parse_model_keys(args.model_specs):
        for step in STEPS:
            path = expected_output(sweep_root, model_key, args.tag, step)
            row: dict[str, Any] = {
                "model": model_key,
                "step": step,
                "output": str(path),
            }
            if path.is_file():
                try:
                    row.update(load_result(path))
                except Exception as exc:  # Keep summary generation robust after partial failures.
                    row.update({"status": f"read_error:{type(exc).__name__}"})
            else:
                row.update({"status": "missing"})
            rows.append(row)

    output_dir = args.output_dir or (sweep_root / "logs" / f"summary_{args.tag}")
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / f"summary_{args.tag}.json"
    tsv_path = output_dir / f"summary_{args.tag}.tsv"

    payload = {
        "sweep_root": str(sweep_root),
        "tag": args.tag,
        "rows": rows,
        "counts": {
            "ok": sum(1 for row in rows if row.get("status") == "ok"),
            "missing_or_failed": sum(1 for row in rows if row.get("status") != "ok"),
        },
    }
    with json_path.open("w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")

    columns = (
        "model",
        "step",
        "status",
        "token_perplexity",
        "mean_nll_nats",
        "scored_tokens",
        "wall_time_sec",
        "world_size",
        "visible_cuda_devices",
        "stats",
        "msd_utilization_mode",
        "figure5_layer_cycles",
        "mean_effective_precision",
        "plot_norm_digit_read",
        "global_utilization",
        "hw_latency_overhead",
        "output",
    )
    with tsv_path.open("w") as f:
        f.write("\t".join(columns) + "\n")
        for row in rows:
            f.write("\t".join("" if row.get(col) is None else str(row.get(col, "")) for col in columns) + "\n")

    print(f"Summary JSON: {json_path}")
    print(f"Summary TSV : {tsv_path}")
    print(f"OK rows: {payload['counts']['ok']} / {len(rows)}")
    if payload["counts"]["missing_or_failed"]:
        print(f"Missing/failed rows: {payload['counts']['missing_or_failed']}")


if __name__ == "__main__":
    main()

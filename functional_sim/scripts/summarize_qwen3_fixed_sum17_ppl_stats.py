#!/usr/bin/env python3
"""Summarize fixed-sum 17 dB full-PPL and sampled-stat runs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean
from typing import Any


DEFAULT_ROOT = Path("../data/qwen3_final_experiments/fixed_sum17_ppl_stats300")


def snr_label(snr: str) -> str:
    return f"snr{snr.replace('.', 'p')}db"


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    with path.open() as f:
        return json.load(f)


def figure5_means(per_layer: dict[str, Any]) -> dict[str, float | None]:
    fields = (
        "avg_layer_cycle",
        "avg_mean_channel_cycle",
        "layer_cycle_std",
        "avg_std_channel_cycle",
    )
    out: dict[str, float | None] = {}
    for field in fields:
        values = [
            float(layer[field])
            for layer in per_layer.values()
            if isinstance(layer, dict) and layer.get(field) is not None
        ]
        out[f"stats_mean_{field}"] = round(mean(values), 6) if values else None
    return out


def metric_block(prefix: str, result: dict[str, Any] | None) -> dict[str, Any]:
    if result is None:
        return {f"{prefix}_status": "missing"}

    metrics = result.get("metrics", {})
    reliability = result.get("reliability", {})
    performance = result.get("performance", {})
    config = result.get("config", {})
    out: dict[str, Any] = {
        f"{prefix}_status": "ok",
        f"{prefix}_token_perplexity": metrics.get("token_perplexity"),
        f"{prefix}_mean_nll_nats": metrics.get("mean_nll_nats"),
        f"{prefix}_scored_tokens": reliability.get("scored_tokens"),
        f"{prefix}_num_chunks": reliability.get("num_chunks"),
        f"{prefix}_limit_samples": config.get("limit_samples"),
        f"{prefix}_world_size": config.get("world_size"),
        f"{prefix}_wall_time_sec": performance.get("wall_time_sec"),
    }
    return out


def stats_block(result: dict[str, Any] | None) -> dict[str, Any]:
    if result is None:
        return {}

    msd = result.get("msd_perf_stats", {})
    global_stats = msd.get("global", {})
    per_layer = msd.get("per_layer", {})
    mean_eff = global_stats.get("mean_effective_precision")
    out: dict[str, Any] = {
        "stats_mean_effective_precision": mean_eff,
        "stats_plot_norm_digit_read": (
            round(float(mean_eff) / 3.0, 6) if mean_eff is not None else None
        ),
        "stats_global_utilization": global_stats.get("global_utilization"),
        "stats_hw_latency_overhead": global_stats.get("hw_latency_overhead"),
        "stats_mac_sparsity": global_stats.get("mac_sparsity"),
        "stats_zero_block_ratio": global_stats.get("zero_block_ratio"),
        "stats_max_budget": global_stats.get("max_budget"),
        "stats_max_total_delay": global_stats.get("max_total_delay"),
    }
    out.update(figure5_means(per_layer if isinstance(per_layer, dict) else {}))
    return out


def calibration_block(path: Path) -> dict[str, Any]:
    cal = load_json(path)
    if cal is None:
        return {"calibration_status": "missing"}

    summary = cal.get("global_summary", {})
    return {
        "calibration_status": "ok",
        "calibration_layers": summary.get("num_layers"),
        "calibration_channels": summary.get("total_channels"),
        "calibration_budget_mean": summary.get("budget_mean"),
        "calibration_eff_precision_mean": summary.get("eff_precision_mean"),
        "calibration_min_snr": summary.get("min_snr"),
        "calibration_wall_time_sec": summary.get("wall_time_sec"),
    }


def summarize_one(root: Path, model: str, snr: str, stats_limit: str) -> dict[str, Any]:
    label = snr_label(snr)
    snr_dir = root / model / label
    cal_path = snr_dir / "calib" / f"calibration_MXFP8_fixed_sum_{model}_{label}.json"
    full_path = (
        snr_dir
        / "ppl"
        / "full_no_stats"
        / f"ppl_results_MXFP8_fixed_sum_{model}_{label}_full_no_stats.json"
    )
    stats_path = (
        snr_dir
        / "ppl"
        / f"stats_limit{stats_limit}"
        / f"ppl_results_MXFP8_fixed_sum_{model}_{label}_stats_limit{stats_limit}.json"
    )

    full = load_json(full_path)
    stats = load_json(stats_path)

    row: dict[str, Any] = {
        "model": model,
        "target_snr_db": snr,
        "calibration": str(cal_path),
        "full_ppl_result": str(full_path),
        "stats_result": str(stats_path),
    }
    row.update(calibration_block(cal_path))
    row.update(metric_block("full", full))
    row.update(metric_block("stats", stats))
    row.update(stats_block(stats))
    row["status"] = (
        "ok"
        if row.get("calibration_status") == "ok"
        and row.get("full_status") == "ok"
        and row.get("stats_status") == "ok"
        else "incomplete"
    )
    return row


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--models", default="qwen0_6b qwen1_7b qwen4b qwen8b")
    parser.add_argument("--target-snrs", default="17")
    parser.add_argument("--stats-limit", default="300")
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    rows = [
        summarize_one(args.root, model, snr, args.stats_limit)
        for model in args.models.split()
        for snr in args.target_snrs.split()
    ]

    output_dir = args.output_dir or (args.root / "summaries")
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "fixed_sum17_ppl_stats_summary.json"
    tsv_path = output_dir / "fixed_sum17_ppl_stats_summary.tsv"

    payload = {
        "root": str(args.root),
        "models": args.models.split(),
        "target_snrs": args.target_snrs.split(),
        "stats_limit": args.stats_limit,
        "rows": rows,
        "counts": {
            "ok": sum(1 for row in rows if row.get("status") == "ok"),
            "incomplete": sum(1 for row in rows if row.get("status") != "ok"),
        },
    }
    with json_path.open("w") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")

    columns = (
        "model",
        "target_snr_db",
        "status",
        "calibration_status",
        "full_status",
        "stats_status",
        "full_token_perplexity",
        "full_mean_nll_nats",
        "full_scored_tokens",
        "full_num_chunks",
        "full_world_size",
        "full_wall_time_sec",
        "stats_token_perplexity",
        "stats_mean_nll_nats",
        "stats_scored_tokens",
        "stats_num_chunks",
        "stats_limit_samples",
        "stats_world_size",
        "stats_wall_time_sec",
        "stats_mean_effective_precision",
        "stats_plot_norm_digit_read",
        "stats_global_utilization",
        "stats_hw_latency_overhead",
        "stats_mac_sparsity",
        "stats_zero_block_ratio",
        "stats_mean_avg_layer_cycle",
        "stats_mean_avg_mean_channel_cycle",
        "stats_mean_layer_cycle_std",
        "stats_mean_avg_std_channel_cycle",
        "calibration_budget_mean",
        "calibration_eff_precision_mean",
        "calibration_min_snr",
        "calibration_wall_time_sec",
        "full_ppl_result",
        "stats_result",
        "calibration",
    )
    with tsv_path.open("w") as f:
        f.write("\t".join(columns) + "\n")
        for row in rows:
            f.write(
                "\t".join("" if row.get(col) is None else str(row.get(col, "")) for col in columns)
                + "\n"
            )

    print(f"Summary JSON: {json_path}")
    print(f"Summary TSV : {tsv_path}")
    print(f"OK rows: {payload['counts']['ok']} / {len(rows)}")


if __name__ == "__main__":
    main()

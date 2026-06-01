#!/usr/bin/env python3
"""Summarize fixed-sum SNR probes for equivalent digit-read targeting."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean
from typing import Any


DEFAULT_ROOT = Path("../data/qwen3_final_experiments/fixed_sum_norm_sweep")


def snr_label(snr: str) -> str:
    return f"snr{snr.replace('.', 'p')}db"


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    with path.open() as f:
        return json.load(f)


def find_ppl_result(snr_dir: Path, model_key: str, label: str, limit_samples: str | None) -> Path | None:
    if limit_samples:
        path = (
            snr_dir
            / "ppl"
            / f"util_fig5_limit{limit_samples}"
            / f"ppl_results_MXFP8_fixed_sum_{model_key}_{label}_util_fig5_limit{limit_samples}.json"
        )
        return path if path.is_file() else None

    matches = sorted(
        (snr_dir / "ppl").glob(
            f"util_fig5_limit*/ppl_results_MXFP8_fixed_sum_{model_key}_{label}_util_fig5_limit*.json"
        ),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return matches[0] if matches else None


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
        out[f"mean_{field}"] = round(mean(values), 6) if values else None
    return out


def summarize_one(root: Path, model_key: str, snr: str, limit_samples: str | None) -> dict[str, Any]:
    label = snr_label(snr)
    snr_dir = root / model_key / label
    cal_path = snr_dir / "calib" / f"calibration_MXFP8_fixed_sum_{model_key}_{label}.json"
    ppl_path = find_ppl_result(snr_dir, model_key, label, limit_samples)

    row: dict[str, Any] = {
        "model": model_key,
        "target_snr_db": snr,
        "label": label,
        "calibration": str(cal_path),
        "ppl_result": str(ppl_path) if ppl_path else "",
        "status": "missing",
    }

    cal = load_json(cal_path)
    if cal is not None:
        gcal = cal.get("global_summary", {})
        row.update(
            {
                "calibration_status": "ok",
                "calibration_layers": gcal.get("num_layers"),
                "calibration_channels": gcal.get("total_channels"),
                "calibration_budget_mean": gcal.get("budget_mean"),
                "calibration_eff_precision_mean": gcal.get("eff_precision_mean"),
                "calibration_min_snr": gcal.get("min_snr"),
                "calibration_wall_time_sec": gcal.get("wall_time_sec"),
            }
        )
    else:
        row["calibration_status"] = "missing"

    ppl = load_json(ppl_path) if ppl_path else None
    if ppl is None:
        return row

    metrics = ppl.get("metrics", {})
    reliability = ppl.get("reliability", {})
    performance = ppl.get("performance", {})
    config = ppl.get("config", {})
    msd = ppl.get("msd_perf_stats", {})
    g = msd.get("global", {})
    per_layer = msd.get("per_layer", {})
    mean_eff = g.get("mean_effective_precision")
    row.update(
        {
            "status": "ok",
            "token_perplexity": metrics.get("token_perplexity"),
            "mean_nll_nats": metrics.get("mean_nll_nats"),
            "scored_tokens": reliability.get("scored_tokens"),
            "num_chunks": reliability.get("num_chunks"),
            "limit_samples": config.get("limit_samples"),
            "world_size": config.get("world_size"),
            "wall_time_sec": performance.get("wall_time_sec"),
            "mean_effective_precision": mean_eff,
            "plot_norm_digit_read": round(float(mean_eff) / 3.0, 6) if mean_eff is not None else None,
            "global_utilization": g.get("global_utilization"),
            "hw_latency_overhead": g.get("hw_latency_overhead"),
            "mac_sparsity": g.get("mac_sparsity"),
            "zero_block_ratio": g.get("zero_block_ratio"),
            "max_budget": g.get("max_budget"),
            "max_total_delay": g.get("max_total_delay"),
        }
    )
    row.update(figure5_means(per_layer if isinstance(per_layer, dict) else {}))
    return row


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--models", default="qwen0_6b")
    parser.add_argument("--target-snrs", default="17 18 19")
    parser.add_argument("--limit-samples", default=None)
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    rows = [
        summarize_one(args.root, model, snr, args.limit_samples)
        for model in args.models.split()
        for snr in args.target_snrs.split()
    ]

    output_dir = args.output_dir or (args.root / "summaries")
    output_dir.mkdir(parents=True, exist_ok=True)
    suffix = f"limit{args.limit_samples}" if args.limit_samples else "latest"
    json_path = output_dir / f"fixed_sum_norm_sweep_{suffix}.json"
    tsv_path = output_dir / f"fixed_sum_norm_sweep_{suffix}.tsv"

    payload = {
        "root": str(args.root),
        "models": args.models.split(),
        "target_snrs": args.target_snrs.split(),
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
        "target_snr_db",
        "status",
        "token_perplexity",
        "mean_nll_nats",
        "scored_tokens",
        "num_chunks",
        "limit_samples",
        "mean_effective_precision",
        "plot_norm_digit_read",
        "global_utilization",
        "hw_latency_overhead",
        "mac_sparsity",
        "zero_block_ratio",
        "mean_avg_layer_cycle",
        "mean_avg_mean_channel_cycle",
        "mean_layer_cycle_std",
        "mean_avg_std_channel_cycle",
        "calibration_budget_mean",
        "calibration_eff_precision_mean",
        "calibration_min_snr",
        "wall_time_sec",
        "calibration_wall_time_sec",
        "ppl_result",
        "calibration",
    )
    with tsv_path.open("w") as f:
        f.write("\t".join(columns) + "\n")
        for row in rows:
            f.write("\t".join("" if row.get(col) is None else str(row.get(col, "")) for col in columns) + "\n")

    print(f"Summary JSON: {json_path}")
    print(f"Summary TSV : {tsv_path}")
    print(f"OK rows: {payload['counts']['ok']} / {len(rows)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Summarize sampled fixed-sum norm and N:M sparsity sweep outputs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean
from typing import Any


DEFAULT_ROOT = Path("../data/qwen3_final_experiments/sparsity_norm_sweep300")


def snr_label(snr: str) -> str:
    return f"snr{snr.replace('.', 'p')}db"


def parse_nm_points(raw: str) -> list[tuple[int, int]]:
    points: list[tuple[int, int]] = []
    for token in raw.split():
        if ":" not in token:
            raise SystemExit(f"Invalid N:M point '{token}'. Use forms like 2:4.")
        n_raw, m_raw = token.split(":", 1)
        n, m = int(n_raw), int(m_raw)
        if m <= 0 or n < 0 or n > m:
            raise SystemExit(f"Invalid N:M point '{token}'.")
        points.append((n, m))
    return points


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    with path.open() as f:
        return json.load(f)


def figure5_means(per_layer: dict[str, Any]) -> dict[str, float | None]:
    out: dict[str, float | None] = {}
    for field in (
        "avg_layer_cycle",
        "avg_mean_channel_cycle",
        "layer_cycle_std",
        "avg_std_channel_cycle",
    ):
        values = [
            float(layer[field])
            for layer in per_layer.values()
            if isinstance(layer, dict) and layer.get(field) is not None
        ]
        out[f"mean_{field}"] = round(mean(values), 6) if values else None
    return out


def result_fields(path: Path) -> dict[str, Any]:
    data = load_json(path)
    if data is None:
        return {"status": "missing", "output": str(path)}

    metrics = data.get("metrics", {})
    reliability = data.get("reliability", {})
    performance = data.get("performance", {})
    config = data.get("config", {})
    msd = data.get("msd_perf_stats", {})
    global_stats = msd.get("global", {}) if isinstance(msd, dict) else {}
    per_layer = msd.get("per_layer", {}) if isinstance(msd, dict) else {}
    mean_eff = global_stats.get("mean_effective_precision")

    row: dict[str, Any] = {
        "status": "ok",
        "token_perplexity": metrics.get("token_perplexity"),
        "mean_nll_nats": metrics.get("mean_nll_nats"),
        "scored_tokens": reliability.get("scored_tokens"),
        "num_chunks": reliability.get("num_chunks"),
        "limit_samples": config.get("limit_samples"),
        "world_size": config.get("world_size"),
        "wall_time_sec": performance.get("wall_time_sec"),
        "peak_memory": performance.get("peak_memory"),
        "mean_effective_precision": mean_eff,
        "plot_norm_digit_read": round(float(mean_eff) / 3.0, 6) if mean_eff is not None else None,
        "global_utilization": global_stats.get("global_utilization"),
        "hw_latency_overhead": global_stats.get("hw_latency_overhead"),
        "mac_sparsity": global_stats.get("mac_sparsity"),
        "zero_block_ratio": global_stats.get("zero_block_ratio"),
        "output": str(path),
    }
    row.update(figure5_means(per_layer if isinstance(per_layer, dict) else {}))
    return row


def fixed_sum_row(root: Path, model: str, snr: str, limit_samples: str) -> dict[str, Any]:
    label = snr_label(snr)
    path = (
        root
        / "fixed_sum"
        / model
        / label
        / "ppl"
        / f"stats_limit{limit_samples}"
        / f"ppl_results_MXFP8_fixed_sum_{model}_{label}_stats_limit{limit_samples}.json"
    )
    row = {
        "model": model,
        "family": "fixed_sum",
        "point": f"snr{snr}",
        "target_snr_db": snr,
        "nm_keep": "",
        "x_value": "",
        "x_metric": "plot_norm_digit_read",
    }
    row.update(result_fields(path))
    if row.get("plot_norm_digit_read") is not None:
        row["x_value"] = row["plot_norm_digit_read"]
    return row


def baseline_row(root: Path, family: str, model: str, n: int, m: int) -> dict[str, Any]:
    nm_dir = f"{n}-{m}"
    keep_ratio = round(n / m, 6)
    if family == "wanda":
        path = (
            root
            / "baselines"
            / model
            / "wanda_base"
            / nm_dir
            / f"ppl_results_MXFP8_{model}_sweep300.json"
        )
    elif family == "act":
        path = root / "baselines" / model / "act_base" / nm_dir / "ppl_results_MXFP8.json"
    else:
        raise ValueError(f"Unsupported baseline family: {family}")

    row = {
        "model": model,
        "family": family,
        "point": f"{n}:{m}",
        "target_snr_db": "",
        "nm_keep": f"{n}:{m}",
        "x_value": keep_ratio,
        "x_metric": "keep_ratio",
    }
    row.update(result_fields(path))
    return row


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--models", default="qwen8b qwen4b qwen1_7b")
    parser.add_argument("--target-snrs", default="15 17 20")
    parser.add_argument("--nm", default="1:4 2:4 3:4")
    parser.add_argument("--limit-samples", default="300")
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    models = args.models.split()
    nm_points = parse_nm_points(args.nm)
    rows: list[dict[str, Any]] = []
    for model in models:
        for snr in args.target_snrs.split():
            rows.append(fixed_sum_row(args.root, model, snr, args.limit_samples))
        for family in ("wanda", "act"):
            for n, m in nm_points:
                rows.append(baseline_row(args.root, family, model, n, m))

    output_dir = args.output_dir or (args.root / "summaries")
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / f"sparsity_norm_sweep_limit{args.limit_samples}.json"
    tsv_path = output_dir / f"sparsity_norm_sweep_limit{args.limit_samples}.tsv"

    payload = {
        "root": str(args.root),
        "models": models,
        "target_snrs": args.target_snrs.split(),
        "nm_points": [f"{n}:{m}" for n, m in nm_points],
        "limit_samples": args.limit_samples,
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
        "family",
        "point",
        "target_snr_db",
        "nm_keep",
        "x_metric",
        "x_value",
        "status",
        "token_perplexity",
        "mean_nll_nats",
        "scored_tokens",
        "num_chunks",
        "limit_samples",
        "world_size",
        "wall_time_sec",
        "peak_memory",
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

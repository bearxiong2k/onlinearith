#!/usr/bin/env python3
"""Index the local, immutable result snapshots without running experiments.

Only the catalog is generated. Source JSONs and manuscript figures are never
rewritten. No sibling repository, model, dataset, or third-party package is used.
"""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path


def main() -> None:
    evidence = Path(__file__).resolve().parent
    repo = evidence.parents[2]
    manifest = json.loads((evidence / "manifest.json").read_text())
    rows = []
    for entry in manifest["entries"]:
        path = repo / entry["destination_path"]
        payload = path.read_bytes()
        if len(payload) != entry["size_bytes"] or hashlib.sha256(payload).hexdigest() != entry["sha256"]:
            raise ValueError(f"Snapshot integrity mismatch: {path}")
        if path.suffix != ".json":
            continue
        result = json.loads(payload)
        if not isinstance(result, dict) or not isinstance(result.get("metrics"), dict):
            continue
        config = result.get("config", {})
        snapshot = result.get("config_snapshot", {})
        stats = result.get("msd_perf_stats", {}).get("global", {})
        precision = stats.get("mean_effective_precision")
        limit = config.get("limit_samples")
        category = entry["category"]
        if category.startswith("historical_"):
            scope = "historical_scope_requires_review"
        elif limit is not None:
            scope = f"limit_samples_{limit}"
        elif category in {"full_ppl_scale", "full_ppl_or_sampled_work_17db", "rebuttal_quality_or_sensitivity"}:
            scope = "full_test"
        else:
            scope = "scope_requires_review"
        rows.append({
            "source_root": entry["source_root"],
            "source_path": entry["source_path"],
            "snapshot_path": str(path.relative_to(evidence)),
            "category": category,
            "scope": scope,
            "model": result.get("model"),
            "dataset": result.get("dataset"),
            "max_length": config.get("max_length"),
            "stride": config.get("stride"),
            "limit_samples": limit,
            "text_manifest": config.get("text_manifest"),
            "token_perplexity": result["metrics"].get("token_perplexity"),
            "scored_tokens": result.get("reliability", {}).get("scored_tokens"),
            "num_chunks": result.get("reliability", {}).get("num_chunks"),
            "stats_mode": config.get("stats"),
            "mean_effective_precision": precision,
            "executed_digit_ratio": precision / 3.0 if precision is not None else None,
            "use_mxfp8": snapshot.get("use_mxfp8"),
            "mxfp8_block_size": snapshot.get("mxfp8_block_size"),
            "use_msd_truncation": snapshot.get("use_msd_truncation"),
            "sha256": entry["sha256"],
        })
    if not rows:
        raise ValueError("No result snapshots found")
    with (evidence / "result_catalog.tsv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]), delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Verified {len(manifest['entries'])} snapshots; indexed {len(rows)} PPL results.")


if __name__ == "__main__":
    main()

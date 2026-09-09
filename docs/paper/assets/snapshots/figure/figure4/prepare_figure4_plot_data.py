#!/usr/bin/env python3
"""Prepare manually editable Figure 4 plot-data CSV from raw extracted CSV.

Step 1:
    python prepare_figure4_plot_data.py

This script converts figure4_data.csv into figure4_plot_data.csv with a
plot-centric schema (x/y/labels/connect groups). You can then manually remove
rows or set include=0 before plotting.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Any


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if text == "":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _to_int(value: Any) -> int | None:
    fv = _to_float(value)
    if fv is None:
        return None
    return int(fv)


def _load_raw_rows(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(dict(row))
    return rows


def _line_group(family: str) -> str:
    if family in {"fixed_sum", "uniform", "target_snr"}:
        return family
    return ""


def _marker_style(family: str) -> str:
    if family == "fixed_sum":
        return "o"
    if family == "uniform":
        return "s"
    if family == "target_snr":
        return "^"
    if family == "dense":
        return "*"
    if family == "activation":
        return "^"
    if family == "wanda":
        return "D"
    return "o"


def _line_style(family: str) -> str:
    if family == "fixed_sum":
        return "solid"
    if family == "uniform":
        return "solid"
    if family == "target_snr":
        return "dashed"
    return "none"


def _point_label(row: dict[str, Any]) -> str:
    family = str(row.get("family", ""))
    if family == "uniform":
        horizon = _to_int(row.get("horizon_B"))
        return f"H={horizon}" if horizon is not None else "uniform"
    if family == "target_snr":
        db = _to_int(row.get("db"))
        return f"{db}db" if db is not None else "snr"
    if family == "fixed_sum":
        db = _to_int(row.get("db"))
        return f"{db}db" if db is not None else "fixed"
    if family in {"activation", "wanda"}:
        n = _to_int(row.get("n"))
        m = _to_int(row.get("m"))
        if n is not None and m is not None:
            prefix = "act" if family == "activation" else "wanda"
            return f"{prefix} {n}:{m}"
        return family
    if family == "dense":
        return "dense"
    return str(row.get("method_label", ""))


def _nm_label(row: dict[str, Any]) -> str:
    family = str(row.get("family", ""))
    if family not in {"activation", "wanda"}:
        return ""
    n = _to_int(row.get("n"))
    m = _to_int(row.get("m"))
    if n is None or m is None:
        return ""
    return f"{n}:{m}"


def _connect_order(row: dict[str, Any]) -> float:
    family = str(row.get("family", ""))
    if family in {"fixed_sum", "target_snr"}:
        db = _to_float(row.get("db"))
        if db is not None:
            return db
    if family == "uniform":
        hb = _to_float(row.get("horizon_B"))
        if hb is not None:
            return hb
    x = _to_float(row.get("plot_norm_digit_read"))
    return x if x is not None else 0.0


def _project_row(raw: dict[str, Any]) -> dict[str, Any] | None:
    family = str(raw.get("family", ""))
    x = _to_float(raw.get("plot_norm_digit_read"))
    y = _to_float(raw.get("plot_ppl"))

    # n:m means n pruned in each group of m, so plotted work fraction is kept part.
    if family in {"activation", "wanda"}:
        n_val = _to_float(raw.get("n"))
        m_val = _to_float(raw.get("m"))
        if n_val is not None and m_val is not None and m_val != 0:
            x = (m_val - n_val) / m_val

    if x is None or y is None:
        return None

    line_group = _line_group(family)
    connect_order = _connect_order(raw)
    if family in {"activation", "wanda"}:
        connect_order = x

    return {
        "include": 1,
        "family": family,
        "method_label": str(raw.get("method_label", "")),
        "operating_point": str(raw.get("operating_point", "")),
        "x": x,
        "y": y,
        "line_group": line_group,
        "connect_order": connect_order,
        "point_label": _point_label(raw),
        "nm_label": _nm_label(raw),
        "n": _to_int(raw.get("n")),
        "m": _to_int(raw.get("m")),
        "horizon_B": _to_int(raw.get("horizon_B")),
        "db": _to_int(raw.get("db")),
        "marker_style": _marker_style(family),
        "line_style": _line_style(family),
        "source": str(raw.get("plot_source", "")),
    }


def _sort_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    family_order = {
        "fixed_sum": 0,
        "uniform": 1,
        "target_snr": 2,
        "dense": 3,
        "activation": 4,
        "wanda": 5,
    }
    return sorted(
        rows,
        key=lambda r: (
            family_order.get(str(r.get("family", "")), 99),
            float(r.get("connect_order", 0.0)),
            float(r.get("x", 0.0)),
            str(r.get("point_label", "")),
        ),
    )


def _write_rows(path: Path, rows: list[dict[str, Any]]) -> None:
    fieldnames = [
        "include",
        "family",
        "method_label",
        "operating_point",
        "x",
        "y",
        "line_group",
        "connect_order",
        "point_label",
        "nm_label",
        "n",
        "m",
        "horizon_B",
        "db",
        "marker_style",
        "line_style",
        "source",
    ]

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            out_row: dict[str, Any] = {}
            for key in fieldnames:
                value = row.get(key)
                out_row[key] = "" if value is None else value
            writer.writerow(out_row)


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare Figure 4 plot-data CSV")
    parser.add_argument(
        "--raw-csv",
        type=str,
        default=str(Path(__file__).resolve().parent / "figure4_data.csv"),
        help="Input raw CSV from extract_figure4_data.py",
    )
    parser.add_argument(
        "--output-csv",
        type=str,
        default=str(Path(__file__).resolve().parent / "figure4_plot_data.csv"),
        help="Output manually editable plot-data CSV",
    )
    args = parser.parse_args()

    raw_path = Path(args.raw_csv).expanduser().resolve()
    out_path = Path(args.output_csv).expanduser().resolve()
    if not raw_path.exists():
        raise FileNotFoundError(f"Raw CSV not found: {raw_path}")

    raw_rows = _load_raw_rows(raw_path)
    plot_rows: list[dict[str, Any]] = []
    for row in raw_rows:
        projected = _project_row(row)
        if projected is not None:
            plot_rows.append(projected)

    plot_rows = _sort_rows(plot_rows)
    _write_rows(out_path, plot_rows)

    print(f"[figure4] wrote plot-data CSV: {out_path}")
    print(f"[figure4] rows: {len(plot_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

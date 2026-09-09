#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Any

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

CONFIG: dict[str, Any] = {
    "input_csv": "figure5_plot_data.csv",
    "output_png": "figure5_revised.png",
    "output_pdf": "figure5_revised.pdf",
    "dpi": 300,
    "figure_size": (3.45, 4.55),
    "matched_uniform_horizons": [8, 9, 10],
    "top_xlim": (0.30, 0.85),
    "top_ylim": (0.72, 1.02),
    "bottom_ylim": (0.0, 0.28),
    "top_legend": {
        "labels": ["Layer-wise L2", "Uniform horizon", "Dense MX"],
        "loc": "upper right",
        "bbox_to_anchor": (0.98, 0.84),
        "handlelength": 2.2,
        "borderaxespad": 0.2,
    },
    "bottom_legend": {
        "whole_block_label": "Whole-block skip",
        "partial_window_label": "Partial window exec.",
        "loc": "upper center",
        "bbox_to_anchor": (0.5, 1.15),
        "ncol": 2,
        "handlelength": 1.6,
    },
    "style": {
        "layerwise": "#10233f",
        "uniform": "#6f8098",
        "dense": "#2d3748",
        "whole_block": "#8bb8f8",
        "partial_window": "#eeaa2d",
        "grid": "#d2d8e0",
        "spine": "#4a5568",
        "text": "#2d3748",
    },
}


def apply_paper_style() -> None:
    mpl.rcParams.update(
        {
            "font.size": 8,
            "axes.labelsize": 9,
            "legend.fontsize": 8,
            "xtick.labelsize": 8,
            "ytick.labelsize": 8,
            "axes.spines.top": True,
            "axes.spines.right": True,
            "axes.linewidth": 0.8,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "savefig.bbox": "tight",
        }
    )



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



def _is_enabled(value: Any) -> bool:
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "t", "yes", "y"}



def _load_rows(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            if not _is_enabled(raw.get("include", "1")):
                continue
            family = str(raw.get("family", "")).strip()
            x = _to_float(raw.get("x_norm_digit_read"))
            actual = _to_float(raw.get("actual_total_cycle"))
            dense_max = _to_float(raw.get("dense_max_total_cycle"))
            zero_block = _to_float(raw.get("zero_block_contribution"))
            partial_window = _to_float(raw.get("partial_window_contribution"))
            if None in {x, actual, dense_max, zero_block, partial_window}:
                continue
            rows.append(
                {
                    "family": family,
                    "x": x,
                    "actual_total_cycle": actual,
                    "dense_max_total_cycle": dense_max,
                    "actual_over_dense_max": _to_float(raw.get("actual_over_dense_max")) or (actual / dense_max),
                    "zero_block_norm": zero_block / dense_max,
                    "partial_window_norm": partial_window / dense_max,
                    "saved_norm": (zero_block + partial_window) / dense_max,
                    "point_label": str(raw.get("point_label", "")).strip(),
                    "horizon": _to_int(raw.get("horizon_B")),
                    "db": _to_int(raw.get("db")),
                }
            )
    return rows



def _nearest_layerwise(uniform_row: dict[str, Any], layerwise_rows: list[dict[str, Any]]) -> dict[str, Any]:
    return min(layerwise_rows, key=lambda r: abs(float(r["x"]) - float(uniform_row["x"])))



def _style_axes(ax: Any, config: dict[str, Any]) -> None:
    style = config["style"]
    for spine in ["left", "bottom", "top", "right"]:
        ax.spines[spine].set_color(style["spine"])
        ax.spines[spine].set_linewidth(0.8)
    ax.grid(axis="y", color=style["grid"], linestyle=(0, (1.2, 2.4)), linewidth=0.7)
    ax.grid(axis="x", color=style["grid"], linestyle=(0, (1.2, 2.4)), linewidth=0.7)

    ax.tick_params(direction="out", length=3, width=0.8, color=style["spine"])



def _draw_top_panel(ax: Any, rows: list[dict[str, Any]], config: dict[str, Any]) -> None:
    style = config["style"]
    top_legend = config["top_legend"]
    uniform = sorted([r for r in rows if r["family"] == "uniform"], key=lambda r: float(r["x"]))
    layerwise = sorted([r for r in rows if r["family"] == "fixed_sum"], key=lambda r: float(r["x"]))

    dense_handle = ax.axhline(1.0, color=style["dense"], linewidth=1.0, linestyle=(0, (5, 5)), zorder=4)

    layerwise_handle, = ax.plot(
        [r["x"] for r in layerwise],
        [r["actual_over_dense_max"] for r in layerwise],
        color=style["layerwise"],
        linewidth=1.9,
        marker="o",
        markersize=3.6,
        zorder=3,
    )
    uniform_handle, = ax.plot(
        [r["x"] for r in uniform],
        [r["actual_over_dense_max"] for r in uniform],
        color=style["uniform"],
        linewidth=1.3,
        linestyle=(0, (2, 2)),
        marker="s",
        markerfacecolor="white",
        markeredgecolor=style["uniform"],
        markeredgewidth=1.0,
        markersize=4.0,
        zorder=2,
    )

    # Minimal point labels to keep the panel readable in half-column layout.
    for row in uniform:
        if row.get("horizon") in {8, 9, 10}:
            ax.annotate(
                f"H={row['horizon']}",
                xy=(row["x"], row["actual_over_dense_max"]),
                xytext=(4, 4),
                textcoords="offset points",
                fontsize=7,
                color=style["uniform"],
            )
    for row in layerwise:
        if row.get("db") in {14, 19, 25}:
            ax.annotate(
                f"{row['db']} dB",
                xy=(row["x"], row["actual_over_dense_max"]),
                xytext=(4, -11),
                textcoords="offset points",
                fontsize=7,
                color=style["layerwise"],
            )

    ax.legend(
        [layerwise_handle, uniform_handle, dense_handle],
        top_legend["labels"],
        loc=top_legend["loc"],
        bbox_to_anchor=tuple(top_legend["bbox_to_anchor"]),
        frameon=False,
        handlelength=top_legend["handlelength"],
        borderaxespad=top_legend["borderaxespad"],
    )

    ax.set_xlim(*tuple(config["top_xlim"]))
    ax.set_ylim(*tuple(config["top_ylim"]))
    ax.set_ylabel("Normalized FFN latency")
    ax.set_xlabel("Executed-digit ratio")
    _style_axes(ax, config)



def _draw_bottom_panel(ax: Any, rows: list[dict[str, Any]], config: dict[str, Any]) -> None:
    style = config["style"]
    bottom_legend = config["bottom_legend"]
    uniform_rows = sorted([r for r in rows if r["family"] == "uniform"], key=lambda r: int(r.get("horizon") or 0))
    layerwise_rows = sorted([r for r in rows if r["family"] == "fixed_sum"], key=lambda r: float(r["x"]))

    matched_rows: list[dict[str, Any]] = []
    for horizon in config["matched_uniform_horizons"]:
        candidates = [r for r in uniform_rows if r.get("horizon") == horizon]
        if not candidates:
            continue
        u = candidates[0]
        l2 = _nearest_layerwise(u, layerwise_rows)
        matched_rows.extend([u, l2])

    xs = [0.0, 0.9, 2.3, 3.2, 4.6, 5.5][: len(matched_rows)]
    bar_labels: list[str] = []
    for row in matched_rows:
        if row["family"] == "uniform":
            bar_labels.append(f"H={row['horizon']}")
        else:
            bar_labels.append(f"{row['db']} dB")

    edge_colors = [style["uniform"] if r["family"] == "uniform" else style["layerwise"] for r in matched_rows]
    face_alpha = [0.95 if r["family"] == "uniform" else 1.0 for r in matched_rows]

    for x, row, edge_color, alpha in zip(xs, matched_rows, edge_colors, face_alpha):
        ax.bar(
            x,
            row["zero_block_norm"],
            width=0.62,
            color=style["whole_block"],
            edgecolor=edge_color,
            linewidth=0.9,
            alpha=alpha,
            zorder=3,
        )
        ax.bar(
            x,
            row["partial_window_norm"],
            bottom=row["zero_block_norm"],
            width=0.62,
            color=style["partial_window"],
            edgecolor=edge_color,
            linewidth=0.9,
            alpha=alpha,
            zorder=3,
        )

    # Group labels for matched-work anchors.
    pair_centers: list[float] = []
    pair_texts: list[str] = []
    for idx in range(0, len(matched_rows), 2):
        if idx + 1 >= len(matched_rows):
            break
        pair_centers.append((xs[idx] + xs[idx + 1]) / 2.0)
        ref_x = 0.5 * (matched_rows[idx]["x"] + matched_rows[idx + 1]["x"])
        pair_texts.append(f"~{ref_x:.2f} work")
    for xc, txt in zip(pair_centers, pair_texts):
        ax.text(xc, config["bottom_ylim"][1] * 0.98, txt, ha="center", va="top", fontsize=7, color=style["text"])

    ax.set_xticks(xs)
    ax.set_xticklabels(bar_labels)
    ax.set_ylim(*tuple(config["bottom_ylim"]))
    ax.set_ylabel("Speedup breakdown \n (over Dense MX)")
    _style_axes(ax, config)

    handles = [
        Patch(facecolor=style["whole_block"], edgecolor="#4a5568", label=bottom_legend["whole_block_label"]),
        Patch(facecolor=style["partial_window"], edgecolor="#4a5568", label=bottom_legend["partial_window_label"]),
    ]
    ax.legend(
        handles=handles,
        loc=bottom_legend["loc"],
        bbox_to_anchor=tuple(bottom_legend["bbox_to_anchor"]),
        frameon=False,
        ncol=bottom_legend["ncol"],
        handlelength=bottom_legend["handlelength"],
    )



def _draw(config: dict[str, Any], rows: list[dict[str, Any]], output_path: Path, dpi: int) -> None:
    apply_paper_style()
    fig, axes = plt.subplots(2, 1, figsize=tuple(config["figure_size"]), constrained_layout=True)

    _draw_top_panel(axes[0], rows, config)
    _draw_bottom_panel(axes[1], rows, config)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi)
    plt.close(fig)



def main() -> int:
    parser = argparse.ArgumentParser(description="ICCAD-style Figure 5 plot")
    parser.add_argument("--csv", type=str, default=str(Path(__file__).resolve().parent / CONFIG["input_csv"]))
    parser.add_argument("--output", type=str, default=str(Path(__file__).resolve().parent / CONFIG["output_pdf"]))
    parser.add_argument("--dpi", type=int, default=int(CONFIG["dpi"]))
    args = parser.parse_args()

    csv_path = Path(args.csv).expanduser().resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found: {csv_path}")

    rows = _load_rows(csv_path)
    _draw(dict(CONFIG), rows, Path(args.output).expanduser().resolve(), int(args.dpi))
    print(f"[figure5 revised] wrote plot: {Path(args.output).expanduser().resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Any

import matplotlib as mpl
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

CONFIG: dict[str, Any] = {
    "panel_a_csv": "figure6_panel_a_data.csv",
    "panel_b_csv": "figure6_panel_b_data.csv",
    "panel_c_csv": "figure6_panel_c_data.csv",
    "output_png": "figure6_revised.png",
    "output_pdf": "figure6_revised.pdf",
    "dpi": 300,
    "figure_size": (4.6,5.5),
    "a_xlim": (11.5, 25.5),
    "a_ylim": (0.3, 0.77),
    "b_xlim": (0.0, 5800.0),
    "b_ylim": (18.2, 28.6),
    "b_inset_xlim": (350.0, 5800.0),
    "b_inset_ylim": (18.28, 18.76),
    "c_main_ylim": (17.8, 20.7),
    "c_outlier_ylim": (1280.0, 1520.0),
    "annotation_fontsize": 8.0,
    "style": {
        "layerwise": "#000000",
        "channelwise": "#7a8ba6",
        "uniform": "#7A7A7A",
        "weight_only": "#d17a22",
        "activation_plus_weight": "#2a7fb8",
        "grid": "#d2d8e0",
        "spine": "#4a5568",
        "text": "#2d3748",
    },
}

METHOD_COLORS = {
    "Uniform": "uniform",
    "Weightonly": "weight_only",
    "Weight+Activation-layerwise": "activation_plus_weight",
    "Weight+Actibation-channelwise": "channelwise",
}

METHOD_SHORT_LABELS = {
    "Uniform": "Uniform",
    "Weightonly": "W-only",
    "Weight+Activation-layerwise": "A+W (L)",
    "Weight+Actibation-channelwise": "A+W (C)",
}


def apply_paper_style() -> None:
    mpl.rcParams.update(
        {
            "font.size": 8,
            "axes.labelsize": 9,
            "axes.titlesize": 9,
            "legend.fontsize": 7,
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



def _load_csv(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(dict(row))
    return rows



def _style_axes(ax: Any, config: dict[str, Any]) -> None:
    style = config["style"]
    for spine in ["left", "bottom", "top", "right"]:
        ax.spines[spine].set_color(style["spine"])
        ax.spines[spine].set_linewidth(0.8)
    ax.grid(axis="y", color=style["grid"], linestyle=(0, (1.2, 2.4)), linewidth=0.7)
    ax.grid(axis="x", color=style["grid"], linestyle=(0, (1.2, 2.4)), linewidth=0.7)

    ax.tick_params(direction="out", length=3, width=0.8, color=style["spine"])



def _align_panel_c_with_panel_b(
    ax_b: Any,
    ax_c_low: Any,
    ax_c_high: Any,
    *,
    top_weight: float = 1.0,
    bottom_weight: float = 2.0,
    gap_fraction: float = 0.05,
) -> None:
    """Align panel C (high+low) as one footprint with panel B."""
    b_pos = ax_b.get_position()
    c_low_pos = ax_c_low.get_position()

    # Keep C centered in its grid column, but enforce B-matched total height.
    width = c_low_pos.width
    x0 = c_low_pos.x0
    y0 = b_pos.y0
    total_h = b_pos.height

    weights = max(top_weight + bottom_weight, 1e-6)
    gap_h = total_h * gap_fraction
    usable_h = max(total_h - gap_h, total_h * 0.7)
    high_h = usable_h * (top_weight / weights)
    low_h = usable_h - high_h

    ax_c_low.set_position([x0, y0, width, low_h])
    ax_c_high.set_position([x0, y0 + low_h + gap_h, width, high_h])





def _draw_panel_a(ax: Any, rows: list[dict[str, Any]], config: dict[str, Any]) -> None:
    style = config["style"]
    ann_fs = float(config.get("annotation_fontsize", 8.0))
    layerwise = []
    uniform_refs = []
    for row in rows:
        family = str(row.get("family", "")).strip()
        if family == "fixed_sum":
            x = _to_float(row.get("target_snr_db"))
            y = _to_float(row.get("norm_digit_read"))
            if x is None or y is None:
                continue
            point = {
                "x": x,
                "y": y,
                "label": str(row.get("point_label", "")).strip(),
            }
            layerwise.append(point)
        elif family == "uniform":
            y = _to_float(row.get("norm_digit_read"))
            h = _to_float(row.get("uniform_horizon_B"))
            if y is None:
                continue
            uniform_refs.append({"y": y, "h": h})

    layerwise.sort(key=lambda r: float(r["x"]))

    for snr in range(12, 26, 2):
        ax.axvline(snr, color=style["grid"], linewidth=0.55, linestyle=(0, (1.0, 3.0)), zorder=0)

    bar_base = float(config["a_ylim"][0])
    ax.bar(
        [r["x"] for r in layerwise],
        [max(r["y"] - bar_base, 0.0) for r in layerwise],
        bottom=bar_base,
        width=0.52,
        color=style["layerwise"],
        edgecolor=style["layerwise"],
        linewidth=0.6,
        alpha=0.24,
        zorder=2,
    )

    y_min, y_max = tuple(config["a_ylim"])
    x_min, x_max = tuple(config["a_xlim"])
    refs_in_view = [r for r in uniform_refs if y_min <= float(r["y"]) <= y_max]
    refs_in_view.sort(key=lambda r: float(r["y"]))
    for ref in refs_in_view:
        y = float(ref["y"])
        h = ref["h"]
        ax.axhline(y, color=style["uniform"], linewidth=0.9, linestyle=(0, (4.0, 2.5)), alpha=0.9, zorder=1)
        if h is not None:
            ax.text(
                x_min + 0.15,
                y + 0.004,
                f"Uniform H={int(h)}",
                ha="left",
                va="bottom",
                fontsize=max(ann_fs - 0.5, 6.5),
                color=style["uniform"],
                zorder=4,
            )


    ax.set_xlim(*tuple(config["a_xlim"]))
    ax.set_ylim(*tuple(config["a_ylim"]))
    ax.set_xticks([12, 14, 16, 18, 20, 22, 24, 25])
    ax.set_ylabel("Executed-digit ratio")
    ax.set_xlabel("Target SNR (dB)", labelpad=1)
    ax.tick_params(axis="x", pad=1)
    _style_axes(ax, config)



def _draw_panel_b(ax: Any, rows: list[dict[str, Any]], config: dict[str, Any]) -> None:
    style = config["style"]
    points = []
    for row in rows:
        x = _to_float(row.get("cal_size_tokens"))
        y = _to_float(row.get("ppl_quant"))
        if x is None or y is None:
            continue
        points.append({"x": x, "y": y, "tokens": _to_float(row.get("cal_size_tokens"))})
    points.sort(key=lambda r: float(r["x"]))

    xs = [p["x"] for p in points]
    ys = [p["y"] for p in points]

    ax.plot(xs, ys, color=style["layerwise"], linewidth=1.6, zorder=2)
    ax.scatter(xs, ys, s=22, color=style["layerwise"], edgecolors="white", linewidths=0.5, zorder=3)


    axins = inset_axes(ax, width="44%", height="45%", loc="upper right", borderpad=0.7)
    axins.plot(xs[1:], ys[1:], color=style["layerwise"], linewidth=1.2, zorder=2)
    axins.scatter(xs[1:], ys[1:], s=16, color=style["layerwise"], edgecolors="white", linewidths=0.4, zorder=3)
    axins.set_xlim(*tuple(config["b_inset_xlim"]))
    axins.set_ylim(*tuple(config["b_inset_ylim"]))
    axins.tick_params(labelsize=7)
    _style_axes(axins, config)

    ax.set_xlim(*tuple(config["b_xlim"]))
    ax.set_ylim(*tuple(config["b_ylim"]))
    ax.set_ylabel("Perplexity")
    ax.set_xlabel("Calibration token number", labelpad=1)
    _style_axes(ax, config)



def _draw_panel_c(ax_low: Any, ax_high: Any, rows: list[dict[str, Any]], config: dict[str, Any]) -> None:
    style = config["style"]
    ann_fs = float(config.get("annotation_fontsize", 8.0))
    order = [
        "Uniform",
        "Weightonly",
        "Weight+Activation-layerwise",
        "Weight+Actibation-channelwise",
    ]

    bars = []
    for key in order:
        for row in rows:
            if str(row.get("method_key", "")).strip() == key:
                val = _to_float(row.get("ppl"))
                if val is not None:
                    bars.append({"key": key, "value": val})
                break

    colors = [style[METHOD_COLORS[b["key"]]] for b in bars]
    values = [b["value"] for b in bars]
    labels_short = [METHOD_SHORT_LABELS[b["key"]] for b in bars]

    xs = list(range(len(bars)))
    ax_low.bar(xs, values, color=colors, edgecolor=style["spine"], linewidth=0.8, zorder=3)
    ax_high.bar(xs, values, color=colors, edgecolor=style["spine"], linewidth=0.8, zorder=3)

    main_ylim = tuple(config["c_main_ylim"])
    outlier_ylim = tuple(config["c_outlier_ylim"])
    ax_low.set_ylim(*main_ylim)
    ax_high.set_ylim(*outlier_ylim)

    for x, value in zip(xs, values):
        if value <= main_ylim[1]:
            ax_low.text(x, value + 0.06, f"{value:.2f}", ha="center", va="bottom", fontsize=ann_fs, color=style["text"])
        elif value >= outlier_ylim[0]:
            ax_high.text(x, min(value + 7.0, outlier_ylim[1] - 4.0), f"{value:.1f}", ha="center", va="bottom", fontsize=ann_fs, color=style["text"])

    ax_low.set_xticks(xs)
    ax_low.set_xticklabels(labels_short, rotation=30, ha="right")
    ax_low.tick_params(axis="x", pad=1)
    ax_high.tick_params(bottom=False, labelbottom=False)
    ax_low.set_ylabel("Perplexity")

    _style_axes(ax_low, config)
    _style_axes(ax_high, config)

    ax_high.spines["bottom"].set_visible(False)
    ax_low.spines["top"].set_visible(False)
    ax_high.grid(axis="x", visible=False)
    ax_low.grid(axis="x", visible=False)

    d = 0.014
    kwargs = dict(transform=ax_high.transAxes, color=style["spine"], clip_on=False, linewidth=0.8)
    ax_high.plot((-d, +d), (-d, +d), **kwargs)
    ax_high.plot((1 - d, 1 + d), (-d, +d), **kwargs)
    kwargs.update(transform=ax_low.transAxes)
    ax_low.plot((-d, +d), (1 - d, 1 + d), **kwargs)
    ax_low.plot((1 - d, 1 + d), (1 - d, 1 + d), **kwargs)




def _draw(config: dict[str, Any], rows_a: list[dict[str, Any]], rows_b: list[dict[str, Any]], rows_c: list[dict[str, Any]], output_path: Path, dpi: int) -> None:
    apply_paper_style()
    fig = plt.figure(figsize=tuple(config["figure_size"]), constrained_layout=False)
    grid = fig.add_gridspec(2, 2, height_ratios=[0.7, 1.0], hspace=0.03, wspace=0.4)

    ax_a = fig.add_subplot(grid[0, :])
    ax_b = fig.add_subplot(grid[1, 0])
    grid_c = grid[1, 1].subgridspec(2, 1, height_ratios=[1, 4], hspace=0.0)
    ax_c_high = fig.add_subplot(grid_c[0, 0])
    ax_c_low = fig.add_subplot(grid_c[1, 0], sharex=ax_c_high)

    # Keep panel B square while stretching panel A across the full width.
    ax_a.set_box_aspect(0.34)
    ax_b.set_box_aspect(1.0)



    _draw_panel_a(ax_a, rows_a, config)
    _draw_panel_b(ax_b, rows_b, config)
    _draw_panel_c(ax_c_low, ax_c_high, rows_c, config)

    # Manual spacing gives direct control over inter-row distance.
    fig.subplots_adjust(left=0.11, right=0.985, top=0.785, bottom=0.09, hspace=0.1, wspace=0.12)

    # Override subgridspec auto geometry so C-high+C-low match B as one panel.
    _align_panel_c_with_panel_b(ax_b, ax_c_low, ax_c_high)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi)
    plt.close(fig)



def main() -> int:
    parser = argparse.ArgumentParser(description="ICCAD-style Figure 6 plot")
    parser.add_argument("--panel-a-csv", type=str, default=str(Path(__file__).resolve().parent / CONFIG["panel_a_csv"]))
    parser.add_argument("--panel-b-csv", type=str, default=str(Path(__file__).resolve().parent / CONFIG["panel_b_csv"]))
    parser.add_argument("--panel-c-csv", type=str, default=str(Path(__file__).resolve().parent / CONFIG["panel_c_csv"]))
    parser.add_argument("--output", type=str, default=str(Path(__file__).resolve().parent / CONFIG["output_pdf"]))
    parser.add_argument("--dpi", type=int, default=int(CONFIG["dpi"]))
    args = parser.parse_args()

    panel_a_path = Path(args.panel_a_csv).expanduser().resolve()
    panel_b_path = Path(args.panel_b_csv).expanduser().resolve()
    panel_c_path = Path(args.panel_c_csv).expanduser().resolve()
    for p in [panel_a_path, panel_b_path, panel_c_path]:
        if not p.exists():
            raise FileNotFoundError(f"CSV not found: {p}")

    rows_a = _load_csv(panel_a_path)
    rows_b = _load_csv(panel_b_path)
    rows_c = _load_csv(panel_c_path)
    _draw(dict(CONFIG), rows_a, rows_b, rows_c, Path(args.output).expanduser().resolve(), int(args.dpi))
    print(f"[figure6 revised] wrote plot: {Path(args.output).expanduser().resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

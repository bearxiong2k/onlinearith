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
    "input_csv": "figure4_plot_data.csv",
    "output_png": "figure4_revised.png",
    "output_pdf": "figure4_revised.pdf",
    "dpi": 300,
    "figure_size_full": (7.0, 3.7),
    "figure_size_half": (3.45, 2.7),
    "layout": "full",  # full or half
    "max_display_ppl": 40000.0,
    "main_xlim": (0.24, 1.03),
    "main_ylim": (14.0, 75),
    "main_log_y": False,
    "inset_xlim": (0.35, 0.88),
    "inset_ylim": (17.15, 20.85),
    "inset_log_y": False,
    "show_inset": True,
    "legend_ncol": 3,
    "legend_items_per_column": 2,
    "uniform_labels": ["H=8", "H=9", "H=10", "H=11"],
    "layerwise_labels": ["12db", "18db"],
    "activation_labels": ["2:4", "16:32", "12:32", "8:32","20:32"],
    "wanda_labels": ["2:4", "16:32", "12:32", "8:32", "20:32"],
    "annotation_fontsize": 8.0,
    "markers": {
        "main_layerwise": "o",
        "main_channelwise": "^",
        "main_uniform": "s",
        "main_activation_other": "<",
        "main_activation_24": "<",
        "main_wanda_other": ">",
        "main_wanda_24": ">",
        "main_dense": "*",
        "inset_layerwise": "o",
        "inset_channelwise": "^",
        "inset_uniform": "s",
        "inset_activation_other": "<",
        "inset_activation_24": "<",
        "inset_wanda_other": ">",
        "inset_wanda_24": ">",
        "inset_dense": "*",
    },
    "style": {
        "layerwise": "#000000",
        "channelwise": "#7a8ba6",
        "uniform": "#7A7A7A",
        "activation": "#2a7fb8",
        "activation_24": "#165a8a",
        "activation_line": "#2a7fb8",
        "wanda": "#d17a22",
        "wanda_24": "#9d5711",
        "wanda_line": "#d17a22",
        "dense": "#111111",
        "grid": "#d2d8e0",
        "spine": "#4a5568",
        "zoom": "#9aa5b1",
    },
}

def apply_paper_style() -> None:
    mpl.rcParams.update(
        {
            "font.size": 8,
            "axes.labelsize": 9,
            "axes.titlesize": 9,
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



def _family_display_name(family: str) -> str:
    return {
        "fixed_sum": "Layer-wise L2",
        "target_snr": "Channel-wise L2",
        "uniform": "Uniform horizon",
        "activation": "Activation-gated n:m",
        "wanda": "Wanda n:m",
        "dense": "Dense MX",
    }.get(family, family)



def _load_rows(path: Path, max_display_ppl: float) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with open(path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            if not _is_enabled(raw.get("include", "1")):
                continue
            x = _to_float(raw.get("x"))
            y = _to_float(raw.get("y"))
            if x is None or y is None or y > max_display_ppl:
                continue
            family = str(raw.get("family", "")).strip()
            n = _to_int(raw.get("n"))
            m = _to_int(raw.get("m"))
            # Figure 4 policy: omit extreme 24:32 activation/Wanda outliers.
            if family in {"activation", "wanda"} and n == 24 and m == 32:
                continue
            if family in {"activation", "wanda"} and n is not None and m not in {None, 0}:
                x = float(m - n) / float(m)
            point_label = str(raw.get("point_label", "")).strip()
            rows.append(
                {
                    "family": family,
                    "x": x,
                    "y": y,
                    "point_label": point_label,
                    "n": n,
                    "m": m,
                    "horizon": _to_int(raw.get("horizon_B")),
                    "db": _to_int(raw.get("db")),
                    "connect_order": _to_float(raw.get("connect_order")) or x,
                }
            )
    rows.sort(key=lambda r: (r["family"], float(r["connect_order"]), float(r["x"]), float(r["y"])))
    return rows



def _group(rows: list[dict[str, Any]], family: str) -> list[dict[str, Any]]:
    out = [r for r in rows if r["family"] == family]
    out.sort(key=lambda r: (float(r["connect_order"]), float(r["x"]), float(r["y"])))
    return out



def _nm_label(row: dict[str, Any], prefix: str) -> str:
    n = row.get("n")
    m = row.get("m")
    if n is None or m is None:
        return prefix
    return f"{prefix} {n}:{m}"


def _nm_only_label(row: dict[str, Any]) -> str:
    n = row.get("n")
    m = row.get("m")
    if n is None or m is None:
        return str(row.get("point_label", "")).replace("act ", "").replace("wanda ", "")
    return f"{n}:{m}"



def _apply_axes_style(ax: Any, config: dict[str, Any], with_grid: bool = True) -> None:
    style = config["style"]
    for spine in ["left", "bottom", "top", "right"]:
        ax.spines[spine].set_color(style["spine"])
        ax.spines[spine].set_linewidth(0.8)
    if with_grid:
        ax.grid(axis="y", color=style["grid"], linestyle=(0, (1.2, 2.4)), linewidth=0.7)
        ax.grid(axis="x", color=style["grid"], linestyle=(0, (1.2, 2.4)), linewidth=0.7)

    ax.tick_params(direction="out", length=3, width=0.8, color=style["spine"])



def _annotate(
    ax: Any,
    x: float,
    y: float,
    text: str,
    config: dict[str, Any],
    *,
    dx: float = 4,
    dy: float = 4,
    ha: str = "left",
    va: str = "bottom",
    fontsize: float | None = None,
) -> None:
    font_size = float(fontsize if fontsize is not None else config.get("annotation_fontsize", 8.0))
    ax.annotate(
        text,
        xy=(x, y),
        xytext=(dx, dy),
        textcoords="offset points",
        fontsize=font_size,
        color="#2d3748",
        ha=ha,
        va=va,
        clip_on=False,
    )



def _draw(config: dict[str, Any], rows: list[dict[str, Any]], output_path: Path, dpi: int) -> None:
    apply_paper_style()
    if config["layout"] == "half":
        fig = plt.figure(figsize=tuple(config["figure_size_half"]), constrained_layout=True)
    else:
        fig = plt.figure(figsize=tuple(config["figure_size_full"]), constrained_layout=True)
    ax = fig.add_subplot(111)
    _apply_axes_style(ax, config)

    style = config["style"]
    markers = config["markers"]
    layerwise = _group(rows, "fixed_sum")
    channelwise = _group(rows, "target_snr")
    uniform = _group(rows, "uniform")
    activation = _group(rows, "activation")
    wanda = _group(rows, "wanda")
    dense = _group(rows, "dense")

    main_xmin, main_xmax = tuple(config["main_xlim"])
    main_ymin, main_ymax = tuple(config["main_ylim"])

    def _in_main(row: dict[str, Any]) -> bool:
        return main_xmin <= row["x"] <= main_xmax and main_ymin <= row["y"] <= main_ymax

    layerwise_main = [r for r in layerwise if _in_main(r)]
    channelwise_main = [r for r in channelwise if _in_main(r)]
    uniform_main = [r for r in uniform if _in_main(r)]
    activation_main = [r for r in activation if _in_main(r)]
    wanda_main = [r for r in wanda if _in_main(r)]
    dense_main = [r for r in dense if _in_main(r)]

    handles: list[Any] = []
    labels: list[str] = []

    if layerwise_main:
        h, = ax.plot(
            [r["x"] for r in layerwise_main],
            [r["y"] for r in layerwise_main],
            color=style["layerwise"],
            linewidth=1.3,

            linestyle=(0, (3, 2)),
            marker=markers["main_layerwise"],
            markersize=4.5,
            markerfacecolor=style["layerwise"],
            markeredgewidth=0.0,
            zorder=4,
        )
        handles.append(h)
        labels.append("Layer-wise L2")

    if channelwise_main:
        h, = ax.plot(
            [r["x"] for r in channelwise_main],
            [r["y"] for r in channelwise_main],
            color=style["channelwise"],
            linewidth=1.3,
            linestyle=(0, (3, 2)),
            marker=markers["main_channelwise"],
            markersize=4.5,
            markerfacecolor="white",
            markeredgecolor=style["channelwise"],
            zorder=3,
        )
        handles.append(h)
        labels.append("Channel-wise L2")

    if uniform_main:
        h = ax.scatter(
            [r["x"] for r in uniform_main],
            [r["y"] for r in uniform_main],
            color="white",
            marker=markers["main_uniform"],
            s=48,
            edgecolors=style["uniform"],
            linewidths=1.0,
            zorder=5,
        )
        handles.append(h)
        labels.append("Uniform horizon")

    activation_other = [r for r in activation if not (r.get("n") == 2 and r.get("m") == 4)]
    activation_24 = [r for r in activation if r.get("n") == 2 and r.get("m") == 4]
    activation_other_main = [r for r in activation_main if not (r.get("n") == 2 and r.get("m") == 4)]
    activation_24_main = [r for r in activation_main if r.get("n") == 2 and r.get("m") == 4]

    wanda_other = [r for r in wanda if not (r.get("n") == 2 and r.get("m") == 4)]
    wanda_24 = [r for r in wanda if r.get("n") == 2 and r.get("m") == 4]
    wanda_other_main = [r for r in wanda_main if not (r.get("n") == 2 and r.get("m") == 4)]
    wanda_24_main = [r for r in wanda_main if r.get("n") == 2 and r.get("m") == 4]

    if activation_other_main:
        h = ax.scatter(
            [r["x"] for r in activation_other_main],
            [r["y"] for r in activation_other_main],
            s=54,
            marker=markers["main_activation_other"],
            color="none",
            edgecolors=style["activation"],
            linewidths=1.3,
            zorder=5,
        )
        handles.append(h)
        labels.append("Activation-gated n:m")

    if activation_24_main:
        h = ax.scatter(
            [r["x"] for r in activation_24_main],
            [r["y"] for r in activation_24_main],
            s=66,
            marker=markers["main_activation_24"],
            color=style["activation"],
            edgecolors="None",
            linewidths=1.1,
            zorder=6,
        )
        handles.append(h)
        labels.append("Activation-gated 2:4")

    if wanda_other_main:
        h = ax.scatter(
            [r["x"] for r in wanda_other_main],
            [r["y"] for r in wanda_other_main],
            s=54,
            marker=markers["main_wanda_other"],
            color="none",
            edgecolors=style["wanda"],
            linewidths=1.3,
            zorder=5,
        )
        handles.append(h)
        labels.append("Wanda n:m")

    if wanda_24_main:
        h = ax.scatter(
            [r["x"] for r in wanda_24_main],
            [r["y"] for r in wanda_24_main],
            s=66,
            marker=markers["main_wanda_24"],
            color=style["wanda"],
            edgecolors="None",
            linewidths=1.1,
            zorder=6,
        )
        handles.append(h)
        labels.append("Wanda 2:4")

    if dense_main:
        h = ax.scatter(
            [r["x"] for r in dense_main],
            [r["y"] for r in dense_main],
            s=140,
            marker=markers["main_dense"],
            color=style["dense"],
            zorder=7,
        )
        handles.append(h)
        labels.append("Dense MX")

    ax.set_xlim(*tuple(config["main_xlim"]))
    ax.set_ylim(*tuple(config["main_ylim"]))
    if bool(config.get("main_log_y", False)):
        ax.set_yscale("log")
        ax.set_yticks([20, 100, 1000, 10000])
    ax.set_xlabel("Executed-digit ratio (dense MX = 1.0)")
    ax.set_ylabel("Perplexity")

    # Main-axis annotations.
    for row in uniform_main:
        if row["point_label"] in config["uniform_labels"]:
            _annotate(ax, row["x"], row["y"], row["point_label"], config, dx=0, dy=8, ha="center", va="bottom")
    activation_label_set = set(config.get("activation_labels", []))
    wanda_label_set = set(config.get("wanda_labels", []))

    for row in activation_other_main:
        short = _nm_only_label(row)
        if short in {"20:32","16:32", "12:32", "8:32"}:
            _annotate(ax, row["x"], row["y"], short, config, dx=8, dy=1, ha="left", va="center")
    for row in activation_24_main:
        _annotate(ax, row["x"], row["y"], _nm_only_label(row), config, dx=8, dy=1, ha="left", va="center")
    for row in wanda_other_main:
        short = _nm_only_label(row)
        if short in {"20:32"}:
            _annotate(ax, row["x"], row["y"], short, config, dx=-8, dy=1, ha="right", va="center")
    for row in wanda_24_main:
        _annotate(ax, row["x"], row["y"], _nm_only_label(row), config, dx=-8, dy=1, ha="right", va="center")
    if dense_main:
        _annotate(ax, dense_main[0]["x"], dense_main[0]["y"], "Dense MX", config, dx=6, dy=7, ha="right", va="bottom")

    # Inset for the overall range (including high-value outliers).
    if config["show_inset"]:
        axins = inset_axes(ax, width="41%", height="54%", loc="upper right", borderpad=0.8)
        _apply_axes_style(axins, config)
        axins.grid(axis="both", color=style["grid"], linestyle=(0, (1.0, 2.4)), linewidth=0.6)

        if layerwise:
            axins.plot(
                [r["x"] for r in layerwise],
                [r["y"] for r in layerwise],
                color=style["layerwise"],
                linewidth=1.2,
                linestyle=(0, (3, 2)),

                marker=markers["inset_layerwise"],
                markersize=3.5,
                zorder=4,
            )
        if channelwise:
            axins.plot(
                [r["x"] for r in channelwise],
                [r["y"] for r in channelwise],
                color=style["channelwise"],
                linewidth=1.2,
                linestyle=(0, (3, 2)),
                marker=markers["inset_channelwise"],
                markersize=2.8,
                markerfacecolor="white",
                markeredgecolor=style["channelwise"],
                zorder=3,
            )
        if uniform:
            axins.scatter(
                [r["x"] for r in uniform],
                [r["y"] for r in uniform],
                color="white",
                marker=markers["inset_uniform"],
                s=34,
                edgecolors=style["uniform"],
                linewidths=1.0,
                zorder=5,
            )
        if activation_other:
            axins.scatter(
                [r["x"] for r in activation_other],
                [r["y"] for r in activation_other],
                s=50,
                marker=markers["inset_activation_other"],
                color=style["activation"],
                edgecolors="None",
                linewidths=0.8,
                zorder=5,
            )
        if activation_24:
            axins.scatter(
                [r["x"] for r in activation_24],
                [r["y"] for r in activation_24],
                s=50,
                marker=markers["inset_activation_24"],
                color=style["activation"],
                edgecolors="None",
                linewidths=0.9,
                zorder=6,
            )
        if wanda_other:
            axins.scatter(
                [r["x"] for r in wanda_other],
                [r["y"] for r in wanda_other],
                s=50,
                marker=markers["inset_wanda_other"],
                color=style["wanda"],
                edgecolors="None",
                linewidths=0.8,
                zorder=5,
            )
        if wanda_24:
            axins.scatter(
                [r["x"] for r in wanda_24],
                [r["y"] for r in wanda_24],
                s=50,
                marker=markers["inset_wanda_24"],
                color=style["wanda"],
                edgecolors="None",
                linewidths=0.9,
                zorder=6,
            )
        if dense:
            axins.scatter(
                [r["x"] for r in dense],
                [r["y"] for r in dense],
                s=56,
                marker=markers["inset_dense"],
                color=style["dense"],
                zorder=7,
            )

        axins.set_xlim(*tuple(config["inset_xlim"]))
        axins.set_ylim(*tuple(config["inset_ylim"]))
        axins.set_xticks([0.35,0.45, 0.55, 0.65, 0.75, 0.85])
        if bool(config.get("inset_log_y", False)):
            axins.set_yscale("log")
            axins.set_yticks([20, 100, 1000, 10000])
        else:
            axins.set_yticks([17.5, 18.5, 19.5, 20.5])
        axins.tick_params(labelsize=7)

        for row in uniform:
            if row["point_label"] in {"H=9", "H=10", "H=11"}:
                _annotate(axins, row["x"], row["y"], row["point_label"], config, dx=0, dy=7, ha="center", va="bottom", fontsize=7.6)
        for row in activation_other:
            short = _nm_only_label(row)
            if short in activation_label_set:
                _annotate(axins, row["x"], row["y"], short, config, dx=6, dy=1, ha="left", va="center", fontsize=7.6)

    legend_items_per_column = max(1, int(config.get("legend_items_per_column", 2)))
    legend_ncol = max(1, (len(labels) + legend_items_per_column - 1) // legend_items_per_column)

    ax.legend(
        handles,
        labels,
        ncol=legend_ncol,
        loc="upper center",
        bbox_to_anchor=(0.5, 1.18),
        frameon=True,
        framealpha=1.0,
        facecolor="white",
        edgecolor=style["spine"],
        fancybox=False,
        columnspacing=1.1,
        handletextpad=0.6,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi)
    plt.close(fig)



def main() -> int:
    parser = argparse.ArgumentParser(description="ICCAD-style Figure 4 plot")
    parser.add_argument("--csv", type=str, default=str(Path(__file__).resolve().parent / CONFIG["input_csv"]))
    parser.add_argument("--output", type=str, default=str(Path(__file__).resolve().parent / CONFIG["output_pdf"]))
    parser.add_argument("--dpi", type=int, default=int(CONFIG["dpi"]))
    parser.add_argument("--layout", choices=["full", "half"], default=str(CONFIG["layout"]))
    args = parser.parse_args()

    csv_path = Path(args.csv).expanduser().resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found: {csv_path}")

    config = dict(CONFIG)
    config["layout"] = args.layout
    rows = _load_rows(csv_path, max_display_ppl=float(config["max_display_ppl"]))
    _draw(config, rows, Path(args.output).expanduser().resolve(), int(args.dpi))
    print(f"[figure4 revised] wrote plot: {Path(args.output).expanduser().resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

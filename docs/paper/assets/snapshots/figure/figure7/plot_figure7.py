#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import matplotlib as mpl
import matplotlib.pyplot as plt

CONFIG: dict[str, Any] = {
    "output_png": "figure7_revised.png",
    "output_pdf": "figure7.pdf",
    "dpi": 300,
    # Half-column width to align with other ICCAD figures in this workspace.
    "figure_size": (3.45, 2.2),
    "labels": [
        "Control plane",
        "Data plane leaf",
        "Data plane adder",
        "Weight SRAM",
    ],
    "area_values": [45.1, 7996.6, 2489.0, 2477.0],
    "energy_values": [23.7, 328.0, 96.0, 488.9],
    "style": {
        "control": "#ffbc40",
        "leaf": "#fffab6",
        "adder": "#7a8ba6",
        "sram": "#ffbce9",
        "text": "#2d3748",
    },
}


def apply_paper_style() -> None:
    mpl.rcParams.update(
        {
            "font.size": 8,
            "axes.labelsize": 9,
            "axes.titlesize": 8,
            "legend.fontsize": 6.6,
            "xtick.labelsize": 8,
            "ytick.labelsize": 8,
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
            "savefig.bbox": "tight",
        }
    )


def _compose_labels(values: list[float], labels: list[str]) -> list[str]:
    total = sum(values)
    if total <= 0:
        return [f"{label}\n0.0%" for label in labels]
    return [f"{label}\n{(100.0 * value / total):.1f}%" for value, label in zip(values, labels)]


def _draw_pie(ax: Any, values: list[float], labels: list[str], colors: list[str], panel_title: str) -> None:
    labeled = _compose_labels(values, labels)
    wedges, text_labels = ax.pie(
        values,
        startangle=110,
        counterclock=False,
        colors=colors,
        labels=labeled,
        labeldistance=1.05,
        wedgeprops={"linewidth": 0.7, "edgecolor": "white"},
        textprops={"fontsize": 6.2, "color": "#2d3748"},
    )
    for txt in text_labels:
        txt.set_ha("center")

    ax.axis("equal")
    return wedges


def _draw(config: dict[str, Any], output_path: Path, dpi: int) -> None:
    apply_paper_style()

    labels = list(config["labels"])
    area_values = [float(v) for v in config["area_values"]]
    energy_values = [float(v) for v in config["energy_values"]]
    style = config["style"]
    colors = [style["control"], style["leaf"], style["adder"], style["sram"]]

    fig, axes = plt.subplots(
        1,
        2,
        figsize=tuple(config["figure_size"]),
        constrained_layout=False,
        facecolor="white",
    )
    for ax in axes:
        ax.set_facecolor("white")

    _draw_pie(axes[0], area_values, labels, colors, "(a) Area breakdown")
    _draw_pie(axes[1], energy_values, labels, colors, "(b) Energy breakdown")

    fig.subplots_adjust(left=0.04, right=0.98, top=0.95, bottom=0.07, wspace=0.34)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi, facecolor="white")
    plt.close(fig)


def main() -> int:
    parser = argparse.ArgumentParser(description="ICCAD-style Figure 7 pie charts")
    parser.add_argument("--output", type=str, default=str(Path(__file__).resolve().parent / CONFIG["output_pdf"]))
    parser.add_argument("--dpi", type=int, default=int(CONFIG["dpi"]))
    args = parser.parse_args()

    output_path = Path(args.output).expanduser().resolve()
    _draw(dict(CONFIG), output_path, int(args.dpi))
    print(f"[figure7 revised] wrote plot: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
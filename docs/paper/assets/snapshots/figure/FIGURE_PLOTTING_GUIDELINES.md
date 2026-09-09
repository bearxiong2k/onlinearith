# ICCAD Figure Plotting Guidelines

This file records shared plotting conventions for Figures 4-6 in this directory.

## Scope
- Directory: `~/coding/figure`
- Target paper venue: ICCAD
- Reference template: `template.tex` (ACM/ICCAD-style baseline)
- Current scripts:
  - `figure4/plot_figure4.py`
  - `figure5/plot_figure5.py`
  - `figure6/plot_figure6.py`

## Common Requirements
- Use consistent paper-oriented font sizes suitable for two-column ACM style.
- Use closed axis borders on all plots: left, right, top, and bottom spines enabled.
- Keep spine color/width and tick styling consistent across figures.
- Keep grid style subtle and consistent (light y-grid by default).
- Export with stable print settings:
  - `dpi = 300`
  - vector-font-friendly options (`pdf.fonttype = 42`, `ps.fonttype = 42`)
  - tight bounding box for saved figures

## Figure-Specific Notes
- Figure 4:
  - Main plot shows the full-range overview; inset shows the critical near-dense region.
  - Exclude `12:16` ACT/Wanda points.
  - Do not connect ACT/Wanda points with lines.
  - Plot `H` as obvious standalone square markers (no dashed connection).
  - Keep annotations minimal: `Dense MX`, `H`, and a single shared `n:m` label (no `act`/`wanda` prefix).

- Figure 5:
  - Two stacked panels with matched style settings.
  - Closed-border styling applies to both panels.

- Figure 6:
  - Subgraphs A, B, C must be uniform square panels.
  - Use `set_box_aspect(1.0)` for each main panel axis.
  - For panel C outliers, use a contracted y-axis (broken-axis view) to show both normal and outlier ranges.

## Workflow Checklist Before Final Paper Export
- Regenerate all revised plots:
  - `python figure4/plot_figure4.py`
  - `python figure5/plot_figure5.py`
  - `python figure6/plot_figure6.py`
- Verify visual consistency side-by-side:
  - Spine visibility on all four sides
  - Font sizes and label readability in half/full column context
  - Legend placement does not overlap key data
  - Figure 6 panel A/B/C are visually square and balanced
- Confirm filenames/paths used by LaTeX include commands in the paper source.

## Change Log
- 2026-04-12:
  - Enforced closed-border axes for Figures 4-6.
  - Updated Figure 6 layout so A/B/C are uniform square panels.
  - Panel C outlier display uses a contracted y-axis (broken-axis view).
  - Figure 4 now uses color-separated ACT/Wanda dots with connecting lines and structured annotation placement (SNR below, H above, ACT right, Wanda left) with slightly larger annotation fonts.
  - Figure 4 inset usage is: main axis for full-range overview and inset for critical-region zoom; `2:4` points are explicitly shown as separate highlighted points, and `12:16` points are excluded.

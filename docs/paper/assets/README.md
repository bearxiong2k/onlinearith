# Paper figure source archive

Imported on 2026-09-09 from the clean `../figure` repository at commit
`40c5f10d6d4a5490dddcd88cb3b2ce6523ad204d`. The 24 files (1,645,466 bytes)
under [snapshots/figure](snapshots/figure/) retain the original hierarchy and
bytes. Git internals and Python bytecode were excluded.

Start with the [figure/data audit](../figure_data_audit.md) before reusing an
image or CSV. These are archived ICCAD assets, not approved figures for the
next submission. In particular, the Figure 4 baseline notation and some
Figure 4/6 plot values need correction from evidence in a future writing task.

| Directory | Contents | Reuse status |
|---|---|---|
| [figure4](snapshots/figure/figure4/) | PPL/work curve, editable plotting CSV, preparer and renderer | Visual/source reference; numerical provenance defects documented in the audit |
| [figure5](snapshots/figure/figure5/) | Legacy block-serial functional cycle accounting, plotting CSV and renderer | Historical functional accounting; does not measure the new hardware's latency |
| [figure6](snapshots/figure/figure6/) | Calibration/ablation panels, three CSVs and renderer | Audit required before scientific reuse; panels have different evidence scopes |
| [figure7](snapshots/figure/figure7/) | Old area/energy pie chart and hard-coded plotting values | Historical hardware artwork; new hardware evidence belongs under `hardware_sim/` |

The `*_draft.png` and `*_revised.*` names are preserved historical names,
not a claim that the revised files are validated. `template.tex` and
`FIGURE_PLOTTING_GUIDELINES.md` record the old venue's presentation choices.
The raw `figure4_data.csv` required by `prepare_figure4_plot_data.py` is absent
from the source archive. Preserve the preparer for provenance; do not use it
to overwrite the archived plotting CSV.

[manifest.json](manifest.json) records each original root/path, local
destination, size and SHA256. Source files may contain historical machine
paths. They are provenance strings; no symlink or sibling runtime dependency
has been installed. No figures were regenerated during this organization.

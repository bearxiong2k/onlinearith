# ICCAD manuscript baseline

This is the user-supplied starting version for the next paper. The original
`sample-sigconf.tex`, `reference.bib`, and `figures/figure1.pdf` through
`figure7.pdf` are preserved byte-for-byte. `manifest.json` records their
2026-09-09 SHA-256 hashes; the directory was untracked in the host repository
when inspected, so the host Git revision alone does not identify these files.

The TeX is byte-identical to the manuscript source at
`../rebuttal/sample-sigconf.tex`, revision
`e13339c996b3551deb9723567aca3e9bfc03868f` of that sibling repository. The
[historical review-era PDF](../docs/paper/review_history/iccad/TSS_ICCAD.pdf)
is retained with the review history. It has nine pages and was not rebuilt
from these sources during this organization.

Start new writing from the [paper workspace](../docs/paper/README.md) and
[manuscript audit](../docs/paper/manuscript_review_audit.md). Existing hardware
claims and artwork refer to the earlier architecture and need revision before
reuse. Keep this source baseline intact until a working revision is opened.

## Source and build inventory

- Entry point: `sample-sigconf.tex`, using `acmart` with `sigconf`.
- Bibliography: `reference.bib`, 63 entries; 28 distinct cited keys were found.
- Graphics: seven local PDF assets; all referenced files exist.
- Explicit packages: `algorithm`, `algpseudocode`, `siunitx`, `microtype`,
  `enumitem`; `acmart` and `ACM-Reference-Format` are external TeX dependencies.
- Static inspection found no missing bibliography keys, undefined `ref`/`eqref`
  labels, or duplicate labels.
- `latexmk`, `pdflatex`, `bibtex`, and `tectonic` were absent on 2026-09-09.
  No PDF compilation has been verified.

Once a suitable TeX installation is available, the original template can be
built from this directory with:

```bash
latexmk -pdf -outdir=build sample-sigconf.tex
```

This is a baseline build command, not a DATE or ISCAS submission configuration.
The new venue and its current requirements remain to be selected and checked.

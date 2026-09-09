# Hardware reference material

This directory is excluded from active RTL and simulation filelists.

- `legacy_candidates/`: exact, quarantined source candidates copied from the
  audited Anchor revision. They are useful for porting mechanics, not active
  architecture truth.
- [September TSS delivery](tss_delivery_20260909/README.md): a preserved
  conventional-multiplier presentation prototype, including mapped synthesis
  and pre-route power reports. Its arithmetic differs from active M1, and the
  delivery contains no layout. Read the
  [delivery audit](../docs/reference/tss_delivery_audit.md) before reuse.
- [Author-supplied layout figure](layout_20260909/README.md): subsequent layout
  image for the writing stage, with unchanged image bytes and caption metadata.
- [Rebuttal GPU profile](rebuttal_gpu_20260909/README.md): measured full-GPU and
  non-FFN timing sources for the end-to-end figure, with the old hybrid ratios
  retained separately as historical formulas.

Consult the corresponding source audit before reading or promoting a file.
For Anchor candidates, use
`hardware_sim/docs/reference/legacy_source_map.md`; the TSS delivery has its
own audit and manifest.

# TSS hardware delivery snapshot

Status: **reference only; not adopted by the active hardware contracts**.
Imported: 2026-09-09 from `../TSS` at
`dd6fe890c36effd248b4d0ae56947d7dadfb7dd1` (clean worktree).

Read the [delivery audit](../../docs/reference/tss_delivery_audit.md) before
using any number, diagram, or RTL here. This is the **Stage-1
conventional-multiplier presentation prototype**, with signed 8-by-8
multipliers and whole-leaf suppression. It does not implement the local frozen
M1 target-mantissa and temporal-placement arithmetic. The active M2 gate
remains open.

The delivery contains RTL, synthesis constraints, a mapped netlist, Design
Compiler reports and a command transcript, and PrimeTime-PX power reports.
It contains **no layout database, layout figure, PnR report, extracted
parasitics, testbench, or activity waveform**. Its power summary explicitly
identifies the current estimate as pre-route.

The author subsequently supplied a [layout image](../layout_20260909/README.md)
outside this original delivery. It now has its own figure/provenance record
for the paper; this snapshot's original inventory is unchanged.

## Contents and preservation

| Path | Use |
| --- | --- |
| [manifest.json](manifest.json) | Source revision, complete tracked-file inventory, exclusions, original and stored checksums |
| [SHA256SUMS](SHA256SUMS) | Checksums of the 39 preserved payload files |
| [source/stage1_tile_v1/docs/stage1_tile_architecture.md](source/stage1_tile_v1/docs/stage1_tile_architecture.md) | Delivered implementation description, including streamed activation storage |
| [source/stage1_tile_v1/rtl](source/stage1_tile_v1/rtl) | Unmodified reference RTL; excluded from active source lists |
| [source/stage1_tile_v1/synth](source/stage1_tile_v1/synth) | Mapped cell-area/timing reports, constraints, log, and compressed netlist |
| [source/stage1_tile_v1/power/reports](source/stage1_tile_v1/power/reports) | Pre-route power estimates with differing activity windows |
| [source/stage1_presentation_layout_contract.md](source/stage1_presentation_layout_contract.md) | Earlier presentation brief; superseded storage/interface details remain as provenance |

All 39 non-PDF tracked files are preserved. Their original size is 20,758,047
bytes; stored payload size is 4,032,154 bytes. The original 15,367,635-byte
mapped netlist and 2,718,136-byte reference-hierarchy report are stored with
`.gz` suffixes using deterministic gzip compression. Decompression reproduces
their original bytes and SHA-256 hashes. Every other payload is byte-for-byte
identical to its source.

The existing manuscript PDF (1,154,828 bytes) is inventoried with its checksum
but excluded from this hardware snapshot. `.git` is excluded; its immutable
revision and remote are recorded instead. No source file was edited or moved.

Manifest `size_bytes` and `sha256` identify the original source.
`stored_size_bytes` and `stored_sha256` identify the local destination;
`encoding` distinguishes `identity` from `gzip`. Destination paths are relative
to the `onlinearith` repository root. Snapshot checks require no sibling
repository or proprietary tool.

Original documents, filelists, and reports retain their historical relative
and absolute paths. Several referenced inputs are absent; preservation does
not imply that these flows are runnable. The audit lists the missing inputs
and the contracts that would need reconciliation before adoption.

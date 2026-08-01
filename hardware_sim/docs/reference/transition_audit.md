# Hardware Redesign Transition Audit

Status: historical audit and redesign rationale
Audit date: 2026-08-01
Reorganization completed: 2026-08-01
Implementation status: no numerical, RTL, trace, or cost-model implementation
was changed in this audit.

This document records what currently exists across `onlinearith`, the modified
Transformers fork, `../anchors`, and `../rebuttal`; which parts remain useful;
and which assumptions are superseded by the revised hardware design. It guided
the repository reorganization and is now a detailed reference. The current
sources of truth are `hardware_sim/docs/architecture_contract.md`,
`hardware_sim/docs/evidence_contract.md`, and
`hardware_sim/docs/decision_log.md`.

The audit was made against these revisions:

| Repository | Revision | Role at the audited revision |
|---|---:|---|
| `onlinearith` | `2d07c53` | experiment, calibration, PPL, and plotting drivers |
| `../transformers` | `3910a1596f` | authoritative Qwen3 numerical kernel and statistics implementation |
| `../anchors` | `5959bb8` | old trace-driven RTL/cost anchors A0--A4 |
| `../rebuttal` | `e13339c` | old end-to-end cost model, trace artifacts, and rebuttal writing |

The deletion at the audited revision of the stage-1/stage-2 boundary and local
`down_proj`-consumer sections in
`docs/archive/paper_planning/hardware_design.md` was preserved. That archived note
still contains other old serial-parallel assumptions and is not the new design
contract.

## 1. Executive conclusion

The existing `onlinearith` and modified-Transformers simulations are frozen
algorithmic/quality facts. They will not be edited to make their tensor program
look like the revised circuit, and their calibration, PPL, and executed-digit
results will not be invalidated or recomputed under altered numerical
semantics as part of the hardware redesign.

The current software implementation order is:

```text
frozen software simulation:
    product     = activation_mantissa * weight_mantissa
    contribution = truncate_product(product, scheduled_product_digits)

revised design:
    activation_target = form_scheduled_activation_mantissa(activation)
    weight_aligned    = offline_align_weight_element(weight)
    contribution      = standard_fixed_point_multiply(
                            activation_target,
                            weight_aligned)
```

The first sequence defines the frozen software evidence. The second defines the
new hardware realization. Their relationship must be captured by an explicit
downstream interpretation/translation contract; it will not be resolved by
changing the model simulator.

The redesign therefore invalidates downstream circuit events and costs, not the
recorded software facts. Old Anchor-2 characterization, boundary traces,
payload/queue results, and end-to-end hardware cost rows cannot be relabeled as
results for the revised design. Existing calibration tables, PPL values, and
executed-digit measurements remain the authoritative algorithmic evidence with
their original semantics and provenance.

The parts worth extracting are:

- the frozen PPL, calibration, executed-digit, and model-scale evidence in
  `onlinearith` and `../transformers`;
- the metadata/window-control ideas and selected source RTL from Anchors 0, 1,
  and 4, subject to a new arithmetic contract;
- the Icarus/Yosys/ABC test and synthesis scaffolding in `../anchors`;
- the versioned-ledger, source-status, report-generation, and unit-test patterns
  in `../rebuttal`.

The old siblings should remain frozen historical inputs. Later work should not
depend on their directory layouts or consume their result tables directly.

## 2. Decisions already made

These are redesign decisions, not open questions.

### D1. Method identity is unchanged

The paper-level principle remains **temporal significance scheduling**. The
algorithmic object remains a local execution window on an aligned contribution
stream. The method must not be recast as generic sparsity, quantization,
pruning, or masking.

### D2. The custom hardware scope ends at stage 1

The custom stage-2 `down_proj` consumer, stage-1/stage-2 packet interface,
packetizer, boundary headers, elastic FIFO, shard queue, and reduced-payload
claim are removed from the active design.

This does not mean deleting `down_proj` from the neural network or changing how
the frozen functional simulation treated it. Existing PPL/calibration runs keep
the original full model graph and original projection semantics.

The new hardware/general simulator instead has a stage-1-only custom scope. It
must consume projection-resolved frozen facts where available, exclude old
stage-2/interface events from new circuit accounting, and treat `down_proj` as
a common baseline term if a later table uses an end-to-end FFN denominator.

### D3. The leaf arithmetic primitive changes

The active datapath will use a standard fixed-point multiplier whose operands
are:

1. the target activation mantissa formed under the local execution window; and
2. an offline-aligned, fixed-point representation of the corresponding weight
   element.

There is no runtime stream of recoded weight digits being advanced alongside
activation digits in an online serial-parallel multiplier.

### D4. Weight alignment is an offline representation concern

Weight-element alignment/recoding is prepared before runtime. Runtime traces
must count reads of the stored aligned weight representation and standard
multiplier issues; they must not infer a runtime weight-digit stream from the
old implementation.

### D5. Software evidence is frozen; old hardware evidence is legacy

The existing TSS calibration, PPL, and executed-digit results are frozen facts
and remain reusable exactly as recorded. The same applies to FP16, dense MXFP8,
WANDA 2:4, and activation N:M 2:4 results under their recorded protocols. No
model/calibration code or semantics will change for this redesign. Any later
read-only reproduction/export must use the frozen setup unchanged and does not
define a new method.

Old latency, area, energy, payload, queue, and circuit-event values describe
the superseded hardware contract. They remain historical evidence and reader
fixtures, but not claims about the revised standard-multiplier design.

When a paper table combines frozen quality/work facts with new downstream
hardware estimates, it must show the two provenances separately.

### D6. Executed-digit ratio remains the primary work metric

The recorded executed-digit ratio and its existing plotting convention
`mean_effective_precision / 3.0` remain frozen algorithmic/work facts. Their
definition will not be rewritten to match a new circuit counter.

The downstream simulator must separately count activation-target formation,
aligned-weight reads, standard-multiplier issues, tree work, and accumulation.
It may map the frozen digit metric into those events only through a documented
formula or trace adapter. Standard-multiplier count and hardware read/latency/
energy ratios are not aliases for executed-digit ratio.

### D7. Later code must be self-contained with respect to legacy repos

`../anchors` and `../rebuttal` will not be active runtime dependencies. Reusable
source, tests, and methodology will be extracted during reorganization; large
generated outputs and obsolete architectural packages will not be copied into
the active tree.

### D8. Evidence strength must remain explicit

Every reported hardware quantity must continue to distinguish at least:

- trace-backed event count;
- mapped/synthesized RTL result;
- formula-backed estimate;
- assumed parameter or proxy;
- missing/pending measurement.

No formula-backed or proxy value should become a "measured" value through
report aggregation.

### D9. Nangate use is already cleared for this project

The prior license check for the local Nangate cell files is complete. This is
the same personal-research project, so reuse or relocation of those files
inside the reorganized project is not a blocker and requires no new license
review. Preserve their headers and provenance as normal research hygiene.

### D10. Reorganization does not move the frozen simulator boundary

The next repository reorganization may add or rearrange active documentation,
RTL, downstream general-simulation, trace-adapter, and cost-model material. It
must not move, rename, or modify the existing `onlinearith` experiment entry
points or the authoritative Qwen/LLM simulation files in the Transformers
fork. Stable commands and result schemas remain intact.

## 3. Current `onlinearith` and Transformers implementation

### 3.1 What has been built

The current project has a mature experiment shell:

- `ppltest.py` implements the WikiText-2 sliding-window PPL methodology,
  explicit model sharding, data-parallel window sharding, lite/full statistics,
  progress/provenance output, and result JSON emission.
- `ppl_batch.py`, `dist_utils.py`, and the documented run scripts provide batch
  and distributed execution.
- `experiment_config.py` centralizes setup IDs, configuration validation,
  snapshots, and runtime replacement of MLP projection modules.
- `calibrate.py` drives SNR-min and fixed-sum calibration and emits structured
  calibration artifacts.
- `tests/test_mx_exact_chunked.py`,
  `tests/test_mxfp_weight_cache_compact.py`, the Qwen3-8B memory probe, and the
  OOM ladder capture useful memory/chunking contracts.
- plotting helpers and active experiment documents encode the current baseline
  families and executed-digit plotting conventions.

The authoritative Qwen3 implementation is in the sibling Transformers fork,
not this repository. Its useful engineering includes:

- blockwise MX quantization and compact weight caching;
- output-channel chunking that avoids materializing the entire 4-D product
  tensor at once;
- optional compiled truncation;
- per-layer statistics hooks and progress reporting;
- a staged calibration cache and optimizer interface.

### 3.2 Frozen numerical semantics and downstream boundary

In
`../transformers/src/transformers/models/qwen3/modeling_qwen3.py`,
`_forward_msd_truncated` currently:

1. quantizes activation and weight blocks;
2. computes activation-side intra-block delays;
3. computes inter-block delays from combined activation/weight block scales;
4. materializes `prods = x_q * w_q`;
5. computes an effective product precision
   `p_eff = max(B - inter_delay - intra_delay - online_delay, 0)`; and
6. NAF/BSD-truncates `prods` before block reduction.

The calibration oracle in
`../transformers/src/transformers/models/qwen3/calibration_msd.py` repeats the
same product-first operation in `_compute_truncated_result`. The fixed-sum
solver then optimizes error curves generated by that oracle.

These operations and the calibration results derived from them are frozen. The
project will not change `_forward_msd_truncated`,
`_compute_truncated_result`, their cache/chunking behavior, or their calibrated
budgets.

The new offline-aligned weight format and standard-multiplier model belong in
the downstream hardware/general-simulation area. That area must document which
frozen quantities it consumes (for example, horizons, effective-precision
statistics, or projection-resolved work summaries), how they determine a
target activation mantissa, and which new circuit events are derived. This
adapter is not a replacement numerical PPL oracle.

### 3.3 Projection-scope caveat for downstream consumption

`experiment_config.reconfigure_mlp_layers` currently replaces
`gate_proj`, `up_proj`, and `down_proj`. The performance accumulator therefore
profiles all three projections. This is a frozen property of the software
evidence, not a request to change `reconfigure_mlp_layers`.

The v1 event ledger compounds this mismatch: it aggregates all profiled
projection counters and then splits each aggregate evenly into only `g` and
`u`. For a 28-layer Qwen3 model, for example, the selected rebuttal trace says
`num_layers = 84`/`N_prepass_instance = 84`, which is the number of projection
modules rather than the number of gate/up prepass instances. This ledger is a
rebuttal compatibility artifact, not a clean stage-1 ground truth.

The downstream stage-1 hardware model should consume per-layer/per-projection
facts and select `gate_proj`/`up_proj` where those facts exist. It must not
recover gate/up counts by dividing a global aggregate. If an old artifact has
only the invalid aggregate split, label it unusable for the new circuit ledger
rather than modifying the frozen simulation semantics.

### 3.4 Statistics and trace code

`msd_perf_stats.py` currently records useful layer-level distributions, but its
hardware outputs are tied to the old design:

- `N_leaf_exec = round(sum(p_eff))` treats one product digit as one leaf-cycle
  event;
- the block-cycle model assumes fixed non-killed block service plus tree drain;
- boundary payload digits are `ceil(p_eff)` packed into words;
- every output channel produces a burst assigned to a stage-2 shard;
- headers, boundary words, and queue replay are Anchor-3-specific.

The statistics and their files remain frozen. The event definitions, cycle
equations, aggregate splitting, boundary CSV mode, and v1 circuit ledger are
not inputs to the revised circuit cost model unless an explicit adapter marks
the exact fields it uses. The new downstream ledger should be separately
versioned; `N_leaf_exec` must never silently be reinterpreted as a
standard-multiplier count.

## 4. What was built in `../anchors`

`../anchors` implemented a trace-driven cost methodology anchored by small,
parameterized SystemVerilog blocks rather than a full tile. This general
methodology is still appropriate. The five old anchors were:

| Old anchor | Implemented function | Status under revised design |
|---|---|---|
| A0 | metadata-only scale prepass, raw-exponent/delay shadow banks | Conditionally reusable if the same block-scale alignment and `D` definition survive |
| A1 | one-block-ahead `tau`/window builder and double-buffered config | Control arithmetic is conditionally reusable; config payload and horizon meaning must be refrozen |
| A2 | 32 digit-stream leaves, reduction tree, channel accumulator | Datapath and all characterization invalid; test/synthesis scaffolding reusable |
| A3 | stage-1 packetizer, headers, elastic FIFO, and queue replay | Removed from active architecture |
| A4 | horizon/rawexp/delay/config plus completion and payload storage | Only selected metadata stores are candidates; old total area/bit count is invalid |

### 4.1 Anchor 0

Anchor 0 implements narrow signed add/max/subtract control for:

```text
E_raw[p,b,c] = beta_x[n,b] + beta_w[p,c,b]
E_max[p,c]   = max_b E_raw[p,b,c]
D[p,b,c]     = E_max[p,c] - E_raw[p,b,c]
```

Its synchronous-memory handling, ping-pong bank pattern, testbench, synthesis
scripts, and report parsing are useful. Whether the arithmetic itself survives
depends on the new offline weight alignment contract: the redesign must first
decide whether runtime still consumes `beta_w` per block and whether `D` is
unchanged.

### 4.2 Anchor 1

Anchor 1 implements:

```text
tau_k = D + lambda_x[k]
L_k   = max(0, H - tau_k)
```

and emits block kill, active-element, start, remaining-window, and subtree
fields. The builder and shadow/active bank mechanics are plausible reuse
candidates if `tau` and `L` now describe activation-mantissa formation. The old
`rem_ctr` as a product/weight-digit execution count and the old
`subtree_init`/tree contract are not automatically valid.

### 4.3 Anchor 2

The old leaf contains a synthesizable `*`, but it is not the revised
multiplier datapath. It is a small digit-by-digit multiplier controlled by
parallel activation and weight digit pointers: each live cycle reads one
activation digit, reads one weight digit, multiplies them, and increments both
pointers. Thirty-two such streams feed the old pipelined tree.

The revised multiplier has different operands, widths, issue semantics,
storage reads, timing, activity, and likely tree input widths. Consequently,
none of these old Anchor-2 results transfers:

- mapped engine area;
- `t_drain` as a complete block latency model;
- `E_blk_fix`;
- `E_leaf_cycle`;
- the equation `E_blk_fix + N_leaf_exec * E_leaf_cycle`.

The parameterized RTL style, microbench organization, cross-anchor fixture,
Yosys scripts, and result parsers are still useful templates.

### 4.4 Anchor 3

Anchor 3 is entirely downstream of a design feature that no longer exists. Its
packetizer/FIFO RTL, payload/header traces, shard assignment, queue replay,
queue-depth sensitivity, area, and energy must remain legacy-only. The generic
idea of replaying timestamped arrivals is reusable elsewhere only if a future
architecture introduces a real queue; it is not part of the current core.

### 4.5 Anchor 4

The old 80,032-bit inventory and hybrid-area estimate include completion
metadata, stage-boundary payload FIFO storage, and the old window-config format.
They cannot be reduced by merely subtracting Anchor 3's logic area.

Potentially reusable source blocks are the horizon store, raw-exponent shadow
RAM, delay bank, and generic synchronous RAM. The window-config store is
reusable only after the new config word is defined. Completion and payload
stores are removed.

### 4.6 RTL toolchain and what it actually proves

The installed open-source simulation/synthesis tools and the already-cleared
local reference cell models are worth keeping as a reproducible flow:

| Component | Audited version/use | Evidence boundary |
|---|---|---|
| Icarus Verilog | 11.0, SystemVerilog smoke/characterization testbenches and VCD generation | Functional RTL simulation, not timing or power signoff |
| Yosys | 0.63+184, git `240439bdb` | elaboration, generic synthesis, Liberty mapping, and reports |
| ABC | invoked by Yosys scripts | mapped critical-path/Fmax proxy, not placed-and-routed closure |
| Liberty/cell models | local Nangate Open Cell Library copy, typical corner, 1.1 V, 25 C | cleared mapping reference for this personal-research project; preserve headers/provenance |
| Python helpers | counter parsing, characterization fits, JSON/CSV/Markdown reports | reproducible orchestration and reporting |

Although old characterization testbenches emit VCD files, the Anchor-2 and
Anchor-3 energy scripts do not extract switching power from those VCDs. They
apply assumed capacitance densities, activity factors, voltage, and event costs
to simulation counters. The reports correctly label these as rough proxies,
not signoff power. The new standard multiplier needs fresh width-specific
synthesis and activity characterization; old energy coefficients are not a
starting measurement.

## 5. What was built in `../rebuttal`

### 5.1 Reusable machinery

The `e2e_cost_model` package provides several good software patterns:

- a typed anchor-cost loader with canonical-report preference and fallbacks;
- normalization of versioned event ledgers;
- explicit `ledger_source` and `source_status` fields;
- separate event construction and cost evaluation;
- structured JSON/CSV/Markdown report generation;
- unit tests for conversions, ledger consumption, queue artifacts, method
  policies, and result formatting.

The packed-artifact directory also demonstrates a useful provenance pattern:
143 compact inputs were copied with original path, byte count, SHA-256, and
notes; the roughly 4.4-GB raw boundary CSV was deliberately excluded while its
command, checksum, provenance, and replay summaries were retained.

These are patterns to extract, not reasons to retain a runtime dependency on
the rebuttal repository.

### 5.2 Architecture-specific assumptions that are now invalid

The old cost model is built around:

- `N_leaf_exec` as digit-stream multiplier work;
- Anchor-2 `E_blk_fix` and `E_leaf_cycle` coefficients;
- Anchor-3 payload/header energy and queueing;
- layer latency `max(gate_proj, up_proj) + down_proj`;
- a dense three-projection MAC formula;
- old Anchor-4 storage and controller totals;
- reduced stage-output payload claims.

Those equations and all generated TSS rows must be retired or rewritten.
Loader/report structure can survive, but field names must not give obsolete
events new meanings.

### 5.3 Selected trace limitations

The selected Qwen3-0.6B trace was useful validation of the old end-to-end trace
plumbing. Its provenance says:

- setup 6, MXFP8+MSD with fixed `B=16` and no calibration argument;
- 10 limited samples and 457 scored tokens;
- 84 profiled projection modules;
- 91,721,728 boundary bursts and more than 32 billion boundary words;
- queue latencies of hundreds of millions to billions of cycles under the
  tested service rates.

The V4 configuration pairs the separate 17-dB quality result with this B=16
trace for latency/payload modeling. That was an explicit rebuttal modeling
convenience, not one self-consistent revised-design run. The raw trace is also
about the deleted interface. Preserve its provenance, but do not migrate it as
new simulator input.

### 5.4 Writing status

The rebuttal drafts, tables, and paper-facing hardware language document the
superseded serial-parallel, stage-2, and boundary story. They are historical
source material from which experiment descriptions, baseline explanations,
and evidence-labeling discipline can be recovered. No hardware claim, cost
number, or TSS result should be copied forward without re-derivation.

The V4 configuration also contains machine-specific absolute paths. New active
configuration must use project-relative paths, CLI arguments, or environment
variables.

## 6. Reuse matrix

| Source | Frozen/reuse boundary | New downstream work | Do not carry as revised hardware evidence |
|---|---|---|---|
| PPL runners | preserve code, protocols, result JSONs, and PPL values verbatim | none in `onlinearith`; consume artifacts read-only | old boundary-trace events |
| Experiment config | preserve setup IDs, snapshots, and original projection behavior | external artifact-selection/translation config | none of the stable setup facts |
| Qwen numerical code | preserve MX/TSS numerical implementation as the authoritative software fact | no model-kernel edits; build hardware interpretation outside Transformers | literal reuse as revised RTL structure |
| Calibration | preserve cache/oracle semantics, budgets, SNR points, and fixed-sum results | no recalibration; consume recorded horizons/results with provenance | treating old hardware costs as calibration facts |
| Performance stats | preserve files and per-layer statistics as recorded | a separate stage-1 circuit-ledger adapter using only well-defined fields | payload/burst/header/shard events and the aggregate g/u split |
| Anchor 0 | source/test/synthesis pattern; possibly arithmetic | verify against offline weight representation, then re-synthesize | old numbers if the contract changes |
| Anchor 1 | source/test/bank pattern; possibly `tau`/`L` arithmetic | new config semantics and widths | old product-digit interpretation |
| Anchor 2 | scaffolding and report parsers | full datapath RTL, timing, area, and activity | old leaf/tree characterization |
| Anchor 3 | generic queue-replay idea only | none for the current design | all active interface RTL and results |
| Anchor 4 | generic RAM and selected metadata stores | inventory/config width and new synthesis | completion/payload stores and old total |
| RTL toolchain | Icarus/Yosys/ABC flow and the already-cleared local cell library | new multiplier characterization scripts | claims of signoff power/timing |
| Rebuttal cost model | loaders, schema normalization, source labels, writers, tests | event fields, cost equations, latency, area composition | generated old TSS tables/config formulas |
| Rebuttal artifacts | checksums/manifests/provenance pattern | new trace package after implementation | old boundary trace as simulator input |

## 7. Contracts required before implementation

The broad redesign is decided, but the following details must be frozen before
the numerical oracle or RTL can be considered correct.

### 7.1 Operand representation contract

Specify for the activation target and offline-aligned weight:

- signed representation and zero handling;
- mantissa/radix convention;
- operand widths and whether activation width is fixed or width-classed;
- exact offline alignment equation and retained weight metadata;
- rounding/truncation rule, guard bits, saturation, and overflow;
- product width and post-multiply scaling;
- accumulator width and rounding point.

### 7.2 Schedule-to-multiply contract

Specify whether a standard multiply is issued once after a target activation
mantissa is complete, or whether any intermediate activation-prefix updates
can issue work. The audit's functional boundary assumes the multiplier consumes
the selected target mantissa, but it does not invent the issue timing.

Also freeze:

- whether `D`, `lambda_x`, `tau`, `H`, and `L` retain their old equations;
- how a zero-length window maps to block/element skip;
- whether partial windows shorten block latency or only reduce digit activity;
- multiplier pipeline depth, initiation interval, sharing, and lane count;
- reduction-tree issue and drain policy.

### 7.3 Comparison boundary

Choose and label whether hardware tables report:

- the redesigned gate/up stage alone; or
- an end-to-end FFN total that adds a common, unchanged `down_proj` cost.

This choice affects denominators, but it does not restore a custom stage 2 or
an interface claim.

### 7.4 Frozen numerical-evidence contract

The numerical reference and calibration semantics are already frozen by the
existing simulator. Record rather than redesign:

- the exact setup/configuration and calibration artifact used by each result;
- whether a value is full WikiText-2 or `--limit-samples` evidence;
- the recorded executed-digit definition and denominator;
- model/Transformers/onlinearith revisions and artifact checksums;
- the available per-layer/per-projection fields used by downstream accounting.

The new fixed-point/RTL reference may test its own circuit behavior, but it is
not a replacement forward/PPL or calibration kernel. Any mapping from a frozen
software horizon/effective-precision value to a target activation mantissa must
be explicit and tested in the downstream simulator.

## 8. Required new simulation/accounting shape

### 8.1 Downstream implementation order

Implementation should proceed without editing the frozen model simulator:

1. inventory the frozen result/calibration/statistics artifacts, revisions,
   schemas, and checksums;
2. freeze the translation from recorded horizons/effective-precision facts to
   target activation-mantissa behavior;
3. implement pure reference functions for offline weight alignment, target
   activation formation, fixed-point multiply, and accumulation outside the
   frozen model code;
4. construct a separate stage-1 circuit ledger from projection-resolved frozen
   facts, with formula-backed fields labeled where direct counts do not exist;
5. implement RTL blocks and deterministic reference-vector co-simulation;
6. characterize the mapped multiplier/control/storage and rebuild the cost
   model;
7. combine frozen quality/work evidence and new hardware results only at the
   reporting layer, with both provenances visible.

This prevents downstream hardware work from mutating established algorithmic
facts or hardening an undocumented interpretation.

### 8.2 Event ledger v2

The new ledger should be explicitly stage-1-only and retain layer/projection
identity. Candidate non-overlapping fields are:

```text
metadata/control:
    N_pre_scan
    N_pre_resolve
    N_cfg_block

window/activity:
    N_block_total
    N_block_skip
    N_element_active
    N_activation_digit_read
    N_activation_prefix_update

fixed-point datapath:
    N_aligned_weight_element_read
    N_standard_multiply_issue
    N_tree_input
    N_accumulator_update
```

If multiplier widths vary, counts must be keyed by operand-width class rather
than collapsed into one supposedly uniform `N_standard_multiply_issue` cost.

The ledger must include:

- schema and numerical-kernel versions;
- the offline weight format identifier;
- activation/weight/product widths;
- exact projection scope (`gate_proj`, `up_proj`);
- source/provenance and sample count;
- explicit formulas for any derived counts.

There should be no stage-boundary payload, burst, header, shard, or queue field.
Backward compatibility should be implemented through an explicit v1 reader or
alias layer, never by silently changing what `N_leaf_exec` means.

### 8.3 RTL anchors

The new RTL suite should be organized by function rather than preserving A0--A4
numbering for its own sake:

- metadata alignment/prepass, if still required;
- activation-window/target-mantissa control;
- standard multiplier leaf or lane;
- reduction and accumulation;
- minimal active/shadow metadata storage.

At least one deterministic tiny transaction should be generated by the Python
reference and consumed by SystemVerilog so numerical results and event counts
are checked together. Multiplier synthesis should sweep the actual operand
widths selected by the representation contract.

### 8.4 Cost model

The first revised cost model should be mechanically tied to the v2 ledger:

- each dynamic term owns a distinct event count;
- standard-multiplier energy is width- and implementation-specific;
- activation-digit reads and aligned-weight reads are separate;
- metadata/storage area excludes baseline-common state;
- no Anchor-3/interface term exists;
- common `down_proj` is included only when the declared comparison boundary is
  end-to-end FFN;
- mapped area/timing, trace counts, formulas, and assumptions retain separate
  status labels.

## 9. Reorganization extraction manifest

This manifest guided the completed repository split. The root functional
commands remain in place as a compatibility surface; functional documentation
now lives under `functional_sim/`; all new hardware work is rooted at
`hardware_sim/`. Exact reviewed legacy candidates are quarantined under
`hardware_sim/reference/`, and the cleared cell files are local under
`hardware_sim/tech/`. The active redesigned kernel, ledger, and report package
remain future implementation work governed by the new contracts.

### Bring into the active project

- a concise active design-contract location and an archive/legacy index;
- new downstream hardware/general-simulation packages placed alongside, not
  inside, the frozen PPL/calibration/model code paths;
- reusable RTL source/tests for metadata control and generic storage after
  reviewing their dependencies;
- generic Icarus/Yosys/ABC orchestration and report parsers;
- the already-cleared local cell-library files with their existing headers and
  provenance;
- a clean, versioned event-ledger/report package derived from the rebuttal code;
- small synthetic fixtures and unit tests;
- artifact-manifest/checksum tooling, if still useful.

### Leave in frozen legacy repositories

- Anchor-2 digit-stream RTL/netlists/results as an active datapath;
- all Anchor-3 RTL, traces, queue replays, and characterization;
- Anchor-4 completion and payload storage;
- generated `build/`, netlist, characterization, plot, and result trees;
- the 4.4-GB raw boundary CSV;
- V0--V4 rebuttal tables/configurations as active configuration;
- paper/rebuttal prose that asserts serial-parallel weight digits, stage 2, or
  a reduced-payload boundary;
- absolute machine-specific paths.

### Preserve history without importing it

The active documentation should retain the audited commit IDs and point to the
legacy repositories. Small extracted files should record their origin. There
is no need to duplicate generated artifacts merely to preserve provenance;
their existing repositories and manifests already do that.

## 10. Acceptance criteria for the later redesign

The redesign is not ready for new hardware/paper results until all of these
hold:

- `onlinearith` and modified-Transformers simulation code/results remain
  unchanged and their revisions/provenance are recorded;
- one frozen downstream operand/schedule/translation contract exists;
- a stage-1-only v2 ledger reports target-activation work and standard
  multiplier issues separately;
- Python circuit reference and RTL agree on result and event counts for tiny
  transactions;
- multiplier, tree, and retained control/storage RTL are re-synthesized;
- energy source status is explicit and no old proxy coefficient is carried
  forward unnoticed;
- no active cost equation contains stage-2 payload/interface terms;
- frozen calibration/PPL/executed-digit results are used without semantic
  rewriting or regeneration;
- any table combining frozen software evidence with new hardware accounting
  exposes both sources and does not imply they came from one new model run;
- executed-digit ratio remains the primary algorithmic work metric, while new
  circuit reads/multiplies/latency remain separate accounting metrics.

## 11. Key audited sources

These are the shortest paths back to the evidence used in this audit and the
original extraction candidates.

| Topic | Primary source paths |
|---|---|
| PPL/config/calibration entry points | `ppltest.py`, `ppl_batch.py`, `experiment_config.py`, `calibrate.py` |
| Current Qwen arithmetic | `../transformers/src/transformers/models/qwen3/modeling_qwen3.py` |
| Current calibration oracle | `../transformers/src/transformers/models/qwen3/calibration_msd.py` |
| Current trace/statistics code | `../transformers/src/transformers/models/qwen3/msd_perf_stats.py` |
| Old integrated hardware contract | `../anchors/hardware-contract-v1.md` |
| Old canonical costs/status | `../anchors/reports/tss_anchor_costs_v1.json`, `../anchors/reports/tss_anchor_costs_v1.md` |
| Metadata prepass | `../anchors/anchor0/rtl/`, `../anchors/anchor0/tb/`, `../anchors/anchor0/scripts/` |
| Window builder/config | `../anchors/anchor1/rtl/`, `../anchors/anchor1/tb/`, `../anchors/anchor1/yosys/` |
| Superseded leaf datapath | `../anchors/anchor2/rtl/anchor2_leaf_ctrl.sv`, `../anchors/anchor2/rtl/anchor2_stage1_block_engine.sv` |
| Old energy-proxy method | `../anchors/anchor2/scripts/fit_anchor2_energy.py`, `../anchors/anchor3/scripts/fit_anchor3_energy.py` |
| Deleted boundary path | `../anchors/anchor3/`, especially `scripts/trace_boundary_queue.py` |
| Storage candidates/inventory | `../anchors/anchor4/rtl/`, `../anchors/anchor4/docs/anchor4_bit_accounting.md` |
| Synthesis reference files | `../anchors/tech_lib/stdcells.lib`, `../anchors/tech_lib/stdcells.v` |
| Old ledger/cost/report code | `../rebuttal/e2e_cost_model/`, `../rebuttal/tests/test_e2e_cost_model.py` |
| Old V4 assumptions | `../rebuttal/configs/e2e_cost_model_rebuttal_v4.json` |
| Artifact provenance pattern | `../rebuttal/packed_rebuttal_artifacts/README.md`, `../rebuttal/packed_rebuttal_artifacts/manifest.json` |

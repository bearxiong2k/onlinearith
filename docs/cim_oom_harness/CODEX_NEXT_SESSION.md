# Qwen3-8B OOM/performance handoff

Use this prompt for the next Codex session:

```text
Continue the Qwen3-8B OOM/performance iteration in /home/xzj/coding/onlinearith.

Read and follow:
- AGENTS.md
- docs/cim_oom_harness/CODEX_PROMPT.md
- docs/cim_oom_harness/CODEX_OOM_PERF_PLAN.md

Hard invariants:
- Preserve PPL methodology: WikiText-2 raw test, MAX_LENGTH=4096, STRIDE=512,
  masked context labels, weighted NLL accumulation.
- Do not implement model sharding/device_map until single-GPU setup 2 and setup 6
  are proven.
- Do not change dataset, tokenizer, labels, loss weighting, MAX_LENGTH, or STRIDE.
- Treat fixed-sum calibrated MSD, uniform MSD, MX-only, WANDA structured
  sparsity, and activation n:m as paper-critical paths. Do not call the overall
  OOM/perf iteration complete until these paths have comparable runner hygiene
  and smoke evidence.

GPU visibility rule:
- Before any Qwen3-8B probe/PPL/calibration/timing run, execute:
  ../.venv3_10/bin/python -c 'import torch; print(torch.cuda.is_available(), torch.cuda.device_count())'
- Expected output is True and 8 devices. If it reports False/0, do not run GPU
  performance work in that environment.
- Valid GPU progress has cuda_alloc_gib/cuda_peak_* fields and should be visible
  in nvtop. Ignore sandbox progress files without cuda_* fields.

Current implementation:
- Exact output-chunked MX-only path is implemented.
- Compact MXFP weight cache is implemented.
- PPL/probe flags are implemented: --stats, --mx-chunk-target-mib,
  --msd-chunk-target-mib, --weight-cache-dtype.
- Tail-logits chunked loss is implemented and covered by tests.
- Shared MXFP/MSD progress reporting is wired into probe, ppltest, ppl_batch,
  and the ladder script.
- Sibling Transformers modeling_qwen3.py has the optimized MSD truncation path:
  frexp/ldexp scale reconstruction, no final zero-mask allocation, and NAF-width
  frexp exponent extraction.
- `--gpus` is applied before torch import in probe, ppltest, and ppl_batch so
  requested physical GPUs are honored before CUDA state is cached.
- `PYTORCH_ALLOC_CONF=expandable_segments:True` is set by default before torch
  import in probe, ppltest, and ppl_batch.
- `--compile-msd-truncate` is implemented for probe, ppltest, and ppl_batch.
  It sets `config.msd_compile_truncate=True` and uses
  `torch.compile(_msd_truncate, fullgraph=True, mode="reduce-overhead")` only
  when explicitly requested on CUDA. The default remains false.
- Parent venv now has setuptools installed, so torch.compile is no longer
  blocked by ModuleNotFoundError.
- `calibrate.py` is now wired into the same Qwen3-8B runtime controls:
  `--gpus` is applied before torch import, `PYTORCH_ALLOC_CONF` defaults to
  `expandable_segments:True`, model `use_cache` is forced false, and the CLI
  accepts `--mx-chunk-target-mib`, `--cal-chunk-target-mib`,
  `--weight-cache-dtype`, and `--compile-msd-truncate`.
- Calibration capture now applies `--projection-filter` before hook
  registration and quantized-weight capture, so targeted 8B calibration probes
  do not materialize every MLP projection's quantized weights.
- Sibling Transformers `calibration_msd.py` has calibration-only runtime
  controls, compile-aware `_msd_truncate` scheduling, and frexp-based
  intra-block delay extraction that preserves the old `floor(log2(abs(x)))`
  delay semantics.

Path parity status:
- MX-only baselines and uniform MSD setup 6 are memory-feasible on one 32 GB GPU
  for the validated Qwen3-8B probes/smokes below.
- Fixed-sum calibrated MSD is partially optimized: calibration generation has
  the new controls and a targeted one-layer smoke, and `ppltest.py
  --calibration` injects metadata into the optimized MSD runtime. Missing:
  broader staged calibration and a calibrated-MSD Qwen3-8B PPL smoke using the
  generated fixed-sum metadata.
- WANDA structured sparsity baseline is not yet at parity. Its calibration and
  PPL scripts live under `wanda_base/` and still use older runner plumbing:
  torch is imported before GPU visibility is applied, allocator defaults are not
  set before torch import, `use_cache=False` and tail-logits loss are not wired,
  chunk/cache controls are not exposed, and cache cleanup/progress handling is
  not aligned with `ppltest.py`.
- Runtime activation n:m baseline is not yet at parity. `act_base/ppl_batch_base_act.py`
  has the same older PPL loop issues as WANDA and needs the shared PPL utilities
  plus Qwen3-8B smoke validation.

Valid GPU measurements:
- Setup 2 probe, seq_len=4096: status ok; peak_alloc=27.6147 GiB;
  peak_reserved=28.2090 GiB; reserved_headroom=3.1477 GiB;
  meets_min_headroom=true; mxfp_weight_cache.total_gib=10.7578.
- Setup 2 ppltest --limit-samples=2 completed on one GPU.
- Setup 6 baseline before the NAF-width frexp change:
  layer 0 gate/up/down completed in about 51.2s / 102.1s / 153.9s;
  bounded timeout reached layers.1.mlp.up_proj chunk 1830 / 3072;
  peak_reserved about 19.3418 GiB.
- Setup 6 with kept NAF-width frexp change:
  layer 0 gate/up/down completed in about 45.8s / 91.3s / 137.6s;
  bounded timeout reached layers.1.mlp.up_proj at 100%, then entered
  layers.1.mlp.down_proj; peak_reserved about 19.3418 GiB.
- Setup 6 chunk-size trials:
  MSD_CHUNK=2048 OOMed immediately, peak_reserved=30.533 GiB,
  reserved_headroom=0.823 GiB.
  MSD_CHUNK=1024 avoided OOM in a bounded run but did not materially improve
  runtime versus 256 MiB.
- frexp-width plus in-place stats-off p_eff construction was slower on GPU
  (layer 0 about 46.9s / 93.6s / 141.0s) and was reverted.
- Setup 6 with `--compile-msd-truncate`, seq_len=4096: status ok;
  elapsed=1059.95s; loss=0.01120709; peak_alloc=27.8387 GiB;
  peak_reserved=28.7617 GiB; reserved_headroom=2.5950 GiB;
  meets_min_headroom=true; mxfp_weight_cache.total_gib=10.7578.
- Setup 6 `ppltest --limit-samples=2 --compile-msd-truncate` completed on one
  GPU. It is a smoke only: the first two WikiText test samples score 8 tokens.
  Token PPL=423.0598, mean NLL=6.0475, peak memory=27.08 GB.
- Setup 6 `ppltest --limit-samples=80 --compile-msd-truncate` completed on one
  GPU. This prefix has 4,144 tokens and evaluates two windows, including a full
  4,096-token context window. Token PPL=8.8708, mean NLL=2.1828, scored
  tokens=4,144, peak memory=28.03 GB, wall time=2000.6s.
- Targeted Qwen3-8B calibration smoke completed on GPU 5:
  `calibrate.py --model-path ../Qwen3-8B --gpus 5 --setup 1 --optimizer fixed_sum
  --projection-filter model.layers.0.mlp.gate_proj --num-texts 1 --max-length 64
  --batch-size 1 --target-snr 10 --curve-window 1 --mx-chunk-target-mib 256
  --cal-chunk-target-mib 64 --weight-cache-dtype float16 --compile-msd-truncate`.
  It captured/solved exactly one layer, total_channels=12,288, budget range
  [4, 9], budget_mean=6.09, mean_snr=12.84 dB, wall_time=6.68s. Output was
  written under `/tmp/onlinearith_calib_smoke/` and should not be committed.

Invalid/non-source-of-truth artifacts:
- Ignore 2026-05-21 sandbox progress files without cuda_* fields. They were CPU
  or CUDA-invisible runs and are not GPU evidence.
- Generated probe JSON/log files are not committed; rely on this handoff for
  summarized measurements.

Recommended next steps:
1. Verify CUDA visibility outside the sandbox.
2. Run the cheap contracts:
   ../.venv3_10/bin/python tests/test_msd_truncate_equivalence.py
   ../.venv3_10/bin/python tests/test_mx_exact_chunked.py
   ../.venv3_10/bin/python tests/test_mxfp_weight_cache_compact.py
   ../.venv3_10/bin/python tests/test_ppl_tail_logits_loss.py
   ../.venv3_10/bin/python test_mxfp8linear.py
   ../.venv3_10/bin/python test_fixed_sum_optimizer.py
   ../.venv3_10/bin/python calibrate.py --list
3. Bring WANDA and activation baseline runners to parity with `ppltest.py`:
   early `--gpus`, allocator default before torch import, `use_cache=False`,
   shared window/loss utilities, tail-logits loss, chunk/cache controls, cache
   cleanup, and `--limit-samples` smoke support.
4. Stage calibrated-MSD fixed-sum validation:
   projection-filtered calibration -> broader MLP subset -> calibrated
   `ppltest.py --setup 6 --calibration <fixed_sum.json> --compile-msd-truncate`
   smoke. Treat `target-snr` fixed-sum metadata as the main calibrated method.
5. Then run WANDA and activation Qwen3-8B smokes with direct CUDA evidence.
6. Full setup 6 seq_len=4096 probe completes in about 17.7 minutes with
   compile enabled; a two-window setup 6 PPL smoke takes about 33.3 minutes.
7. If optimizing further, keep MSD math unchanged and benchmark only with direct
   CUDA.
   Current conservative setup 6 chunking at seq_len=4096 uses gate/up chunk 4
   and down chunk 1 because the temporary (N, chunk, nb, bs) tensor is large.
```

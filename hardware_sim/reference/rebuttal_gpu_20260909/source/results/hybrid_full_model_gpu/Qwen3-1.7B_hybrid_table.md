# Full-GPU Baseline With CIM FFN Ratio Table

The dense baseline is measured as full GPU runtime. The GPU FFN bucket is
derived as full GPU minus GPU non-FFN runtime, and each method scales that
FFN bucket by its V4 TLM/CIM FFN cycle ratio.

## Provenance

- Model: `Qwen3-1.7B` from `/home/xzj/coding/Qwen3-1.7B`
- Device: `NVIDIA GeForce RTX 5090` via `cuda:0`
- PyTorch/CUDA: `2.10.0+cu130` / `13.0`
- Transformers: `5.2.0.dev0`
- Driver: `580.95.05`
- dtype: `bfloat16`; batch size: `1`
- Warmup/repeat: `1` / `3`
- Full-GPU timing: `decoder model with MLPs enabled plus last-token lm_head projection`
- GPU non-FFN timing: `same path after replacing decoder MLP forwards with zero outputs`
- Decode timing: `KV cache prepared outside CUDA event; timed path is one-token decode`
- FFN ratio source: `method_ffn_cycles / dense_ffn_cycles from V4 TLM/CIM e2e_summary.tsv`

## Table

| Model | Scenario | Method | GPU full ms | GPU non-FFN ms | GPU FFN ms | CIM FFN ratio | E2E norm | E2E gain | Source status |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| Qwen3-1.7B | decode_s2048 | Dense MXFP8 | 22.7986 | 20.7103 | 2.0882 | 1.000000 | 1.000000 | 0.0000 | generated_from_shape |
| Qwen3-1.7B | decode_s2048 | TSS 17 dB | 22.7986 | 20.7103 | 2.0882 | 0.535680 | 0.957471 | 4.2529 | formula_backed_from_msd_global_stats:stage1_total_macs_mean_precision_zero_blocks;payload_leaf_digits_no_burst_headers;a1_energy=pending_zero_with_warning;a2_energy=rough_proxy_not_signoff_power |
| Qwen3-1.7B | decode_s2048 | Mask-Compare CIM 2:4 | 22.7986 | 20.7103 | 2.0882 | 0.875000 | 0.988551 | 1.1449 | formula_backed_from_mask_ledger_counts |
| Qwen3-1.7B | prefill_s512 | Dense MXFP8 | 24.9042 | 20.6057 | 4.2986 | 1.000000 | 1.000000 | 0.0000 | generated_from_shape |
| Qwen3-1.7B | prefill_s512 | TSS 17 dB | 24.9042 | 20.6057 | 4.2986 | 0.535680 | 0.919857 | 8.0143 | formula_backed_from_msd_global_stats:stage1_total_macs_mean_precision_zero_blocks;payload_leaf_digits_no_burst_headers;a1_energy=pending_zero_with_warning;a2_energy=rough_proxy_not_signoff_power |
| Qwen3-1.7B | prefill_s512 | Mask-Compare CIM 2:4 | 24.9042 | 20.6057 | 4.2986 | 0.875000 | 0.978425 | 2.1575 | formula_backed_from_mask_ledger_counts |

Notes:

- Dense GPU FFN is measured indirectly as full GPU minus GPU non-FFN.
- E2E gain is normalized to the measured full-GPU dense baseline; no absolute CIM ns/cycle bridge is used for this table.

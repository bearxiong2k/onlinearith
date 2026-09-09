# Attachment: Supporting Measurements for Paper #229

All perplexity values are WikiText-2 unless noted. Tables A4-A5 use measured GPU
non-FFN timing combined with TLM/CIM FFN service ratios as described in the main
response.

## Table A1. Qwen Scale, High-Quality WikiText-2 PPL

| Model | FP16 | MXFP8 | TSS 30 dB | WANDA 2:4 | Act. 2:4 |
|---|---:|---:|---:|---:|---:|
| Qwen3-0.6B | 17.3443 | 17.2754 | 17.3212 (+0.0458) | 40.3042 | 37.5716 |
| Qwen3-1.7B | 14.6644 | 14.6248 | 14.4661 (-0.1587) | 27.2134 | 20.9451 |
| Qwen3-4B | 11.2364 | 11.2757 | 11.2926 (+0.0169) | 18.7089 | 16.5446 |
| Qwen3-8B | 8.2722 | 8.2964 | 8.3177 (+0.0213) | 12.4731 | 10.6433 |

## Table A2. Llama-3.2-3B Cross-Family PPL

| Model | MXFP8 | TSS 17 dB | TSS 30 dB | WANDA 2:4 | Act. 2:4 |
|---|---:|---:|---:|---:|---:|
| Llama-3.2-3B | 6.5173 | 6.7859 | 6.5271 | 15.1917 | 11.0518 |

## Table A3. Qwen Lower-Work Operating Point, 17 dB

| Model | MXFP8 | TSS 17 dB | WANDA 2:4 | Act. 2:4 |
|---|---:|---:|---:|---:|
| Qwen3-0.6B | 17.2754 | **19.4307** | 40.3042 | 37.5716 |
| Qwen3-1.7B | 14.6248 | **14.9315** | 27.2134 | 20.9451 |
| Qwen3-4B | 11.2757 | **13.7060** | 18.7089 | 16.5446 |
| Qwen3-8B | 8.2964 | 11.5926 | 12.4731 | **10.6433** |

## Table A4. Full-GPU-Relative Hybrid E2E Latency

Measured GPU full/non-FFN times are combined with TLM/CIM FFN service ratios.
Every gain is normalized to the measured full-GPU baseline:
$T_{\mathrm{hybrid}}=T_{\mathrm{gpu,nonFFN}}+
r_{\mathrm{FFN}}(T_{\mathrm{gpu,full}}-T_{\mathrm{gpu,nonFFN}})$.

| Scenario | Method | Meas. GPU full ms | Meas. GPU non-FFN ms | GPU FFN slice ms | FFN share | TLM FFN ratio | Hybrid E2E ms | Norm. vs GPU | Gain |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| decode_s2048 | GPU full baseline | 22.799 | 20.710 | 2.088 | 9.2% | 1.000000 | 22.799 | 1.000000 | 0.000% |
| decode_s2048 | TSS 17 dB | 22.799 | 20.710 | 2.088 | 9.2% | 0.535680 | 21.829 | 0.957471 | 4.253% |
| decode_s2048 | Mask-CIM 2:4 | 22.799 | 20.710 | 2.088 | 9.2% | 0.875000 | 22.538 | 0.988551 | 1.145% |
| prefill_s512 | GPU full baseline | 24.904 | 20.606 | 4.299 | 17.3% | 1.000000 | 24.904 | 1.000000 | 0.000% |
| prefill_s512 | TSS 17 dB | 24.904 | 20.606 | 4.299 | 17.3% | 0.535680 | 22.908 | 0.919857 | 8.014% |
| prefill_s512 | Mask-CIM 2:4 | 24.904 | 20.606 | 4.299 | 17.3% | 0.875000 | 24.367 | 0.978425 | 2.158% |

## Table A5. Qwen3-1.7B Decode, Common-Interface Comparison

Arbitrary flexible-mask hardware is excluded unless a matched CIM
routing/buffering/utilization model is available; Table A5b states the
modeled 2:4 Mask-CIM assumptions.

| Method | PPL | Norm. E2E lat. | Lat. gain | Norm. throughput | Norm. E2E energy | Energy red. | Norm. area | Basis |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Dense MXFP8 | 14.6248 | 1.000 | 0.0% | 1.000 | 1.000 | 0.0% | 1.000 | measured full-GPU denominator; dense simulator baseline |
| TSS 17 dB | 14.9315 | 0.957 | 4.3% | 1.044 | 0.884 | 11.6% | 1.011 | measured GPU split plus TLM FFN ratio; RTL timing/area; proxy dynamic energy |
| Mask-CIM 2:4 | 20.9451 | 0.989 | 1.1% | 1.012 | 0.925 | 7.5% | 1.114 | formula-backed mask ledger; dense reads/payload kept; no packed-sparse issue |

## Table A5b. Mask-CIM 2:4 Modeling Assumptions

| Component | Modeled treatment |
|---|---|
| Activation read | dense |
| Mask generation/control | counted |
| Weight read | selected 2-of-4 entries benefit |
| Local reduction tree | selected fan-in benefit |
| Fixed pipeline stages | dense |
| Output payload | dense |
| Utilization model | dense-lane issue; no packed sparse issue |
| Routing/buffering for arbitrary masks | not assigned without matched CIM design |
| Energy status | formula-backed mask ledger; TSS controller energy remains proxy where labeled |
| Latency ledger | dense fixed/access/payload/control terms; selected-read and local-tree terms receive 2-of-4 benefit |
| Energy ledger | activation read + compare + mask payload/control + selected weight/compute/tree + dense output payload |

## Table A6. Qwen3-1.7B $K$ Sensitivity

A6 is a within-sweep ablation on the same fixed evaluation subset for all $K$
rows; compare absolute PPL within A6, while A1 remains the full-test headline.

| $K$ | MXFP8 PPL | TSS 17 dB PPL | Digit-work proxy | Metadata entries vs $K=32$ |
|---:|---:|---:|---:|---:|
| 8 | 13.6369 | 13.5499 (-0.0870) | 0.465 | 4.00x |
| 16 | 13.5906 | 13.5840 (-0.0066) | 0.470 | 2.00x |
| 32 | 13.5924 | 13.7575 (+0.1651) | 0.473 | 1.00x |
| 64 | 13.6242 | 13.7191 (+0.0949) | 0.474 | 0.50x |
| 128 | 13.5624 | 13.4459 (-0.1165) | 0.474 | 0.25x |

## Table A7. Calibration Runtime Examples

| Model/configuration | Runtime |
|---|---:|
| Qwen3-1.7B, $K=64$, 17 dB | 2802.9 s |
| Qwen3-1.7B, $K=16$, 17 dB | 2963.4 s |
| Llama-3.2-3B, 17 dB | 5584.0 s |
| Llama-3.2-3B, 20 dB | 5692.0 s |
| Llama-3.2-3B, 30 dB | 5868.7 s |

## Table A8. Control-Path Accounting

Control work is counted once and staged one block ahead. The table separates the
counted control operations from the timing and storage anchors.

| Category | Item | Accounting | Value / policy |
|---|---|---|---|
| Control work | Scale prepass | counted | computes $E$, $E_{\max}$, and $D$ |
| Control work | Scheduler/window build | counted | consumes $D$, $H$, and $\lambda_x$ |
| Control work | $\lambda_x$ decode/fanout | counted | included in controller path |
| Control work | Configuration switch | counted | active/shadow buffering |
| Timing anchor | Controller service | counted | 3 staged control cycles |
| Timing anchor | Data-plane slot | reference | 16 cycles/block |
| Timing anchor | Slack after fill | derived | about 13 cycles |
| Storage anchor | Horizon table | counted | 1 integer/output channel |
| Storage anchor | Control/storage inventory | counted | 80,032 bits; 81,153.208 $\mu\mathrm{m}^2$ |

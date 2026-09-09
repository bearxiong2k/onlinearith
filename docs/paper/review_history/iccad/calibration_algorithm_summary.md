# Calibration Algorithm Summary

Source docs/code:

- `/home/xzj/coding/onlinearith/docs/calibration/fixed_sum_calibration.md`
- `/home/xzj/coding/onlinearith/calibrate.py`
- `/home/xzj/coding/transformers/src/transformers/models/qwen3/calibration_msd.py`
- `/home/xzj/coding/onlinearith/test_fixed_sum_optimizer.py`

## What Calibration Produces

Calibration produces one integer MSD horizon/budget per MXFP linear layer and
output channel:

```text
msd_calibration_data[layer_name][channel] = B_j
```

At inference, this replaces the uniform `msd_cycle_budget` with a static
per-channel budget table. There is no online optimization and no graph change.

## Practical Defaults

From `calibrate.py`:

| Parameter | Default |
|---|---:|
| Target SNR | 30 dB |
| Calibration texts | 20 paragraphs |
| Max tokens per text | 512 |
| Batch size | 4 |
| Online delay | 2 |
| Budget bounds | 4 to 48 cycles |
| Fixed-sum error-curve window | +/-3 cycles |

For rebuttal runs, the same driver is also used with other target SNRs such as
15/17/20/30 dB.

## Stage 1: Exact-MX Cache Capture

`collect_layer_block_cache()` runs calibration texts through the model with MSD
truncation disabled and hooks each MXFP linear layer.

It stores:

- activation MX blocks `(x_q, x_scales)` for each calibration batch;
- weight MX blocks `(w_q, w_scales)` once per layer;
- layer metadata needed to replay exact and truncated MX dot products.

This stage uses exact MX quantization, not dense FP output, as the reference for
the truncation error.

## Stage 2a: SNR-Min Budget Search

`solve_min_snr_budgets_from_cache()` finds the minimum per-channel budget that
meets a target SNR. For each layer:

1. Compute exact MX output `Y_exact`.
2. For each output channel, binary search an integer budget in `[4, 48]`.
3. For each candidate budget `B_j`, compute truncated output `Y_hat(B_j)`.
4. Compute per-channel SNR:

```text
SNR_j = 10 log10( mean(Y_exact_j^2) / mean((Y_exact_j - Y_hat_j)^2) )
```

5. Return the smallest `B_j` whose SNR is at least the target.

The implementation uses 12 binary-search iterations and output-channel
chunking to bound the 4D intermediate tensors.

## Delay Formula Used During Search

For a token/sample `n`, channel `c`, block `b`, and element `k`, calibration
uses the same delay model as inference:

```text
combined_e[n,c,b] = floor(log2(x_scale[n,b]) + log2(w_scale[c,b]))
inter_delay[n,c,b] = max_b combined_e[n,c,b] - combined_e[n,c,b]
lambda_x[n,b,k] = max_k floor(log2(abs(x_q[n,b,k]))) - floor(log2(abs(x_q[n,b,k])))
total_delay[n,c,b,k] = inter_delay[n,c,b] + lambda_x[n,b,k] + online_delay
p_eff[n,c,b,k] = max(0, B_j - total_delay[n,c,b,k])
```

Then `p_eff` controls how many MSD mantissa digits are retained for each
element contribution. The unit test validates the `lambda_x` formula.

## Stage 2b: Fixed-Sum Error Curves

The `snr_min` vector `B*` is a feasible anchor. The fixed-sum optimizer keeps
the same total cycle budget:

```text
S = sum_j B*_j
```

For each channel `j`, `build_error_curves_from_cache()` evaluates local squared
error curves around the SNR-min budget:

```text
E_j(b) = ||Y_exact_j - Y_hat_j(b)||^2
b in [B*_j - window, B*_j + window], clamped to [4, 48]
```

The default window is 3, so each channel typically uses up to 7 candidate
budget points.

## Stage 2c: Fixed-Sum Redistribution

`solve_fixed_sum_from_error_curves()` greedily moves cycles from low-loss donor
channels to high-gain receiver channels:

```text
donor_loss_j    = E_j(B_j - 1) - E_j(B_j)
receiver_gain_j = E_j(B_j) - E_j(B_j + 1)
```

Algorithm:

1. Initialize `B = B*`.
2. Build a min-heap of donors keyed by smallest `donor_loss`.
3. Build a max-heap of receivers keyed by largest `receiver_gain`.
4. Move one cycle from best donor to best receiver while
   `receiver_gain > donor_loss`.
5. Stop when no beneficial swap remains.

Constraints:

- `sum(B)` is preserved exactly.
- Budgets remain integer.
- Budgets remain inside `[4, 48]`.

Unit tests cover sum preservation, bounds preservation, no-op behavior when no
beneficial swap exists, beneficial redistribution on synthetic curves, and
backward-compatible JSON output.

## Optional Stage 3: Holdout Validation

If `--holdout-fraction` is set, calibration captures a separate holdout cache
and evaluates the chosen budget vector on held-out texts with
`evaluate_budget_vector_from_cache()`. The output reports layer mean/min SNR,
total error, budget sum, and budget mean.

## Rebuttal Wording

Concise reviewer-facing version:

> Calibration is a one-time offline procedure. First, we run a small set of
> calibration texts through the MXFP model with MSD truncation disabled and
> cache exact-MX activation/weight blocks for each FFN projection. Second, for
> each output channel, we binary-search the minimum integer horizon that reaches
> the target SNR against the exact-MX output. Third, for the fixed-sum operating
> point, we build local per-channel error curves around this SNR-min vector and
> greedily redistribute one cycle at a time from channels with the smallest
> donor loss to channels with the largest receiver gain, stopping when no swap
> reduces total error. This preserves the total cycle budget exactly, keeps all
> budgets in hardware bounds, and stores only the final per-channel integer
> horizons for inference.

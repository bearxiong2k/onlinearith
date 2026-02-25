"""
Debug / validation script for MXFP8Linear.

Tests:
  1. Shape correctness
  2. Block-wise scale correctness (manual re-computation)
  3. Quantisation error magnitude vs fp32 baseline
  4. Batch-dimension handling (3-D input)

Run from repo root:
    cd /home/xzjnew/coding
    python onlinearith/test_mxfp8linear.py
"""

import sys
import math
import torch
import torch.nn as nn

# Make the local transformers importable
sys.path.insert(0, "/home/xzjnew/coding/transformers/src")
from transformers.models.qwen3.modular_qwen3 import MXFP8Linear, _FP8_E4M3_MAX

BLOCK = 8
IN  = 32
OUT = 16
torch.manual_seed(42)


def make_layer(in_f=IN, out_f=OUT, bias=False, block=BLOCK):
    class _Cfg:
        mxfp8_block_size = block
    layer = MXFP8Linear(in_f, out_f, bias=bias, config=_Cfg())
    nn.init.normal_(layer.weight)
    return layer


# ── helper: reference block-wise computation ──────────────────────────────────
def ref_mxfp8_matmul(x: torch.Tensor, w: torch.Tensor, block_size: int) -> torch.Tensor:
    """
    Pure-Python reference: matches the block-wise accumulation in MXFP8Linear.
    x : (N, IN)   w : (OUT, IN)
    returns (N, OUT)
    """
    N, IN_ = x.shape
    feat = IN_
    pad = (-feat) % block_size
    if pad:
        x = torch.nn.functional.pad(x, (0, pad))
        w = torch.nn.functional.pad(w, (0, pad))
    nb = x.shape[-1] // block_size
    x_b = x.float().view(N,   nb, block_size)
    w_b = w.float().view(w.shape[0], nb, block_size)

    scale_x = (x_b.abs().amax(-1) / _FP8_E4M3_MAX).clamp(min=1e-30)  # (N,   nb)
    scale_w = (w_b.abs().amax(-1) / _FP8_E4M3_MAX).clamp(min=1e-30)  # (out, nb)

    x_fp8 = (x_b / scale_x.unsqueeze(-1)).to(torch.float8_e4m3fn).float()
    w_fp8 = (w_b / scale_w.unsqueeze(-1)).to(torch.float8_e4m3fn).float()

    out = torch.zeros(N, w.shape[0])
    for b in range(nb):
        elem = x_fp8[:, b, :] @ w_fp8[:, b, :].t()       # (N, out)
        sc   = scale_x[:, b:b+1] * scale_w[:, b:b+1].t() # (N, out)
        out += elem * sc
    return out


# ──────────────────────────────────────────────────────────────────────────────

def test_shape():
    layer = make_layer()
    x = torch.randn(4, IN)
    y = layer(x)
    assert y.shape == (4, OUT), f"shape mismatch: {y.shape}"
    print("[PASS] test_shape")


def test_3d_batch():
    layer = make_layer()
    x = torch.randn(2, 5, IN)
    y = layer(x)
    assert y.shape == (2, 5, OUT), f"3-D shape mismatch: {y.shape}"
    print("[PASS] test_3d_batch")


def test_bias():
    layer = make_layer(bias=True)
    nn.init.ones_(layer.bias_param)
    x = torch.zeros(3, IN)
    y = layer(x)
    # With all-zero input the block scales will be tiny (clamped to eps),
    # fp8-quantised x is 0, so output should equal bias.
    # Verify by checking the result equals bias for zero input.
    # (scale_x * scale_w * 0) => 0, result => bias
    expected = torch.ones(3, OUT)
    assert torch.allclose(y, expected, atol=1e-5), f"bias test failed: max diff {(y - expected).abs().max()}"
    print("[PASS] test_bias")


def test_matches_reference():
    layer = make_layer()
    x = torch.randn(6, IN)
    y_mx   = layer(x)
    y_ref  = ref_mxfp8_matmul(x, layer.weight.data, BLOCK)
    max_diff = (y_mx.float() - y_ref).abs().max().item()
    assert max_diff < 1e-5, f"mismatch vs reference: max diff {max_diff}"
    print(f"[PASS] test_matches_reference  (max_diff={max_diff:.2e})")


def test_quantisation_error():
    """Compare MX FP8 output to fp32 reference; report SNR / max-abs-error."""
    layer = make_layer()
    fp_ref  = nn.Linear(IN, OUT, bias=False)
    fp_ref.weight.data.copy_(layer.weight.data)

    x = torch.randn(64, IN)
    y_fp32  = fp_ref(x).detach()
    y_mxfp8 = layer(x).detach()

    abs_err  = (y_fp32 - y_mxfp8).abs()
    rel_err  = abs_err / (y_fp32.abs() + 1e-8)
    signal_power   = y_fp32.pow(2).mean()
    noise_power    = abs_err.pow(2).mean()
    snr_db = 10 * math.log10((signal_power / noise_power).item()) if noise_power > 0 else float("inf")

    print(f"[INFO] test_quantisation_error")
    print(f"       FP32 output  max={y_fp32.abs().max():.4f}, mean={y_fp32.abs().mean():.4f}")
    print(f"       MX FP8  output  max={y_mxfp8.abs().max():.4f}, mean={y_mxfp8.abs().mean():.4f}")
    print(f"       Absolute error: max={abs_err.max():.6f}, mean={abs_err.mean():.6f}")
    print(f"       Relative error: max={rel_err.max():.4%}, mean={rel_err.mean():.4%}")
    print(f"       SNR: {snr_db:.2f} dB")


def test_scale_values():
    """Assert that computed scales are fp32 positive, one per block."""
    class _Cfg:
        mxfp8_block_size = BLOCK
    layer = MXFP8Linear(IN, OUT, bias=False, config=_Cfg())
    nn.init.normal_(layer.weight)

    x = torch.randn(3, IN)
    feat = IN
    pad  = (-feat) % BLOCK
    x2   = torch.nn.functional.pad(x, (0, pad)).float()
    nb   = x2.shape[-1] // BLOCK
    blocks = x2.view(3, nb, BLOCK)
    _, scales = MXFP8Linear._quantize_fp8(blocks)

    assert scales.shape == (3, nb),      f"scale shape wrong: {scales.shape}"
    assert scales.dtype == torch.float32, f"scale dtype wrong: {scales.dtype}"
    assert (scales > 0).all(),            "non-positive scales detected"
    print(f"[PASS] test_scale_values  scales.shape={scales.shape}, dtype={scales.dtype}")


# ──────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print(f"PyTorch {torch.__version__}  |  BLOCK={BLOCK}, IN={IN}, OUT={OUT}")
    print("=" * 60)
    test_shape()
    test_3d_batch()
    test_bias()
    test_matches_reference()
    test_quantisation_error()
    test_scale_values()
    print("=" * 60)
    print("All tests passed.")

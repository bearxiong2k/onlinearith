#!/usr/bin/env python3
"""
Contract test for the stats-off MSD inference fast path.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import torch

REPO_ROOT = Path(__file__).resolve().parents[1]
TRANSFORMERS_SRC = (REPO_ROOT / ".." / "transformers" / "src").resolve()
if TRANSFORMERS_SRC.exists() and str(TRANSFORMERS_SRC) not in sys.path:
    sys.path.insert(0, str(TRANSFORMERS_SRC))

from transformers.models.qwen3.modeling_qwen3 import MXFP8Linear
from transformers.models.qwen3.msd_perf_stats import MSDPerfAccumulator


class Cfg:
    use_msd_truncation = True
    use_activation_nm_sparsity = False
    mxfp8_block_size = 8
    mxfp_use_chunked_exact = True
    mxfp_chunk_target_mib = 1
    mxfp_weight_cache_dtype = "float16"
    msd_cycle_budget = 6
    msd_online_delay = 2
    msd_budget_dynamic_scale = 0.0
    msd_budget_dynamic_threshold = 0.0
    msd_budget_dynamic_mode = "linear"
    msd_deep_pipeline = False
    msd_pipeline_precision_loss = 2
    msd_calibration_data = None
    msd_chunk_target_mib = 1
    msd_compile_truncate = False


class Ctx:
    def __init__(self, layer_name: str, out_features: int, perf_stats):
        self.channel_budgets = {
            layer_name: torch.full((out_features,), float(Cfg.msd_cycle_budget), dtype=torch.float32)
        }
        self.default_budget = Cfg.msd_cycle_budget
        self._channel_budgets_device_cache = {}
        self.perf_stats = perf_stats


def _prepare(layer: MXFP8Linear, x: torch.Tensor):
    batch_shape = x.shape[:-1]
    n = math.prod(batch_shape) if batch_shape else 1
    x_2d = x.float().reshape(n, layer.in_features)
    x_q, x_scales, _ = layer._prepare_blocks(x_2d, n)
    w_q, w_scales, _ = layer._prepare_blocks(layer.weight.float(), layer.out_features)
    return n, x_q, x_scales, w_q, w_scales


def test_stats_off_msd_forward_matches_stats_on_path():
    torch.manual_seed(20260524)
    cfg = Cfg()
    layer = MXFP8Linear(24, 17, bias=False, config=cfg)
    layer.layer_name = "layers.0.mlp.gate_proj"
    layer.eval()
    with torch.no_grad():
        layer.weight.normal_(mean=0.0, std=0.2)

    x = torch.randn(3, 5, layer.in_features, dtype=torch.float32)
    n, x_q, x_scales, w_q, w_scales = _prepare(layer, x)

    stats_off = Ctx(layer.layer_name, layer.out_features, perf_stats=None)
    stats_on = Ctx(
        layer.layer_name,
        layer.out_features,
        perf_stats=MSDPerfAccumulator(lite=True, lite_p_eff_cap=3.0),
    )

    with torch.inference_mode():
        out_off = layer._forward_msd_truncated(x_q, x_scales, w_q, w_scales, n, stats_off)
        out_on = layer._forward_msd_truncated(x_q, x_scales, w_q, w_scales, n, stats_on)

    torch.testing.assert_close(out_off, out_on, rtol=0, atol=0)


if __name__ == "__main__":
    test_stats_off_msd_forward_matches_stats_on_path()
    print("ok")

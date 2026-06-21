#!/usr/bin/env python3
"""
Contract test for the stats-off MSD inference fast path.
"""
from __future__ import annotations

import math
import sys
import tempfile
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
    progress_events = []
    cfg._mxfp_progress_hook = lambda **event: progress_events.append(event)
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

    stats = stats_on.perf_stats.finalize(online_delay=Cfg.msd_online_delay)
    assert stats["global"]["num_layers"] == 1
    assert stats["global"]["mean_effective_precision"] > 0
    assert stats["global"]["max_total_delay"] >= Cfg.msd_online_delay
    ledger = stats["event_ledger"]
    assert ledger["schema"] == "tss_event_ledger_v1"
    assert ledger["N_pre_scan"] > 0
    assert ledger["N_pre_scan"] == ledger["N_pre_resolve"]
    assert sum(ledger["N_blk_total"].values()) == ledger["N_pre_scan"]
    assert sum(ledger["N_blk_exec"].values()) + sum(ledger["N_blk_skip"].values()) == ledger["N_pre_scan"]
    assert sum(ledger["N_leaf_exec"].values()) > 0
    assert layer.layer_name in stats["per_layer"]
    assert [event["phase"] for event in progress_events] == ["msd_chunk", "msd_chunk"]


def test_event_ledger_includes_boundary_trace_totals():
    with tempfile.TemporaryDirectory() as tmp:
        trace_path = Path(tmp) / "boundary.csv"
        stats = MSDPerfAccumulator(
            lite=True,
            figure5_layer_cycles=True,
            boundary_trace_path=str(trace_path),
            boundary_trace_shards=2,
            boundary_trace_payload_digits_per_word=4,
        )
        p_eff = torch.tensor(
            [
                [
                    [[1.0, 0.0], [2.0, 3.0]],
                    [[0.0, 0.0], [0.0, 0.0]],
                ]
            ],
            dtype=torch.float32,
        )
        b_final_c = torch.full((1, 2), 6.0)
        channel_cycle = torch.tensor([[4.0, 2.0]], dtype=torch.float32)
        stats.record_chunk(
            "layers.0.mlp.gate_proj",
            p_eff,
            b_final_c,
            0,
            2,
            1,
            2,
            2,
            max_delay_chunk=torch.tensor([2.0, 0.0]),
            max_budget_chunk=torch.tensor([6.0, 6.0]),
            channel_cycle_chunk=channel_cycle,
        )
        result = stats.finalize(online_delay=Cfg.msd_online_delay)
        ledger = result["event_ledger"]
        assert ledger["N_payload_word"] == {"0": 2, "1": 0}
        assert ledger["N_burst"] == {"0": 1, "1": 0}
        assert ledger["N_hdr_word"] == {"0": 12, "1": 0}
        assert ledger["N_boundary_word"] == {"0": 14, "1": 0}
        assert ledger["boundary_hdr_words_per_burst"] == 12
        assert result["boundary_trace"]["totals"]["N_payload_digit"] == {"0": 6, "1": 0}


def test_event_ledger_can_count_boundary_totals_without_csv():
    stats = MSDPerfAccumulator(
        lite=True,
        boundary_event_ledger=True,
        boundary_trace_shards=2,
        boundary_trace_payload_digits_per_word=4,
    )
    p_eff = torch.tensor(
        [
            [
                [[1.0, 0.0], [2.0, 3.0]],
                [[4.0, 4.0], [0.0, 0.0]],
            ]
        ],
        dtype=torch.float32,
    )
    b_final_c = torch.full((1, 2), 6.0)
    stats.record_chunk(
        "layers.0.mlp.up_proj",
        p_eff,
        b_final_c,
        0,
        2,
        1,
        2,
        2,
        max_delay_chunk=torch.tensor([2.0, 0.0]),
        max_budget_chunk=torch.tensor([6.0, 6.0]),
    )
    result = stats.finalize(online_delay=Cfg.msd_online_delay)
    ledger = result["event_ledger"]
    assert "boundary_trace" not in result
    assert ledger["N_payload_word"] == {"0": 2, "1": 2}
    assert ledger["N_burst"] == {"0": 1, "1": 1}
    assert ledger["N_hdr_word"] == {"0": 12, "1": 12}
    assert ledger["N_boundary_word"] == {"0": 14, "1": 14}
    assert ledger["boundary_trace_path"] is None


if __name__ == "__main__":
    test_stats_off_msd_forward_matches_stats_on_path()
    test_event_ledger_includes_boundary_trace_totals()
    test_event_ledger_can_count_boundary_totals_without_csv()
    print("ok")

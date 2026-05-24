#!/usr/bin/env python3
"""Contracts for opt-in PPL model-sharding helpers."""

from __future__ import annotations

import sys
from pathlib import Path

import torch

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
TRANSFORMERS_SRC = (REPO_ROOT / ".." / "transformers" / "src").resolve()
if TRANSFORMERS_SRC.exists() and str(TRANSFORMERS_SRC) not in sys.path:
    sys.path.insert(0, str(TRANSFORMERS_SRC))

from experiment_config import reconfigure_mlp_layers
from ppltest import model_input_device, parse_max_memory_arg
from transformers import Qwen3Config, Qwen3ForCausalLM
from transformers.models.qwen3.modeling_qwen3 import MXFP8Linear


def test_parse_max_memory_arg():
    assert parse_max_memory_arg(None) is None
    assert parse_max_memory_arg("") is None
    assert parse_max_memory_arg("0:30GiB, 1:28GiB, cpu:64GiB") == {
        0: "30GiB",
        1: "28GiB",
        "cpu": "64GiB",
    }

    for bad in ("0", "0:", ":30GiB", "0:30GiB,0:28GiB"):
        try:
            parse_max_memory_arg(bad)
        except ValueError:
            pass
        else:
            raise AssertionError(f"expected ValueError for {bad!r}")


def test_model_input_device_uses_embedding_weight_device():
    model = torch.nn.Sequential()

    class Wrapper(torch.nn.Module):
        def __init__(self):
            super().__init__()
            self.embedding = torch.nn.Embedding(8, 4)

        def get_input_embeddings(self):
            return self.embedding

    wrapped = Wrapper()
    assert model_input_device(wrapped, torch.device("meta")) == wrapped.embedding.weight.device
    assert model_input_device(model, torch.device("cpu")) == torch.device("cpu")


def test_reconfigure_mlp_layers_preserves_existing_projection_device():
    config = Qwen3Config(
        vocab_size=97,
        hidden_size=32,
        intermediate_size=64,
        num_hidden_layers=1,
        num_attention_heads=4,
        num_key_value_heads=2,
        head_dim=8,
        max_position_embeddings=64,
        use_cache=False,
    )
    model = Qwen3ForCausalLM(config).eval()
    original_device = model.model.layers[0].mlp.gate_proj.weight.device
    model.config.use_mxfp8 = True

    reconfigure_mlp_layers(model, device=None)

    gate_proj = model.model.layers[0].mlp.gate_proj
    assert isinstance(gate_proj, MXFP8Linear)
    assert gate_proj.weight.device == original_device


def _run_direct() -> None:
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()


if __name__ == "__main__":
    _run_direct()
    print("ok")

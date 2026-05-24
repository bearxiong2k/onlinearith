#!/usr/bin/env python3
"""Verify tail-logit PPL loss slicing is loss-equivalent."""

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

from ppl_utils import mask_context_labels, prepare_tail_logits_loss_kwargs
from transformers import Qwen3Config, Qwen3ForCausalLM


def main() -> None:
    torch.manual_seed(0)
    config = Qwen3Config(
        vocab_size=97,
        hidden_size=32,
        intermediate_size=64,
        num_hidden_layers=2,
        num_attention_heads=4,
        num_key_value_heads=2,
        head_dim=8,
        max_position_embeddings=64,
        use_cache=False,
    )
    model = Qwen3ForCausalLM(config).eval()

    for seq_len in (2, 3, 8, 17):
        input_ids = torch.randint(0, config.vocab_size, (1, seq_len))
        for trg_len in sorted({1, min(2, seq_len), seq_len // 2 or 1, seq_len}):
            labels = mask_context_labels(input_ids, trg_len)
            kwargs = prepare_tail_logits_loss_kwargs(labels, trg_len)
            chunked_kwargs = prepare_tail_logits_loss_kwargs(
                labels,
                trg_len,
                loss_token_chunk_size=3,
                output_logits=False,
            )
            assert kwargs["logits_to_keep"].device.type == "cpu"
            assert chunked_kwargs["logits_to_keep"].device.type == "cpu"
            with torch.inference_mode():
                full = model(input_ids, labels=labels, use_cache=False).loss
                sliced = model(input_ids, labels=labels, use_cache=False, **kwargs).loss
                chunked = model(input_ids, labels=labels, use_cache=False, **chunked_kwargs).loss
            torch.testing.assert_close(sliced, full, rtol=1e-6, atol=1e-6)
            torch.testing.assert_close(chunked, full, rtol=1e-6, atol=1e-6)

    print("ok")


if __name__ == "__main__":
    main()

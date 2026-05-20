"""Pure helpers for WikiText sliding-window PPL accounting.

These functions mirror the existing PPL runners without importing datasets,
Transformers, or torch at module import time.
"""

from __future__ import annotations

import math
from collections.abc import Iterable, Sequence
from typing import TypeVar

T = TypeVar("T")


def precompute_windows(seq_len: int, max_length: int = 4096, stride: int = 512) -> list[tuple[int, int, int]]:
    """
    Return ``(begin_loc, end_loc, trg_len)`` windows for weighted PPL scoring.

    ``trg_len`` is the number of newly scored tokens in the window. Earlier
    context tokens must be masked out of the labels by the caller.
    """
    windows: list[tuple[int, int, int]] = []
    prev_end_loc = 0
    for begin_loc in range(0, seq_len, stride):
        end_loc = min(begin_loc + max_length, seq_len)
        trg_len = end_loc - prev_end_loc
        windows.append((begin_loc, end_loc, trg_len))
        prev_end_loc = end_loc
        if end_loc == seq_len:
            break
    return windows


def mask_context_labels(input_ids, trg_len: int, ignore_index: int = -100):
    """Clone token IDs and mask context labels outside the newly scored tail."""
    labels = input_ids.clone()
    labels[:, :-trg_len] = ignore_index
    return labels


def prepare_tail_logits_loss_kwargs(
    labels,
    trg_len: int,
    *,
    loss_token_chunk_size: int | None = None,
    output_logits: bool = True,
) -> dict:
    """
    Return kwargs that compute the same shifted causal loss using only useful logits.

    Hugging Face's causal loss uses logit position ``i`` to predict label
    position ``i + 1``.  For a PPL window with ``trg_len`` newly scored tail
    labels, only logits from the position immediately before that tail through
    the penultimate input position can affect the loss.  Supplying explicit
    ``shift_labels`` keeps the loss equivalent while avoiding a full
    sequence-length vocabulary projection.
    """
    seq_len = labels.shape[-1]
    keep = min(seq_len - 1, trg_len)
    if keep <= 0:
        return {}
    start = seq_len - keep - 1
    logits_to_keep = labels.new_tensor(list(range(start, start + keep)))
    shift_labels = labels[..., start + 1 : start + 1 + keep].contiguous()
    kwargs = {"logits_to_keep": logits_to_keep, "shift_labels": shift_labels}
    if loss_token_chunk_size is not None:
        kwargs["loss_token_chunk_size"] = int(loss_token_chunk_size)
    if not output_logits:
        kwargs["output_logits"] = False
    return kwargs


def accumulate_weighted_nll(
    total_nll: float,
    total_tokens: int,
    loss: float,
    trg_len: int,
) -> tuple[float, int]:
    """Accumulate average window loss weighted by scored-token count."""
    return total_nll + float(loss) * trg_len, total_tokens + trg_len


def finalize_ppl(total_nll: float, total_tokens: int) -> float:
    """Exponentiate the corpus-level mean NLL once."""
    if total_tokens <= 0:
        raise ValueError("total_tokens must be positive")
    return math.exp(total_nll / total_tokens)


def iter_shard(items: Sequence[T], rank: int, world_size: int) -> Iterable[T]:
    """Yield the rank-local strided shard used by the current runners."""
    return items[rank::world_size]

#!/usr/bin/env python3
"""Measure full-GPU and GPU non-FFN timing, then apply CIM FFN ratios."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import subprocess
import time
import types
from pathlib import Path
from typing import Any, Callable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-path", default="/home/xzj/coding/Qwen3-1.7B")
    parser.add_argument("--model-name", default=None)
    parser.add_argument("--device", default="cuda:0")
    parser.add_argument("--dtype", choices=["bfloat16", "float16", "float32"], default="bfloat16")
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--prefill-len", type=int, default=512)
    parser.add_argument("--decode-context-len", type=int, default=2048)
    parser.add_argument("--warmup", type=int, default=3)
    parser.add_argument("--repeat", type=int, default=9)
    parser.add_argument("--seed", type=int, default=229)
    parser.add_argument(
        "--e2e-summary",
        default="results/e2e_cost_model/rebuttal_v4/e2e_summary.tsv",
        help="V4 cost-model TSV that provides dense/TSS/mask CIM-FFN cycles.",
    )
    parser.add_argument("--output-dir", default="results/hybrid_full_model_gpu")
    return parser.parse_args()


def torch_dtype(name: str):
    import torch

    return {
        "bfloat16": torch.bfloat16,
        "float16": torch.float16,
        "float32": torch.float32,
    }[name]


def percentile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    pos = (len(ordered) - 1) * q
    lower = int(pos)
    upper = min(lower + 1, len(ordered) - 1)
    frac = pos - lower
    return ordered[lower] * (1.0 - frac) + ordered[upper] * frac


def summarize(values: list[float]) -> dict[str, float]:
    return {
        "median_ms": statistics.median(values),
        "mean_ms": statistics.fmean(values),
        "min_ms": min(values),
        "max_ms": max(values),
        "p25_ms": percentile(values, 0.25),
        "p75_ms": percentile(values, 0.75),
        "iqr_ms": percentile(values, 0.75) - percentile(values, 0.25),
    }


def base_model_for(causal_lm):
    prefix = getattr(causal_lm, "base_model_prefix", None)
    if prefix and hasattr(causal_lm, prefix):
        return getattr(causal_lm, prefix)
    if hasattr(causal_lm, "model"):
        return causal_lm.model
    raise RuntimeError("Could not locate base decoder model.")


def patch_mlp_to_zero(model) -> list[str]:
    patched: list[str] = []

    def zero_forward(self, hidden_states, *args, **kwargs):
        return hidden_states.new_zeros(hidden_states.shape)

    for name, module in model.named_modules():
        if name.endswith(".mlp"):
            module.forward = types.MethodType(zero_forward, module)
            patched.append(name)
    if not patched:
        raise RuntimeError("No decoder MLP modules ending with '.mlp' were found.")
    return patched


def extract_hidden(output):
    if hasattr(output, "last_hidden_state"):
        return output.last_hidden_state
    return output[0]


def extract_past(output):
    if hasattr(output, "past_key_values"):
        return output.past_key_values
    return output[1] if len(output) > 1 else None


def sync(device: str) -> None:
    import torch

    if device.startswith("cuda"):
        torch.cuda.synchronize(device)


def measure_ms(
    fn: Callable[[], Any],
    *,
    device: str,
    warmup: int,
    repeat: int,
    prepare: Callable[[], None] | None = None,
) -> list[float]:
    import torch

    times: list[float] = []
    with torch.inference_mode():
        for _ in range(warmup):
            if prepare is not None:
                prepare()
            fn()
        sync(device)
        for _ in range(repeat):
            if prepare is not None:
                prepare()
            sync(device)
            start = torch.cuda.Event(enable_timing=True)
            end = torch.cuda.Event(enable_timing=True)
            start.record()
            fn()
            end.record()
            sync(device)
            times.append(float(start.elapsed_time(end)))
    return times


def nvidia_smi() -> dict[str, str]:
    try:
        out = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=name,driver_version",
                "--format=csv,noheader",
                "-i",
                "0",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return {}
    if not out:
        return {}
    parts = [item.strip() for item in out.split(",", 1)]
    return {"nvidia_smi_name": parts[0], "driver_version": parts[1] if len(parts) > 1 else "unknown"}


def read_e2e_rows(path: Path, model_name: str) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as fh:
        rows = list(csv.DictReader(fh, delimiter="\t"))
    return [row for row in rows if row.get("model") == model_name]


def as_float(row: dict[str, str], key: str) -> float | None:
    value = row.get(key)
    if value in (None, "", "NA"):
        return None
    return float(value)


def build_hybrid_rows(
    model_name: str,
    timing_rows: dict[str, dict[str, Any]],
    e2e_rows: list[dict[str, str]],
) -> list[dict[str, Any]]:
    rows_by_scenario: dict[str, list[dict[str, str]]] = {}
    for row in e2e_rows:
        rows_by_scenario.setdefault(row["scenario"], []).append(row)

    hybrid: list[dict[str, Any]] = []
    for scenario, timing in timing_rows.items():
        scenario_rows = rows_by_scenario.get(scenario, [])
        dense = next((row for row in scenario_rows if row["kind"] == "dense"), None)
        if dense is None:
            continue
        full_gpu_ms = timing["full_gpu"]["median_ms"]
        full_gpu_iqr_ms = timing["full_gpu"]["iqr_ms"]
        nonffn_gpu_ms = timing["gpu_nonffn"]["median_ms"]
        nonffn_gpu_iqr_ms = timing["gpu_nonffn"]["iqr_ms"]
        dense_gpu_ffn_ms = full_gpu_ms - nonffn_gpu_ms
        if dense_gpu_ffn_ms <= 0.0:
            raise RuntimeError(
                f"Derived non-positive GPU FFN bucket for {scenario}: "
                f"full={full_gpu_ms:.6f} ms nonffn={nonffn_gpu_ms:.6f} ms"
            )
        dense_cim_cycles = as_float(dense, "dense_ffn_cycles")
        if dense_cim_cycles is None or dense_cim_cycles <= 0.0:
            raise RuntimeError(f"Missing dense CIM FFN cycles for {model_name} {scenario}")
        for row in scenario_rows:
            method_cim_cycles = as_float(row, "method_ffn_cycles")
            method_ffn_ratio = (
                method_cim_cycles / dense_cim_cycles
                if method_cim_cycles is not None
                else None
            )
            method_gpu_scaled_ffn_ms = (
                dense_gpu_ffn_ms * method_ffn_ratio if method_ffn_ratio is not None else None
            )
            e2e_ms = (
                nonffn_gpu_ms + method_gpu_scaled_ffn_ms
                if method_gpu_scaled_ffn_ms is not None
                else None
            )
            e2e_norm = e2e_ms / full_gpu_ms if e2e_ms is not None else None
            hybrid.append(
                {
                    "model": model_name,
                    "scenario": scenario,
                    "method": row["method"],
                    "kind": row["kind"],
                    "gpu_full_ms": full_gpu_ms,
                    "gpu_full_iqr_ms": full_gpu_iqr_ms,
                    "gpu_attention_nonffn_ms": nonffn_gpu_ms,
                    "gpu_attention_nonffn_iqr_ms": nonffn_gpu_iqr_ms,
                    "gpu_dense_ffn_ms": dense_gpu_ffn_ms,
                    "gpu_dense_ffn_share": dense_gpu_ffn_ms / full_gpu_ms,
                    "dense_cim_ffn_cycles": dense_cim_cycles,
                    "method_cim_ffn_cycles": method_cim_cycles,
                    "method_ffn_ratio_from_cim": method_ffn_ratio,
                    "method_gpu_scaled_ffn_ms": method_gpu_scaled_ffn_ms,
                    "e2e_ms": e2e_ms,
                    "e2e_latency_norm": e2e_norm,
                    "e2e_gain_pct": 100.0 * (1.0 - e2e_norm) if e2e_norm is not None else None,
                    "token_ppl": row.get("token_ppl"),
                    "source_status": row.get("energy_source_status"),
                    "status": row.get("status"),
                }
            )
    return hybrid


def fmt(value: Any, digits: int = 4) -> str:
    if value is None:
        return "NA"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def write_markdown(path: Path, metadata: dict[str, Any], rows: list[dict[str, Any]]) -> None:
    lines = [
        "# Full-GPU Baseline With CIM FFN Ratio Table",
        "",
        "The dense baseline is measured as full GPU runtime. The GPU FFN bucket is",
        "derived as full GPU minus GPU non-FFN runtime, and each method scales that",
        "FFN bucket by its V4 TLM/CIM FFN cycle ratio.",
        "",
        "## Provenance",
        "",
        f"- Model: `{metadata['model_name']}` from `{metadata['model_path']}`",
        f"- Device: `{metadata['device_name']}` via `{metadata['device']}`",
        f"- PyTorch/CUDA: `{metadata['torch_version']}` / `{metadata['torch_cuda']}`",
        f"- Transformers: `{metadata['transformers_version']}`",
        f"- Driver: `{metadata.get('driver_version', 'unknown')}`",
        f"- dtype: `{metadata['dtype']}`; batch size: `{metadata['batch_size']}`",
        f"- Warmup/repeat: `{metadata['warmup']}` / `{metadata['repeat']}`",
        f"- Full-GPU timing: `{metadata['full_gpu_timing_policy']}`",
        f"- GPU non-FFN timing: `{metadata['gpu_nonffn_timing_policy']}`",
        f"- Decode timing: `{metadata['decode_timing_policy']}`",
        f"- FFN ratio source: `{metadata['ffn_ratio_source']}`",
        "",
        "## Table",
        "",
        "| Model | Scenario | Method | GPU full ms | GPU non-FFN ms | GPU FFN ms | CIM FFN ratio | E2E norm | E2E gain | Source status |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    row["model"],
                    row["scenario"],
                    row["method"],
                    fmt(row["gpu_full_ms"], 4),
                    fmt(row["gpu_attention_nonffn_ms"], 4),
                    fmt(row["gpu_dense_ffn_ms"], 4),
                    fmt(row["method_ffn_ratio_from_cim"], 6),
                    fmt(row["e2e_latency_norm"], 6),
                    fmt(row["e2e_gain_pct"], 4),
                    row.get("source_status") or "NA",
                ]
            )
            + " |"
        )
    lines.extend(
        [
            "",
            "Notes:",
            "",
            "- Dense GPU FFN is measured indirectly as full GPU minus GPU non-FFN.",
            "- E2E gain is normalized to the measured full-GPU dense baseline; no absolute CIM ns/cycle bridge is used for this table.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()

    import torch
    import transformers
    from transformers import AutoModelForCausalLM

    if not torch.cuda.is_available() or not args.device.startswith("cuda"):
        raise RuntimeError("CUDA is required for this profiling path.")

    torch.manual_seed(args.seed)
    torch.set_float32_matmul_precision("high")
    device = torch.device(args.device)
    model_path = Path(args.model_path).expanduser().resolve()
    model_name = args.model_name or model_path.name
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    model = AutoModelForCausalLM.from_pretrained(
        str(model_path),
        dtype=torch_dtype(args.dtype),
        local_files_only=True,
    )
    model.to(device)
    model.eval()
    base_model = base_model_for(model)
    vocab_size = int(model.config.vocab_size)

    prefill_ids = torch.randint(vocab_size, (args.batch_size, args.prefill_len), device=device)
    prefill_mask = torch.ones_like(prefill_ids)
    context_ids = torch.randint(vocab_size, (args.batch_size, args.decode_context_len), device=device)
    context_mask = torch.ones_like(context_ids)
    decode_ids = torch.randint(vocab_size, (args.batch_size, 1), device=device)
    decode_mask = torch.ones(
        (args.batch_size, args.decode_context_len + 1),
        dtype=context_mask.dtype,
        device=device,
    )

    def with_lm_head(hidden):
        return model.lm_head(hidden[:, -1:, :]) if hasattr(model, "lm_head") else hidden

    def prefill_once():
        out = base_model(input_ids=prefill_ids, attention_mask=prefill_mask, use_cache=False)
        return with_lm_head(extract_hidden(out))

    decode_state: dict[str, Any] = {}

    def prepare_decode() -> None:
        out = base_model(input_ids=context_ids, attention_mask=context_mask, use_cache=True)
        decode_state["past"] = extract_past(out)

    def decode_once():
        if "past" not in decode_state:
            prepare_decode()
            sync(args.device)
        out = base_model(
            input_ids=decode_ids,
            attention_mask=decode_mask,
            past_key_values=decode_state["past"],
            use_cache=True,
        )
        return with_lm_head(extract_hidden(out))

    torch.cuda.reset_peak_memory_stats(device)
    started = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    full_prefill_times = measure_ms(prefill_once, device=args.device, warmup=args.warmup, repeat=args.repeat)
    full_decode_times = measure_ms(
        decode_once,
        device=args.device,
        warmup=args.warmup,
        repeat=args.repeat,
        prepare=prepare_decode,
    )

    patched = patch_mlp_to_zero(model)
    decode_state.clear()
    sync(args.device)
    nonffn_prefill_times = measure_ms(
        prefill_once,
        device=args.device,
        warmup=args.warmup,
        repeat=args.repeat,
    )
    nonffn_decode_times = measure_ms(
        decode_once,
        device=args.device,
        warmup=args.warmup,
        repeat=args.repeat,
        prepare=prepare_decode,
    )
    ended = time.strftime("%Y-%m-%dT%H:%M:%S%z")

    timing_rows = {
        f"decode_s{args.decode_context_len}": {
            "scenario": f"decode_s{args.decode_context_len}",
            "mode": "decode",
            "seq_len": args.decode_context_len,
            "full_gpu": {
                "times_ms": full_decode_times,
                **summarize(full_decode_times),
            },
            "gpu_nonffn": {
                "times_ms": nonffn_decode_times,
                **summarize(nonffn_decode_times),
            },
        },
        f"prefill_s{args.prefill_len}": {
            "scenario": f"prefill_s{args.prefill_len}",
            "mode": "prefill",
            "seq_len": args.prefill_len,
            "full_gpu": {
                "times_ms": full_prefill_times,
                **summarize(full_prefill_times),
            },
            "gpu_nonffn": {
                "times_ms": nonffn_prefill_times,
                **summarize(nonffn_prefill_times),
            },
        },
    }
    hybrid_rows = build_hybrid_rows(
        model_name,
        timing_rows,
        read_e2e_rows(Path(args.e2e_summary), model_name),
    )

    smi = nvidia_smi()
    metadata = {
        "schema": "full_gpu_with_nonffn_and_cim_ratio_v2",
        "started": started,
        "ended": ended,
        "model_name": model_name,
        "model_path": str(model_path),
        "device": args.device,
        "device_name": torch.cuda.get_device_name(device),
        "torch_version": torch.__version__,
        "torch_cuda": torch.version.cuda,
        "transformers_version": transformers.__version__,
        "driver_version": smi.get("driver_version", "unknown"),
        "dtype": args.dtype,
        "batch_size": args.batch_size,
        "warmup": args.warmup,
        "repeat": args.repeat,
        "patched_mlp_count": len(patched),
        "patched_mlp_examples": patched[:5],
        "peak_memory_mib": torch.cuda.max_memory_allocated(device) / (1024 * 1024),
        "input_policy": "random token ids; timing-only shape/provenance run",
        "full_gpu_timing_policy": "decoder model with MLPs enabled plus last-token lm_head projection",
        "gpu_nonffn_timing_policy": "same path after replacing decoder MLP forwards with zero outputs",
        "decode_timing_policy": "KV cache prepared outside CUDA event; timed path is one-token decode",
        "ffn_ratio_source": "method_ffn_cycles / dense_ffn_cycles from V4 TLM/CIM e2e_summary.tsv",
        "e2e_summary": str(Path(args.e2e_summary).resolve()),
    }

    payload = {"metadata": metadata, "timing_rows": timing_rows, "hybrid_rows": hybrid_rows}
    json_path = output_dir / f"{model_name}_gpu_nonffn_profile.json"
    tsv_path = output_dir / f"{model_name}_hybrid_table.tsv"
    md_path = output_dir / f"{model_name}_hybrid_table.md"
    json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with tsv_path.open("w", encoding="utf-8", newline="") as fh:
        fields = [
            "model",
            "scenario",
            "method",
            "kind",
            "gpu_full_ms",
            "gpu_full_iqr_ms",
            "gpu_attention_nonffn_ms",
            "gpu_attention_nonffn_iqr_ms",
            "gpu_dense_ffn_ms",
            "gpu_dense_ffn_share",
            "dense_cim_ffn_cycles",
            "method_cim_ffn_cycles",
            "method_ffn_ratio_from_cim",
            "method_gpu_scaled_ffn_ms",
            "e2e_ms",
            "e2e_latency_norm",
            "e2e_gain_pct",
            "token_ppl",
            "source_status",
            "status",
        ]
        writer = csv.DictWriter(fh, fieldnames=fields, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(hybrid_rows)
    write_markdown(md_path, metadata, hybrid_rows)
    print(f"Wrote {json_path}")
    print(f"Wrote {tsv_path}")
    print(f"Wrote {md_path}")


if __name__ == "__main__":
    main()

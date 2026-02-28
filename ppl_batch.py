"""
Batch PPL evaluation across all MSD / MXFP configuration combinations.

Loads the model ONCE, then iterates through every setup by patching
config fields in-memory (no config.json editing needed).  Each run's
results are saved to a separate JSON file under the naming convention
    ppl_results_{tag}.json

Skips setups whose result file already exists (resume-safe).

Usage:
    cd /home/xzjnew/coding/onlinearith
    source /home/xzjnew/coding/.venv_310/bin/activate
    python ppl_batch.py                  # run all setups
    python ppl_batch.py --list           # list setups without running
    python ppl_batch.py --only 1 6 10    # run only setup #1, #6, #10
    python ppl_batch.py --skip-existing  # skip setups with existing result files (default)
    python ppl_batch.py --force          # re-run even if result file exists
"""

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
from datasets import load_dataset
from tqdm import tqdm
from transformers import AutoModelForCausalLM, AutoTokenizer

# ── Constants ─────────────────────────────────────────────────────────────────
MODEL_PATH  = "../Qwen3-0.6B"
DATASET     = ("wikitext", "wikitext-2-raw-v1", "test")
MAX_LENGTH  = 4096
STRIDE      = 512
RESULTS_DIR = Path(__file__).parent   # save next to this script

# ── Setup definitions ─────────────────────────────────────────────────────────
# Each setup is (id, tag, description, config_overrides_dict)
# config_overrides are applied ON TOP of a clean baseline (all mxfp/msd off).

_MSD_DEFAULTS = {
    "use_msd_truncation": True,
    "msd_cycle_budget": 16,
    "msd_online_delay": 2,
    "msd_budget_dynamic_scale": 1.0,
    "msd_budget_dynamic_threshold": 0.0,
    "msd_budget_dynamic_mode": "linear",
    "msd_deep_pipeline": False,
    "msd_pipeline_precision_loss": 2,
    "msd_calibration_data": None,
}

def _msd(budget=16, pipeline=False, **extra):
    d = dict(_MSD_DEFAULTS)
    d["msd_cycle_budget"] = budget
    d["msd_deep_pipeline"] = pipeline
    d.update(extra)
    return d


SETUPS = [
    # ── Tier 1: Baseline & MX-only ──
    (1,  "baseline",          "FP16 baseline (no quantization)",
     {"use_mxfp8": False, "use_mxfp6": False, "use_mxfp4": False}),

    (2,  "MXFP8",             "MXFP8 only",
     {"use_mxfp8": True}),

    (3,  "MXFP6_E2M3",       "MXFP6 E2M3 only",
     {"use_mxfp6": True, "mxfp6_format": "e2m3"}),

    (4,  "MXFP6_E3M2",       "MXFP6 E3M2 only",
     {"use_mxfp6": True, "mxfp6_format": "e3m2"}),

    (5,  "MXFP4",             "MXFP4 only",
     {"use_mxfp4": True}),

    # ── Tier 2: MSD default budget (B=16) across formats ──
    (6,  "MXFP8_MSD_B16",    "MXFP8 + MSD B=16",
     {"use_mxfp8": True, **_msd(16)}),

    (7,  "MXFP6_E2M3_MSD_B16", "MXFP6 E2M3 + MSD B=16",
     {"use_mxfp6": True, "mxfp6_format": "e2m3", **_msd(16)}),

    (8,  "MXFP6_E3M2_MSD_B16", "MXFP6 E3M2 + MSD B=16",
     {"use_mxfp6": True, "mxfp6_format": "e3m2", **_msd(16)}),

    (9,  "MXFP4_MSD_B16",    "MXFP4 + MSD B=16",
     {"use_mxfp4": True, **_msd(16)}),

    # ── Tier 3: Budget sweep (MXFP8) ──
    (10, "MXFP8_MSD_B8",     "MXFP8 + MSD B=8",
     {"use_mxfp8": True, **_msd(8)}),

    (11, "MXFP8_MSD_B12",    "MXFP8 + MSD B=12",
     {"use_mxfp8": True, **_msd(12)}),

    # (B=16 already covered by setup #6)

    (12, "MXFP8_MSD_B20",    "MXFP8 + MSD B=20",
     {"use_mxfp8": True, **_msd(20)}),

    (13, "MXFP8_MSD_B24",    "MXFP8 + MSD B=24",
     {"use_mxfp8": True, **_msd(24)}),

    (14, "MXFP8_MSD_B32",    "MXFP8 + MSD B=32",
     {"use_mxfp8": True, **_msd(32)}),

    # ── Tier 3b: Budget sweep (MXFP4) ──
    (15, "MXFP4_MSD_B8",     "MXFP4 + MSD B=8",
     {"use_mxfp4": True, **_msd(8)}),

    (16, "MXFP4_MSD_B12",    "MXFP4 + MSD B=12",
     {"use_mxfp4": True, **_msd(12)}),

    # (B=16 already covered by setup #9)

    (17, "MXFP4_MSD_B20",    "MXFP4 + MSD B=20",
     {"use_mxfp4": True, **_msd(20)}),

    (18, "MXFP4_MSD_B24",    "MXFP4 + MSD B=24",
     {"use_mxfp4": True, **_msd(24)}),

    (19, "MXFP4_MSD_B32",    "MXFP4 + MSD B=32",
     {"use_mxfp4": True, **_msd(32)}),

    # ── Tier 4: Deep pipeline ──
    (20, "MXFP8_MSD_B16_pipeline", "MXFP8 + MSD B=16 + pipeline",
     {"use_mxfp8": True, **_msd(16, pipeline=True)}),

    (21, "MXFP4_MSD_B16_pipeline", "MXFP4 + MSD B=16 + pipeline",
     {"use_mxfp4": True, **_msd(16, pipeline=True)}),
]


# ── Baseline config (everything off) ─────────────────────────────────────────
_BASELINE_OVERRIDES = {
    "use_mxfp8": False, "use_mxfp6": False, "use_mxfp4": False,
    "use_msd_truncation": False, "msd_deep_pipeline": False,
    "msd_calibration_data": None,
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def get_device_and_dtype():
    if torch.backends.mps.is_available():
        return "mps", torch.float16
    if torch.cuda.is_available():
        return "cuda", torch.float16
    return "cpu", torch.float32


def peak_memory_str(device):
    if device == "cuda":
        return f"{torch.cuda.max_memory_allocated() / 1024**3:.2f} GB"
    return "N/A"


def reset_peak_memory(device):
    if device == "cuda":
        torch.cuda.reset_peak_memory_stats()


def apply_config(config, overrides):
    """Apply a dict of overrides to a model config (in-place)."""
    for k, v in overrides.items():
        setattr(config, k, v)


def evaluate_ppl(model, encodings, device, seq_len, num_words, num_chars, num_bytes):
    """Run sliding-window PPL and return a results dict."""
    reset_peak_memory(device)

    total_nll_sum = 0.0
    total_tokens  = 0
    per_chunk_nlls = []
    prev_end_loc = 0
    t_start = time.perf_counter()

    for begin_loc in tqdm(range(0, seq_len, STRIDE), desc="  PPL windows", leave=False):
        end_loc = min(begin_loc + MAX_LENGTH, seq_len)
        trg_len = end_loc - prev_end_loc

        input_ids  = encodings.input_ids[:, begin_loc:end_loc].to(device)
        target_ids = input_ids.clone()
        target_ids[:, :-trg_len] = -100

        with torch.no_grad():
            outputs = model(input_ids, labels=target_ids)
            avg_nll = outputs.loss.item()

        total_nll_sum += avg_nll * trg_len
        total_tokens  += trg_len
        per_chunk_nlls.append(avg_nll)

        prev_end_loc = end_loc
        if end_loc == seq_len:
            break

    elapsed  = time.perf_counter() - t_start
    mean_nll = total_nll_sum / total_tokens

    token_ppl  = math.exp(mean_nll)
    word_ppl   = math.exp(mean_nll * total_tokens / num_words)
    bpb        = (mean_nll * total_tokens / num_bytes) / math.log(2)
    bpc        = (mean_nll * total_tokens / num_chars) / math.log(2)
    throughput = total_tokens / elapsed
    chunk_arr  = np.array(per_chunk_nlls)

    return {
        "metrics": {
            "token_perplexity": round(token_ppl, 4),
            "word_perplexity":  round(word_ppl, 4),
            "bits_per_byte":    round(bpb, 4),
            "bits_per_char":    round(bpc, 4),
            "mean_nll_nats":    round(mean_nll, 4),
        },
        "reliability": {
            "num_chunks":     len(per_chunk_nlls),
            "chunk_nll_mean": round(float(chunk_arr.mean()), 4),
            "chunk_nll_std":  round(float(chunk_arr.std()), 4),
            "scored_tokens":  total_tokens,
        },
        "performance": {
            "throughput_tokens_per_sec": round(throughput, 1),
            "wall_time_sec":             round(elapsed, 2),
            "peak_memory":               peak_memory_str(device),
        },
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Batch PPL evaluation for all MXFP/MSD setups")
    parser.add_argument("--list", action="store_true", help="List all setups and exit")
    parser.add_argument("--only", nargs="+", type=int, metavar="ID",
                        help="Run only these setup IDs (e.g. --only 1 6 10)")
    parser.add_argument("--force", action="store_true",
                        help="Re-run even if result file already exists")
    args = parser.parse_args()

    # ── List mode ──
    if args.list:
        print(f"{'ID':>3}  {'Tag':<30}  Description")
        print("─" * 75)
        for sid, tag, desc, _ in SETUPS:
            result_file = RESULTS_DIR / f"ppl_results_{tag}.json"
            exists = "  ✓ (done)" if result_file.exists() else ""
            print(f"{sid:3d}  {tag:<30}  {desc}{exists}")
        return

    # ── Filter setups ──
    if args.only:
        selected = {s for s in args.only}
        run_setups = [(s, t, d, c) for s, t, d, c in SETUPS if s in selected]
        if not run_setups:
            print(f"No matching setup IDs: {args.only}")
            print(f"Valid IDs: {[s[0] for s in SETUPS]}")
            return
    else:
        run_setups = list(SETUPS)

    # ── Device & model ──
    device, dtype = get_device_and_dtype()
    print(f"Device: {device}  |  dtype: {dtype}")
    print(f"Total setups to evaluate: {len(run_setups)}")
    print()

    print("Loading tokenizer & model …")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, local_files_only=True)
    model_kwargs = {"local_files_only": True, "torch_dtype": dtype}
    if device == "cuda":
        model_kwargs["device_map"] = "cuda"

    model = AutoModelForCausalLM.from_pretrained(MODEL_PATH, **model_kwargs)
    model.to(device)
    model.eval()

    num_params = sum(p.numel() for p in model.parameters())
    print(f"Model: {MODEL_PATH}  |  Params: {num_params/1e6:.1f}M")

    # ── Dataset ──
    ds_name, ds_config, ds_split = DATASET
    print(f"Loading dataset: {ds_name}/{ds_config} ({ds_split}) …")
    test_data = load_dataset(ds_name, ds_config, split=ds_split)
    raw_text  = "\n\n".join(test_data["text"])
    encodings = tokenizer(raw_text, return_tensors="pt")
    seq_len   = encodings.input_ids.size(1)
    num_words = len(raw_text.split())
    num_chars = len(raw_text)
    num_bytes = len(raw_text.encode("utf-8"))
    print(f"Tokens: {seq_len:,}  |  Words: {num_words:,}")
    print()

    # ── Run setups ──
    summary = []
    total_start = time.perf_counter()

    for i, (sid, tag, desc, overrides) in enumerate(run_setups):
        result_file = RESULTS_DIR / f"ppl_results_{tag}.json"
        print(f"{'═'*60}")
        print(f"  [{i+1}/{len(run_setups)}]  Setup #{sid}: {desc}")
        print(f"  Tag: {tag}  →  {result_file.name}")
        print(f"{'═'*60}")

        # Skip if exists
        if result_file.exists() and not args.force:
            with open(result_file) as f:
                existing = json.load(f)
            ppl = existing.get("metrics", {}).get("token_perplexity", "?")
            print(f"  ⏭  Already exists (PPL={ppl}). Use --force to re-run.\n")
            summary.append((sid, tag, ppl, "skipped"))
            continue

        # Reset to baseline, then apply this setup's overrides
        apply_config(model.config, _BASELINE_OVERRIDES)
        apply_config(model.config, overrides)

        # Invalidate cached MSD context so it gets re-created
        if hasattr(model, "_msd_context"):
            model._msd_context = None
            model._msd_context_config_hash = None

        # Show active config
        active_flags = []
        for k in ["use_mxfp8", "use_mxfp6", "use_mxfp4", "use_msd_truncation",
                   "msd_cycle_budget", "msd_deep_pipeline"]:
            v = getattr(model.config, k, None)
            if v is not None and v is not False:
                active_flags.append(f"{k}={v}")
        print(f"  Config: {', '.join(active_flags) or '(baseline fp16)'}")

        # Evaluate
        results = evaluate_ppl(model, encodings, device, seq_len,
                               num_words, num_chars, num_bytes)

        # Add metadata
        results["setup"] = {"id": sid, "tag": tag, "description": desc,
                            "config_overrides": {k: v for k, v in overrides.items()
                                                 if not callable(v)}}
        results["model"] = MODEL_PATH
        results["dataset"] = f"{ds_name}/{ds_config}/{ds_split}"
        results["config"] = {"max_length": MAX_LENGTH, "stride": STRIDE,
                             "dtype": str(dtype)}

        # Save
        with open(result_file, "w") as f:
            json.dump(results, f, indent=2)

        ppl = results["metrics"]["token_perplexity"]
        wall = results["performance"]["wall_time_sec"]
        print(f"  ✓  PPL={ppl:.4f}  |  {wall:.0f}s  |  saved → {result_file.name}\n")
        summary.append((sid, tag, ppl, f"{wall:.0f}s"))

    total_elapsed = time.perf_counter() - total_start

    # ── Summary ──
    print()
    print(f"{'═'*60}")
    print(f"  BATCH COMPLETE  ({total_elapsed/60:.1f} min total)")
    print(f"{'═'*60}")
    print(f"{'ID':>3}  {'Tag':<30}  {'PPL':>10}  {'Time':>8}")
    print("─" * 60)
    for sid, tag, ppl, t in summary:
        ppl_str = f"{ppl:.4f}" if isinstance(ppl, float) else str(ppl)
        print(f"{sid:3d}  {tag:<30}  {ppl_str:>10}  {t:>8}")
    print("─" * 60)
    print(f"Results saved in: {RESULTS_DIR}")


if __name__ == "__main__":
    main()

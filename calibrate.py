import sys
sys.path.insert(0, "/home/xzjnew/coding/transformers/src")

import json
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from transformers.models.qwen3.calibration_msd import calibrate_channel_budgets

# 1. Load model with MXFP format enabled (MSD off for calibration)
model_path = "/home/xzjnew/coding/Qwen3-0.6B"
tokenizer = AutoTokenizer.from_pretrained(model_path, local_files_only=True)
model = AutoModelForCausalLM.from_pretrained(
    model_path, local_files_only=True, torch_dtype=torch.float16
)
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)
model.eval()

# 2. Prepare calibration texts (use a small diverse sample)
from datasets import load_dataset
ds = load_dataset("wikitext", "wikitext-2-raw-v1", split="validation")
# Take ~20 non-empty paragraphs as calibration data
cal_texts = [t for t in ds["text"] if len(t.strip()) > 100][:20]
print(f"Calibration texts: {len(cal_texts)} paragraphs")

# 3. Run calibration
calibration_data = calibrate_channel_budgets(
    model, tokenizer, cal_texts,
    target_snr_db=30.0,    # Target SNR; try 20, 30, 40
    max_length=512,
    batch_size=4,
    online_delay=2,
)

# 4. Save calibrated config back to config.json
config_path = f"{model_path}/config.json"
with open(config_path, "r") as f:
    cfg = json.load(f)

cfg["msd_calibration_data"] = calibration_data
cfg["use_msd_truncation"] = True

with open(config_path, "w") as f:
    json.dump(cfg, f, indent=2)

print(f"Calibration saved to {config_path}")
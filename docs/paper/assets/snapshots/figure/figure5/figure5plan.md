# Figure5 plan

## Overall plan

**Figure 5 — Layer-wise latency under block-serial execution**

**Where it goes:** immediately after Figure 4.
**What it shows:** layer-wise latency or accumulated block-service time for dense MX, uniform horizon, and L2-based redistribution.
**What it must prove:** the realized schedule creates a credible layer-level latency benefit before full end-to-end accounting.
**Caption spine:** “Because channels run in parallel but blocks execute serially, whole-block skip and partial window execution shorten realized stage-1 service time and accumulates into a layer-level latency benefit.”

## Data extract

From fixed_sum calibration:
"~/coding/data/calib_data"
Currently scanned from 12db to 25db
Each layer's latency and latency std should be extracted from avg_layer_cycle and layer_cycle_std in file with name "ppl_results_MXFP8_fix_time.json"
Each layer's max budget and average budget should be extracted from budget_max and budget_mean in "calibratoin_MXFP8_fixed_sum.json"
Each entry's e_p_eff should be extracted from mean_effective_precision in file "ppl_results_MXFP8_fix_time.json"

From uniform budget:
"~/coding/data/uniform_budget"
Currently scanned from 6B to 11B
Each layer's latency and latency std should be extracted from avg_layer_cycle and layer_cycle_std in file with name "ppl_xB_time.json"
Each layer's max budget and average budget are just the uniform budget x
Each entry's e_p_eff should be extracted from mean_effective_precision in file "ppl_xB_time.json"

## Data process

The up_proj and gate_proj has 32 blocks per channel, so the max dense execution time of these two is 32* max budget, and the average dense execution time is 32* average budget.
The down_proj has 96 blocks per channel, calculations are the same.
X axis for each entry is normalized digit reads, which is e_p_eff/3
Y axis is dense execution time and actual execution time.
The layer wise time should be aggregated, with gate_proj and up_proj parallel, add only all up_proj and down_proj time.

## Code requirment

Do it in three steps, first extract data as a csv file, then prepare plot data as a csv file, finally plot with the latter csv file. The plotting configs and lables should be editable in the the top of the final plot script. Plot each entry in a bar, with different time overlap and show the difference with unoverlap part.
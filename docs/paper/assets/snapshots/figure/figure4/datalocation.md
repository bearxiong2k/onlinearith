# Data location and name mapping for figure4

All data here are ppltest result or ppl_batch result

From target_snr calibration and fixed_sum calibration:
"~/coding/data/calib_data"
Currently scanned from 12db to 25db
full_ppl and uncap_e_p_eff should be extracted from token perplexity and mean_effective_precision in file with name "ppl_results_MXFP8_calibration_snr.json" or "ppl_results_MXFP8_calibration_fix.json"
zero_element_percentage and zero_block_percentage in "ppl_results_MXFP8_calibration_snr.json" or "ppl_results_MXFP8_calibration_fix.json" also need to be extracted
100_ppl and cap_e_eff should be extracted from token perplexity and mean_effective_precision in file "ppl_results_MXFP8_fix_cap.json", only fixed_sum has this file, these data for target_snr should be left blank.
B_mean should be extracted from budget_mean in "calibration_MXFP8.json" for target_snr and "calibration_MXFP8_fixed_sum.json" for fixed_sum.

From uniform budget:
"~/coding/data/uniform_budget"
Currently scanned from 6B to 11B
B_ppl and uncap_e_p_eff should be extracted from token perplexity and mean_effective_precision in file with name "ppl_xB.json"
zero_element_percentage and zero_block_percentage in "ppl_xB.json" also need to be extracted
100_ppl and cap_e_eff should be extracted from token perplexity and mean_effective_precision in file "ppl_xB_cap.json"


From wanda baseline:
"~/coding/data/wanda_base/n-m"
only token perplexity is needed.

From activation mask baseline:
"~/coding/data/act_base/n-m/ppl_results_MXFP8.json"
only token perplexity is needed.


create_clock -name clk -period 4.000 [get_ports clk_i]
set_clock_uncertainty 0.150 [get_clocks clk]
set_clock_transition 0.100 [get_clocks clk]

set non_clock_inputs [remove_from_collection [all_inputs] [get_ports clk_i]]
set_input_delay 0.500 -clock clk $non_clock_inputs
set_output_delay 0.500 -clock clk [all_outputs]

set_driving_cell -lib_cell BUFV4_140P7T35R $non_clock_inputs
set_load 0.020 [all_outputs]


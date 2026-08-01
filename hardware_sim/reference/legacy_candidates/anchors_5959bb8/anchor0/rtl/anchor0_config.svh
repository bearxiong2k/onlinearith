`ifndef ANCHOR0_CONFIG_SVH
`define ANCHOR0_CONFIG_SVH

// Default synthesis-time configuration for Anchor 0.
// Yosys scripts can override these with read_verilog -D...

`ifndef A0_B_BLOCKS
`define A0_B_BLOCKS 128
`endif

`ifndef A0_BETA_W
`define A0_BETA_W 8
`endif

// E_raw = beta_x + beta_w. For two signed 8-bit exponent-like metadata fields,
// a signed 9-bit raw sum is sufficient.
`ifndef A0_ERAW_W
`define A0_ERAW_W 9
`endif

// D = E_max - E_raw is non-negative. With signed E_raw width W, an unsigned D
// width of W is enough to represent the full dynamic range.
`ifndef A0_D_W
`define A0_D_W `A0_ERAW_W
`endif

`endif  // ANCHOR0_CONFIG_SVH

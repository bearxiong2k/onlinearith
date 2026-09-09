# Stage-1 Tile Architecture and Critical-Path Contract

## 1. Purpose and classification

This document is the implementation contract for the SMIC 28 nm Stage-1 tile.
It freezes the RTL, memory, streaming, timing, and physical hierarchy used for
synthesis and block-level layout.

The design is a conventional-multiplier presentation prototype. It replaces
the paper's serial/parallel online multiplier leaves with conventional signed
multipliers. Area, power, latency, and frequency from this implementation are
not measurements of the original online-arithmetic datapath.

## 2. Frozen compute architecture

The tile contains:

- eight owner-lane pairs;
- independent Gate and Up paths in each pair;
- 32 signed 8 x 8 multiplier leaves per path;
- one five-level reduction tree and one 28-bit accumulator per path;
- one streamed 32-element activation block stored in DFFs;
- local compiled SRAM for all weights;
- local compiled SRAM for beta_w and generated delay D;
- a 128 x 8-bit beta_x metadata table stored in DFFs;
- a programmable 16 x 4-bit lambda LUT and 16 Horizon registers;
- one scale prepass shared by all lane pairs.

The tile excludes SiLU, Gate-Up elementwise multiplication, down projection,
NoC, packetization, pad ring, production DFT, MBIST/BISR, power gating, and
system-level retention.

## 3. Logical hierarchy

~~~text
stage1_tile
  control_and_config
  activation_dff_store
    current_value[255:0]
    current_fine[127:0]
    beta_x_table[0:127][7:0]
  beta_w_store
    4 x HS128X32
  delay_store
    4 x HS128X32
  lane_pair[0..7]
    gate_path
      8 x HS128X32 weight SRAM
      32 signed 8 x 8 multipliers
      five-level reduction tree
      signed 28-bit accumulator
    up_path
      8 x HS128X32 weight SRAM
      32 signed 8 x 8 multipliers
      five-level reduction tree
      signed 28-bit accumulator
~~~

Resource count:

| Resource | Count |
| --- | ---: |
| Owner-lane pairs | 8 |
| Path engines | 16 |
| Signed 8 x 8 multipliers | 512 |
| Five-level reduction trees | 16 |
| Signed 28-bit accumulators | 16 |
| Weight HS128X32 macros | 128 |
| beta_w HS128X32 macros | 4 |
| Delay D HS128X32 macros | 4 |
| Activation SRAM macros | 0 |
| Total HS128X32 macros | 136 |
| Current activation value/fine DFF bits | 384 |
| beta_x table DFF bits | 1024 |
| Total activation-side storage DFF bits | 1408 |

Weight capacity remains 128 blocks x 32 elements per path. Activation values
and fine codes are not resident for all 128 blocks; only the current block is
held in the tile. The beta_x metadata table remains resident so the tile can
perform its local Emax and delay prepass without replaying the full activation
payload.

## 4. Numeric contract

| Quantity | Width | Interpretation |
| --- | ---: | --- |
| Activation operand | 8 | signed two's complement after MXFP8 recode |
| Weight operand | 8 | signed two's complement |
| Product | 16 | full signed product |
| Tree level 1 | 17 | two products |
| Tree level 2 | 18 | four products |
| Tree level 3 | 19 | eight products |
| Tree level 4 | 20 | sixteen products |
| Tree level 5 | 21 | thirty-two products |
| Channel accumulator | 28 | accumulation over 128 blocks |
| beta_x, beta_w | 8 each | unsigned exponent codes |
| E and Emax | 10 | unsigned sum and maximum |
| D | 8 | saturated unsigned Emax minus E |
| fine code | 4 | lambda LUT index |
| Horizon | 8 | unsigned suppression threshold |

Metadata equations:

~~~text
E[path, block] = zero_extend(beta_x[block])
               + zero_extend(beta_w[path, block])

Emax[path] = max over blocks 0 through 127 of E[path, block]

D[path, block] = saturate_unsigned_8(Emax[path] - E[path, block])

tau[path, element] = zero_extend(D[path, block])
                   + zero_extend(lambda_lut[fine_code[element]])

leaf_enable = active_lane && (tau < Horizon[path])
~~~

No value-path intermediate saturation or rounding is used. Disabled leaves
contribute signed zero.

## 5. Memory contract

The only compiled macro is the ARM SMIC28 high-speed single-port SRAM:

~~~text
family        HSSPSRAM / SM18CA001
macro         HS128X32
organization  128 words x 32 bits
mux           4
mode          BASE
port          synchronous single port
pipeline      none
retention     enabled
size          44.475 um x 127.04 um
~~~

Power aliases:

~~~text
VDDCE -> VDD
VDDPE -> VDD
VSSE  -> VSS
VNW   -> VDD
VPW   -> VSS
~~~

Each path uses eight macros at a common address to read 256 weight bits, or 32
signed 8-bit weights. beta_w and delay are path-major packed: four macros read
one 8-bit field for each of the 16 paths at a common block address.

No activation value, activation fine code, or beta_x state may infer or
instantiate HS128X32. These arrays are implemented by standard-cell DFFs.

## 6. Activation DFF stream

The compute-time activation interface is:

~~~text
act_valid_i
act_ready_o
act_block_idx_i[6:0]
act_value_i[255:0]
act_fine_i[127:0]
~~~

A transfer occurs on a rising edge when valid and ready are both high. The
presented block index must equal the block requested by the tile. On transfer,
384 payload bits are captured in the current activation DFF bank. They remain
stable until the corresponding block retires.

All 16 paths consume the same logical activation block. Parallel readout is
therefore implemented as DFF output broadcast, not as a multi-port memory.
Physical implementation may branch the broadcast by lane-pair cluster when required
for timing or routability. Buffering is area-first: do not reserve a deep or
overprovisioned tree, and do not buffer only to satisfy an abstract fanout target
when post-route transition and capacitance are clean. Insert only the stages
needed to close setup, hold, transition, capacitance, or routing access.

beta_x is configured before start through target 0 of the 32-bit configuration
port. The table contains 128 entries x 8 bits and is synchronously read during
EMAX_SCAN and DELAY_FILL.

## 7. Configuration protocol

The static configuration interface is:

~~~text
cfg_valid_i, cfg_ready_o
cfg_target_i[2:0]
cfg_bank_i
cfg_path_i[3:0]
cfg_addr_i[6:0]
cfg_word_i[3:0]
cfg_wdata_i[31:0]
cfg_error_o
~~~

| Target | Object | Word sequence | Selector |
| ---: | --- | --- | --- |
| 0 | one beta_x entry | word 0 | address |
| 1 | one path weight block | words 0..7 | path, address |
| 2 | all-path beta_w block | words 0..3 | address |
| 3 | one Horizon register | word 0 | path |
| 4 | one lambda LUT entry | word 0 | path field as LUT index |

Multiword weight and beta_w writes must be contiguous and keep selectors
stable. Static configuration is accepted only while the tile is idle.
Activation values and fine codes use the independent compute-time stream.

## 8. Scheduling

One command computes all 128 blocks for every active lane pair. Gate and Up
run concurrently. All lane pairs remain in tile lockstep.

The command phases are:

1. EMAX_SCAN synchronously reads beta_x DFF metadata and beta_w SRAM for block
   addresses 0 through 127 and retains one 10-bit Emax per path.
2. DELAY_FILL rereads beta_x and beta_w, computes all 16 D values, and writes
   four delay SRAMs for every block.
3. COMPUTE requests activation blocks 0 through 127 in order. Each accepted
   activation block is captured in DFFs while the matching weight and delay
   SRAM reads are issued. The tile waits if the activation source is stalled.

A new command is not accepted while busy is high. done pulses for one cycle
after block 127 retires.

## 9. Datapath pipeline

The initial clock target is 4.0 ns, or 250 MHz.

~~~text
C0 ACT_ACCEPT  Capture activation DFFs; issue weight and delay SRAM reads.
C1 SRAM_Q      SRAM clock-to-Q and activation DFF broadcast.
C2 PRODUCT     Register 32 signed products per path.
C3 TREE_L2     Register reduction tree levels 1 and 2.
C4 TREE_L4     Register reduction tree levels 3 and 4.
C5 BLOCK_SUM   Register the signed 21-bit sum.
C6 ACCUMULATE  Sign-extend and update the signed 28-bit accumulator.
~~~

The implementation is single-inflight at block granularity. The activation
source may introduce arbitrary gaps before C0. Once accepted, one block
completes through the fixed local pipeline before the next activation request.

## 10. Candidate critical paths

| ID | Startpoint to endpoint | Primary risk |
| --- | --- | --- |
| CP1 | Weight SRAM CLK to product register | SRAM clock-to-Q, route, signed multiplier |
| CP2 | Product register to TREE_L2 | two adder levels |
| CP3 | TREE_L2 to TREE_L4 | two adder levels and local route |
| CP4 | TREE_L4 to block-sum register | final reduction addition |
| CP5 | Block-sum register to accumulator | 28-bit feedback addition |
| CP6 | Activation DFF or delay SRAM to product enable | LUT, compare, leaf-mask fanout |
| CP7 | Tile control to 136 SRAM controls | address and enable fanout |
| CP8 | Activation DFF Q to 16 paths | 384-bit shared broadcast across clusters |
| CP9 | beta_x DFF table read mux to E register | 128-entry DFF-table read selection |

CP8 is handled with a central or edge-aligned broadcast spine and local
lane-pair branches. CP9 must be checked after synthesis because the beta_x
table is deliberately implemented as DFFs rather than SRAM.

## 11. Top-level compute interface

~~~text
clk_i, rst_ni
start_i
active_lane_mask_i[7:0]
busy_o, done_o, delay_saturation_o
gate_acc_o[223:0]
up_acc_o[223:0]

act_valid_i, act_ready_o
act_block_idx_i[6:0]
act_value_i[255:0]
act_fine_i[127:0]
~~~

Reset clears control, protocol state, valid state, and accumulators. It does
not clear SRAM or the beta_x DFF table. Software or the upstream controller
must load weights, beta_w, beta_x, Horizon, and lambda before start.

## 12. Physical hierarchy and floorplan

Physical implementation is module-oriented and does not require a square tile.

The primary reusable hardening unit is lane_pair. Each lane-pair block is a
rectangle containing adjacent Gate and Up path slices. Each path slice keeps
its eight weight macros close to its 32 multipliers and reduction tree.

Eight lane-pair rectangles may be assembled as 4 x 2, 8 x 1, 2 x 4, or another
aspect ratio selected for parent-level abutment, SRAM pin direction, PG access,
and routing congestion. Equal tile width and height is not a design goal.

The activation DFF bank and first-level broadcast buffers form a central or
edge-aligned spine. The spine branches locally into each lane-pair block.
beta_w, delay, control, and configuration logic form narrow support modules
near the spine. Macro halos and signal channels are sized per module before
top-level assembly.

The top-level PnR flow must preserve hierarchy or placement groups for:

- activation and control spine;
- lane_pair[0] through lane_pair[7];
- Gate and Up path slices within each lane pair;
- beta_w and delay stores.

## 13. Area interpretation

HS128X32 macro area is 5650.104 square micrometers. The 136 retained macros
therefore occupy 0.768414 square millimeters before halos.

The previous 162-macro implementation used 0.915317 square millimeters of SRAM.
Removing 26 activation macros saves 0.146903 square millimeters of raw macro
area. The 1408 activation-side DFF bits, read mux, clock/data controls, and
broadcast buffers must be measured after synthesis and PnR.

Die area, core area, and summed cell area are different metrics:

- die area is the complete block boundary;
- core area is the placement and routing region inside the die;
- summed cell area is the library area of functional macros and standard cells.

The new die outline must be regenerated from modular floorplanning. It is not
obtained by subtracting macro area from the old square die.

## 14. Verification and completion gates

Tile-level completion requires:

1. ARM HS128X32 wrapper read/write simulation passes.
2. Weight eight-bank mapping passes for all 32 byte lanes and 128 addresses.
3. Path arithmetic matches the independent reference model.
4. Gate and Up paths execute concurrently with independent accumulators.
5. beta_x DFF prepass, delay fill, activation backpressure, ordered block
   streaming, 128-block accumulation, and lane masking pass.
6. DC reports 136 HS128X32 macros and no activation SRAM inference.
7. Formal equivalence between RTL and mapped netlist passes.
8. Mapped GLS passes multiple datasets or seeds.
9. Modular Innovus PnR closes placement, PG, CTS, route, and BCWC timing.
10. PrimeTime setup and hold pass for the declared max/min corner scope.
11. Routed SDF GLS passes with successful SDF annotation.
12. Calibre block-level DRC, LVS, and antenna reports are clean.
13. Activity-based post-route power reports separate SRAM, compute, clock,
    activation DFF/broadcast, hold buffers, and leakage.

Additional OCV closure, production DFT/MBIST, pad ring, seal ring, and
full-chip verification remain separate milestones.

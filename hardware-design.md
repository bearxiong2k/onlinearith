The hardware design has two main parts, the micro Tile for a slice of FFN and the early termination controller.

The micro Tile detail draft:
# 1. Concrete micro-tile architecture

---

## 1.1 Tile definition

I would define the micro-tile as:

> A **\(P \times H\)** FFN tile:
> - \(P\) **owner lanes** for intermediate channels \(i\)
> - \(H\) **consumer outputs** for local `down_proj` outputs \(h\)

A good illustrative point is something like:

- \(P = 8\) or \(16\)
- \(H = 16\) or \(32\)
- MX block size \(B = 32\)

You do **not** need to claim these are final.  
Just say they are **representative tiling parameters**.

---

## 1.2 What the micro-tile contains

I would break it into 5 blocks.

### Block 1 — FFN entry / input preparation
This is where you pay the online-arithmetic interface cost once.

Contains:
- MX block exponent extractor
- mantissa recoder / BSD recoder
- digit broadcaster
- activation block metadata register

**Important message on the figure:**
> Conversion happens only at FFN entry and FFN exit, not between internal FFN stages.

That directly supports one of your core advantages.

---

### Block 2 — Stage-1 producer lanes
For each intermediate channel \(i \in [0, P-1]\), the lane contains:

- local `gate_proj` weight bank
- local `up_proj` weight bank
- two producer MAC paths:
  - `Gate MAC`
  - `Up MAC`
- `t_first` / first-valid-cycle generator for each path
- shared stage-1 ET controller

This is where the **shared owner domain** should be visually emphasized.

---

### Block 3 — Nonlinearity + align + gating multiply
Per owner lane:

- `PWL SiLU` on the gate path
- `time-domain align buffer` between `SiLU(g)` and `u`
- gating multiply `SiLU(g) × u`
- output stream register with carried timing tag

This block is where your **deep pipeline** becomes visible and distinct from prior “standalone dot-product” online arithmetic.

---

### Block 4 — Stage-2 consumer bank
This should be a local `down_proj` consumer array for \(H\) output channels.

Contains:
- local `down_proj` weight bank
- digit-serial consumer multipliers
- output accumulators for \(y_h\)
- optional stage-2 ET controller
- local output register / FFN exit encoder

This block must be visually different from stage-1:
- stage-1 **produces** streams
- stage-2 **consumes** a timed stream

That supports your “consumer mode” claim.

---

### Block 5 — Local control / metadata SRAM
A small top or side band showing:

- `B1_base[i]` SRAM for stage-1 base budgets
- `B2_base[h]` SRAM for stage-2 base budgets
- weight exponent SRAM
- combined-scale LUT
- `t_first` metadata registers
- coefficient ROM for SiLU

This makes the design feel real rather than purely algorithmic.

---

# 2. A concrete block diagram you can draw

Below is the structure I would actually use.

---

## Figure A: FFN micro-tile overview

```text
┌──────────────────────────── FFN MSD-First Online-Arithmetic Micro-Tile ────────────────────────────┐
│ Tile dimensions: P owner lanes (intermediate channels i) × H consumer outputs (down_proj h)       │
│                                                                                                     │
│  FFN Entry / Prepare                                                                                │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ MX decode / exponent extract / BSD recoder / digit broadcaster                                 │  │
│  │ Inputs: x_mantissa_blk, e_x_blk                                                                 │  │
│  │ Outputs: digit stream d_x[t], activation exponent class cls(e_x_blk)                           │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                      │                                                              │
│                                      ▼                                                              │
│                                                                                                     │
│  ┌──────────────────────────── Shared Stage-1 Owner Domain (indexed by i) ──────────────────────┐ │
│  │                                                                                               │ │
│  │  Owner lane i=0                        ...                             Owner lane i=P-1       │ │
│  │  ┌───────────────────────┐                                             ┌────────────────────┐ │ │
│  │  │ gate weight SRAM      │                                             │ gate weight SRAM   │ │ │
│  │  │ up weight SRAM        │                                             │ up weight SRAM     │ │ │
│  │  │ exponent SRAM         │                                             │ exponent SRAM      │ │ │
│  │  │ B1_base[i] SRAM       │                                             │ B1_base[i] SRAM    │ │ │
│  │  └───────┬───────┬───────┘                                             └──────┬──────┬──────┘ │ │
│  │          │       │                                                                 │      │     │ │
│  │     ┌────▼───┐ ┌─▼──────┐                                                     ┌──▼───┐ ┌▼─────┐│ │
│  │     │Gate MAC│ │ Up MAC │                                                     │GateMAC│ │Up MAC││ │
│  │     └────┬───┘ └──┬─────┘                                                     └──┬────┘ └┬────┘│ │
│  │          │ t_g     │ t_u                                                          │ t_g    │ t_u │ │
│  │          ▼         │                                                              ▼        │     │ │
│  │     ┌─────────┐    │                                                         ┌─────────┐   │     │ │
│  │     │ PWL SiLU│    │                                                         │ PWL SiLU│   │     │ │
│  │     │ (5 cyc) │    │                                                         │ (5 cyc) │   │     │ │
│  │     └────┬────┘    │                                                         └────┬────┘   │     │ │
│  │          │ t_s     │                                                              │ t_s    │     │ │
│  │          ├─────────┴───┐                                                      ┌───┴────────┤     │ │
│  │          │ Align / elastic│                                                    │ Align / elastic │ │
│  │          │ buffer         │                                                    │ buffer         │ │
│  │          └──────┬─────────┘                                                    └──────┬────────┘ │ │
│  │                 ▼                                                                    ▼           │ │
│  │             ┌────────┐                                                           ┌────────┐      │ │
│  │             │ × Mul  │                                                           │ × Mul  │      │ │
│  │             └──┬─────┘                                                           └──┬─────┘      │ │
│  │                │ m_i, t_m                                                           │ m_i,t_m     │ │
│  │                ▼                                                                    ▼             │ │
│  │         owner output FIFO                                                     owner output FIFO   │ │
│  │                                                                                               │ │
│  │  [Per-lane ET controller: combined-scale LUT + saturating add + counter + gating]            │ │
│  └───────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                                              │
│                                      ▼ owner streams {m_i, t_m}                                    │
│                                                                                                     │
│  ┌──────────────────────────── Local Stage-2 Consumer Bank ──────────────────────────────────────┐ │
│  │ down_proj weight SRAM / exponent SRAM / B2_base[h] SRAM                                       │ │
│  │                                                                                               │ │
│  │     P owner streams  ─────────►  P × H digit-serial consumer array  ─────────► H accumulators│ │
│  │                                      (consumer mode)                          y_h partial sums │ │
│  │                                                                                               │ │
│  │     Optional ET2: static per-h budget, or same ET primitive replicated for stage-2           │ │
│  └───────────────────────────────────────────────────────────────────────────────────────────────┘ │
│                                      │                                                              │
│                                      ▼                                                              │
│  ┌──────────────────────────────── FFN Exit / Encode ────────────────────────────────────────────┐ │
│  │ final accumulator / output register / optional reconversion                                   │ │
│  └───────────────────────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

The early termination detailed draft:

# 3. Concrete ET figure design

Now the ET figure should be even more explicit.

---

## 3.1 Key message of ET figure

The figure must make three things obvious:

1. **ET decision is local**
2. **ET logic is cheap**
3. **ET gates real activity**
   - weight read
   - digit MAC
   - accumulator toggle
   - FIFO write
   not just output masking

That last point is critical.

---

## 3.2 Recommended ET datapath

I would make the stage-1 ET controller look like this:

---

## Figure B(a): Per-owner ET controller

```text
                         Per-owner ET controller for stage-1 lane i

             activation blk exp          gate weight exp         up weight exp
                  e_x_blk                     e_wg[i]               e_wu[i]
                     │                           │                     │
                     └──────────────┬────────────┴────────────┬────────┘
                                    │                         │
                              Eg = e_x + e_wg           Eu = e_x + e_wu
                                    │                         │
                                    └──────────┬──────────────┘
                                               ▼
                                      combined-scale LUT
                                    (coarse 2D class mapping)
                                               │
                                              ΔB1[i]
                                               │
      B1_base[i] ──────────────────────────────┼──────────────┐
                                               ▼              │
                                        saturating add        │
                                  B1[i] = clip(B1_base+ΔB1)   │
                                               │              │
                                               ▼              │
                                          load down-counter   │
                                               │              │
                               digit_issue_valid│              │start_of_stream
                                               ▼              │
                                        ┌────────────┐        │
                                        │  cnt_i--   │◄───────┘
                                        │ done=0?    │
                                        └─────┬──────┘
                                              │
                                              ├────────► stop weight SRAM read
                                              ├────────► stop MAC toggle
                                              ├────────► stop SiLU/mul toggle
                                              ├────────► suppress FIFO write
                                              └────────► mark lane inactive
```

---

## 3.3 Suggested LUT implementation

To make ET believable, I would recommend a **coarse LUT**, not a complex predictor.

For example:

- Bin `Eg` into 4 classes
- Bin `Eu` into 4 classes
- Use a **4×4 LUT = 16 entries**
- Output:
  \[
  \Delta B_1 \in \{-4,-2,0,+2,+4\}
  \]

This is small, easy to explain, and consistent with your “cheap enough” requirement.

You can explicitly say:

> The dynamic adjustment is implemented as a coarse significance-class lookup, not an online error estimator.

That sentence will help a lot.

---

## 3.4 Optional zero-block bypass

You can add one small side branch in the ET figure:

```text
if max(Eg, Eu) < T_zero  --->  skip_all_i = 1
```

Then:
- the whole owner lane is bypassed
- output FIFO writes a zero-tag or simply no-valid event

But I would draw this as an **optional thin side path**, not the main control.

Because, as your current results suggest, your value is mostly in **partial truncation**, not only full-zero skipping.

---

# 4. Add a cycle timeline subfigure

This is very useful because it explains both time-domain shift and ET in one shot.

---

## Figure B(b): Timing example with ET

```text
Example timing for one owner lane i

cycle:        0   1   2   3   4   5   6   7   8   9   10  11
----------------------------------------------------------------
gate MAC:     d0  d1  d2  d3  d4  d5  --  --  --  --  --  --
up MAC:       d0  d1  d2  d3  d4  d5  --  --  --  --  --  --
B1 counter:   6   5   4   3   2   1   0
ET state:     on  on  on  on  on  on  off off off off off off

SiLU pipe:            s0  s1  s2  s3  s4
SiLU ready:                           ↑ t_s

up ready:                      ↑ t_u

align wait:                        [buffer earlier operand until max(t_s,t_u)]

mul output:                            m0  m1  m2  ...
owner stream valid:                    └──── starts at t_m = max(t_s, t_u)

down consumer:
start using carried owner stream time, not cycle 0
```

You can make it prettier in the paper with colored bars.

This subfigure is valuable because it visually explains:
- digit-serial execution
- finite budget
- SiLU latency
- time alignment
- downstream consumer start time

---

# 5. A concrete set of labels and widths

To make the figure feel like real hardware, add small widths.

These are good illustrative values:

- `B1_base[i]`, `B2_base[h]`: **6 bits**
  - enough for cycle budgets 0–63
- `ΔB1`: **4 bits signed**
  - e.g. \(-4 \ldots +3\) or \(-4 \ldots +4\)
- `t_first`: **6 bits**
  - enough for 0–63 cycle arrival
- SiLU segment index: **3 bits**
  - for 8 segments
- align FIFO depth: **4–8 entries**
  - sized from skew histogram
- zero flag / active flag: **1 bit**

These are not hard commitments, but they make your figure much more concrete.

---

# 6. A concrete low-overhead implementation choice I recommend

If you want the ET story to stay disciplined, I would recommend:

## Minimal believable ET design
### Stage-1:
- **dynamic** budget:
  \[
  B_1[i] = \text{clip}(B_{1,\text{base}}[i] + \Delta B_1(E_g,E_u))
  \]
- local counter-based termination

### Stage-2:
- **static calibrated** budget only:
  \[
  B_2[h] = B_{2,\text{base}}[h]
  \]
- same local counter primitive, no dynamic LUT

This is a very nice compromise because:

- stage-1 is where your main novelty lives
- stage-2 still has ET
- control overhead stays modest

If later you want, you can mention:

> The same ET primitive can be extended to stage-2 with a smaller 1D or 2D LUT.

But I would not force that into the first main figure unless your evaluation shows it is necessary.

---

# 7. Suggested caption text

You can almost use these directly.

---

## Caption for Figure A

> **FFN-spanning MSD-first online-arithmetic micro-tile.**  
> The tile contains \(P\) intermediate-channel owner lanes and \(H\) local down-projection outputs. `gate_proj` and `up_proj` operate as parallel producers under a shared stage-1 budget domain indexed by intermediate channel \(i\). The gate path passes through a pipelined PWL SiLU block, then aligns in the time domain with the `up_proj` stream before gating multiplication. The resulting owner streams carry both numeric value and first-arrival timing metadata into the `down_proj` consumer bank, which starts from upstream arrival rather than cycle 0. Format conversion is performed only at FFN entry and FFN exit, avoiding repeated online-arithmetic interface overhead inside the FFN.

---

## Caption for Figure B

> **Low-overhead early termination for stage-1 owner lanes.**  
> A calibrated base budget \(B_{1,\text{base}}[i]\) derived from combined activation and weight exponent classes, then loaded into a local down-counter. When the counter expires, the lane locally gates weight reads, digit-MAC activity, nonlinearity/multiply toggles, and FIFO writes. The controller operates at stream granularity and requires only a small LUT, a saturating adder, and a short counter, enabling temporal compute sparsity without a global scheduler.

---


# 8. Minimum quantitative numbers to put next to the figure

Even if approximate, I would put a small table near the figure or in the text:

| Item | Per owner lane |
|---|---:|
| Base budget storage | 6 b |
| Dynamic LUT | 16 entries |
| Counter | 6 b |
| `t_first` register | 6 b |
| SiLU segment ROM | 8 entries |
| Align FIFO depth | 4–8 |

And a one-line statement like:

> ET control storage and logic scale with **lanes**, while savings scale with **digit-MAC activity and weight accesses** across the entire FFN computation.

That line helps the overhead argument.

---

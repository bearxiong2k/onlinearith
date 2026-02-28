***
# System Specification: MSD-First Time-Domain Truncated Dot-Product for LLM Simulation

## 1. Overview
I am designing a custom Compute-in-Memory (CiM) dot-product hardware unit optimized for Large Language Model (LLM) inference. The hardware uses **Most Significant Digit (MSD) first, digit-pipelined arithmetic** using Binary Signed-Digit (BSD) representation. 

The core innovation is using **Time-Domain Alignment** and **Cycle Budgeting** to achieve native, hardware-level unstructured sparsity and dynamic precision scaling. I need to simulate the exact mathematical effects (quantization noise, truncation, and dynamic sparsity) of this hardware in PyTorch to evaluate its impact on LLM accuracy.

## 2. Data Formats & Block Structure
*   **Format:** OCP Microscaling Formats (MXFP8, MXFP6, or MXFP4).
*   **Block Size:** 32 elements per block.
*   **Structure:** Each block has a shared scale (e.g., `E8M0`) and 32 individual elements with small local exponents and mantissas.
*   **Weight Pre-processing (Offline):** Because weights are stationary in CiM, the intra-block elements are converted offline into a shared intra-block fixed-point format. This eliminates the need for hardware exponent alignment within the 32-element block.

## 3. Hardware Execution Model (To be Simulated)
Standard hardware aligns floating-point numbers by shifting mantissas in space (wires). This hardware aligns them in **time (clock cycles)** using a "Delayed Start" mechanism, combined with a strict cycle budget.

### A. Time-Domain Alignment (Delayed Start)
For a dot-product consisting of multiple blocks:
1.  The hardware finds the maximum shared scale across the participating blocks: $E_{max}$.
2.  For each block $i$, it calculates the scale difference: $\Delta E_i = E_{max} - E_i$.
3.  **The Delay:** Block $i$ is delayed by $\Delta E_i$ clock cycles before it starts streaming its MSD-first digits into the accumulator. 

### B. Early Termination (Cycle Budgeting)
The hardware does not compute until the least significant bit. It operates under a strict **Cycle Budget ($B$)**. If a block's computation is delayed beyond the budget, it is truncated.
*   **Effective Precision:** A block $i$ delayed by $\Delta E_i$ cycles under a budget $B$ will only compute $P_i = \max(0, B - \Delta E_i)$ digits of precision.
*   **Total Truncation:** If $\Delta E_i \ge B$, the block contributes exactly $0$ to the dot product (hardware-native sparsity).

### C. Hybrid "Glocal" Inter-Channel Budgeting
To handle massive activation outliers without expensive cross-channel hardware, the cycle budget $B$ is determined per-channel using a hybrid approach:
1.  **Offline Base Budget ($B_{base}$):** A static cycle budget assigned to each channel offline, based on profiled weight/activation importance.
2.  **Dynamic Activation Override:** The local hardware looks at the incoming activation's shared scale ($E_{act}$). The final budget for the channel is adjusted dynamically: 
    $B_{final} = B_{base} + f(E_{act})$
    *(Where $f()$ is a simple step function or linear scaling factor that increases the budget for massive activation outliers).*

## 4. Instructions for the AI Coding Tool
I need to modify the modular.py file to simulate this operation in the framework of transfomers library (only inference is considered). The file will be converted to modeling.py automatically, the only thing to pay attention to is that "The modular converter's visit_SimpleStatementLine only matches m.Assign(...) nodes. Python annotated assignments (x: SomeType = value) produce a different CST node type — AnnAssign — which the matcher silently skips. So the three grid list variables and their builder functions were never registered in the dependency graph."

**Requirements for the custom PyTorch simulation code:**
1.  **MX Block Simulation:** Group weight and activation tensors into blocks of 32.  This is already achieved, the current modular.py supports mxfp8/6/4 formats. 
2.  **Time-Domain Truncation Logic:** 
    *   Calculate $\Delta E_i$ for each block relative to the channel/group maximum.
    *   Implement the Hybrid Glocal Budgeting to find $B_{final}$ for each channel.
    *   Calculate the effective precision $P_i = \max(0, B_{final} - \Delta E_i)$ for each block.
3.  **Set up channel budget.**
    *   The offline budget need to be set according to statistical infromation of each channel, this need to be set before the implementation.
4.  **Deep pipelining.** 
    *   MSD-first arithmatic can also be used through the layers as long as each channel are independent (a series of element-wise operations like Linear-Activation-Linear structure and FFN structure). The modular.py file already leaves compute_context args in forward() for this purpose.


*** 


# Specification: MSD-First Online Arithmetic for Compute-in-Memory (CiM) Dot-Product Engine

## 1. Core Arithmetic Principle: Binary Signed-Digit (BSD)
The entire data path operates using the **Binary Signed-Digit (BSD)** number system.
*   **Digit Set:** Each digit can be `{-1, 0, 1}`.
*   **Advantage:** BSD allows for **carry-free addition**. Carries do not ripple from the Least Significant Digit (LSD) to the Most Significant Digit (MSD). This enables serial, digit-by-digit computation starting from the MSD (Online Arithmetic).

## 2. Hardware Components & Behavior

### A. Digit-Pipelined Multiplier (MSD-First)
*   **Inputs:** Operands $A$ and $X$ arrive serially, one digit per clock cycle, MSD-first.
*   **Internal State:** 
    *   `Partial Multiplicand Register`: Accumulates digits of $A$.
    *   `Partial Multiplier Register`: Accumulates digits of $X$.
    *   `Product Residual Register`: Holds the running partial sum.
*   **Cycle $i$ Behavior:**
    1.  Receive incoming digits $a_{-i}$ and $x_{-i}$.
    2.  Use $x_{-i}$ to control a Mux: Select `Partial Multiplicand`, `0`, or `-(Partial Multiplicand)`.
    3.  Use $a_{-i}$ to control a Mux: Select `Partial Multiplier`, `0`, or `-(Partial Multiplier)`.
    4.  **Three-Operand Carry-Free Addition:** Add the two Mux outputs to the `Product Residual` (which is shifted left by 1 position, i.e., multiplied by 2).
    5.  **Output:** Extract the MSD of the addition result as the product digit $p_{-i+2}$. Save the remaining lower digits back into the `Product Residual Register`.
*   **Online Delay:** The multiplier outputs its first valid product digit after a short delay (typically 1-2 cycles).

### B. Online Accumulator Tree (MSD-First Addition)
*   **Inputs:** Multiple streams of product digits arriving MSD-first from parallel multipliers.
*   **Structure:** A binary tree of 2-input Online Adders (or a multi-operand online compressor tree).
*   **Node Behavior (2-input Online Adder):**
    1.  Receives one digit from stream $P_1$ and one from $P_2$.
    2.  Adds the incoming digits to a left-shifted internal `Sum Residual` register.
    3.  Extracts the MSD of the result as the output digit for the current cycle.
    4.  Saves the lower digits as the new `Sum Residual`.
*   **Dot-Product Output:** The root of the tree outputs the absolute MSD of the entire dot-product.

## 3. Time-Domain Alignment & MX Formats
To support floating-point dynamic range without massive hardware overhead, the design leverages OCP Microscaling Formats (e.g., MXFP4/6/8 with a block size of 32) and translates spatial shifting into **temporal delays**.

We utilize the high dynamic range of mxfp format in the time domain align so that less important calculation can be avoided through early termination. We first use intra-block fixed point for weights which is offline settled, and a two level delayed start which is inter-block (shared scale product) and intra-block (exponetial part of fp8/6/4).

***

Now according to this description, give a step by step plan to implement it.
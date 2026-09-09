# 第一级展示型版图：架构问题最终答复

## 1. 文档目的与适用范围

本文档用于直接回答第一级（Stage 1）并行版图项目提出的架构问题，并作为下一阶段 RTL、综合和布局布线工作的输入合同。

本项目的目标是产出可信、易展示的完整 tile 综合与版图结果，包括层次结构、floorplan、宏单元摆放、标准单元布局和基本时序结果。它不承担以下任务：

- 完整复现论文中的在线算术数据流；
- 实现周期精确的 TSS 时序行为；
- 完成模型到 RTL 的位精确功能验证；
- 重新生成可用于论文或 rebuttal 的硬件性能数据。

本项目采用以下已经确定的调整：

- 将每个串并行在线乘法器叶节点替换为常规乘法器；
- activation 仍采用 MXFP8 表示及原有 block 组织；
- 每个离线重编码后的 weight 固定为 8 bit 有符号定点数；
- 保留 `gate_proj`/`up_proj` 映射、权重驻留方式、metadata 来源、归约树和通道累加结构；
- 简化控制时序和 stage 外部接口。

由于乘法器实现已经改变，本项目产生的面积、时延、吞吐率和功耗结果必须标注为：

> **第一级常规乘法器展示型原型（Stage-1 conventional-multiplier presentation prototype）**

这些结果不能表述为论文中串并行 TSS 数据面的更新测量结果。

## 2. 术语定义

本文统一采用以下层次，避免将不同含义都简称为 lane：

- **lane 对（owner-lane pair）**：负责一个输出通道分配，同时包含一条 `gate_proj` 路径和一条 `up_proj` 路径。
- **路径引擎（path engine）**：一套完整的 `gate_proj` 或 `up_proj` block 计算引擎。
- **乘法器叶节点（multiplier leaf）**：路径引擎中对应一个 block 内元素的乘法器。

因此，`OWNER_LANES` 表示 lane 对数量，不表示单个乘法器的数量。

## 3. 已确定的完整 tile 配置

版图目标是完整的 8-lane-pair 参考 tile，而不是只实现一个 lane 对后在概念上复制：

```text
OWNER_LANES       = 8 个 lane 对
PATHS             = 每个 lane 对 2 条路径：gate_proj 和 up_proj
K                 = 每条路径 32 个乘法器叶节点
BLOCKS_PER_CH     = 每个 owner channel 参考配置为 128 个 block
```

完整第一级 tile 的资源数量为：

| 组件 | 数量 |
|---|---:|
| lane 对 | 8 |
| 路径引擎 | 16 |
| 常规乘法器叶节点 | 512 |
| 五级路径局部归约树 | 16 |
| 路径局部通道累加器 | 16 |
| 逻辑 weight memory | 16，即每个 lane 对各有一个 Gate 和一个 Up weight memory |
| 共享 activation buffer | 2 个 bank，用于 ping-pong 双缓冲 |

完整物理层次如下：

```text
完整第一级 tile
  共享 ACT_BUFF[0/1]
  activation metadata 输入与缓存
  共享 lambda_x 解码和广播

  8 个并行工作的 lane 对
    每个 lane 对有一套同时覆盖 gate/up 的 metadata prepass

    gate 路径
      本地 Gate Weight SRAM
      32 个空间并行的常规乘法器
      一棵五级局部归约树
      一个 gate 通道累加器

    up 路径
      本地 Up Weight SRAM
      32 个空间并行的常规乘法器
      一棵五级局部归约树
      一个 up 通道累加器
```

每个 lane 对中的 Gate 和 Up 路径并行执行，但不共享 weight memory、乘法器、归约树或累加器。共享内容仅限 activation 数据、activation-side metadata 以及相应的解码/广播逻辑。

一个 output channel 对应的多个 input block 仍然按时间串行处理；block 内的 32 个元素则空间并行处理。

论文中后续的 SiLU、Gate-Up 逐元素乘法和全部 `down_proj` shard 均不属于本次第一级版图边界。

## 4. 展示型数据面的数值格式与位宽

### 4.1 乘法器输入

activation 的外部表示仍为 MXFP8。现有 activation recode/unpack 边界负责把 MXFP8 元素转换为供展示型常规乘法器使用的 8 bit 有符号计算操作数。

需要特别说明：MXFP8 原始编码不能直接作为二补码整数送入普通整数乘法器。MX block-scale exponent 继续作为独立 metadata 处理，不直接并入乘法器输入位宽。

weight 使用已经确定的格式：

```text
8 bit 有符号、离线重编码的定点数
```

### 4.2 数据面位宽推导

```text
ACT_W        = 8 bit
WT_W         = 8 bit，有符号重编码定点数
PROD_W       = ACT_W + WT_W = 16 bit
K            = 每个 block 32 个乘积
BLOCK_SUM_W  = PROD_W + ceil(log2(K))
             = 16 + 5 = 21 bit
ACC_W        = BLOCK_SUM_W + ceil(log2(BLOCKS_PER_CH))
             = 21 + 7 = 28 bit
             （BLOCKS_PER_CH = 128）
```

为保留所有结构性进位，五级归约树采用逐级扩位：

| 位置 | 并行数据数量 | 每个数据的位宽 |
|---|---:|---:|
| 乘法器输出 | 32 | 16 bit |
| 归约树第 1 级 | 16 | 17 bit |
| 归约树第 2 级 | 8 | 18 bit |
| 归约树第 3 级 | 4 | 19 bit |
| 归约树第 4 级 | 2 | 20 bit |
| 归约树第 5 级/block sum | 1 | 21 bit |
| 通道累加器/第一级输出 | 1 | 28 bit |

本项目的数据面内部不需要中途 saturation。block-scale 恢复、舍入到后续模型格式以及模型级位精确等价不属于本次展示范围。

### 4.3 保留的 metadata 位宽

沿用参考配置：

```text
beta_x / beta_w  = 8 bit MX block-scale exponent field
raw E            = 10 bit
D                = 8 bit
H                = 8 bit
lambda_x[k]      = 每个元素 4 bit
```

简化后的常规乘法器数据面不再实现原有的逐叶节点 `start_ctr`、`rem_ctr` 和 `subtree_init` 状态。

## 5. 仅保留必要控制逻辑

为了展示 TSS metadata 路径并驱动简化后的 block 数据面，tile 只保留以下必要控制：

1. activation buffer bank 选择和 block dispatch；
2. weight/weight metadata 地址生成；
3. scale prepass：

   ```text
   E       = beta_x + beta_w
   E_max   = max_b(E)
   D       = E_max - E
   ```

4. 共享 `lambda_x` 解码和广播；
5. Horizon table 读取；
6. 简化的 window 比较：

   ```text
   tau[k]      = D + lambda_x[k]
   leaf_en[k]  = (tau[k] < H)
   block_kill  = ~(|leaf_en)
   ```

7. 根据 `leaf_en` 产生乘法器和归约树的 enable/clock-enable；
8. Gate/Up accumulator clear、block 计数、busy 和完成控制。

这样仍可在版图和 RTL 中展示 whole-block suppression 和 element-level suppression，但不再实现常规一次性乘法器不需要的逐 digit temporal window。

以下原始控制状态明确省略：

- 每个 leaf 的 start counter；
- 每个 leaf 的 remaining-digit counter；
- 周期精确的 partial-window execution；
- 存储式 `subtree_init`；
- 面向 `down_proj` 的 packetizer、completion header 和 queue control。

归约树内部节点的 enable 可直接由对应子树的 `leaf_en` 做 OR reduction 得到。

## 6. 数据与 metadata 来源

| 数据/metadata | 完整 tile 中的来源 |
|---|---|
| activation value | 上游输入的 MXFP8 数据先写入 tile 内部双 activation buffer，再经过现有 recode/unpack 边界送入计算引擎。 |
| weight value | 本地 Gate 或 Up weight memory 中驻留的 8 bit 有符号重编码定点权重。 |
| `beta_x[n,b]` | 与 activation block 同时进入 tile 的动态 activation MX block-scale metadata。 |
| activation fine code | 与 activation block 同时进入的 element exponent/fine-code metadata。 |
| `beta_w[p,c,b]` | 与对应 path weight 一起驻留的静态 weight block-scale metadata。 |
| `lambda_x[n,b,k]` | 从 activation fine code 解码一次，再广播给相关 Gate/Up 控制逻辑。 |
| `H[p,c]` | 离线 calibration 产生并预加载到 Horizon table 的静态整数。 |
| `D[p,c,b]` | tile 内部 scale prepass 根据 `beta_x` 和 `beta_w` 计算，并保存在 delay store 中。 |

因此，`D` 不是 tile 顶层输入。activation value buffer 和 activation metadata buffer 均位于本次完整 tile 的版图及面积统计边界内。

## 7. 简化的执行时序与 stage 接口

### 7.1 执行模型

每个 lane 对采用 single-inflight、固定时延的 block transaction：

1. lane 对空闲时接收一个 block；
2. 同一个 activation block 同时广播给该 lane 对的 Gate 和 Up 引擎；
3. Gate 和 Up 并行计算；
4. 两条路径分别把 block sum 累加到本地通道累加器；
5. 两条路径完成后，该 lane 对产生一次完成指示。

八个 lane 对之间可以并行工作；同一个 lane 对内不重叠执行两个 block。

### 7.2 顶层概念接口

```text
公共输入
  clk_i
  rst_ni
  start_i[7:0]
  channel_acc_clear_i[7:0]
  activation/configuration load interface

每个 lane 对的输出
  busy_o[7:0]
  done_o[7:0]
  gate_acc_o[0:7][27:0]
  up_acc_o[0:7][27:0]
```

接口行为固定如下：

- 不要求 AXI、NoC、packet header 或完整的 ready/valid 协议；
- 不支持 block 中途暂停；
- 不支持下游 backpressure；
- 仅在 `busy_o[pair] == 0` 时接收 `start_i[pair]`；
- busy 期间出现的新 start 可以忽略，并在仿真中触发错误检查；
- 同一 lane 对的 Gate 和 Up 在 wrapper 边界上同时完成；
- reset 清除 busy、valid、控制和 accumulator 状态，但不清除 SRAM/buffer 内容；
- weight、weight metadata 和 Horizon 可通过抽象 setup port 或 testbench preload 初始化，不要求生产级配置总线。

### 7.3 block latency 与 initiation interval

实现采用固定的 `BLOCK_LATENCY`。具体数值由下一阶段的乘法器/归约树 pipeline、工艺库和目标时钟决定。

由于同一 lane 对不重叠执行 block：

```text
II_per_pair = BLOCK_LATENCY
```

论文/rebuttal 中的 16-cycle block slot 以及 Anchor 2 proxy 的时序不是本展示型原型的约束。

## 8. 对原始问题的逐项最终答复

| 原始问题 | 本项目的最终答复 |
|---|---|
| 一个 tile 到底有几个 multiplier lane？ | 完整 tile 有 8 个 lane 对、16 个路径引擎和 512 个常规乘法器叶节点。 |
| 是每个 lane 一个 multiplier，还是多个 lane 共享 multiplier？ | 每个 lane 对拥有两套独立的 32-multiplier 引擎，分别用于 Gate 和 Up。不同 lane 对、不同路径之间不共享数据面乘法器。 |
| 32 个 element 是 32 路并行、少路复用，还是 block-serial？ | block 内 32 个 element 空间并行；同一 owner channel 的多个 block 按时间串行。没有少路 multiplier folding。 |
| reduction tree 是每 lane 独立、跨 lane 共享，还是时分复用？ | 每个路径引擎一棵独立五级归约树，完整 tile 共 16 棵；不跨 lane 共享，也不时分复用。 |
| accumulator 是每 lane 一个，还是集中式？ | 每个路径引擎一个本地 accumulator；每个 lane 对有 Gate/Up 两个，完整 tile 共 16 个，不使用集中式 accumulator。 |
| 一个 block 需要多少 cycle，连续 block 的 initiation interval 是多少？ | 使用固定 `BLOCK_LATENCY`，同一 lane 对为 single-inflight，因此 `II=BLOCK_LATENCY`。具体 cycle 数由下一阶段 pipeline 和工艺约束决定，不沿用 rebuttal 数值。 |
| activation、weight、`beta_x`、`beta_w`、`H`、`D` 分别从哪里来？ | activation 和 `beta_x` 进入 tile 内部 activation/metadata buffer；8 bit 重编码 weight 和 `beta_w` 本地驻留；`H` 离线生成后预加载；`D` 由 tile 内部 prepass 计算。 |
| weight storage 是 register file、综合 memory，还是 28 nm SRAM macro？ | 逻辑上是位于 tile 内部的本地 weight memory，共 16 个。使用真实 28 nm SRAM macro、抽象 macro 还是 generated memory view 明确延期到下一阶段；面积报告中不能把它当作零成本外部存储。 |
| tile 的输入输出端口、valid/ready、backpressure 和 reset 行为是什么？ | 使用简化的 `start/busy/done` 接口；不实现生产级 ready/valid 和下游 backpressure。reset 清除控制及 accumulator，不清除 memory 内容。 |
| tile 是只处理一个 projection，还是 gate/up 两条路径共享？ | tile 同时处理 Gate 和 Up。两条路径共享 activation-side metadata 分发，但各自拥有独立 memory、乘法器、归约树和 accumulator。 |
| tile 的目标频率、面积、吞吐率和功耗预算是什么？ | 这些不是展示型架构的固定要求，明确交给下一物理设计阶段。最终只报告所选工艺库和约束下得到的结果。 |
| 是否需要 scan、MBIST、test mode、power gating 或 retention？ | 本展示项目不要求。除非具体 P&R flow 要求最小 test/clock-gate bypass pin，否则均不实现。 |
| layout 边界是否包含 SRAM、接口 buffer、clock/reset cell 和 physical-only cells？ | 边界包含完整 8-lane-pair tile、双 activation buffer、activation metadata buffer、16 个逻辑 weight memory、必要 metadata/control store、简化控制、本地 accumulator 和接口 buffer。clock/reset tree 及 physical-only cell 的具体纳入和统计方式延期到下一阶段。 |

## 9. 完整 tile 的版图边界

### 9.1 明确包含

- 8 个 lane 对；
- 512 个常规乘法器；
- 16 棵归约树和 16 个 accumulator；
- 2 个内部 activation buffer bank；
- activation metadata buffer；
- 16 个 Gate/Up 逻辑 weight memory；
- weight metadata、Horizon、raw-E、delay 和 leaf-mask 状态；
- 共享 activation decode/broadcast；
- 必要的简化控制器；
- 本地输入/输出接口 buffer；
- tile 的 clock/reset 入口。

### 9.2 明确排除

- SiLU；
- Gate-Up 逐元素 gating multiplier；
- 全部 `down_proj` shard；
- Stage 2 packetizer、FIFO、NoC 和系统仲裁；
- pad ring 和封装接口；
- 生产级 DFT；
- SRAM MBIST/BISR；
- power gating、isolation 和 retention。

## 10. 明确延期到下一物理设计阶段的事项

上述架构问题已经关闭。以下只属于实现选择，不再反向改变第一级架构：

1. Gate/Up weight memory 的精确容量、banking、word width 和 port 数量；
2. 使用真实 28 nm SRAM compiler view、抽象 macro，还是 generated memory；
3. Horizon、raw-E、delay、metadata 和 activation buffer 使用 flop、综合 memory 还是 macro；
4. multiplier/tree pipeline register 的位置，以及由此得到的具体 `BLOCK_LATENCY` 和 II；
5. 实际 technology library、PVT corner、目标 clock、utilization、aspect ratio、routing layer 和 floorplan 约束；
6. 绝对面积、吞吐率和功耗目标/预算；
7. clock tree、reset cell 的实现方式；
8. tap、endcap、filler、tie、decap 等 physical-only cell 是否计入 headline area。

这些延期事项会影响最终版图指标，但不会重新打开以下已经固定的结论：

```text
完整 8-lane-pair tile
Gate/Up 两条并行路径
每条路径 32 个空间并行乘法器
每条路径独立归约树
每条路径独立 accumulator
内部双 activation buffer
MXFP8 activation，经 recode/unpack 后形成 8 bit 有符号计算操作数
8 bit 有符号重编码定点 weight
```


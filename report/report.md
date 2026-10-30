# 操作系统实验报告

## 实验基本信息

| 项目       | 内容                                 |
| -------- | ---------------------------------- |
| **实验名称** | Lab3 : \[断,都可以断]                  |
| **小组成员** | 2413330-张子馨、2410691-刘思岑、2411191-王可 |
| **完成日期** | 2026-10-29                         |

### 小组分工

| 成员          | 负责的模块                |
| ----------- | -------------------- |
| 2413330-张子馨 | 功能模块二 |
| 2410691-刘思岑 | 功能模块一 |
| 2411191-王可  | 无      |

2413330-张子馨负责功能模块二实现部分，参与撰写AI协作开发经验， 2410691-刘思岑负责撰写功能模块一实现部分，参与撰写实验总结与收获和AI协作开发经验，2411191-王可负责撰写报告其他所有部分，参与撰写AI协作开发经验。

***

## 一、实验目的

本实验的主要目的是：

1. 理解页表的建立和使用方法
2. 理解物理内存的管理方法
3. 理解页面分配算法

***

## 二、实验环境

| 成员          | AI 编程工具          | 底层模型                              | 备注                    |
| ----------- | ---------------- | --------------------------------- | --------------------- |
| 2413330-张子馨 | Cline（VS Code插件） | DeepSeek-V4-Flash和DeepSeek-V4-pro | 勾选了计划和执行时使用不同的模型      |
| 2410691-刘思岑 | Codex(VS Code插件) | ChatGPT-6 Sol                     | 无                     |
| 2411191-王可  | Codex（终端Agent）   | GPT-6.1-Sol                       | 使用WSL环境运行Codex终端Agent |

***

## 三、实验整体逻辑分析

### 2.1 本章节的逻辑主线

[请用自己的话描述本章实验的核心主线，例如：
- 本章围绕哪个核心主题展开？（例如：用户进程管理、虚拟内存、文件系统等）
- 整个实验解决什么问题？（例如：如何让用户程序运行在操作系统之上）]

### 2.2 功能的逐步实现

[说明本章实验是按照什么顺序逐步实现各个功能的，以及为什么要按这个顺序，例如：

1. 首先实现**功能A** → 为什么首先实现这个？（例如：建立系统调用接口是后续所有用户态功能的基础）
2. 接着再完善**功能B** → 为什么接着实现这个？（例如：有了系统调用后，需要能够加载和启动第一个用户进程）
3. 然后完成**功能C** → 为什么然后实现这个？（例如：有了第一个进程后，需要实现进程复制功能）
4. 最后补充了**功能D** → 为什么最后实现这个？（例如：最后完善进程退出和清理机制，形成完整闭环）]

---

## 四、实验内容与实现

<!-- 
说明：本部分按照 exercises 文档中的练习顺序组织
每个功能模块或者练习中可能包含多项任务，请根据实际情况调整
-->

### 功能模块二：[中断与异常处理功能]

**负责人：** [2413330-张子馨]

#### 模块功能描述

**需要实现/修改的函数：**

```c
void interrupt_handler(struct trapframe *tf);(kern\trap\trap.c)
void exception_handler(struct trapframe *tf);(kern\trap\trap.c)
```

**功能说明：**

本模块位于 Trap 处理链路的最末端。异常入口 `__alltraps` 保存现场后调用 `trap(tf)`，`trap()` 内的 `trap_dispatch()` 依据 `scause` 最高位区分中断与异常，分别进入 `interrupt_handler(tf)` 和 `exception_handler(tf)`。本模块负责对已经完成粗分类的 Trap 做进一步的具体识别与处理，处理完成后直接返回，由模块一实现的 `__trapret`（`RESTORE_ALL` + `sret`）恢复现场并回到被中断或出错的位置。

需要处理的主要场景：

1. **时钟中断 `IRQ_S_TIMER`**：这是系统运行期间持续发生的中断。处理时先调用 `clock_set_next_event()` 预约下一次时钟事件（否则 SBI 定时器不会再次触发，系统只能收到一次时钟中断），再执行 `ticks++`；当 `ticks` 为 `TICK_NUM`（100）的整数倍时调用 `print_ticks()` 输出 `100 ticks` 统计信息；当统计信息累计输出达到 `SHUTDOWN_AFTER` 次后调用 `sbi_shutdown()` 关机。
2. **其他可识别中断**：仅做类型区分并输出相应提示，例如软件中断、外部中断等。
3. **无法识别的中断**：输出 `Unknown interrupt: cause N`，并调用已有的 `print_trapframe(tf)` 输出完整 Trap frame 以辅助调试。
4. **非法指令异常**：输出规定格式的 `Illegal instruction at 0x........`，并按出错指令的真实长度更新 `tf->epc`。
5. **断点异常**：输出规定格式的 `Breakpoint at 0x........`，同样按实际指令长度更新 `tf->epc`，保证 `sret` 后不会重复执行同一条异常指令。
6. **其他异常**：本实验不要求具体的恢复逻辑，直接调用 `print_trapframe(tf)` 兜底。

与其它模块的交互关系：本模块依赖模块一（`trapentry.S`）保存/恢复现场并把 `struct trapframe *` 传入 `trap()`；依赖 clock 驱动的 `clock_set_next_event()` 维持周期性时钟中断；依赖 `libs/sbi.h` 中的 `sbi_shutdown()` 完成关机；依赖 `print_trapframe()`、`print_ticks()` 完成调试与统计输出。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown
[ROLE]
你是一名 RISC-V 64 位 ucore 内核开发者，需要在 kern/trap/trap.c 中实现功能模块二：
中断与异常的分发处理（interrupt_handler 和 exception_handler）。

[CONTEXT / RELY]
- 异常入口 __alltraps 已由功能模块一完成：SAVE_ALL 把现场保存为 struct trapframe 并调用
  trap(tf)，返回后执行 RESTORE_ALL + sret。
- trap() 中的 trap_dispatch() 已通过 (intptr_t)tf->cause < 0 区分中断/异常，并分别调用
  interrupt_handler(tf) / exception_handler(tf)，本模块只需实现这两个函数。
- scause 最高位为 1 表示中断，其余位为中断原因；异常时 tf->cause 直接是异常原因。
- 可用接口与宏：clock_set_next_event()、ticks、TICK_NUM=100、SHUTDOWN_AFTER、
  IRQ_S_TIMER、CAUSE_ILLEGAL_INSTRUCTION、CAUSE_BREAKPOINT、print_trapframe(tf)、
  print_ticks()、sbi_shutdown()（libs/sbi.h）。具体定义以实验框架为准。
- print_ticks() 是 trap.c 内已有的 static 函数，直接调用即可，不要新增框架中不存在的头文件或接口。

[SPECIFICATION]
1. interrupt_handler(tf)：
   - IRQ_S_TIMER：先调用 clock_set_next_event() 重新设置下一次时钟事件；再执行 ticks++；
     当 ticks % TICK_NUM == 0 时调用已有的 print_ticks() 输出统计信息；
     统计信息累计输出达到 SHUTDOWN_AFTER 次后调用 sbi_shutdown()；
     累计次数直接用 ticks / TICK_NUM >= SHUTDOWN_AFTER 判断，不新增计数器。
     若实验框架中未定义 SHUTDOWN_AFTER，在本文件中补充 #define SHUTDOWN_AFTER 10。
   - 其余可识别中断：用 switch 分支做类型区分并输出对应提示（如 "Supervisor software interrupt"）。
   - 无法识别的中断：输出 "Unknown interrupt: cause %d"，再调用 print_trapframe(tf)。
2. exception_handler(tf)：
   - CAUSE_ILLEGAL_INSTRUCTION：输出 "Illegal instruction at 0x%08x"，然后前移 tf->epc。
   - CAUSE_BREAKPOINT：输出 "Breakpoint at 0x%08x"，然后前移 tf->epc。
   - 其他异常：调用 print_trapframe(tf) 兜底。
3. tf->epc 的前移量必须按出错指令的真实长度计算：读取 epc 处指令的低 2 位，
   0b11 表示 32 位指令（+4），否则为 16 位压缩指令（+2）。

[CONSTRAINTS]
- 不得修改函数签名，不得改动 trap.c 中这两个处理函数以外的函数。
- 只在 "//lab3 function2 YOUR CODE" 标记区域新增代码，保留 TICK_NUM、print_ticks() 等已有内容。
- 所有输出统一使用 cprintf()；项目中没有 printk()，不得调用不存在的接口。
- 必须保持"Trap 类型识别、处理行为、执行位置更新、后续 Trap 返回"之间的一致性。
- 时钟中断绝不能只计数而不设置下一次时钟事件，否则系统只能收到一次时钟中断。
- 不得假定所有异常的 epc 偏移量相同。

[OUTPUT]
输出可直接替换 "//lab3 function2 YOUR CODE" 标记处的 C 代码，并给出关键设计说明。
````

#### 实现迭代过程

本模块的实现经历了 2 次迭代，过程如下：

---

##### 第一次迭代

**实现思路：**

按照 `trap_dispatch()` 已经完成的粗分类，在 `interrupt_handler()` 中用 `switch` 处理 `IRQ_S_TIMER`（重新设置下一次时钟事件、计数、周期性输出统计信息、达到次数后关机）及各类可识别中断；在 `exception_handler()` 中处理非法指令与断点异常，其余类型统一调用 `print_trapframe(tf)` 兜底。此时对 `tf->epc` 的处理较为简单，统一按 4 字节指令长度执行 `tf->epc += 4`。

**遇到的问题：**

- 问题1：运行 `make grade` 时，"trap entry, register restore, and breakpoint EPC" 用例失败（0/35），总分只有 65/100，而非法指令和时钟中断两个用例均通过。
- 问题2：分析失败原因是断点异常返回后寄存器上下文被破坏。用 `riscv64-unknown-elf-objdump -d` 反汇编测试代码发现，`ebreak` 被汇编为 `9002`（即 2 字节的压缩指令 `c.ebreak`），而报错代码如下：

```asm
6a:   9002            ebreak
6c:   10500513        li      a0,261
```

因此 `tf->epc += 4` 会把 `ebreak` 之后的第一条指令 `li a0, 261` 一并跳过，导致后续寄存器一致性校验失败。

**问题解决策略：**

- 针对问题1与问题2：不再假定指令长度固定为 4 字节，而是在修改提示词的 `[SPECIFICATION]` 中明确要求"按 epc 处指令编码判断长度"，并加入 `instr_length()` 辅助函数：读取 epc 处的 16 位半字，若低 2 位为 `0b11` 则返回 4，否则返回 2。非法指令与断点异常都用该函数计算前移量，兼容 16 位压缩指令与 32 位指令。

---

##### 第二次迭代

**修改内容：**

1. 新增 `instr_length()`，非法指令和断点异常均按 `tf->epc += instr_length(tf->epc)` 更新返回地址。
2. 时钟中断中严格保证 `clock_set_next_event()` → `ticks++` → `ticks % TICK_NUM == 0` 时 `print_ticks()` 的顺序，并在统计输出累计达到 `SHUTDOWN_AFTER`（框架未给出具体数值，按 ucore 惯例取 10，即 1000 次时钟中断）后调用 `sbi_shutdown()`；该阈值远大于测试要求的 200 ticks，不会造成提前关机。
3. 对未识别中断补充 `Unknown interrupt: cause %d` 提示并调用 `print_trapframe(tf)`；对未要求恢复的异常同样以 `print_trapframe(tf)` 兜底。

**最终结果：**

经过 2 次迭代，该模块最终：

- ✅ 编译通过
- ✅ 全部三个评测用例通过（35/35、25/25、40/40），总分 100/100
- ✅ 功能符合预期

**关键改进点总结：**

1. 在 `[RELY]` 中补充了"`scause` 最高位表示中断、其余位为原因"的编码规则，使中断原因提取正确。
2. 在 `[SPECIFICATION]` 中明确了 `tf->epc` 必须按出错指令真实长度前移，避免了压缩指令场景下跳过指令、破坏寄存器上下文的问题。
3. 在 `[SPECIFICATION]` 与 `[CONSTRAINTS]` 中强调了时钟中断必须重新设置下一次时钟事件，保证时钟中断能够持续产生，而不是只触发一次。
4. 明确了 `SHUTDOWN_AFTER` 的语义为"统计信息累计输出次数"，使关机条件与 `ticks` 计数之间的关系清晰。

---


## 五、测试与验证

<!-- 根据该实验的具体情况，提供完整的测试运行截图，应包含：
- 编译及运行成功的输出（make qemu），可能有多个
- 测试通过的结果（make grade），只有一个
-->

**测试截图：**

![测试结果截图](./images/test_result.png)

---

## 六、实验总结与收获

### 对操作系统的理解

1. 列出你们认为本实验中重要的知识点，以及与对应的 OS 原理中的知识点，并简要说明二者的含义、关系和差异
2. 列出你们认为 OS 原理中很重要、但在本实验中没有对应上的知识点

### AI 协作开发的经验

[写出你们在与 AI 协作过程中实际收获的经验或者感悟]

---

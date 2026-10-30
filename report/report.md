# 操作系统实验报告

## 实验基本信息

| 项目 | 内容 |
|------|------|
| 实验名称 | Lab3：中断与异常处理 |
| 小组成员 | 2413330-张子馨、2410691-刘思岑、2411191-王可 |
| 完成日期 | 待填写 |

### 小组分工

- 2410691-刘思岑：功能模块一。
- 2413330-张子馨：。
- 2411191-王可：。
- 三人共同完成代码审查、集成测试，以及各自任务中的 spec、prompt、问题修复记录。

## 一、实验目的

## 二、实验环境

| 成员 | AI 编程工具 | 底层模型 | 备注 |
|------|------------|---------|------|
| 2413330-张子馨| Cline（VS Code插件）|  DeepSeek-V4-Flash和DeepSeek-V4-pro| 勾选了计划和执行时使用不同的模型 |
| 2410691-刘思岑|Codex(VS Code插件)|ChatGPT-6 Sol| 无
| 2411191-王可| Codex（终端Agent）|GPT-6.1-Sol| 使用WSL环境运行Codex终端Agent|

## 三、实验整体逻辑分析

## 四、实验内容与实现

### 功能模块一：Trap 上下文恢复与 Trap 入口（`kern/trap/trapentry.S`）

**最终功能：** Trap 发生时，由已有的 `SAVE_ALL` 在栈上形成与 `struct trapframe` 一致的现场；`__alltraps` 将该帧的地址作为第一个参数传给 C 语言 `trap(struct trapframe *tf)`；`trap()` 返回后，`__trapret` 调用 `RESTORE_ALL`，恢复被打断程序的通用寄存器、`sstatus`、`sepc` 和原栈指针，最后通过 `sret` 回到正确的执行位置。该模块提供完整的“保存现场 → 调用 C 处理 → 恢复现场 → Trap 返回”底层闭环，具体中断和异常的分类处理由模块二负责。



#### 任务一：实现 `RESTORE_ALL`，恢复 Trap frame 中的寄存器与返回状态

##### 功能与接口
功能：
    从 Trap frame（异常现场保存区）中恢复发生异常前的寄存器状态，为返回原程序做准备。

接口表：

| 项目 | 内容 |
|---|---|
| 实现位置 | `kern/trap/trapentry.S` |
| 实现对象 | `RESTORE_ALL` 汇编宏 |
| 输入 | `sp` 指向的 Trap frame |
| 布局依据 | `trap.h` 中的 `struct trapframe`，以及已有的 `SAVE_ALL` |
| 核心功能 | 恢复通用寄存器、`sstatus` 和 `sepc` |
| 特别注意 | `x2(sp)` 必须最后恢复，否则会失去 Trap frame 的寻址基址 |
| 完成后 | 由 `__trapret` 中的 `sret` 返回 |



##### spec

**Spec：** 前置条件是 `SAVE_ALL` 已产生完整 Trap frame，且 `sp` 指向帧首；后置条件是处理函数可能修改的 `status`、`epc` 已写回对应 CSR，所有可写通用寄存器恢复为帧中值，`sp` 恢复为 Trap 前的值。恢复其他寄存器期间不能提前改变作为帧基址的 `sp`；即从已经保存好的 Trap frame 中恢复现场，保证程序能从正确位置继续执行；恢复 sp 必须放在最后。

**最终 Prompt：**





[PROMPT]

任务：完成 Lab3 功能模块一，使 Trap 处理形成“保存现场 → 调用 C 处理函数
→ 恢复现场 → 返回原执行流”的完整流程。
修改位置：只修改 kern/trap/trapentry.S 中两处标有
“#lab3 function1 YOUR CODE”的位置，分别补全 RESTORE_ALL 宏和
__alltraps 入口。保留 lab3 function1 注释，将 YOUR CODE 改为负责人
学号 2410691。不要修改其他文件或无关代码。

[RELY]


实现时可以依赖项目中已有的：

1. SAVE_ALL：已将 Trap 现场保存到当前 sp 指向的 Trap frame。
   其中原来的 x2(sp) 经 sscratch 保存到帧的第 2 槽。
2. kern/trap/trap.h 中的 struct trapframe：
   第 0～31 槽是通用寄存器；第 32～35 槽依次是
   status、epc、badvaddr、cause。
3. trap(struct trapframe *tf)：已有的 C 语言 Trap 处理接口。
4. __trapret：已有的返回入口，会执行 RESTORE_ALL 和 sret。
5. riscv.h 中的 LOAD、REGBYTES 等宏，以及 RISC-V 调用约定：
   第一个函数参数通过 a0 传递。

[GUARANTEE]


必须交付以下两处实现：

1. RESTORE_ALL 汇编宏：从当前 Trap frame 恢复执行现场。
2. __alltraps 中 SAVE_ALL 之后的代码：把 Trap frame 传给 trap()，
   并在 trap() 返回后衔接 __trapret。

不得修改 SAVE_ALL、struct trapframe、trap() 的函数签名，以及现有的
__trapret 和 sret。

[SPECIFICATION]


1. RESTORE_ALL

- 开始执行时，sp 指向 SAVE_ALL 建立的 Trap frame。
- 按实际帧布局恢复 sstatus、sepc 和可写通用寄存器。
- x0 是恒为零的寄存器，无需恢复；badvaddr 和 cause 不需要写回 CSR。
- 第 2 槽保存的是 Trap 发生前的 sp。必须等所有以当前 sp 为基址的
  帧数据读取完成后，最后恢复 x2(sp)。
- 执行结束时，寄存器和返回位置应与 Trap frame 中记录的状态一致，
  随后可由 sret 返回。

2. __alltraps

- SAVE_ALL 执行后，当前 sp 是完整 Trap frame 的首地址。
- 按 RISC-V 调用约定，把这个地址作为 struct trapframe * 参数传给
  trap(struct trapframe *tf)。
- trap() 返回后，sp 仍须指向同一个 Trap frame，使控制流能够进入
  __trapret 并正确恢复现场。
- 不另行假设 Trap frame 布局，也不改动已保存的现场。
##### 实现过程与关键代码

实现先写回 `sstatus` 和 `sepc`，再加载其余通用寄存器，最后执行 `LOAD x2, 2*REGBYTES(sp)`。这样 `sp` 在全部读取 Trap frame 的过程中始终是帧基址。`LOAD` 和 `REGBYTES` 沿用项目的 `riscv.h` 宏定义。

##### 遇到的问题、修复及验证

已在实现时避免一个关键顺序错误：如果提前恢复 `x2`，后续加载会以 Trap 前的栈指针寻址，读错 Trap frame。当前已做静态核对；运行时寄存器恢复、断点返回等结果需在可用的 RISC-V 工具链与 QEMU 环境中验证，尚未记录为通过。

#### 任务二：实现 `__alltraps`，向 C 语言 `trap()` 传递 Trap frame

##### 功能与接口

功能：

Trap 发生后，`__alltraps` 保存现场，并把 Trap frame 交给 C 语言的 `trap()` 处理。处理结束后，进入现场恢复和返回流程。

接口表：

| 项目 | 内容 |
|---|---|
| 实现位置 | `kern/trap/trapentry.S` |
| 实现对象 | `__alltraps` 汇编入口 |
| 输入 | Trap 发生时的处理器状态 |
| 已有依赖 | `SAVE_ALL` 将现场保存为 Trap frame，此时 `sp` 指向帧首 |
| 调用接口 | 将 `sp` 放入参数寄存器 `a0`，调用 `trap(struct trapframe *tf)` |
| 返回要求 | `trap()` 返回后，`sp` 仍指向该 Trap frame |
| 后续流程 | 进入 `__trapret`，由 `RESTORE_ALL` 恢复现场，再执行 `sret` 返回 |


##### Spec：
**Spec：** 前置条件是处理器因 Trap 跳转到 `__alltraps`；后置条件是 `trap()` 收到有效、完整的 Trap frame 指针，返回后继续进入 `__trapret`。调用前后必须维持帧基址和 RISC-V ABI 对栈的要求，不得破坏待恢复的帧内容。

**最终 Prompt：**
[PROMPT]
任务：补全 Trap 汇编入口与 C 语言处理函数之间的调用。

只修改 kern/trap/trapentry.S 中 __alltraps 下方标有
“#lab3 function1 YOUR CODE”的位置。先阅读该文件和 kern/trap/trap.h，
依据现有代码完成传参和调用，不修改其他位置。保留 lab3 function1
注释，并将 YOUR CODE 改为负责人学号 2410691。

[RELY]
可以依赖以下已有内容：

1. SAVE_ALL 已在 __alltraps 中执行，并在当前栈上建立完整的 Trap frame。
   执行后，sp 指向该帧的首地址。
2. kern/trap/trap.h 定义了 struct trapframe，并声明了
   void trap(struct trapframe *tf)。
3. RISC-V 调用约定使用 a0 传递第一个函数参数。
4. __trapret 已存在，其后续流程是 RESTORE_ALL 和 sret。

[GUARANTEE]
必须补全 __alltraps 中 SAVE_ALL 之后的代码，使其完成两件事：

1. 把当前 Trap frame 的地址作为参数传给 trap()。
2. trap() 返回后，继续进入现有的 __trapret 返回流程。

不得修改 SAVE_ALL、RESTORE_ALL、__trapret、struct trapframe
或 trap() 的函数签名。

[SPECIFICATION]
- 进入待补全部分时，sp 指向 SAVE_ALL 建立的 Trap frame。
- 调用 trap() 时，传入的 struct trapframe *tf 必须指向该帧，
  并符合 RISC-V 的函数参数传递约定。
- 不得覆盖或破坏 Trap frame 中保存的寄存器和返回状态。
- trap() 返回后，sp 仍指向同一个 Trap frame，使 __trapret
  能从中恢复现场。
- 控制流在 trap() 返回后顺序进入 __trapret，不另建返回流程。


##### 实现过程与关键代码

在 `SAVE_ALL` 之后执行 `mv a0, sp` 和 `jal trap`。`SAVE_ALL` 已将原始 `a0` 保存于帧中，因此传参不会丢失被打断程序的 `a0`；`trap()` 返回后由 `RESTORE_ALL` 恢复它。没有额外调整 `sp`，以便直接衔接 `__trapret`。

##### 遇到的问题、修复及验证

实现时核对了 `a0` 传参和返回后的帧基址关系。当前尚未在 QEMU 中实测 Trap 入口、C 函数调用与返回闭环；模块二的处理函数仍需完成，整体验证也依赖该部分。





### 功能模块二：中断与异常处理（`kern/trap/trap.c`）

#### 任务一：实现 `interrupt_handler()`，处理中断与持续时钟事件

##### 功能与接口

##### Spec 与最终 Prompt

##### 实现过程与关键代码

##### 遇到的问题、修复及验证

#### 任务二：实现 `exception_handler()`，处理非法指令与断点异常

##### 功能与接口

##### Spec 与最终 Prompt

##### 实现过程与关键代码

##### 遇到的问题、修复及验证

## 五、测试与验证

## 六、知识点对应与实验总结

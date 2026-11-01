# AI 提示词汇总

## [2413330-张子馨] 功能模块二：中断与异常处理

### 1. 第一轮：实现中断与异常处理

```text
[ROLE]
你是一名 RISC-V 64 位 ucore 内核开发者，需要在 kern/trap/trap.c 中实现功能模块二：
中断与异常的分发处理（interrupt_handler 和 exception_handler）。

[任务]
在 kern/trap/trap.c 的 "//lab3 function2 YOUR CODE" 标记处实现 interrupt_handler() 和
exception_handler()，不得修改 trap.c 中其他函数，不得修改函数签名。

[已知条件]
- 异常入口 __alltraps 已由功能模块一完成：保存现场为 struct trapframe 并调用 trap(tf)，
  返回后恢复现场并执行 sret。
- trap_dispatch() 已通过 (intptr_t)tf->cause < 0 区分中断与异常，并分别调用这两个处理函数。
- scause 最高位为 1 表示中断，其余位为中断原因；异常时 tf->cause 直接是异常原因。
- 可用接口与宏：clock_set_next_event()、ticks、TICK_NUM=100、SHUTDOWN_AFTER、
  IRQ_S_TIMER、CAUSE_ILLEGAL_INSTRUCTION、CAUSE_BREAKPOINT、print_trapframe(tf)、
  print_ticks()、sbi_shutdown()（libs/sbi.h）。

[要求]
1. interrupt_handler(tf)：
   - IRQ_S_TIMER：调用 clock_set_next_event() 设置下一次时钟事件；执行 ticks++；
     当 ticks % TICK_NUM == 0 时调用 print_ticks() 输出统计信息；
     统计信息累计输出达到 SHUTDOWN_AFTER 次后调用 sbi_shutdown() 关机。
   - 其他可识别中断：用 switch 分支做类型区分并输出对应提示，例如
     "Supervisor software interrupt"、"Supervisor external interrupt"。
   - 无法识别的中断：输出 "Unknown interrupt: cause %d"，再调用 print_trapframe(tf)。
2. exception_handler(tf)：
   - CAUSE_ILLEGAL_INSTRUCTION：输出 "Illegal instruction at 0x%08x"。
   - CAUSE_BREAKPOINT：输出 "Breakpoint at 0x%08x"。
   - 两者都执行 tf->epc += 4，跳过当前异常指令，避免 Trap 返回后重复执行。
   - 其他异常：调用 print_trapframe(tf) 兜底。

[输出]
直接给出可替换 "//lab3 function2 YOUR CODE" 标记处的 C 代码，注释使用中文。
```

### 2. 第二轮：根据评测失败修复断点异常的 EPC 更新

```text
make grade 运行时，"trap entry, register restore, and breakpoint EPC" 用例失败（0/35），
总分只有 65/100，非法指令和时钟中断两个用例通过。

用 riscv64-unknown-elf-objdump -d 反汇编测试目标文件，断点附近为：
6a:   9002            ebreak
6c:   10500513        li      a0,261

说明 ebreak 被汇编为 2 字节压缩指令 c.ebreak，而当前 exception_handler 对断点异常执行
tf->epc += 4，会跳过 ebreak 之后的第一条指令，导致寄存器上下文校验失败。

请在保持其他逻辑不变的前提下修复：
1. 新增辅助函数读取 tf->epc 处的 16 位指令，低 2 位为 0b11 时返回 4，否则返回 2。
2. 非法指令异常和断点异常都按该函数返回的长度前移 tf->epc。
3. 给出完整修改后的两个处理函数，并说明为什么不能统一按 4 字节前移。
```

### 3. 最终提示词

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

## [2411191-王可] 实验报告其他模块
请结合我上传的实验指导书和老师提供的lab3.zip，为实验报告撰写“功能的逐步实现”这一节。

【任务范围】
分析lab3“断，都可以断”，说明本实验如何逐步建立中断与异常处理机制，以及各步骤之间的依赖关系。不要扩展到用户进程管理、进程调度、文件系统等本实验未要求实现的功能。

【分析要求】
请先阅读指导书中lab3的实验要求，再检查代码，重点关注：
1. kern/trap/trapentry.S：SAVE_ALL、RESTORE_ALL、__alltraps、__trapret。
2. kern/trap/trap.h：struct trapframe的布局。
3. kern/trap/trap.c：trap、trap_dispatch，以及待补充的interrupt_handler、exception_handler。
4. kern/init/init.c、kern/driver/clock.c、kern/driver/intr.c：Trap入口设置、时钟初始化和中断开启。
5. tools/中的相关测试文件：了解验证内容，不要把测试代码当作待实现的核心功能。

必须区分“框架已经提供的功能”和“本实验需要补充的功能”。特别注意，SAVE_ALL、trap、trap_dispatch、idt_init、clock_init等已有实现，不能全部描述成从零编写。

【内容组织】
请按照功能之间的依赖关系组织为4—5个步骤，可以参考以下思路，但应以实际材料为准：

1.先理解已有的上下文保存方式和TrapFrame布局，再补全RESTORE_ALL，使保存的寄存器和处理器状态能够正确恢复。
2.接着补全 __alltraps，将当前TrapFrame的地址按调用约定传给C语言trap函数，并衔接处理完成后的恢复与sret返回流程。
3.在上述入口和返回机制基础上，实现中断与异常的具体处理，包括时钟中断、断点异常和非法指令异常。
4.最后结合已有初始化流程和测试，检查整个处理链路是否能够持续响应事件，并正确恢复执行。

如果把异常处理和时钟中断处理分为两个步骤，请说明它们都依赖公共Trap框架，不要编造两者之间必须先后实现的关系。

【每一步必须说明】
- 实现或补全什么功能；
- 涉及哪些关键函数或模块；
- 为什么安排在这个阶段，它依赖前面哪些条件；
- 它为后续功能提供什么支持。

必要时简要说明：时钟处理中重新设置下一次事件的作用，以及异常处理中根据指令长度调整epc的作用。不要展开为逐行代码解释。

【避免混淆】
- 写的是功能实现的逻辑顺序，不要直接照抄kern_init的运行顺序。
- 框架已有的初始化和中断开关机制，应作为支撑条件说明。
- 不要把sret一律写成“返回用户态”，应表述为返回Trap发生前相应的执行状态。
- 这份压缩包是老师提供的初始代码，不能据此声称我们已经完成实现、通过测试或观察到运行结果。
- 如指导书与代码存在差异，请指出与本节有关的差异，不要自行编造缺失接口或常量。

【输出要求】
直接给出可放入实验报告的正文，用4—5条编号表述。
每条采用“首先……／接着……／然后……／最后……”的自然表达，把“做什么”和“为什么”连贯地写在一起。
总字数控制在400—550字，语言清楚、具体、简洁，不贴代码，不重复介绍实验背景，不添加总结段。

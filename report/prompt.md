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

 [2410691]：
第一轮：提取要求
我负责 Lab 4 的“虚拟内存页操作”模块。请阅读指导手册中功能模块一的要求，以及当前框架的 pmm.c、`pmm.h`、`mmu.h`。暂时不要写代码。请列出需要实现的函数、可复用的接口、各函数的输入输出、边界情况和可验证的结果。不要套用其他版本 ucore 的实现。

第二轮：检查遗漏
检查刚才整理的要求是否覆盖以下情况：首次映射、映射到同一物理页、替换成另一物理页、删除未映射地址、重复删除，以及 get_pte 分配失败。逐项说明页表项、物理页引用计数和 
TLB 应如何变化；有不确定的地方请回到当前代码核对。

第三轮：生成最终提示词
请把确认后的要求整理成一份可以交给代码生成 AI 的完整提示词，分为 [TASK]、`[SPECIFICATION]`、`[RELY]`、`[CONSTRAINT]`、`[CHECK]`。限定只修改 pmm.c 中 LAB4 function1 YOUR CODE 的位置，将标记改为 //lab4-2410691。要求 AI 先核对接口，再实现代码，最后如实报告编译和测试结果；不能声称未运行的测试已经通过。







[2411191]:

在code/目录中完成《riscv64-ucore-lab4-guide.pdf》中的“功能模块三：进程调度”。以ZIP中已经修改过的代码为基础，先阅读现有接口、函数和测试，再在标有`LAB4 function3 YOUR CODE`的位置补齐实现。

源码改动限于以下三个文件：
- kern/process/proc.c：实现cpu_idle和proc_run。
- kern/schedule/sched.c：实现schedule。
- kern/process/switch.S：实现RV64汇编函数switch_to，文件扩展名使用仓库里的大写.S。

沿用现有的进程创建、唤醒、页表管理和线程首次运行流程。模块一、模块二和Challenge不在本次实现范围内。保留现有函数签名、结构体布局和测试脚本。

[RELY]
- kern/process/proc.h：struct proc_struct、struct context、PROC_RUNNABLE、le2proc，以及current、idleproc、proc_list。调度使用state、list_link、need_resched、runs；实际切换使用pgdir和context。
- libs/list.h：list_entry_t和list_next()。proc_list是带哨兵的循环双向链表。普通线程通过list_link挂入链表，idleproc不在链表中。
- kern/sync/sync.h：local_intr_save(flag)、local_intr_restore(flag)，用于保存并恢复进入临界区前的中断状态，支持嵌套使用。
- libs/riscv.h 和 kern/mm/pmm.h：write_csr()、SATP_MODE_SV39、RISCV_PGSHIFT、boot_pgdir_pa、flush_tlb()。参考kern/mm/pmm.c的enable_paging()构造RV64 Sv39的satp。当前代码用boot_pgdir_pa初始化proc->pgdir，该字段保存页表根的物理地址。
- 现有proc_init()已创建idleproc和initproc。copy_thread()已把新线程的context.ra设置为forkret，把context.sp设置为该线程的trapframe地址。首次运行沿forkret → forkrets → __trapret → kernel_thread_entry进入线程函数。
- schedule()和 proc_run()已有声明，proc.c中已有switch_to()声明。沿用这些接口。

[GUARANTEE]
实现并交付以下四个函数，直接修改解压后的源码：
1. kern/process/proc.c中的void cpu_idle(void)
2. kern/schedule/sched.c中的void schedule(void)
3. kern/process/proc.c中的void proc_run(struct proc_struct *proc)
4. kern/process/switch.S 中可供C代码链接的全局符号switch_to，对应void switch_to(struct context *from, struct context *to)

完成后说明修改了哪些文件。在具备RISC-V交叉工具链和QEMU的环境中，从code/运行 `make qemu` 和 `make grade`，报告实际观察到的结果。若无法运行，说明缺少的工具或实际遇到的错误，并标明哪些测试尚未验证。

[SPECIFICATION]
1. cpu_idle(void)
   - 按现有noreturn声明实现无限空闲循环。
   - 循环检查current->need_resched。标志为真时调用schedule()，从schedule()返回后继续循环。调度标志由schedule()清除。

2. schedule(void)
   - 先保存并关闭本地中断，再清除current->need_resched。
   - current == idleproc时，从proc_list的第一个真实节点开始查找。否则，从current->list_link的下一个节点开始，经过表尾后回绕到表头，当前线程最多作为最后一个候选。
   - 通过le2proc(node, list_link)取得候选线程，按遍历顺序选择第一个PROC_RUNNABLE。跳过链表哨兵，最多遍历一圈。链表为空或没有可运行线程时，选idleproc。
   - 对选中的线程执行一次runs++，即使选中的是current或idleproc。只有选中的线程与current不同，才调用proc_run(next)。
   - 查找、计数和发起切换都在关中断的临界区内。该次schedule()调用继续执行时，恢复这次调用保存的中断状态。选中当前线程、空链表等路径也要正确恢复。

3. proc_run(struct proc_struct *proc)
   - 如果proc == current，直接返回。
   - 对实际切换，先保存并关闭本地中断，再保存旧的current指针并将current更新为proc。
   - 用目标进程的页表根物理地址构造`((uintptr_t)SATP_MODE_SV39 << 60) | (proc->pgdir >> RISCV_PGSHIFT)`，通过write_csr(satp, ...)写入，然后调用flush_tlb()。禁止使用沿用Sv32格式的lsatp()。
   - 页表切换完成后，调用switch_to(&prev->context, &proc->context)。旧线程之后被调度回来、从这次switch_to调用继续执行时，恢复它在本次proc_run()中保存的中断状态。

4. switch_to(struct context *from, struct context *to)
   - 在.text段导出全局符号switch_to。按RV64调用约定，a0是from，a1是to。
   - 用sd把旧线程的ra、sp、s0至s11保存到from。按struct context的实际布局，ra的字节偏移是0，sp是8，s0至s11是16、24、…、104。
   - 用ld从to的对应偏移恢复同一组寄存器，再用ret跳转到恢复后的ra。首次运行的新线程由此进入forkret，已经运行过的线程从之前的切换调用处继续执行。
   - 此函数只保存和恢复寄存器上下文。中断状态、页表和调度选择由上层处理。

验收时，用`make qemu`确认initproc打印`this initproc, pid = 1, name = "init"` 和 `To U: "Hello world!!".`；用`make grade`检查`[Test Schedule] PASS`。评分脚本会检查两个测试线程都获得过执行机会。当前源码的do_exit()是会触发`process exit!!`的占位实现，如果问候信息打印后出现该提示，请如实记录，无需为此改写do_exit()。c:\Users\27566\Desktop\riscv64-ucore-lab4-guide.pdf


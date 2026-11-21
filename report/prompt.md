# AI 提示词汇总

## [2413330-张子馨] 功能模块二：进程创建及初始化

### 最终提示词

````markdown
[ROLE]
你是一名 RISC-V 64 位 ucore 内核开发者，需要在 kern/process/proc.c 中实现功能模块二：
进程创建及初始化。

[任务]
在 kern/process/proc.c 的 "//LAB4 function2 2413330" 标记处实现 alloc_proc、proc_init、
kernel_thread、do_fork、copy_thread、copy_mm 六个函数，不得修改标记外的其他函数，
不得修改函数签名。

[已知条件]
- struct proc_struct、struct context、struct trapframe 定义在 kern/process/proc.h；
  proc_list、hash_list、idleproc、initproc、current、nr_process 已声明。
- kern/process/entry.S 中的 kernel_thread_entry 约定 s0 存放函数入口、s1 存放参数；
  forkret、forkrets、__trapret 组成新线程首次运行的恢复链路。
- bootstack 是内核启动栈，boot_pgdir_pa 是内核页表物理地址。
- 可借助 kmalloc、kfree、alloc_pages、free_pages、page2kva、kva2page、get_pid、
  find_proc、set_proc_name、wakeup_proc、list_init、list_add、local_intr_save、
  local_intr_restore、read_csr 及 SSTATUS_SPP、SSTATUS_SPIE、SSTATUS_SIE。
- 本实验的内核线程共享内核地址空间，copy_mm 暂不复制地址空间。

[要求]
1. alloc_proc：用 kmalloc 分配 PCB，所有字段初始化为安全空白状态，state 为 PROC_UNINIT，
   context 清零，tf 为 NULL，pgdir 为 boot_pgdir_pa；分配失败返回 NULL。
2. proc_init：初始化 proc_list 和 hash_list；把当前执行现场包装成 idleproc，PID 为 0，
   kstack 为 bootstack，state 为 PROC_RUNNABLE，current 指向它；再用 kernel_thread
   创建 init_main 线程作为 initproc，PID 为 1，命名为 init。
3. kernel_thread：把 fn 和 arg 分别放入 trapframe 的 s0 和 s1；status 设置 SSTATUS_SPP
   和 SSTATUS_SPIE、清除 SSTATUS_SIE；epc 设为 kernel_thread_entry；调用 do_fork 并
   返回新线程 PID。
4. do_fork：依次完成 alloc_proc、设置 parent 为 current、setup_kstack、copy_mm、
   copy_thread；在 local_intr_save 和 local_intr_restore 保护的临界区内分配 PID，
   挂入 proc_list 和 hash_list，nr_process 加一，最后 wakeup_proc；任一步失败时按
   相反顺序释放资源并返回错误码。
5. copy_thread：在 proc 的内核栈顶安放 trapframe，context.ra 设为 forkret，
   context.sp 指向 trapframe，使新线程首次经 forkret、forkrets、__trapret 运行。
6. copy_mm：本阶段不复制地址空间，直接返回 0。

[约束]
- idleproc 不经过 do_fork，其 tf、flags、context.ra 必须保持为 0。
- 线程生命周期状态与资源挂接顺序必须一致，失败路径不得泄漏 PCB、内核栈或链表节点。
- kernel_thread 与 copy_thread 必须与 entry.S 中 s0 存函数、s1 存参数的约定一致。
- 测试要求 initproc 的 parent 为 idleproc，context.ra 和 context.sp 非零。
- 只修改标记处，不得修改框架测试和接口声明，不得硬编码测试数据。

[输出]
给出可直接替换标记处的 C 代码，注释使用中文；说明修改的文件、核心实现和验证结果；
执行 make 与 test_lab4_process_create 验证，不得声称未实际运行的测试通过。
````

### 过程与函数提问

## 1.
```text
怎么调试该功能模块实现正确？请说明可以查看 idleproc、initproc 哪些字段来判断创建是否成功，
以及 test_lab4_process_create 断言失败时，如何定位到 pid、kstack、parent、context.ra 等具体字段。
```

## 2.
```text
请结合 kern/process/proc.c、kern/process/entry.S 和 kern/trap/trapentry.S，说明 kernel_thread
为什么把 fn 和 arg 放进 trapframe 的 s0、s1，kernel_thread_entry 又是怎样使用这两个寄存器的。
请给出对应代码，并解释 s0、s1 在 RISC-V 调用约定中的作用。
```

## 3.
```text
请解释 struct context 和 struct trapframe 的区别：两者各自保存哪些寄存器、由谁保存和恢复，
为什么 copy_thread 要把 trapframe 复制到新线程内核栈顶，而 context.sp 又指向这个 trapframe。
```

## 4.
```text
请按执行顺序说明 initproc 从 do_fork 返回到第一次真正运行的过程：do_fork、copy_thread、
wakeup_proc、schedule、proc_run、switch_to、forkret、forkrets、__trapret 各自完成什么。
重点说明新线程的 context.ra 为什么设为 forkret，以及 switch_to 的 ret 如何接到 forkret。
```

## 5.
```text
proc_init 中 idleproc 为什么不调用 do_fork，而是直接复用当前执行现场？请说明它的 pid、kstack、
tf 和 context.ra 为什么取这些值，以及 current 指向 idleproc 之后 cpu_idle 是如何工作的。
```

## 6.
```text
do_fork 为什么要在 local_intr_save 和 local_intr_restore 之间分配 PID 并挂入 proc_list 和
hash_list？如果去掉这段临界区，可能出现什么问题？请结合 get_pid、list_add 和 wakeup_proc
的实际代码说明。
```
 [2410691]：
第一轮：提取要求
我负责 Lab 4 的“虚拟内存页操作”模块。请阅读指导手册中功能模块一的要求，以及当前框架的 pmm.c、`pmm.h`、`mmu.h`。暂时不要写代码。请列出需要实现的函数、可复用的接口、各函数的输入输出、边界情况和可验证的结果。不要套用其他版本 ucore 的实现。

第二轮：检查遗漏
检查刚才整理的要求是否覆盖以下情况：首次映射、映射到同一物理页、替换成另一物理页、删除未映射地址、重复删除，以及 get_pte 分配失败。逐项说明页表项、物理页引用计数和 
TLB 应如何变化；有不确定的地方请回到当前代码核对。

第三轮：生成最终提示词
请把确认后的要求整理成一份可以交给代码生成 AI 的完整提示词，分为 [TASK]、`[SPECIFICATION]`、`[RELY]`、`[CONSTRAINT]`、`[CHECK]`。限定只修改 pmm.c 中 LAB4 function1 YOUR CODE 的位置，将标记改为 //lab4-2410691。要求 AI 先核对接口，再实现代码，最后如实报告编译和测试结果；不能声称未运行的测试已经通过。

## [2411191-王可] 功能模块三：进程调度

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


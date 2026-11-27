# AI 提示词汇总

## [2413330-张子馨] 功能模块一：用户态系统调用功能

### 最终提示词

````markdown
[ROLE]
你是一名 RISC-V 64 位 ucore 内核开发者，需要在 kern/trap/trap.c 和 kern/syscall/syscall.c
中实现 Lab 5 功能模块一：用户态系统调用功能。

[任务]
只修改 kern/trap/trap.c 的 exception_handler() 和 kern/syscall/syscall.c 中标有
"//lab5 function1 YOUR CODE" 的位置，保留原有注释，不得修改函数签名，不得实现其他功能模块。

[已知条件]
- struct trapframe 定义在 kern/trap/trap.h：gpr.a0 保存系统调用号，gpr.a1~a5 保存参数，
  epc 为陷入地址，cause 为异常原因。
- user/libs/syscall.c 的封装约定：a0 放编号，a1~a5 放参数，ecall 后从 a0 取返回值。
- 系统调用号与 NUM_SYSCALLS 定义在 libs/unistd.h，syscalls[] 分发表位于 syscall.c。
- do_exit、do_fork、do_wait、do_execve、do_yield、do_kill 声明在 kern/process/proc.h。
- user_mem_check(mm, addr, len, write) 声明在 kern/mm/vmm.h；cputchar 用于字符输出。
- current->tf 指向当前进程的 trapframe；E_INVAL 定义在 libs/error.h。

[要求]
1. exception_handler 增加 CAUSE_USER_ECALL 分支：调用 syscall() 后执行 tf->epc += 4。
2. syscall 从 current->tf 读取 a0 作为编号、a1~a5 作为参数；编号必须满足
   0 < num < NUM_SYSCALLS 且 syscalls[num] != NULL，否则向 a0 写入 -E_INVAL。
3. 合法调用时把 syscalls[num] 的返回值写回 tf->gpr.a0。
4. sys_exit 转调 do_exit；sys_fork 以 tf->gpr.sp 和 current->tf 转调 do_fork(0, stack, tf)。
5. sys_wait 的 code_store 非空时按可写检查；sys_exec 的 name、binary 按只读检查；
   检查失败返回 -E_INVAL，通过后分别转调 do_wait、do_execve。
6. sys_yield、sys_kill 分别转调 do_yield、do_kill；sys_getpid 返回 current->pid；
   sys_putc 调用 cputchar 后返回 0；sys_pgdir 在框架未提供 print_pgdir 时直接返回 0。

[约束]
- syscalls[] 数组位于函数定义之前，必须在数组前补 static 前向声明，并包含 <vmm.h>、<error.h>。
- 不修改系统调用编号和参数顺序，不信任任何用户指针。
- 只修改标记处，不得修改框架测试和接口声明，不得硬编码测试数据。

[输出]
给出可直接替换标记处的 C 代码，注释使用中文；说明修改的文件和核心实现；
执行 make 与 test_lab5_syscall 验证，不得声称未实际运行的测试通过。
````

### 过程与函数提问

## 1.
```text
请阅读 kern/trap/trap.h、libs/unistd.h 和 user/libs/syscall.c，说明系统调用号与参数
在用户态封装、trapframe、内核分发表三处是如何对应的。a0 与 a1~a5 分别承担什么角色，
syscall() 应该从哪里取参、把返回值写回哪里？
```

## 2.
```text
请检查 syscalls[] 分发表的下标范围与 NUM_SYSCALLS 的关系。系统调用号为 0、超过表长、
以及表项为 NULL 这三种情况分别会怎样？为什么边界判断必须同时检查 num > 0、
num < NUM_SYSCALLS 和 syscalls[num] != NULL？
```

## 3.
```text
sys_wait 的 code_store 和 sys_exec 的 name、binary 都是用户指针。请结合
user_mem_check(mm, addr, len, write) 的签名说明：哪些参数按可写检查、哪些按只读检查，
检查失败应该返回什么错误码，为什么不能直接在内核中解引用这些指针。
```

## 4.
```text
exception_handler 识别到 CAUSE_USER_ECALL 后为什么要执行 tf->epc += 4？
如果不前移 epc，sret 返回用户态后会发生什么？ecall 是否可能是 2 字节压缩指令，
是否需要像 ebreak 那样用 instr_length() 判断长度？
```

## 5.
```text
sys_pgdir 按语义应调用 print_pgdir()，但当前框架只在 kern/mm/pmm.h 中声明、没有实现。
请确认其他功能模块是否提供该函数，并说明在不实现 print_pgdir 的前提下 sys_pgdir
直接返回 0 是否影响 tools/grade.sh 中 pgdir 用例的检查。
```

## [2411191-王可] 功能模块二：创建加载第一个用户进程功能

### 最终提示词

````markdown

[PROMPT]

你正在VS Code终端agent环境中协助我完成RISC-V64 ucore Lab5。

实验指导书已经提供。当前工作区是实验代码，功能模块一已经实现。本次任务是按照指导书完成功能模块二：“创建加载第一个用户进程功能”。

请先阅读指导书中功能模块二、“用户进程管理”和“第一次进入用户态”的相关内容，再检查当前代码，然后直接进行修改，不要只给出示例代码或实现建议。

目标调用链为：
proc_init
→ kernel_thread(init_main)
→ init_main
→ kernel_thread(user_main)
→ user_main
→ kernel_execve
→ do_execve
→ load_icode
→ __trapret
→ sret
→ 用户程序入口。

父进程通过do_wait等待并回收退出的子进程。

修改以kern/process/proc.c 为主，保留功能模块一的已有实现、函数接口、实验标记和项目风格。不要重复定义已有函数，不要直接套用其他版本ucore的代码。

本次不实现功能模块三、四、COW或双重GDB分支任务，也不自动提交或推送仓库。

开始修改前，检查模块二的前置依赖：
1. 区分真正已有实现、仅有函数声明和留空占位的函数。
2. 对proc_init、copy_thread等缺失的Lab4基础功能，允许补齐本模块必需的最小实现，并在最终说明中单独列出。
3. 对do_fork、copy_mm等模块三函数，以及do_exit等模块四函数，如尚未实现，应明确记录为跨模块依赖，不要擅自完成，也不要用空函数、固定成功返回值或注释掉调用的方式绕过。
4. 即使完整运行被其他模块阻塞，也应先完成本次模块二中能够独立完成的实现和检查，再准确报告剩余阻塞。


[RELY]

所有接口、字段、宏和调用约定以当前工作区的实际代码为准。指导书用于确定实验目标；其中旧版本代码、说明性示例不能替代当前仓库的接口定义。

重点阅读：

1. 进程及调度
- kern/process/proc.c
- kern/process/proc.h
- kern/process/entry.S
- kern/process/switch.S
- kern/schedule/sched.c
- kern/sync/sync.h

可使用current、idleproc、initproc、proc_list、hash_list，
以及 setup_kstack、put_kstack、setup_pgdir、put_pgdir、
get_pid、hash_proc、unhash_proc、set_links、remove_links、
set_proc_name、find_proc、wakeup_proc、schedule等已有辅助接口。

2. 虚拟内存
- kern/mm/vmm.c、vmm.h
- kern/mm/pmm.c、pmm.h
- kern/mm/memlayout.h、mmu.h

可使用mm_create、mm_map、exit_mmap、mm_destroy、
mm_count_inc、mm_count_dec、pgdir_alloc_page、
page2kva、PADDR、user_mem_check等实际存在的接口。

注意区分：
- mm->pgdir所使用的内核虚拟地址；
- proc->pgdir所保存的页表物理地址；
- satp 所需的页表页号和模式位。

3. ELF与异常返回
- libs/elf.h
- libs/riscv.h
- kern/trap/trap.h
- kern/trap/trapentry.S

使用仓库定义的elfhdr、proghdr、trapframe、
ELF_PT_LOAD、ELF_PF_R/W/X、
SSTATUS_SPP、SSTATUS_SPIE、SSTATUS_SIE、
PTE_U、PTE_R/W/X/V等。

异常返回已有__trapret、forkrets等入口，应检查其真实行为后复用。
内核线程入口kernel_thread_entry使用哪些寄存器传递fn和arg，
必须以当前entry.S为准。

4. 用户程序及构建
- user/hello.c、user/exit.c、user/testbss.c
- user/libs/initcode.S、ulib.c、syscall.c
- Makefile
- tools/user.ld
- tools/test_lab5.c、inject.py、grade.sh

复用现有KERNEL_EXECVE、KERNEL_EXECVE2宏和用户程序二进制符号。
保留Makefile中TEST、TESTSTART、TESTSIZE的测试程序选择机制。

注意：wait()的用户库封装传入 pid=0。
不能根据现有注释中“pid=-1 表示任意子进程”的说法，
擅自改成Linux的waitpid约定。


[GUARANTEE]

按指导书实现或完善kern/process/proc.c中以下8个函数，保持签名：

1. static int init_main(void *arg)
2. static struct proc_struct *alloc_proc(void)
3. int kernel_thread(int (*fn)(void *), void *arg,
                     uint32_t clone_flags)
4. int do_wait(int pid, int *code_store)
5. static int user_main(void *arg)
6. static int kernel_execve(const char *name,
                            unsigned char *binary, size_t size)
7. int do_execve(const char *name, size_t len,
                 unsigned char *binary, size_t size)
8. static int load_icode(unsigned char *binary, size_t size)

必要时增加局部辅助函数和前置声明。

保留lab5 function2等实验注释。学号标注沿用项目中已经填写的学号；
如果无法确定，应保留待填写标记，不要编造。

完成后交付：
- 实际代码修改；
- 修改文件和函数清单；
- 启动、装载、进入用户态和等待回收的调用链说明；
- 实际执行的检查命令及结果；
- 尚未完成的跨模块依赖和环境限制。

不能把“代码已填写”“编译通过”“用户态运行通过”
和“整个 Lab5 通过”混为一谈。


[SPECIFICATION]

1. alloc_proc

- 分配失败返回NULL。
- 保留Lab4已有字段的正确初始化。
- 初始化Lab5新增的exit_code、wait_state、cptr、yptr、optr。
- 初始化需要初始化的链表节点，避免未初始化字段进入进程管理逻辑。
- 新进程应处于PROC_UNINIT，尚未分配有效PID、用户地址空间或内核栈。
- 页表字段沿用当前工程的启动页表表示方式。

2. kernel_thread

- 构造并清零临时trapframe。
- 按 kernel_thread_entry 的寄存器约定设置fn和arg。
- 设置内核线程入口地址和适合返回S模式的状态位。
- 正确设置SPP、SPIE和SIE，不能使新内核线程误入U模式。
- 通过do_fork 创建线程，保留传入clone_flags，并按工程约定添加CLONE_VM。
- 返回创建结果，不吞掉错误。

3. init_main

- 通过kernel_thread创建执行user_main的子线程，检查创建结果。
- 循环调用do_wait(0, NULL)，等待并回收所有子进程，包括后续交由initproc收养的子进程。
- 不应把一次被唤醒或一次等待返回当成全部子进程结束。
- 子进程全部回收后，按照项目测试要求输出结束信息并检查进程、链表及内存状态。
- 若进行空闲页数量检查，应选择一致的统计时点，并考虑当前工程实际存在的持久分配。
- initproc不应通过正常返回意外进入do_exit。

4. user_main

- 存在TEST等测试宏时，通过KERNEL_EXECVE2选择对应二进制。
- 普通构建可默认选择hello，便于首先验证基础装载和用户态输出。
- 不要把某个用户程序硬编码到所有构建路径。
- exec成功后不应继续执行原来的内核线程业务；失败路径应明确处理或报告错误。

5. kernel_execve

- 内核线程已经运行于S模式，不能照搬用户态ecall包装来发起首次exec。
- 调用do_execve完成程序映像准备后，必须真正接入异常返回路径。
- 成功路径应使sp指向有效的目标trapframe，再转入__trapret，或使用当前工程等价的forkrets入口，最终执行sret。
- 成功后不应作为普通C函数返回user_main。
- trapframe的准备位置及切换过程必须安全：不能覆盖当前仍在使用的C调用栈帧、返回地址或局部变量。
- 处理好current->tf、内核栈和失败返回路径的关系。
- 如使用内联汇编，应正确声明约束、寄存器和memory clobber，不能依赖优化器偶然生成正确代码。
- 优先复用现有返回入口，不额外修改模块一的异常分发逻辑。

6. do_execve

- 正确处理程序名及长度；设置进程名前先保存为有界且以零结尾的内核缓冲区，不能假设用户字符串已经终止。
- 区分内核启动路径中的可信内核指针与用户态传入的指针；用户指针须按当前工程接口进行检查。
- 在释放旧mm前，保证后续仍要读取的name和binary数据仍然有效。
- 特别注意：仅通过user_mem_check，并不能保证释放旧mm后binary仍可访问。
- 对来自旧用户地址空间的ELF数据，应在销毁旧映像前安全保存，或采用等价且明确说明的有效生命周期方案。
- 当前进程有旧mm时，先切换到安全的内核页表，再按引用计数释放旧地址空间。
- 仅在旧mm引用计数归零时销毁它，并正确更新current->mm 和 current->pgdir。
- 调用load_icode装载新映像，成功后更新进程名。
- 明确处理装载失败：
  旧映像仍有效时可以返回错误；
  旧映像已销毁时不得返回原用户程序继续执行，应按项目约定进入失败退出路径。
- 释放错误路径中的临时缓冲区，避免泄漏和重复释放。
- 如失败退出依赖未完成的模块四，应如实标注依赖，不能以无限循环或伪造成功替代。

7. load_icode

- 建立新mm和页表，保留必要的内核映射。
- 检查ELF魔数、头部和程序头表是否位于binary的size范围内。
- 使用仓库实际定义的ELF字段。
- 检查p_filesz <= p_memsz，以及文件偏移、段地址和长度计算是否越界或溢出。
- 只装载ELF_PT_LOAD段；正确处理空段、非页对齐边界和跨页复制。
- 根据ELF段属性建立VMA，并设置合法的RISC-V用户页权限；不能把所有段统一设成可写可执行。
- 正确分配页面、复制文件内容，并清零BSS，即p_memsz超出p_filesz的部分。
- 避免重复清零或重复映射导致同页已有段内容被破坏。
- 在[USTACKTOP-USTACKSIZE, USTACKTOP)建立用户栈VMA，按工程约定提供可用的栈页并保留栈保护语义。
- 栈指针使用工程定义的USTACKTOP，并满足ABI对齐要求。
- 正确关联mm、页表和当前进程，设置引用计数、satp，并执行必要的TLB和指令缓存同步。
- 清零并设置目标trapframe：
  epc = ELF 入口；
  gpr.sp = 用户栈顶；
  SPP清零，返回 U 模式；
  SPIE按约定置位；
  SIE在恢复过程中保持关闭。
- 失败时回收已经建立的用户映射、页表、VMA和mm，避免泄漏或留下部分提交的进程状态。

8. do_wait

- pid=0：等待任意一个直接子进程。
- pid>0：仅等待指定的直接子进程，不能回收无亲子关系的进程。
- 其他pid按当前工程约定返回错误；无匹配子进程时返回-E_BAD_PROC。
- code_store非NULL时，检查目标地址可写，不能直接信任用户指针。
- 找到僵尸子进程后，保存退出码，从PID哈希表和进程关系中摘除，再释放其内核栈和PCB。
- 只能回收一次，不能在kfree后继续访问该进程。
- 有匹配子进程但尚未退出时，将当前进程设置为PROC_SLEEPING、WT_CHILD，再调用schedule。
- 扫描子进程、设置等待状态和回收操作应正确配合临界区，避免丢失唤醒。
- 被唤醒后重新检查条件。
- 正确处理PF_EXITING等待中断情形，并与do_exit的父进程唤醒约定一致。

9. 异常返回衔接

- 检查已有SAVE_ALL、RESTORE_ALL是否满足：
  内核运行时sscratch=0；
  返回用户态前sscratch保存有效内核栈顶；
  用户态陷入时能够切换到内核栈。
- 首次用户态启动与后续用户态系统调用都应使用一致的 trapframe 布局。
- 已有实现正确时直接复用；确有问题时才做最小修复，并说明原因。

10. 验证

- 先确认实际构建目录、工具链、QEMU和构建目标。
- 执行可用的编译和静态检查。
- 依赖齐全时，优先使用hello验证：
  用户程序入口可达；
  确实运行于 U 模式；
  用户态系统调用输出可以返回并继续执行。
- 再使用 testbss 检查数据段与 BSS；相关依赖完成后使用exit验证等待和回收。
- 完整make grade包含模块三、四以及其他异常处理的测试。依赖未完成时，不能把完整评分通过作为本次已达成的结果。
- 不修改评分脚本、删除断言或伪造 PASS 输出来获得通过。
- 若因环境或跨模块缺失无法运行，列出具体命令、错误和阻塞函数，明确哪些行为只完成了代码检查、尚未运行验证。

最后用中文说明实现结果，重点解释：
为什么kernel_execve 不能只调用do_execve，
以及用户栈、内核栈、trapframe、sscratch和sret
如何共同完成第一次进入用户态。
````

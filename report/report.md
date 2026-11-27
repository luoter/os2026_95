# 操作系统实验报告

## 实验基本信息

| 项目       | 内容                                 |
| -------- | ---------------------------------- |
| **实验名称** | Lab5 : \[用户程序]                  |
| **小组成员** | 2413330-张子馨、2410691-刘思岑、2411191-王可 |
| **完成日期** | 2026-11-28                         |

### 小组分工

| 成员          | 负责的模块                |
| ----------- | -------------------- |
| 2413330-张子馨 | 功能模块一 |
| 2410691-刘思岑 | 功能模块三和四 |
| 2411191-王可  | 功能模块二 |

---

## 一、实验目的



本实验的主要目的是：

1. 了解第一个用户进程创建过程
2. 了解系统调用框架的实现机制
3. 了解ucore如何实现系统调用sys_fork/sys_exec/sys_exit/sys_wait来进行进程管理

---

## 二、实验环境



| 成员 | AI 编程工具 | 底层模型 | 备注 |
|------|------------|---------|------|
| 2413330-张子馨| Cline（VS Code插件）|  DeepSeek-V4-Flash和DeepSeek-V4-pro| 勾选了计划和执行时使用不同的模型 |
| 2410691-刘思岑|Codex(VS Code插件)|ChatGPT-5.6 Sol| 无
| 2411191-王可| Codex（终端Agent）|GPT-6.1-Sol| 使用WSL环境运行Codex终端Agent|



---

## 三、实验整体逻辑分析

### 2.1 本章节的逻辑主线

- 核心主题：在实验四内核线程的基础上，让程序第一次离开内核态、进入用户态运行，围绕“用户态如何获得内核服务”以及“用户进程如何被创建、复制与终止”展开，把 ucore 从只能运行内核线程推进到能够装载、调度和管理用户程序的阶段。

- 解决的问题：让用户程序真正运行在用户态，并在需要操作系统支持时通过系统调用进入内核获得服务。为此需要建立系统调用的入口与分发机制，创建并装载第一个用户进程，支持用户进程的复制，并实现退出、让出和终止等进程控制功能，从而形成“用户态发起请求—内核处理—返回用户态继续执行”的完整链路。

### 2.2 功能的逐步实现

本实验按照系统调用接入、首个用户进程启动、用户进程复制、进程退出控制四条主线推进，执行链可概括为 ecall 进入 exception_handler 到 syscall 分发到 sys_* 落地，再由 kernel_execve 与 load_icode 装载第一个用户程序，do_fork 派生新进程，最后由 do_exit、do_yield、do_kill 完成收尾。

1. 首先实现**用户态系统调用功能**（exception_handler、syscall 与各 sys_*）→ 系统调用是用户态进入内核的唯一入口，只有先打通 ecall 异常的分发与系统调用号到内核语义的映射，后续的用户进程才有获得内核服务的手段。
2. 接着完成**第一个用户进程的创建与加载**（proc_init、init_main、user_main、kernel_execve、do_execve、load_icode）→ 有了系统调用入口后，需要把执行流真正从内核线程送入用户态，通过解析 ELF、替换地址空间、创建用户栈和 trapframe，让 CPU 首次从用户程序入口开始执行。
3. 然后实现**用户进程复制**（do_fork、copy_mm、dup_mmap、copy_range）→ 第一个进程跑起来之后必须能够派生新进程，按 vma 和页粒度复制父进程的用户地址空间，使子进程在继承父进程的同时拥有独立的执行实体。
4. 最后补充**退出、让出与终止**（do_exit、do_yield、do_kill，配合 do_wait）→ 进程生命周期还缺少收尾环节，只有完成资源回收、重新调度和终止通知，并与父进程等待配合，才能形成完整闭环。

---

## 四、实验内容与实现

<!-- 
说明：本部分按照 exercises 文档中的练习顺序组织
每个功能模块或者练习中可能包含多项任务，请根据实际情况调整
-->

### 功能模块一：用户态系统调用功能

**负责人：** 2413330-张子馨

#### 模块功能描述

**需要实现/修改的函数：**

```c
// kern/trap/trap.c
void exception_handler(struct trapframe *tf);

// kern/syscall/syscall.c
void syscall(void);
static int sys_exit(uint64_t arg[]);
static int sys_fork(uint64_t arg[]);
static int sys_wait(uint64_t arg[]);
static int sys_exec(uint64_t arg[]);
static int sys_yield(uint64_t arg[]);
static int sys_kill(uint64_t arg[]);
static int sys_getpid(uint64_t arg[]);
static int sys_putc(uint64_t arg[]);
static int sys_pgdir(uint64_t arg[]);
```

**功能说明：**

本模块负责把用户态通过 `ecall` 发起的请求接入内核，并把处理结果写回用户可见的寄存器，是用户程序获得内核服务的第一道入口。

- 在系统中的作用：`exception_handler` 只额外关注 `CAUSE_USER_ECALL`，识别后调用 `syscall` 并把 `epc` 前移 4 字节，避免返回后重复执行同一条 `ecall`；`syscall` 按 `a0` 中的系统调用号查表分发，`a1~a5` 组成参数数组；各 `sys_*` 再把统一编号翻译成具体内核语义，最终调用 `do_exit`、`do_fork`、`do_wait`、`do_execve`、`do_yield`、`do_kill` 或直接读写内核资源。
- 主要场景：`sys_getpid`、`sys_putc` 直接返回或在控制台输出；`sys_fork` 以当前 `trapframe` 和用户栈指针复制子进程；`sys_wait` 与 `sys_exec` 需要先用 `user_mem_check` 检查用户指针；编号越界或对应表项为空时按 `-E_INVAL` 处理。
- 与其他模块的交互：向下依赖模块二至四提供的 `do_*` 进程管理函数；向上与 `user/libs/syscall.c` 的封装约定保持一致（`a0` 放编号，`a1~a5` 放参数，返回值写回 `a0`）；`current->tf` 是取参与写回结果的唯一来源。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown

请完成 Lab 5 功能模块一：用户态系统调用功能。只修改 `kern/trap/trap.c` 和 `kern/syscall/syscall.c` 中标有 `lab5 function1` 的位置，保留原有注释，不要实现其他功能模块。

[RELY]
- `struct trapframe` 见 `kern/trap/trap.h`：`gpr.a0` 为系统调用号，`gpr.a1~a5` 为参数，`epc` 为陷入地址，`cause` 为异常原因。
- 用户态封装见 `user/libs/syscall.c`：先 `ld a0, num`，再 `ld a1~a5` 放参数，`ecall` 后从 `a0` 取返回值。
- 内核语义入口为 `do_exit`、`do_fork`、`do_wait`、`do_execve`、`do_yield`、`do_kill`，声明在 `kern/process/proc.h`。
- 用户指针检查用 `user_mem_check(mm, addr, len, write)`，声明在 `kern/mm/vmm.h`；字符输出用 `cputchar`。

[SPECIFICATION]
1. `exception_handler` 增加 `CAUSE_USER_ECALL` 分支：调用 `syscall()`，然后执行 `tf->epc += 4`。
2. `syscall` 从 `current->tf` 读取编号与参数；编号必须满足 `0 < num < NUM_SYSCALLS` 且 `syscalls[num] != NULL`，否则向 `a0` 写入 `-E_INVAL` 并打印提示。
3. 合法调用时把返回值写回 `tf->gpr.a0`。
4. `sys_fork` 传 `do_fork(0, tf->gpr.sp, current->tf)`；`sys_wait` 的 `code_store` 非空时必须按可写检查；`sys_exec` 的 `name` 与 `binary` 必须按只读检查，失败返回 `-E_INVAL`。
5. `sys_putc` 返回 0，`sys_getpid` 返回 `current->pid`；`sys_pgdir` 在框架未提供 `print_pgdir` 实现时直接返回 0。

[CONSTRAINT]
- `syscalls[]` 数组位于函数定义之前，必须在数组前补 `static` 前向声明，并包含 `<vmm.h>`、`<error.h>`。
- 不修改系统调用号和参数顺序；不信任任何用户指针；保留 `lab5 function1` 注释。

````

#### 实现迭代过程

本模块的实现经历了 2 次迭代，过程如下：

---

##### 第一次迭代

**遇到的问题：**
- 问题1：`syscalls[]` 数组在函数定义之前引用 `sys_exit` 等符号，编译报 `undeclared here (not in a function)`。
- 问题2：`sys_wait`/`sys_exec` 中的 `user_mem_check` 与 `E_INVAL` 未声明，编译报隐式声明和未定义错误。

**问题解决策略：**
- 针对问题1：在数组前补充 `static` 函数原型，保持原有 `lab5 function1` 注释位置不变。
- 针对问题2：补充 `<vmm.h>` 和 `<error.h>`，并在提示词的 `[RELY]` 中列出可借助接口的声明位置。

**最终结果：**

经过 2 次迭代，该模块最终：
- ✅ `trap.c` 与 `syscall.c` 编译通过
- ⏳ 完整内核链接与 qemu 运行需在模块二至四补齐 `do_fork`、`do_wait`、`do_execve`、`do_exit`、`do_yield`、`do_kill`、`proc_init` 后统一验证
- ✅ `test_lab5_syscall` 关注的 `epc += 4`、`getpid` 返回值写回、非法编号返回 `-E_INVAL` 均已按约定实现

**关键改进点总结：**
1. 在 `[SPECIFICATION]` 中明确 `a0` 为编号、`a1~a5` 为参数、返回值写回 `a0` 的约定。
2. 明确 `ecall` 长度固定为 4 字节，必须前移 `epc`。
3. 明确所有用户指针先经 `user_mem_check` 检查，非法编号统一返回 `-E_INVAL`。


---

##### 第二次迭代（如有）

[按照和第一次迭代相同的格式]

---

##### 第三次迭代（如有）

[按照和第一次迭代相同的格式]

---

### 功能模块二：创建加载第一个用户进程功能

**负责人：** 2411191-王可

#### 模块功能描述

**需要实现/修改的函数：**

```c
static int init_main(void *arg);
static struct proc_struct *alloc_proc(void);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
int do_wait(int pid, int *code_store);
static int user_main(void *arg);
static int kernel_execve(const char *name, unsigned char *binary, size_t size);
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size);
static int load_icode(unsigned char *binary, size_t size);
void proc_init(void);
static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);
```

**功能说明：**

系统作用：建立从内核线程到第一个用户进程的启动流程，完成ELF装载、用户地址空间和执行上下文初始化，并通过异常返回进入用户态。
主要场景：处理启动程序选择、地址空间替换、代码与数据段装载、BSS清零、用户栈建立，以及父进程等待和回收退出的子进程；同时检查非法参数并清理装载失败时分配的资源。
模块交互：依赖进程创建与调度模块建立、运行线程；调用内存管理接口建立页表和用户映射；复用`forkrets → __trapret → sret`完成特权级切换；通过`do_wait`与退出模块的僵尸状态和父进程唤醒机制配合完成回收。


#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

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

#### 实现迭代过程

本模块的实现经历了 [0] 次迭代。

**最终结果：**

经过 [0] 次迭代，该模块最终：
- ✅ 编译通过
- ✅ 所有相关测试通过
- ✅ 功能符合预期


---



### 功能模块三：复制用户进程功能

**负责人：** 2410691-刘思岑

#### 模块功能描述

**需要实现/修改的函数：**

```c
// 列出本模块涉及的所有函数签名
void example_function(void);
int another_function(int arg);
```

**功能说明：**

[简要描述该模块的功能，包括：
- 该模块在整个系统中的作用
- 需要处理的主要场景
- 与其他模块的交互关系]

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown

[按照提示词模板，给出具体的提示词]

````

#### 实现迭代过程

本模块的实现经历了 [N] 次迭代，过程如下：

---

##### 第一次迭代

如果设计的prompt生成代码后出现问题：

**遇到的问题：**
- 问题1：问题描述、错误信息和原因分析
- 问题2：问题描述、错误信息和原因分析

**问题解决策略：**
- 针对问题1：[说明如何修改提示词]
- 针对问题2：[说明如何修改提示词]

如果没有问题：

**最终结果：**

经过 [N] 次迭代，该模块最终：
- ✅ 编译通过
- ✅ 所有相关测试通过
- ✅ 功能符合预期

**关键改进点总结（如有）：**
1. [改进点1：例如，在 [RELY] 中补充了完整的系统调用号定义]
2. [改进点2：例如，在 [SPECIFICATION] 中明确了异常处理的边界条件]
3. [改进点3：例如，增加了对用户指针合法性检查的要求]

---

##### 第二次迭代（如有）

[按照和第一次迭代相同的格式]

---

##### 第三次迭代（如有）

[按照和第一次迭代相同的格式]

---

### 功能模块四：其余系统调用功能

**负责人：** 2410691-刘思岑

#### 模块功能描述

**需要实现/修改的函数：**

```c
// 列出本模块涉及的所有函数签名
void example_function(void);
int another_function(int arg);
```

**功能说明：**

[简要描述该模块的功能，包括：
- 该模块在整个系统中的作用
- 需要处理的主要场景
- 与其他模块的交互关系]

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown

[按照提示词模板，给出具体的提示词]

````

#### 实现迭代过程

本模块的实现经历了 [N] 次迭代，过程如下：

---

##### 第一次迭代

如果设计的prompt生成代码后出现问题：

**遇到的问题：**
- 问题1：问题描述、错误信息和原因分析
- 问题2：问题描述、错误信息和原因分析

**问题解决策略：**
- 针对问题1：[说明如何修改提示词]
- 针对问题2：[说明如何修改提示词]

如果没有问题：

**最终结果：**

经过 [N] 次迭代，该模块最终：
- ✅ 编译通过
- ✅ 所有相关测试通过
- ✅ 功能符合预期

**关键改进点总结（如有）：**
1. [改进点1：例如，在 [RELY] 中补充了完整的系统调用号定义]
2. [改进点2：例如，在 [SPECIFICATION] 中明确了异常处理的边界条件]
3. [改进点3：例如，增加了对用户指针合法性检查的要求]

---

##### 第二次迭代（如有）

[按照和第一次迭代相同的格式]

---

##### 第三次迭代（如有）

[按照和第一次迭代相同的格式]

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

1. 本实验的重要知识点及其与 OS 原理的对应关系：
   - 系统调用与特权级切换：ucore 通过 `ecall` 触发异常，经 `exception_handler` 交给 `syscall` 按系统调用号分发，再由 `sys_*` 落到内核语义。对应 OS 原理中的“用户态/内核态转换与陷阱机制”，二者都依靠硬件的中断/异常入口完成受控切换；差异在于本实验只处理 `CAUSE_USER_ECALL` 这一类异常，逻辑是教学简化版。
   - 用户进程创建与 ELF 装载：`kernel_execve`、`do_execve`、`load_icode` 负责回收旧地址空间、解析 ELF、建立新映射、创建用户栈并设置 trapframe。对应原理中的“程序装入与地址空间建立”；本实验在装载时一次性完成映射，没有实现按需分页。
   - 进程复制：`do_fork`、`copy_mm`、`dup_mmap`、`copy_range` 按 vma 和页粒度复制父进程的用户地址空间。对应原理中的 `fork` 与地址空间隔离；本实验采用直接复制，而非写时复制（COW）。
   - 进程退出、让出与终止：`do_exit` 释放资源并转入僵尸态、`do_yield` 触发重新调度、`do_kill` 终止目标进程，与 `do_wait` 配合完成回收。对应原理中的进程生命周期与父子进程回收机制。
2. OS 原理中重要但本实验未覆盖的内容：文件系统与持久化存储、设备驱动与完整的 I/O 管理、缺页异常驱动的按需分页与页面置换、多核调度与并发同步、死锁处理、网络协议栈，以及用户权限与安全隔离等。

### AI 协作开发的经验

在本次实验中，我们体会到提示词要明确函数接口、修改范围和预期行为，AI 才能生成可用的代码；系统调用链路跨越用户库、异常入口和内核处理多个层次，AI 可以帮助梳理调用关系和补全样板代码，但 trapframe 布局、地址空间切换和资源回收等关键点仍需我们对照手册自行核对。遇到编译错误或 QEMU 运行异常时，把完整报错和上下文反馈给 AI 再迭代，比一次性给出大段需求更有效。

---

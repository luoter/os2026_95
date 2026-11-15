# 操作系统实验报告

## 实验基本信息

| 项目       | 内容                                 |
| -------- | ---------------------------------- |
| **实验名称** | Lab4 : \[进程管理]                  |
| **小组成员** | 2413330-张子馨、2410691-刘思岑、2411191-王可 |
| **完成日期** | 2026-11-15                         |

### 小组分工

| 成员          | 负责的模块                |
| ----------- | -------------------- |
| 2413330-张子馨 | 功能模块二 |
| 2410691-刘思岑 | 功能模块一 |
| 2411191-王可  | 功能模块三和扩展练习 |

---

## 一、实验目的



本实验的主要目的是：

1. 了解虚拟内存管理的基本结构，掌握虚拟内存的组织与管理方式
2. 了解内核线程创建/执行的管理过程
3. 了解内核线程的切换和基本调度过程

---

## 二、实验环境



| 成员 | AI 编程工具 | 底层模型 | 备注 |
|------|------------|---------|------|
| 2413330-张子馨| Cline（VS Code插件）|  DeepSeek-V4-Flash和DeepSeek-V4-pro| 勾选了计划和执行时使用不同的模型 |
| 2410691-刘思岑|Codex(VS Code插件)|ChatGPT-6-Sol| 无
| 2411191-王可| Codex（终端Agent）|GPT-6.1-Sol| 使用WSL环境运行Codex终端Agent|



---

## 三、实验整体逻辑分析

### 2.1 本章节的逻辑主线

- 核心主题：在已有物理内存管理和基础页表机制之上，搭建虚拟地址空间框架，并引入多执行流并发运行能力，使内核从单一执行流发展为支持多线程调度的内核。

- 解决的问题：让多个执行实体能够并发使用 CPU 运行。为此需要引入虚拟内存描述结构，管理每个执行实体的地址空间布局，并以预映射方式一次性完成全部页表映射，不涉及按需分配与页面置换；同时实现线程控制块、上下文切换和调度器，使内核能够调度多个线程轮流使用 CPU。内核线程仅在内核态运行并共享内核地址空间，用户进程在用户态与内核态之间切换并拥有独立的用户虚拟地址空间，两者在 ucore 中被统一处理，同属唯一的内核进程。

### 2.2 功能的逐步实现

本实验按照虚拟内存页操作、进程创建与初始化、进程调度三条主线推进，执行链可概括为 kern_init 到 pmm_init 到 vmm_init 到 proc_init 到 cpu_idle 到 schedule 到 proc_run 到 switch_to，前半段负责准备好地址空间，后半段负责让第一个可运行线程真正跑起来。

1. 首先实现**虚拟内存页操作**，即 page_insert 与 page_remove → 因为建立和撤销页表映射是所有地址空间操作的基础，只有页表项内容、物理页引用计数和 TLB 状态保持一致，后续线程的地址空间才有可靠支撑。
2. 接着完成**进程创建与初始化**，即 alloc_proc、proc_init、kernel_thread、do_fork、copy_thread 与 copy_mm → 因为有了可靠的页表操作，才能为线程准备控制块、内核栈和首次运行上下文，并使系统中出现 idleproc 与 initproc 两个关键线程。
3. 最后实现**进程调度**，即 cpu_idle、schedule、proc_run 与 switch_to → 因为线程对象创建完成后，还需要选出可运行线程、切换页表并保存恢复寄存器现场，才能让 initproc 真正从 idleproc 手中接管 CPU。

---

## 四、实验内容与实现

<!-- 
说明：本部分按照 exercises 文档中的练习顺序组织
每个功能模块或者练习中可能包含多项任务，请根据实际情况调整
-->

### 功能模块一：[模块名称]

**负责人：** [2410691-刘思岑]

#### 模块功能描述

**需要实现/修改的函数：**

```c
int page_insert(pde_t *pgdir, struct Page *page,
                uintptr_t la, uint32_t perm);
void page_remove(pde_t *pgdir, uintptr_t la);
```

**功能说明：**

本模块负责维护虚拟地址与物理页之间的映射关系。`page_insert` 通过 `get_pte` 获取页表项，建立新映射或更新已有映射，并设置页表权限；`page_remove` 撤销已有映射，对未映射的地址直接返回。

实现中分别处理了首次映射、替换为另一物理页、同一物理页重复映射三种情况，保证物理页引用计数与页表项一致。修改映射后调用 `tlb_invalidate`，防止 CPU 继续使用旧的地址翻译结果。该模块依赖物理页分配和多级页表机制，为后续内核线程运行提供基础映射能力。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown
阅读当前工程的 `kern/mm/pmm.c`、`kern/mm/pmm.h` 及相关页表宏定义，只完成 Lab 4 功能模块一：在 `kern/mm/pmm.c` 的 `LAB4 function1 YOUR CODE` 位置实现以下函数：
```c
int page_insert(pde_t *pgdir, struct Page *page,
                uintptr_t la, uint32_t perm);
void page_remove(pde_t *pgdir, uintptr_t la);
```
将原位置标记改为 `//lab4-2410691`。不要实现其他 Lab 4 模块，也不要补写 Lab 2/3 的代码。
[SPECIFICATION]
1. `page_insert` 使用 `get_pte(pgdir, la, 1)` 获取目标页表项；获取失败时返回 `-E_NO_MEM`，且不能改变目标物理页的引用计数。
2. 新建映射时，增加目标物理页的引用计数，写入目标页号、`PTE_V` 和传入的权限。
3. 如果该地址已映射到同一物理页，只更新权限，不改变该页最终的引用计数，也不能错误释放该页。
4. 如果该地址已映射到另一物理页，应替换映射，减少旧页的引用计数；旧页引用计数降为 0 时释放它。
5. 修改页表项后，使该线性地址对应的 TLB 翻译失效。
6. `page_remove` 使用 `get_pte(pgdir, la, 0)`；页表项不存在或无有效映射时直接返回，不能为删除操作分配新的页表页。
7. 删除有效映射时，清空页表项、使 TLB 翻译失效，并正确减少及检查物理页引用计数。

[RELY]
优先使用框架已有的 `get_pte`、`pte2page`、`pte_create`、`page2ppn`、`page_ref_inc`、`page_ref_dec`、`free_page` 和 `tlb_invalidate`。核对这些函数在当前工程中的声明与返回值，不要凭其他版本 ucore 的接口猜测。

[CONSTRAINT]
只修改 `kern/mm/pmm.c` 中功能模块一的填空区域；保留其他模块和已有测试代码。代码风格尽量与当前文件一致，并给容易出错的“同一页重复映射”和“旧页释放”分支添加简短注释。

````

#### 实现迭代过程

本模块的实现经历了 [1] 次迭代，过程如下：

---

##### 第一次迭代

如果设计的prompt生成代码后出现问题：

**遇到的问题：**
- 问题1：原始 Lab 4 框架仍留有 Lab 2/3 的待补代码，且缺少 best_fit_pmm.h。因此暂时无法通过完整内核编译和运行结果判断模块一是否通过测试。

- 问题2：页表映射有两个容易遗漏的边界情况：同一物理页重复映射不能使引用计数变化；替换为另一物理页时要减少旧页的引用计数，并在引用计数为 0 时释放它。

**问题解决策略：**
- 针对问题1：在提示词的 [RELY] 中要求 AI 先核对当前框架的辅助函数签名，避免套用其他版本 ucore 的代码。
- 针对问题2：在 [SPECIFICATION] 中分别写明首次映射、同页更新、异页替换、无映射删除和内存不足的处理要求。
- 针对问题3：在 [CHECK] 中要求区分代码分析与实际测试结果，避免未经运行就报告“测试通过”。



**关键改进点总结：**
1. 明确同一物理页重复映射时只更新权限，不改变引用计数。
2. 明确替换和删除映射时，页表项、引用计数与 TLB 必须保持一致。
3. 明确删除映射时不得调用会创建页表页的 get_pte(..., 1)。
---


---
### 功能模块二：[进程创建及初始化功能]

**负责人：** [2413330-张子馨]

#### 模块功能描述

**需要实现/修改的函数：**

```c
static struct proc_struct *alloc_proc(void);
void proc_init(void);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
```

**功能说明：**

本模块负责把系统从能运行内核代码推进到能创建并登记多个内核线程，是连接地址空间与调度的中间层。

- 在系统中的作用：alloc_proc 提供干净的进程控制块；proc_init 初始化进程链表与哈希表，把当前执行现场包装成 idleproc，并创建第一个内核线程 initproc；kernel_thread 把函数入口和参数整理成首次运行上下文；do_fork 把控制块、内核栈、PID、链表和状态组合成可运行实体；copy_thread 在新线程内核栈上安放 trapframe 和 context，形成 forkret 到 forkrets 到 __trapret 的首次运行链路；copy_mm 在本阶段承担地址空间处理接口的占位作用。
- 主要场景：idleproc 不经过 fork，直接复用 bootstack 和当前执行现场；initproc 由 do_fork 创建，PID 为 1，parent 为 idleproc。
- 与其他模块的交互：依赖模块一的页操作和物理页分配来建立内核栈，向模块三提供状态为 PROC_RUNNABLE 的线程对象，由 schedule、proc_run 和 switch_to 接管执行。

#### 最终提示词

以下是最终成功实现该功能的提示词：

````markdown

请在 kern/process/proc.c 的 LAB4 function2 标记处实现进程创建及初始化功能，包括 alloc_proc、proc_init、kernel_thread、do_fork、copy_thread、copy_mm。

功能要求：
- alloc_proc：用 kmalloc 分配 PCB 并初始化为安全空白状态，state 为 PROC_UNINIT，context 清零，tf 为 NULL，pgdir 为 boot_pgdir_pa。
- proc_init：初始化 proc_list 和 hash_list；idleproc 直接复用当前执行现场，PID 为 0，kstack 为 bootstack，state 为 PROC_RUNNABLE，current 指向 idleproc；随后用 kernel_thread 创建 init_main 线程作为 initproc，PID 为 1。
- kernel_thread：把 fn 和 arg 分别放入 tf.gpr.s0 和 tf.gpr.s1，status 设置 SSTATUS_SPP 和 SSTATUS_SPIE 并清除 SSTATUS_SIE，epc 指向 kernel_thread_entry，再调用 do_fork。
- do_fork：依次完成 alloc_proc、设置 parent 为 current、setup_kstack、copy_mm、copy_thread，在 local_intr_save 和 local_intr_restore 保护的临界区内分配 PID 并挂入 proc_list 和 hash_list，最后 wakeup_proc，失败时按相反顺序释放资源。
- copy_thread：在新线程内核栈顶安放 trapframe，context.ra 设为 forkret，context.sp 指向 trapframe，形成 forkret 到 forkrets 到 __trapret 的首次运行链路。
- copy_mm：本阶段不复制地址空间，直接返回 0。

注意事项：
- 保持线程生命周期状态与资源挂接顺序一致，避免资源泄漏和状态错误。
- idleproc 不经过 do_fork，其 tf、flags、context.ra 必须保持为 0。
- kernel_thread 与 copy_thread 必须和 entry.S 中 kernel_thread_entry 使用 s0 作为函数入口、s1 作为参数的约定一致。
- 测试要求 initproc 的 parent 为 idleproc，context.ra 和 context.sp 非零。

可借助接口：kmalloc、kfree、alloc_pages、free_pages、page2kva、kva2page、get_pid、find_proc、set_proc_name、wakeup_proc、list_init、list_add、local_intr_save、local_intr_restore、read_csr、bootstack、boot_pgdir_pa、CLONE_VM。

````

#### 实现迭代过程

本模块一次实现成功，未经历提示词迭代。

**最终结果：**

- 编译通过，未出现警告或错误。
- 实现满足 test_lab4_process_create 中的全部字段断言，包括 idleproc 的 PID、内核栈、父进程、状态以及 initproc 的 PID、parent 和首次运行上下文。
- 完整 qemu 运行测试需在功能模块一和功能模块三完成后统一进行。

---

### 功能模块三：[模块名称]

**负责人：** [学号-姓名]

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

### Challenge：[Challenge标题]

**负责人：** [学号-姓名]

[按照Challenge的具体要求进行解答]

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


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

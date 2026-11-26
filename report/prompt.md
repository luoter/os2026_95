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


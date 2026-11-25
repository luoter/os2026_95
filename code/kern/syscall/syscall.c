#include <unistd.h>
#include <proc.h>
#include <syscall.h>
#include <trap.h>
#include <stdio.h>
#include <pmm.h>
#include <vmm.h>
#include <error.h>
#include <assert.h>

/* 系统调用处理函数的统一签名：参数从 trapframe 的 a1~a5 取出后传入 */
static int sys_exit(uint64_t arg[]);
static int sys_fork(uint64_t arg[]);
static int sys_wait(uint64_t arg[]);
static int sys_exec(uint64_t arg[]);
static int sys_yield(uint64_t arg[]);
static int sys_kill(uint64_t arg[]);
static int sys_getpid(uint64_t arg[]);
static int sys_putc(uint64_t arg[]);
static int sys_pgdir(uint64_t arg[]);

static int (*syscalls[])(uint64_t arg[]) = {
    [SYS_exit]              sys_exit,
    [SYS_fork]              sys_fork,
    [SYS_wait]              sys_wait,
    [SYS_exec]              sys_exec,
    [SYS_yield]             sys_yield,
    [SYS_kill]              sys_kill,
    [SYS_getpid]            sys_getpid,
    [SYS_putc]              sys_putc,
    [SYS_pgdir]             sys_pgdir,
};

#define NUM_SYSCALLS        ((sizeof(syscalls)) / (sizeof(syscalls[0])))

//lab5 function1 YOUR CODE

// sys_exit - 结束当前进程，error_code 由父进程通过 wait 取回
static int
sys_exit(uint64_t arg[])
{
    return do_exit((int)arg[0]);
}

// sys_fork - 以当前进程为父进程复制出新进程；子进程从同一 trapframe 返回
static int
sys_fork(uint64_t arg[])
{
    struct trapframe *tf = current->tf;
    uintptr_t stack = tf->gpr.sp;
    return do_fork(0, stack, tf);
}

// sys_wait - 等待指定子进程（pid 为 -1 表示任意子进程）退出
static int
sys_wait(uint64_t arg[])
{
    int pid = (int)arg[0];
    int *code_store = (int *)arg[1];

    // code_store 是用户指针，必须确认可写后再交给 do_wait
    if (code_store != NULL &&
        !user_mem_check(current->mm, (uintptr_t)code_store, sizeof(int), 1))
    {
        return -E_INVAL;
    }
    return do_wait(pid, code_store);
}

// sys_exec - 用用户空间中的 ELF 镜像替换当前进程的地址空间并执行
static int
sys_exec(uint64_t arg[])
{
    const char *name = (const char *)arg[0];
    size_t len = (size_t)arg[1];
    unsigned char *binary = (unsigned char *)arg[2];
    size_t size = (size_t)arg[3];

    // name 与 binary 都来自用户态，逐段检查后才能在内核中访问
    if (!user_mem_check(current->mm, (uintptr_t)name, len, 0) ||
        !user_mem_check(current->mm, (uintptr_t)binary, size, 0))
    {
        return -E_INVAL;
    }
    return do_execve(name, len, binary, size);
}

// sys_yield - 主动让出 CPU，请求调度器重新选择进程
static int
sys_yield(uint64_t arg[])
{
    return do_yield();
}

// sys_kill - 请求终止指定 pid 的进程
static int
sys_kill(uint64_t arg[])
{
    return do_kill((int)arg[0]);
}

// sys_getpid - 返回当前进程号
static int
sys_getpid(uint64_t arg[])
{
    return current->pid;
}

// sys_putc - 向控制台输出一个字符
static int
sys_putc(uint64_t arg[])
{
    cputchar((int)arg[0]);
    return 0;
}

// sys_pgdir - 页表查看接口；框架未提供 print_pgdir 实现，这里直接返回成功
static int
sys_pgdir(uint64_t arg[])
{
    return 0;
}

// syscall - 统一的系统调用分发入口：
// a0 保存系统调用号，a1~a5 保存参数，返回值写回 a0
void syscall(void)
{
    struct trapframe *tf = current->tf;
    uint64_t num = tf->gpr.a0;

    // 编号必须落在合法范围内且对应项已实现，否则按非法参数处理
    if (num > 0 && num < NUM_SYSCALLS && syscalls[num] != NULL)
    {
        uint64_t arg[5];
        arg[0] = tf->gpr.a1;
        arg[1] = tf->gpr.a2;
        arg[2] = tf->gpr.a3;
        arg[3] = tf->gpr.a4;
        arg[4] = tf->gpr.a5;

        tf->gpr.a0 = syscalls[num](arg);
    }
    else
    {
        tf->gpr.a0 = -E_INVAL;
    }
}

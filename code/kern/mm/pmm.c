#include <default_pmm.h>
#include <best_fit_pmm.h>
#include <defs.h>
#include <error.h>
#include <memlayout.h>
#include <mmu.h>
#include <pmm.h>
#include <sbi.h>
#include <stdio.h>
#include <string.h>
#include <riscv.h>
#include <dtb.h>
/* 2410691 修改部分 开始：SLUB 头文件 */
#include <slub.h>
/* 2410691 修改部分 结束 */



// virtual address of physical page array
struct Page *pages;
// amount of physical memory (in pages)
size_t npage = 0;
// the kernel image is mapped at VA=KERNBASE and PA=info.base
uint64_t va_pa_offset;
// memory starts at 0x80000000 in RISC-V
// DRAM_BASE defined in riscv.h as 0x80000000
const size_t nbase = DRAM_BASE / PGSIZE;

// virtual address of boot-time page directory
uintptr_t *satp_virtual = NULL;
// physical address of boot-time page directory
uintptr_t satp_physical;

// physical memory management
const struct pmm_manager *pmm_manager;


static void check_alloc_page(void);

// init_pmm_manager - initialize a pmm_manager instance
static void init_pmm_manager(void) {
    /* lab2 function2-3 2410691 修改部分 开始：Buddy 管理器选择 */
    #ifdef PMM_USE_BUDDY
    pmm_manager = &buddy_pmm_manager;
    #else
    pmm_manager = &best_fit_pmm_manager;
    #endif
    /* lab2 function2-3 2410691 修改部分 结束 */
    cprintf("memory management: %s\n", pmm_manager->name);
    pmm_manager->init();
}

// init_memmap - call pmm->init_memmap to build Page struct for free memory
static void init_memmap(struct Page *base, size_t n) {
    pmm_manager->init_memmap(base, n);
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
}

//lab2 function1 2413330
// page_init - 根据设备树探测物理内存并初始化 Page 描述符数组，
// 然后将空闲页区域注册到当前的 pmm_manager。
static void page_init(void) {
    // 1. 设置 PADDR / KADDR 使用的虚拟<->物理地址映射偏移
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;

    // 2. 读取设备树报告的物理内存布局
    uint64_t mem_base = get_memory_base();
    uint64_t mem_size = get_memory_size();
    uint64_t mem_end = mem_base + mem_size;

    if (mem_base == 0 || mem_size == 0) {
        panic("page_init: invalid physical memory info from DTB");
    }

    // 物理页总数（从 0 到 mem_end 的页帧号）
    npage = PPN(mem_end);

    cprintf("memory: base=0x%016lx size=0x%016lx end=0x%016lx\n",
            mem_base, mem_size, mem_end);
    cprintf("npage: %lu\n", npage);

    // 3. 将 Page 描述符数组放在内核镜像之后（按页对齐）
    extern char end[];
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);

    // 可管理的页数（位于或高于 DRAM_BASE 的页）
    size_t nr_manage = npage - nbase;

    // 4. 先将所有可管理页标记为保留；之后只有交给 init_memmap() 的
    //    空闲区域才会被解除保留
    for (size_t i = 0; i < nr_manage; i++) {
        SetPageReserved(pages + i);
    }

    // 5. 计算空闲物理内存区域。
    //    空闲区从 Page 描述符数组结束之后开始（按页对齐），
    //    到 mem_end 之下的最后一个完整页结束。
    uintptr_t pages_end_va = (uintptr_t)pages + nr_manage * sizeof(struct Page);
    uintptr_t free_start_va = ROUNDUP(pages_end_va, PGSIZE);
    uintptr_t free_start_pa = PADDR(free_start_va);
    uintptr_t free_end_pa = ROUNDDOWN(mem_end, PGSIZE);

    // 6. 将完整的空闲页范围交给 pmm 管理器。
    //    先比较地址再做减法：若 free_start_pa >= free_end_pa，
    //    无符号相减会下溢成巨大正数，必须在源头拦截。
    if (free_start_pa < free_end_pa) {
        size_t nr_free = (free_end_pa - free_start_pa) / PGSIZE;

        cprintf("free region: pa=0x%016lx - 0x%016lx (%lu pages)\n",
                free_start_pa, free_end_pa, nr_free);

        init_memmap(pa2page(free_start_pa), nr_free);
    } else {
        cprintf("page_init: no free physical memory (start=0x%016lx end=0x%016lx)\n",
                free_start_pa, free_end_pa);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
    // We need to alloc/free the physical memory (granularity is 4KB or other size).
    // So a framework of physical memory manager (struct pmm_manager)is defined in pmm.h
    // First we should init a physical memory manager(pmm) based on the framework.
    // Then pmm can alloc/free the physical memory.
    // Now the first_fit/best_fit/worst_fit/buddy_system pmm are available.
    init_pmm_manager();

    // detect physical memory space, reserve already used memory,
    // then use pmm->init_memmap to create free page list
    page_init();

    // use pmm->check to verify the correctness of the alloc/free function in a pmm
    check_alloc_page();

     /* 2410691 修改部分 开始：初始化 SLUB，可按编译开关运行自检 */
    slub_init();
#ifdef SLUB_SELFTEST
    slub_check();
    cprintf("slub_check() succeeded!\n");
#endif
    /* 2410691 修改部分 结束 */

    extern char boot_page_table_sv39[];
    satp_virtual = (pte_t*)boot_page_table_sv39;
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
    cprintf("check_alloc_page() succeeded!\n");
}

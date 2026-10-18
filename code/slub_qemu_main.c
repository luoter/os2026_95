/* Independent RISC-V test kernel. Reuses ucore entry/link/console/PMM code.
 * A reserved, static pool supplies real mapped pages; this does not implement
 * or replace the group's unfinished DTB/page_init assignment. */
#include <assert.h>
#include <buddy_pmm.h>
#include <console.h>
#include <default_pmm.h>
#include <pmm.h>
#include <sbi.h>
#include <slub.h>
#include <stdio.h>
#include <string.h>

#define POOL_PAGES 512
#define RAM_PAGES ((PHYSICAL_MEMORY_END - DRAM_BASE) / PGSIZE)
static struct Page descriptors[RAM_PAGES];
static unsigned char test_pool[POOL_PAGES * PGSIZE] __attribute__((aligned(PGSIZE)));
struct Page *pages = descriptors;
size_t npage = PHYSICAL_MEMORY_END / PGSIZE;
const size_t nbase = DRAM_BASE / PGSIZE;
uint64_t va_pa_offset;
const struct pmm_manager *pmm_manager;

/* The project's sbi.c implements this helper but its public header omits it. */
extern uint64_t sbi_call(uint64_t, uint64_t, uint64_t, uint64_t);

struct Page *alloc_pages(size_t n) { return pmm_manager->alloc_pages(n); }
void free_pages(struct Page *p, size_t n) { pmm_manager->free_pages(p, n); }
size_t nr_free_pages(void) { return pmm_manager->nr_free_pages(); }

static void __noreturn stop(void) {
    sbi_call(8, 0, 0, 0);
    for (;;) {
        asm volatile("wfi");
    }
}

void __panic(const char *file, int line, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    cprintf("SLUB_QEMU_FAIL %s:%d: ", file, line);
    vcprintf(fmt, args);
    cprintf("\n");
    va_end(args);
    stop();
}

int __noreturn kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
    cons_init();
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
    for (size_t i = 0; i < RAM_PAGES; i++) {
        SetPageReserved(pages + i);
    }
#ifdef TEST_USE_BUDDY
    pmm_manager = &buddy_pmm_manager;
#else
    pmm_manager = &default_pmm_manager;
#endif
    pmm_manager->init();
    uintptr_t physical = (uintptr_t)test_pool - va_pa_offset;
    assert(physical >= DRAM_BASE && physical + sizeof(test_pool) <= PHYSICAL_MEMORY_END);
    pmm_manager->init_memmap(pa2page(physical), POOL_PAGES);
    assert(nr_free_pages() == POOL_PAGES);
    cprintf("SLUB independent kernel: backend=%s pool=%lu mapped=%016lx\n",
            pmm_manager->name, (size_t)POOL_PAGES, test_pool);
    pmm_manager->check();
    assert(nr_free_pages() == POOL_PAGES);
    cprintf("PMM_QEMU_PASS backend=%s free=%lu\n", pmm_manager->name, nr_free_pages());
    slub_init();
    slub_check();
    assert(nr_free_pages() == POOL_PAGES);
    cprintf("SLUB_QEMU_PASS backend=%s free=%lu\n", pmm_manager->name, nr_free_pages());
    stop();
}

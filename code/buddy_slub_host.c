/* Host-only smoke test for the two independent Lab2 allocators.
 * Build with tests/run_buddy_slub_host.sh. */
#include <assert.h>
#include <buddy_pmm.h>
#include <pmm.h>
#include <slub.h>

extern int printf(const char *, ...);
extern void abort(void);

#define TEST_PAGES 512
static struct Page descriptors[TEST_PAGES];
static unsigned char ram[TEST_PAGES * PGSIZE] __attribute__((aligned(PGSIZE)));

struct Page *pages = descriptors;
size_t npage = DRAM_BASE / PGSIZE + TEST_PAGES;
const size_t nbase = DRAM_BASE / PGSIZE;
uint64_t va_pa_offset;
const struct pmm_manager *pmm_manager;

void __panic(const char *file, int line, const char *fmt, ...) {
    printf("panic at %s:%d: %s\n", file, line, fmt);
    abort();
    __builtin_trap();
}

struct Page *alloc_pages(size_t n) { return pmm_manager->alloc_pages(n); }
void free_pages(struct Page *p, size_t n) { pmm_manager->free_pages(p, n); }
size_t nr_free_pages(void) { return pmm_manager->nr_free_pages(); }

int main(void) {
    va_pa_offset = (uintptr_t)ram - DRAM_BASE;
    pmm_manager = &buddy_pmm_manager;
    for (size_t i = 0; i < TEST_PAGES; i++) {
        descriptors[i].flags = 0;
        SetPageReserved(&descriptors[i]);
    }
    pmm_manager->init();
    /* Start and end on non-buddy boundaries. */
    pmm_manager->init_memmap(descriptors + 3, TEST_PAGES - 9);
    pmm_manager->check();
    size_t before = nr_free_pages();

    struct Page *p = alloc_pages(17);
    assert(p != NULL && nr_free_pages() == before - 32);
    free_pages(p, 17);
    assert(nr_free_pages() == before);
    pmm_manager->check();

    struct Page *live[80] = {0};
    size_t lengths[80] = {0};
    unsigned char occupied[TEST_PAGES] = {0};
    unsigned int seed = 0x12345678U;
    size_t used = 0;
    for (unsigned int step = 0; step < 3000; step++) {
        seed = seed * 1664525U + 1013904223U;
        unsigned int slot = seed % 80;
        if (live[slot] != NULL) {
            size_t first = live[slot] - descriptors;
            size_t actual = 1;
            while (actual < lengths[slot]) {
                actual *= 2;
            }
            for (size_t j = 0; j < actual; j++) {
                assert(occupied[first + j] == 1);
                occupied[first + j] = 0;
            }
            free_pages(live[slot], lengths[slot]);
            used -= actual;
            live[slot] = NULL;
        } else {
            size_t count = (seed >> 16) % 33 + 1;
            size_t actual = 1;
            while (actual < count) {
                actual *= 2;
            }
            struct Page *q = alloc_pages(count);
            if (q != NULL) {
                size_t first = q - descriptors;
                assert(first >= 3 && first + actual <= TEST_PAGES - 6);
                for (size_t j = 0; j < actual; j++) {
                    assert(occupied[first + j] == 0);
                    occupied[first + j] = 1;
                }
                live[slot] = q;
                lengths[slot] = count;
                used += actual;
            }
        }
        assert(nr_free_pages() + used == before);
    }
    for (unsigned int i = 0; i < 80; i++) {
        if (live[i] != NULL) {
            free_pages(live[i], lengths[i]);
        }
    }
    assert(nr_free_pages() == before);
    pmm_manager->check();

   /**cs修改部分*/ /* 开始 */
    slub_init();
    slub_check();
    printf("Buddy and SLUB host checks passed (%lu free pages).\n", before);
/**cs修改部分*/ /* 结束 */
    return 0;
}

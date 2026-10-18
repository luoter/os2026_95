/* Independent tests of classic Buddy's public PMM behavior. */
#include <assert.h>
#include <buddy_pmm.h>
#include <pmm.h>
#include <string.h>

extern int printf(const char *, ...);
extern void exit(int) __attribute__((noreturn));

#define TEST_PAGES 512
static struct Page descriptors[TEST_PAGES];
static struct Page snapshot[TEST_PAGES];
struct Page *pages = descriptors;
/* Deliberately not aligned to large buddy orders: detect array-index buddies. */
const size_t nbase = DRAM_BASE / PGSIZE + 3;
size_t npage = DRAM_BASE / PGSIZE + 3 + TEST_PAGES;
uint64_t va_pa_offset;
const struct pmm_manager *pmm_manager = &buddy_pmm_manager;

void __panic(const char *file, int line, const char *fmt, ...) {
    printf("BUDDY_TEST_ASSERT %s:%d: %s\n", file, line, fmt);
    exit(86);
}
struct Page *alloc_pages(size_t n) { return pmm_manager->alloc_pages(n); }
void free_pages(struct Page *p, size_t n) { pmm_manager->free_pages(p, n); }
size_t nr_free_pages(void) { return pmm_manager->nr_free_pages(); }

static size_t rounded(size_t n) {
    size_t r = 1;
    while (r < n) {
        r *= 2;
    }
    return r;
}
static void prepare(void) {
    memset(descriptors, 0, sizeof(descriptors));
    for (size_t i = 0; i < TEST_PAGES; i++) {
        SetPageReserved(pages + i);
        list_init(&pages[i].page_link);
    }
    pmm_manager->init();
}
static struct Page *aligned_base(size_t n) {
    size_t skip = (n - nbase % n) % n;
    assert(skip + n <= TEST_PAGES);
    return pages + skip;
}
static void reject_without_change(size_t request) {
    size_t before = nr_free_pages();
    memcpy(snapshot, descriptors, sizeof(descriptors));
    assert(alloc_pages(request) == NULL);
    assert(nr_free_pages() == before);
    assert(memcmp(snapshot, descriptors, sizeof(descriptors)) == 0);
}

static void initialization_test(void) {
    prepare();
    assert(nr_free_pages() == 0 && alloc_page() == NULL);
    pmm_manager->init_memmap(pages + 3, 100);
    pmm_manager->init_memmap(pages + 200, 70);
    assert(nr_free_pages() == 170);
    struct Page *held[170];
    unsigned char seen[TEST_PAGES] = {0};
    for (size_t i = 0; i < 170; i++) {
        held[i] = alloc_page();
        assert(held[i] != NULL);
        size_t index = held[i] - pages;
        assert((index >= 3 && index < 103) || (index >= 200 && index < 270));
        assert(!seen[index]);
        seen[index] = 1;
    }
    reject_without_change(1);
    for (size_t i = 170; i > 0; i--) {
        free_page(held[i - 1]);
    }
    assert(nr_free_pages() == 170);
    printf("PASS initialization: irregular ranges, holes, bounds, exact handoff count\n");
}

static void rounding_test(void) {
    prepare();
    pmm_manager->init_memmap(pages + 3, TEST_PAGES - 9);
    size_t before = nr_free_pages();
    static const size_t requests[] = {1, 2, 3, 5, 8, 9, 17, 31, 32, 33, 63, 65};
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i++) {
        size_t n = requests[i], r = rounded(n);
        struct Page *p = alloc_pages(n);
        assert(p != NULL && page2ppn(p) % r == 0);
        assert(p >= pages + 3 && p + r <= pages + TEST_PAGES - 6);
        assert(nr_free_pages() == before - r);
        free_pages(p, n);
        assert(nr_free_pages() == before);
    }
    reject_without_change(before + 1);
    reject_without_change((size_t)-1);
    pmm_manager->check();
    printf("PASS rounding: 5->8, 17->32, alignment, overflow, whole-block free\n");
}

static void splitting_test(void) {
    for (unsigned int pass = 0; pass < 2; pass++) {
        prepare();
        struct Page *base = aligned_base(8);
        pmm_manager->init_memmap(base, 8);
        unsigned char seen[8] = {0};
        for (unsigned int i = 0; i < 8; i++) {
            struct Page *p = alloc_page();
            assert(p != NULL && p >= base && p < base + 8);
            assert(!seen[p - base]);
            seen[p - base] = 1;
        }
        assert(nr_free_pages() == 0);
        reject_without_change(1);
        static const unsigned int order[] = {7, 5, 3, 1, 6, 4, 2, 0};
        for (unsigned int i = 0; i < 8; i++) {
            free_page(base + (pass == 0 ? 7 - i : order[i]));
        }
        assert(nr_free_pages() == 8);
        struct Page *large = alloc_pages(8);
        assert(large == base && nr_free_pages() == 0);
        free_pages(large, 8);
        assert(nr_free_pages() == 8);
    }
    printf("PASS splitting/merging: both release orders reconstruct original 8-page block\n");
}

static void fragmentation_test(void) {
    prepare();
    struct Page *base = aligned_base(8);
    pmm_manager->init_memmap(base, 8);
    for (unsigned int i = 0; i < 8; i++) {
        assert(alloc_page() != NULL);
    }
    /* +1 and +2 are adjacent physical pages, but belong to different parents. */
    free_page(base + 1);
    free_page(base + 2);
    assert(nr_free_pages() == 2);
    reject_without_change(2);
    struct Page *a = alloc_page(), *b = alloc_page();
    assert((a == base + 1 && b == base + 2) || (a == base + 2 && b == base + 1));
    for (unsigned int i = 0; i < 8; i++) {
        free_page(base + i);
    }
    assert(alloc_pages(8) == base);
    free_pages(base, 8);

    prepare();
    base = aligned_base(8);
    pmm_manager->init_memmap(base, 2);
    pmm_manager->init_memmap(base + 4, 2);
    assert(nr_free_pages() == 4);
    reject_without_change(4);
    a = alloc_pages(2);
    b = alloc_pages(2);
    assert((a == base && b == base + 4) || (b == base && a == base + 4));
    free_pages(a, 2);
    free_pages(b, 2);
    assert(nr_free_pages() == 4);
    printf("PASS fragmentation: non-buddy neighbors and unmapped gaps never merge\n");
}

static void random_test(void) {
    prepare();
    pmm_manager->init_memmap(pages + 3, TEST_PAGES - 9);
    struct Page *live[80] = {0};
    size_t requests[80] = {0};
    unsigned char occupied[TEST_PAGES] = {0};
    size_t before = nr_free_pages(), used = 0;
    unsigned int seed = 0x5ab13791U;
    for (unsigned int step = 0; step < 5000; step++) {
        seed = seed * 1664525U + 1013904223U;
        unsigned int slot = (seed >> 8) % 80;
        if (live[slot] != NULL) {
            size_t first = live[slot] - pages, r = rounded(requests[slot]);
            for (size_t j = 0; j < r; j++) {
                assert(occupied[first + j]);
                occupied[first + j] = 0;
            }
            free_pages(live[slot], requests[slot]);
            used -= r;
            live[slot] = NULL;
        } else {
            size_t n = (seed >> 16) % 65 + 1, r = rounded(n);
            struct Page *p = alloc_pages(n);
            if (p != NULL) {
                size_t first = p - pages;
                assert(first >= 3 && first + r <= TEST_PAGES - 6);
                assert(page2ppn(p) % r == 0);
                for (size_t j = 0; j < r; j++) {
                    assert(!occupied[first + j]);
                    occupied[first + j] = 1;
                }
                live[slot] = p;
                requests[slot] = n;
                used += r;
            }
        }
        assert(nr_free_pages() + used == before);
    }
    for (unsigned int i = 0; i < 80; i++) {
        if (live[i] != NULL) {
            free_pages(live[i], requests[i]);
        }
    }
    assert(nr_free_pages() == before);
    pmm_manager->check();
    printf("PASS randomized: 5000 operations, independent per-page ownership and counts\n");
}

int main(int argc, char **argv) {
    assert(argc == 2);
    const char *mode = argv[1];
    if (strcmp(mode, "normal") == 0) {
        initialization_test();
        rounding_test();
        splitting_test();
        fragmentation_test();
        random_test();
        printf("BUDDY_CLASSIC_PASS free=%lu\n", nr_free_pages());
        return 0;
    }
    prepare();
    pmm_manager->init_memmap(pages + 3, TEST_PAGES - 9);
    if (strcmp(mode, "alloc-zero") == 0) {
        alloc_pages(0);
    } else if (strcmp(mode, "init-zero") == 0) {
        pmm_manager->init_memmap(pages, 0);
    } else if (strcmp(mode, "init-overlap") == 0) {
        pmm_manager->init_memmap(pages + 4, 5);
    } else if (strcmp(mode, "init-outside") == 0) {
        pmm_manager->init_memmap(pages + TEST_PAGES - 1, 2);
    } else if (strcmp(mode, "free-outside") == 0) {
        free_pages((struct Page *)((uintptr_t)pages - sizeof(struct Page)), 1);
    } else if (strcmp(mode, "free-reserved") == 0) {
        free_page(pages);
    } else {
        struct Page *p = alloc_pages(3);
        assert(p != NULL);
        if (strcmp(mode, "free-zero") == 0) {
            free_pages(p, 0);
        } else if (strcmp(mode, "free-interior") == 0) {
            free_pages(p + 1, 1);
        } else if (strcmp(mode, "free-wrong-size") == 0) {
            free_pages(p, 2);
        } else if (strcmp(mode, "free-unaligned") == 0) {
            free_pages((struct Page *)((uintptr_t)p + 1), 1);
        } else if (strcmp(mode, "double-free") == 0) {
            free_pages(p, 3);
            free_pages(p, 3);
        } else if (strcmp(mode, "init-live") == 0) {
            pmm_manager->init_memmap(p, 4);
        } else {
            return 3;
        }
    }
    return 2;
}

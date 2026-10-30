/* 2410691：SLUB 宿主机测试 修改部分 开始 */
#include <assert.h>
#include <buddy_pmm.h>
#include <default_pmm.h>
#include <pmm.h>
#include <slub.h>
#include <string.h>

extern int printf(const char *, ...);
extern void exit(int) __attribute__((noreturn));

#define TEST_PAGES 512
static struct Page descriptors[TEST_PAGES];
static unsigned char ram[TEST_PAGES * PGSIZE] __attribute__((aligned(PGSIZE)));
static unsigned char used[TEST_PAGES];
static size_t spans[TEST_PAGES];
static size_t free_count;

struct Page *pages = descriptors;
size_t npage = DRAM_BASE / PGSIZE + TEST_PAGES;
const size_t nbase = DRAM_BASE / PGSIZE;
uint64_t va_pa_offset;
const struct pmm_manager *pmm_manager;

void __panic(const char *file, int line, const char *fmt, ...) {
    printf("EXPECTED_OR_TEST_ASSERT %s:%d: %s\n", file, line, fmt);
    exit(86);
}

struct Page *alloc_pages(size_t n) { return pmm_manager->alloc_pages(n); }
void free_pages(struct Page *p, size_t n) { pmm_manager->free_pages(p, n); }
size_t nr_free_pages(void) { return pmm_manager->nr_free_pages(); }

/* Test double for a future classic Buddy backend: alloc(n) reserves pow2(n),
 * free(base,n) returns that whole span. It is not the task-three allocator. */
static void rounded_init(void) {
    memset(used, 1, sizeof(used));
    memset(spans, 0, sizeof(spans));
    free_count = 0;
}
static void rounded_memmap(struct Page *base, size_t n) {
    size_t first = base - pages;
    for (size_t i = first; i < first + n; i++) {
        used[i] = 0;
    }
    free_count += n;
}
static size_t round_pages(size_t n) {
    size_t r = 1;
    while (r < n) {
        r *= 2;
    }
    return r;
}
static struct Page *rounded_alloc(size_t n) {
    if (n == 0 || n > TEST_PAGES) {
        return NULL;
    }
    size_t r = round_pages(n);
    for (size_t i = 0; i + r <= TEST_PAGES; i++) {
        if ((nbase + i) % r != 0) {
            continue;
        }
        size_t j = 0;
        while (j < r && !used[i + j]) {
            j++;
        }
        if (j == r) {
            memset(used + i, 1, r);
            spans[i] = r;
            free_count -= r;
            return pages + i;
        }
    }
    return NULL;
}
static void rounded_free(struct Page *base, size_t n) {
    size_t i = base - pages, r = round_pages(n);
    assert(i < TEST_PAGES && spans[i] == r);
    memset(used + i, 0, r);
    spans[i] = 0;
    free_count += r;
}
static size_t rounded_count(void) { return free_count; }
static void rounded_check(void) {}
static const struct pmm_manager rounded_manager = {
    "rounded-test-double", rounded_init, rounded_memmap, rounded_alloc,
    rounded_free, rounded_count, rounded_check
};

static void check_bytes(const void *ptr, size_t n, unsigned char pattern) {
    const unsigned char *p = ptr;
    for (size_t j = 0; j < n; j++) {
        assert(p[j] == pattern);
    }
}

static void mixed_test(void) {
    enum { SLOTS = 80 };
    void *live[SLOTS] = {0};
    size_t lengths[SLOTS] = {0};
    unsigned char patterns[SLOTS] = {0};
    unsigned int seed = 0x82a45139U;
    size_t before = nr_free_pages();
    for (unsigned int step = 0; step < 4000; step++) {
        seed = seed * 1664525U + 1013904223U;
        unsigned int slot = (seed >> 8) % SLOTS;
        if (live[slot] != NULL) {
            check_bytes(live[slot], lengths[slot], patterns[slot]);
            slub_free(live[slot]);
            live[slot] = NULL;
        } else {
            size_t count = (seed >> 16) % 10000 + 1;
            void *obj = slub_alloc(count);
            if (obj != NULL) {
                assert((uintptr_t)obj % 16 == 0);
                for (unsigned int j = 0; j < SLOTS; j++) {
                    if (live[j] != NULL) {
                        uintptr_t a = (uintptr_t)obj, b = (uintptr_t)live[j];
                        assert(a + count <= b || b + lengths[j] <= a);
                    }
                }
                live[slot] = obj;
                lengths[slot] = count;
                patterns[slot] = (unsigned char)(step % 251 + 1);
                memset(obj, patterns[slot], count);
            }
        }
        for (unsigned int j = 0; j < SLOTS; j++) {
            if (live[j] != NULL) {
                check_bytes(live[j], lengths[j], patterns[j]);
            }
        }
    }
    for (unsigned int j = 0; j < SLOTS; j++) {
        slub_free(live[j]);
    }
    assert(nr_free_pages() == before);
}

static void pressure_test(void) {
    size_t before = nr_free_pages();
    void *a = slub_alloc(64);
    assert(a != NULL);
    memset(a, 0x69, 64);
    struct Page *held[TEST_PAGES];
    size_t count = 0;
    while (count < TEST_PAGES && (held[count] = alloc_page()) != NULL) {
        count++;
    }
    assert(nr_free_pages() == 0);
    /* Existing partial slab works without obtaining another physical page. */
    void *b = slub_alloc(64);
    assert(b != NULL);
    assert(slub_alloc(128) == NULL);
    assert(slub_alloc(8195) == NULL);
    assert(nr_free_pages() == 0);
    check_bytes(a, 64, 0x69);
    slub_free(a);
    slub_free(b);
    for (size_t j = 0; j < count; j++) {
        free_page(held[j]);
    }
    assert(nr_free_pages() == before);

    void *objects[TEST_PAGES * 4];
    count = 0;
    while (count < TEST_PAGES * 4 && (objects[count] = slub_alloc(1024)) != NULL) {
        memset(objects[count], 0x53, 1024);
        count++;
    }
    assert(count > 0 && count < TEST_PAGES * 4 && nr_free_pages() == 0);
    assert(slub_alloc(1024) == NULL && slub_alloc(4096) == NULL);
    for (size_t j = count; j > 0; j--) {
        check_bytes(objects[j - 1], 1024, 0x53);
        slub_free(objects[j - 1]);
    }
    assert(nr_free_pages() == before);
}

int main(int argc, char **argv) {
    assert(argc == 3);
    va_pa_offset = (uintptr_t)ram - DRAM_BASE;
    pmm_manager = strcmp(argv[1], "first-fit") == 0 ? &default_pmm_manager :
        strcmp(argv[1], "buddy") == 0 ? &buddy_pmm_manager : &rounded_manager;
    for (size_t i = 0; i < TEST_PAGES; i++) {
        descriptors[i].flags = 0;
        SetPageReserved(&descriptors[i]);
    }
    pmm_manager->init();
    pmm_manager->init_memmap(descriptors + 3, TEST_PAGES - 9);
    const char *mode = argv[2];
    if (strcmp(mode, "before-init") == 0) {
        slub_alloc(16);
        return 2;
    }
    slub_init();
    if (strcmp(mode, "normal") == 0) {
        size_t before = nr_free_pages();
        slub_check();
        mixed_test();
        pressure_test();
        slub_init();
        slub_check();
        assert(nr_free_pages() == before);
        printf("SLUB PASS backend=%s free=%lu mixed=4000 pressure=PASS\n", argv[1], before);
        return 0;
    }
    if (strcmp(mode, "foreign") == 0) {
        int local = 0;
        slub_free(&local);
    } else if (strcmp(mode, "raw-page") == 0) {
        struct Page *p = alloc_page();
        assert(p != NULL);
        slub_free((void *)(page2pa(p) + va_pa_offset));
    } else if (strcmp(mode, "large-interior") == 0) {
        void *p = slub_alloc(8195);
        assert(p != NULL);
        slub_free((char *)p + 4096);
    } else {
        void *p = slub_alloc(32);
        assert(p != NULL);
        if (strcmp(mode, "reinit-live") == 0) {
            slub_init();
        } else if (strcmp(mode, "interior") == 0) {
            slub_free((char *)p + 1);
        } else if (strcmp(mode, "double-live-slab") == 0) {
            void *q = slub_alloc(32);
            assert(q != NULL);
            slub_free(p);
            slub_free(p);
        } else if (strcmp(mode, "double-released-slab") == 0) {
            slub_free(p);
            slub_free(p);
        } else {
            return 3;
        }
    }
    return 2; /* A negative case reaching here failed to reject the input. */
}
/* 2410691：SLUB 宿主机测试 修改部分 结束 */

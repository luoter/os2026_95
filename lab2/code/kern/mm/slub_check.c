/* 2410691：Challenge SLUB 检查函数 修改部分 开始 */
#include <assert.h>
#include <mmu.h>
#include <pmm.h>
#include <slub.h>
#include <string.h>

/* Public-interface tests shared by the normal and isolated test kernels. */
void
slub_check(void) {
    static const size_t sizes[] = {
        0, 1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
        255, 256, 257, 511, 512, 513, 1023, 1024, 1025, 2047, 2048,
        2049, 4095, 4096, 4097, 8195
    };
    enum { COUNT = sizeof(sizes) / sizeof(sizes[0]), MANY = 300 };
    size_t before = nr_free_pages();
    void *objects[COUNT];
    for (unsigned int i = 0; i < COUNT; i++) {
        size_t n = sizes[i] == 0 ? 1 : sizes[i];
        objects[i] = slub_alloc(sizes[i]);
        assert(objects[i] != NULL && (uintptr_t)objects[i] % 16 == 0);
        for (unsigned int k = 0; k < i; k++) {
            size_t m = sizes[k] == 0 ? 1 : sizes[k];
            uintptr_t a = (uintptr_t)objects[i], b = (uintptr_t)objects[k];
            assert(a + n <= b || b + m <= a);
        }
        memset(objects[i], (int)(i + 1), n);
    }
    for (unsigned int i = 0; i < COUNT; i++) {
        const unsigned char *p = objects[i];
        size_t n = sizes[i] == 0 ? 1 : sizes[i];
        for (size_t j = 0; j < n; j++) {
            assert(p[j] == i + 1);
        }
    }
    for (unsigned int i = COUNT; i > 0; i--) {
        slub_free(objects[i - 1]);
    }
    assert(nr_free_pages() == before);

    void *many[MANY];
    for (unsigned int i = 0; i < MANY; i++) {
        many[i] = slub_alloc(64);
        assert(many[i] != NULL);
        memset(many[i], (int)(i % 251 + 1), 64);
    }
    size_t occupied = nr_free_pages();
    /* Every slab retains live odd objects while the even objects are freed. */
    for (unsigned int i = 0; i < MANY; i += 2) {
        slub_free(many[i]);
    }
    assert(nr_free_pages() == occupied);
    for (unsigned int i = 0; i < MANY; i += 2) {
        many[i] = slub_alloc(64);
        assert(many[i] != NULL);
        memset(many[i], (int)(i % 251 + 1), 64);
    }
    assert(nr_free_pages() == occupied);
    for (unsigned int i = 0; i < MANY; i++) {
        const unsigned char *p = many[i];
        for (unsigned int j = 0; j < 64; j++) {
            assert(p[j] == i % 251 + 1);
        }
        slub_free(many[i]);
    }
    assert(nr_free_pages() == before);
    assert(slub_alloc((size_t)-1) == NULL);
    assert(slub_alloc((size_t)-PGSIZE) == NULL);
    slub_free(NULL);
    assert(nr_free_pages() == before);
}
/* 2410691：Challenge SLUB 检查函数 修改部分 结束 */

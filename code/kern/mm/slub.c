#include <assert.h>
#include <list.h>
#include <mmu.h>
#include <pmm.h>
#include <slub.h>

/**cs修改部分*/ /* 开始 */
/* Single-hart teaching allocator; callers serialize operations.
 * Conceptual reference: Linux mm/slub.c (partial slabs and object freelists).
 * Independently implemented for ucore, not a port of Linux source. */
#define SLUB_MAGIC 0x534c5542U
#define SLUB_LARGE 0xffffffffU
#define SLUB_CLASSES 8
#define SLUB_ALIGN 16
#define SLUB_BITMAP_WORDS 4

struct slab {
    list_entry_t partial_link;
    list_entry_t all_link;
    void *free;
    size_t pages; /* original request to the page allocator */
    unsigned int magic;
    unsigned int class_id;
    unsigned int inuse;
    unsigned int total;
    uint64_t allocated[SLUB_BITMAP_WORDS];
};

static const size_t class_sizes[SLUB_CLASSES] = {
    16, 32, 64, 128, 256, 512, 1024, 2048
};
static list_entry_t partial[SLUB_CLASSES];
/* Also track full slabs: validate an untrusted pointer before reading a header. */
static list_entry_t all_slabs;
static bool initialized;

static size_t
object_offset(void) {
    return (sizeof(struct slab) + SLUB_ALIGN - 1) & ~(size_t)(SLUB_ALIGN - 1);
}

static void *
page_address(struct Page *page) {
    return (void *)(page2pa(page) + va_pa_offset);
}

static struct Page *
slab_page(struct slab *s) {
    uintptr_t pa = (uintptr_t)s - va_pa_offset;
    assert(PPN(pa) >= nbase && PPN(pa) < npage);
    assert((pa & (PGSIZE - 1)) == 0);
    return pa2page(pa);
}

static struct slab *
find_slab(const void *ptr) {
    uintptr_t addr = (uintptr_t)ptr;
    for (list_entry_t *le = list_next(&all_slabs); le != &all_slabs;
         le = list_next(le)) {
        struct slab *s = to_struct(le, struct slab, all_link);
        uintptr_t base = (uintptr_t)s;
        if (addr >= base && addr - base < s->pages * PGSIZE) {
            return s;
        }
    }
    return NULL;
}

void
slub_init(void) {
    if (initialized) {
        assert(list_empty(&all_slabs));
    }
    for (unsigned int i = 0; i < SLUB_CLASSES; i++) {
        list_init(&partial[i]);
    }
    list_init(&all_slabs);
    initialized = 1;
}

static void
register_slab(struct slab *s, size_t count, unsigned int id) {
    assert((uintptr_t)s % SLUB_ALIGN == 0);
    list_init(&s->partial_link);
    list_init(&s->all_link);
    s->pages = count;
    s->magic = SLUB_MAGIC;
    s->class_id = id;
    s->free = NULL;
    s->inuse = s->total = 0;
    for (unsigned int i = 0; i < SLUB_BITMAP_WORDS; i++) {
        s->allocated[i] = 0;
    }
    list_add(&all_slabs, &s->all_link);
}

/**cs修改部分*/ /* 结束 */
/**cs修改部分*/ /* 开始 */
void *
slub_alloc(size_t size) {
    assert(initialized);
    if (size == 0) {
        size = 1;
    }
    unsigned int id = 0;
    while (id < SLUB_CLASSES && class_sizes[id] < size) {
        id++;
    }
    if (id == SLUB_CLASSES) {
        size_t offset = object_offset();
        if (size > (size_t)-1 - offset - (PGSIZE - 1)) {
            return NULL;
        }
        size_t count = (size + offset + PGSIZE - 1) / PGSIZE;
        if (npage <= nbase || count > npage - nbase) {
            return NULL;
        }
        struct Page *page = alloc_pages(count);
        if (page == NULL) {
            return NULL;
        }
        struct slab *s = page_address(page);
        register_slab(s, count, SLUB_LARGE);
        s->inuse = s->total = 1;
        return (char *)s + offset;
    }

    list_entry_t *head = &partial[id];
    struct slab *s;
    if (list_empty(head)) {
        struct Page *page = alloc_page();
        if (page == NULL) {
            return NULL;
        }
        s = page_address(page);
        register_slab(s, 1, id);
        s->total = (PGSIZE - object_offset()) / class_sizes[id];
        assert(s->total > 0 && s->total <= SLUB_BITMAP_WORDS * 64);
        for (unsigned int i = s->total; i > 0; i--) {
            void *obj = (char *)s + object_offset() + (i - 1) * class_sizes[id];
            *(void **)obj = s->free;
            s->free = obj;
        }
        list_add(head, &s->partial_link);
    } else {
        s = to_struct(list_next(head), struct slab, partial_link);
    }
    assert(s->magic == SLUB_MAGIC && s->class_id == id && s->free != NULL);
    void *obj = s->free;
    size_t index = ((uintptr_t)obj - (uintptr_t)s - object_offset()) / class_sizes[id];
    assert(index < s->total);
    uint64_t bit = (uint64_t)1 << (index % 64);
    assert(!(s->allocated[index / 64] & bit));
    s->allocated[index / 64] |= bit;
    s->free = *(void **)obj;
    s->inuse++;
    if (s->free == NULL) {
        list_del_init(&s->partial_link);
    }
    return obj;
}

/**cs修改部分*/ /* 结束 */
/**cs修改部分*/ /* 开始 */
void
slub_free(void *ptr) {
    if (ptr == NULL) {
        return;
    }
    assert(initialized);
    struct slab *s = find_slab(ptr);
    assert(s != NULL && s->magic == SLUB_MAGIC);
    if (s->class_id == SLUB_LARGE) {
        assert(ptr == (char *)s + object_offset() && s->inuse == 1);
        size_t count = s->pages;
        struct Page *page = slab_page(s);
        list_del_init(&s->all_link);
        s->magic = 0;
        free_pages(page, count);
        return;
    }
    assert(s->class_id < SLUB_CLASSES && s->pages == 1);
    unsigned int id = s->class_id;
    size_t stride = class_sizes[id];
    uintptr_t begin = (uintptr_t)s + object_offset();
    uintptr_t addr = (uintptr_t)ptr;
    assert(addr >= begin && addr - begin < s->total * stride);
    assert((addr - begin) % stride == 0 && s->inuse > 0);
    size_t index = (addr - begin) / stride;
    uint64_t bit = (uint64_t)1 << (index % 64);
    assert(s->allocated[index / 64] & bit);
    s->allocated[index / 64] &= ~bit;
    if (s->free == NULL) {
        list_add(&partial[id], &s->partial_link);
    }
    *(void **)ptr = s->free;
    s->free = ptr;
    s->inuse--;
    if (s->inuse == 0) {
        struct Page *page = slab_page(s);
        list_del_init(&s->partial_link);
        list_del_init(&s->all_link);
        s->magic = 0;
        free_page(page);
    }
}
/**cs修改部分*/ /* 结束 */

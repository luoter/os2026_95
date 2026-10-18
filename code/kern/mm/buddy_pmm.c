/*cs修改：新增文件*/
#include <buddy_pmm.h>
#include <list.h>
#include <pmm.h>

/* 2^16 pages = 256 MiB, larger than this lab's 128 MiB RAM. Requests beyond
 * this supported block size fail before any shift or size rounding. */
#define BUDDY_MAX_ORDER 16
#define BUDDY_FREE_BIT (1UL << 2)
#define BUDDY_SEEN_BIT (1UL << 3) /* temporary consistency-check mark */
#define BUDDY_ALLOC_HEAD_BIT (1UL << 4)
#define BUDDY_MANAGED_BIT (1UL << 5)

static list_entry_t free_lists[BUDDY_MAX_ORDER + 1];
static size_t free_pages_count;

static size_t
block_pages(unsigned int order) {
    return (size_t)1 << order;
}

/* Integer checks also reject fabricated/misaligned descriptor addresses without
 * comparing or subtracting pointers outside the descriptor array. */
static bool
valid_page_range(struct Page *base, size_t n) {
    if (pages == NULL || npage <= nbase) {
        return 0;
    }
    uintptr_t addr = (uintptr_t)base, start = (uintptr_t)pages;
    if (addr < start || (addr - start) % sizeof(struct Page) != 0) {
        return 0;
    }
    size_t index = (addr - start) / sizeof(struct Page);
    return index < npage - nbase && n <= npage - nbase - index;
}

static bool
request_order(size_t n, unsigned int *order) {
    if (n == 0 || n > block_pages(BUDDY_MAX_ORDER)) {
        return 0;
    }
    *order = 0;
    while (block_pages(*order) < n) {
        (*order)++;
    }
    return 1;
}

static void
put_block(struct Page *base, unsigned int order) {
    assert(order <= BUDDY_MAX_ORDER);
    size_t size = block_pages(order);
    assert(valid_page_range(base, size) && page2ppn(base) % size == 0);
    assert(!PageProperty(base) && (base->flags & BUDDY_FREE_BIT));
    assert(base->flags & BUDDY_MANAGED_BIT);
    assert(!(base->flags & BUDDY_ALLOC_HEAD_BIT));
    base->property = size;
    SetPageProperty(base);
    list_init(&base->page_link);
    list_add(&free_lists[order], &base->page_link);
}

static void
take_block(struct Page *base) {
    assert(PageProperty(base));
    list_del_init(&base->page_link);
    ClearPageProperty(base);
    base->property = 0;
}

static struct Page *
same_order_buddy(struct Page *base, unsigned int order) {
    size_t size = block_pages(order);
    ppn_t ppn = page2ppn(base) ^ size;
    if (ppn < nbase || ppn >= npage || size > npage - ppn) {
        return NULL;
    }
    struct Page *other = pages + (ppn - nbase);
    if (!(other->flags & BUDDY_MANAGED_BIT) || !(other->flags & BUDDY_FREE_BIT) ||
        !PageProperty(other) || other->property != size) {
        return NULL;
    }
    return other;
}

static void
put_and_merge(struct Page *base, unsigned int order) {
    while (order < BUDDY_MAX_ORDER) {
        struct Page *other = same_order_buddy(base, order);
        if (other == NULL) {
            break;
        }
        take_block(other);
        if (other < base) {
            base = other;
        }
        order++;
    }
    put_block(base, order);
}

static void
buddy_init(void) {
    for (unsigned int order = 0; order <= BUDDY_MAX_ORDER; order++) {
        list_init(&free_lists[order]);
    }
    free_pages_count = 0;
}

static void
buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0 && valid_page_range(base, n));
    /* Validate the entire handoff before changing any page. The private managed
     * bit distinguishes never-registered pages from allocated managed pages. */
    for (size_t i = 0; i < n; i++) {
        assert(PageReserved(base + i));
        assert(!((base + i)->flags & BUDDY_MANAGED_BIT));
    }
    for (size_t i = 0; i < n; i++) {
        (base + i)->flags = BUDDY_MANAGED_BIT | BUDDY_FREE_BIT;
        (base + i)->property = 0;
        set_page_ref(base + i, 0);
    }
    free_pages_count += n;
    /* Only initialization decomposes an arbitrary range. Allocated blocks are
     * always whole powers of two and can only be freed as whole blocks. */
    while (n > 0) {
        unsigned int order = 0;
        while (order < BUDDY_MAX_ORDER && block_pages(order + 1) <= n &&
               page2ppn(base) % block_pages(order + 1) == 0) {
            order++;
        }
        size_t size = block_pages(order);
        put_and_merge(base, order);
        base += size;
        n -= size;
    }
}

static struct Page *
buddy_alloc_pages(size_t n) {
    assert(n > 0);
    unsigned int order;
    if (!request_order(n, &order) || block_pages(order) > free_pages_count) {
        return NULL;
    }
    unsigned int found = order;
    while (found <= BUDDY_MAX_ORDER && list_empty(&free_lists[found])) {
        found++;
    }
    if (found > BUDDY_MAX_ORDER) {
        return NULL;
    }
    struct Page *base = le2page(list_next(&free_lists[found]), page_link);
    take_block(base);
    while (found > order) {
        found--;
        put_block(base + block_pages(found), found);
    }
    size_t size = block_pages(order);
    for (size_t i = 0; i < size; i++) {
        assert((base + i)->flags & BUDDY_FREE_BIT);
        assert((base + i)->flags & BUDDY_MANAGED_BIT);
        (base + i)->flags &= ~BUDDY_FREE_BIT;
        (base + i)->property = 0;
        set_page_ref(base + i, 0);
    }
    /* Keep the complete rounded block. property is the actual span only on
     * its allocated head; no public Page fields or interfaces are added. */
    base->flags |= BUDDY_ALLOC_HEAD_BIT;
    base->property = size;
    free_pages_count -= size;
    return base;
}

static void
buddy_free_pages(struct Page *base, size_t n) {
    unsigned int order;
    assert(request_order(n, &order));
    size_t size = block_pages(order);
    assert(valid_page_range(base, size));
    assert(base->flags & BUDDY_ALLOC_HEAD_BIT);
    assert(base->property == size && page2ppn(base) % size == 0);
    /* Reject an invalid free before mutating flags, counters or links. */
    for (size_t i = 0; i < size; i++) {
        struct Page *page = base + i;
        assert((page->flags & BUDDY_MANAGED_BIT) && !PageReserved(page));
        assert(!(page->flags & BUDDY_FREE_BIT) && !PageProperty(page));
        assert(i == 0 || !(page->flags & BUDDY_ALLOC_HEAD_BIT));
    }
    for (size_t i = 0; i < size; i++) {
        (base + i)->flags &= ~BUDDY_ALLOC_HEAD_BIT;
        (base + i)->flags |= BUDDY_FREE_BIT;
        (base + i)->property = 0;
        set_page_ref(base + i, 0);
    }
    free_pages_count += size;
    put_and_merge(base, order);
}

static size_t
buddy_nr_free_pages(void) {
    return free_pages_count;
}

/* Check both the free and allocated partitions and forbid unmerged buddies. */
static void
check_structure(void) {
    size_t listed = 0;
    for (unsigned int order = 0; order <= BUDDY_MAX_ORDER; order++) {
        size_t size = block_pages(order);
        list_entry_t *head = &free_lists[order];
        for (list_entry_t *le = list_next(head); le != head; le = list_next(le)) {
            struct Page *base = le2page(le, page_link);
            assert(valid_page_range(base, size) && page2ppn(base) % size == 0);
            assert(PageProperty(base) && base->property == size);
            assert(order == BUDDY_MAX_ORDER || same_order_buddy(base, order) == NULL);
            for (size_t i = 0; i < size; i++) {
                struct Page *page = base + i;
                assert(!PageReserved(page) && (page->flags & BUDDY_MANAGED_BIT));
                assert((page->flags & BUDDY_FREE_BIT) && !(page->flags & BUDDY_ALLOC_HEAD_BIT));
                assert(!(page->flags & BUDDY_SEEN_BIT));
                page->flags |= BUDDY_SEEN_BIT;
            }
            listed += size;
        }
    }
    size_t marked = 0, managed = 0, allocated = 0;
    for (size_t i = 0; i < npage - nbase; i++) {
        struct Page *page = pages + i;
        if (!(page->flags & BUDDY_MANAGED_BIT)) {
            assert(!(page->flags & (BUDDY_FREE_BIT | BUDDY_ALLOC_HEAD_BIT | BUDDY_SEEN_BIT)));
            continue;
        }
        managed++;
        assert(!PageReserved(page));
        if (page->flags & BUDDY_FREE_BIT) {
            assert(page->flags & BUDDY_SEEN_BIT);
            marked++;
        } else if (page->flags & BUDDY_ALLOC_HEAD_BIT) {
            size_t size = page->property;
            unsigned int order;
            assert(request_order(size, &order) && block_pages(order) == size);
            assert(valid_page_range(page, size) && page2ppn(page) % size == 0);
            for (size_t j = 0; j < size; j++) {
                struct Page *part = page + j;
                assert((part->flags & BUDDY_MANAGED_BIT) && !(part->flags & BUDDY_FREE_BIT));
                assert(!(part->flags & BUDDY_SEEN_BIT) && !PageProperty(part));
                assert(j == 0 || !(part->flags & BUDDY_ALLOC_HEAD_BIT));
                part->flags |= BUDDY_SEEN_BIT;
            }
            allocated += size;
        } else {
            assert(page->flags & BUDDY_SEEN_BIT);
        }
    }
    assert(listed == marked && marked == free_pages_count);
    assert(managed == marked + allocated);
    for (size_t i = 0; i < npage - nbase; i++) {
        pages[i].flags &= ~BUDDY_SEEN_BIT;
    }
}

static void
buddy_check(void) {
    static const size_t requests[] = {1, 2, 3, 5, 8, 9, 17};
    check_structure();
    size_t before = nr_free_pages();
    assert(before >= 32);
    assert(alloc_pages(before + 1) == NULL && nr_free_pages() == before);
    assert(alloc_pages((size_t)-1) == NULL && nr_free_pages() == before);
    for (size_t i = 0; i < sizeof(requests) / sizeof(requests[0]); i++) {
        size_t n = requests[i];
        unsigned int order;
        assert(request_order(n, &order));
        size_t size = block_pages(order);
        struct Page *p = alloc_pages(n);
        assert(p != NULL && page2ppn(p) % size == 0);
        assert(nr_free_pages() == before - size);
        check_structure();
        free_pages(p, n);
        assert(nr_free_pages() == before);
        check_structure();
    }
    struct Page *ones[8];
    for (unsigned int i = 0; i < 8; i++) {
        ones[i] = alloc_page();
        assert(ones[i] != NULL);
        for (unsigned int j = 0; j < i; j++) {
            assert(ones[i] != ones[j]);
        }
    }
    for (unsigned int i = 8; i > 0; i--) {
        free_page(ones[i - 1]);
    }
    check_structure();
    /* Structural checks above prove all available same-order buddies merged. */
    struct Page *large = alloc_pages(8);
    assert(large != NULL);
    free_pages(large, 8);
    assert(nr_free_pages() == before);
    check_structure();
}

const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};

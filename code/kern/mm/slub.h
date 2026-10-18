#ifndef __KERN_MM_SLUB_H__
#define __KERN_MM_SLUB_H__

#include <defs.h>

/**cs修改部分*/ /* 开始 */
/* Single-hart, serialized callers; init after the physical page manager.
 * All returns are 16-byte aligned. size==0 means 1; OOM/overflow returns NULL.
 * free(NULL) is a no-op. Other frees require a live object's original pointer.
 * Small objects share a page; larger objects own contiguous pages. */
void slub_init(void);
void *slub_alloc(size_t size);
void slub_free(void *ptr);
void slub_check(void);

/**cs修改部分*/ /* 结束 */
#endif /* __KERN_MM_SLUB_H__ */

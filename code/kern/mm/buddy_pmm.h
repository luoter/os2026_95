/* cs修改部分 开始：新增 Buddy 管理器头文件 */

#ifndef __KERN_MM_BUDDY_PMM_H__
#define __KERN_MM_BUDDY_PMM_H__

#include <pmm.h>

/* 向 pmm.c 提供 Buddy 物理内存管理器 */
extern const struct pmm_manager buddy_pmm_manager;

/*
 * 接口约定：
 * alloc_pages(n) 实际分配不小于 n 的最小2的幂页数。
 * 例如申请5页，实际占用8页。
 *
 * free_pages(base, n) 归还完整分配块。
 * base 必须是分配返回的块首地址，n 可使用原申请页数。
 * 不允许分段释放。
 */

#endif /* __KERN_MM_BUDDY_PMM_H__ */

/* cs修改部分 结束 */
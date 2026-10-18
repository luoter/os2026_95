# 1. 1.
```text

Prompt——任务、操作要求与输出要求

任务：
完成以下lab2代码中的Best-Fit连续物理内存分配器：


操作要求：
（1）先确认终端能够访问实际项目目录。若当前通过Live Share协作，应确认命令运行的机器和目录，不能仅凭编辑器显示了共享文件，就认为本地终端可以访问这些文件。
（2）阅读相关源码后，在kern/mm/best_fit_pmm.c标有 YOUR CODE的位置补全管理状态和函数，并在合适位置定义best_fit_pmm_manager。
（3）在kern/mm/pmm.c的init_pmm_manager()中，将管理器切换为best_fit_pmm_manager。
（4）不得修改、删除或绕过basic_check()和best_fit_check()，不得硬编码测试数据。
（5）只修改完成任务必需的代码，算法时空复杂度不限，优先保证正确性和可读性。

输出要求：
说明修改的文件、核心实现和验证结果；执行项目支持的编译及测试，检查实际启用的管理器是否为Best-Fit。若环境无法运行测试，明确说明原因，不得声称测试通过。


2.Rely——最小可信依赖

仅依据以下源码中实际存在的接口和约定进行实现：

（1）kern/mm/pmm.h：以struct pmm_manager的真实定义为准，确定管理函数的类型和职责。

（2）kern/mm/memlayout.h：使用已有的struct Page、free_area_t、页面标志及相关宏。

（3）libs/list.h：使用项目提供的双向链表操作，先确认各插入函数的含义。

（4）kern/mm/default_pmm.c：参考初始化、空闲块拆分和相邻块合并的实现，但分配策略必须改为Best-Fit，不照搬潜在错误。

（5）kern/mm/best_fit_pmm.c及其头文件：保留现有测试和对外声明，遵守测试对free_list、nr_free、property和页面标志的使用约定。不得臆造不存在的接口，也不得把参考代码视为无需检查的正确实现。


3.Guarantee——必须交付的接口

完整实现并注册以下职责：

（1）init：初始化空闲管理结构。
（2）init_memmap：登记可用的连续物理页。
（3）alloc_pages：按 Best-Fit 策略分配连续物理页。
（4）free_pages：释放页面并合并相邻空闲块。
（5）nr_free_pages：返回当前空闲页总数。
（6）check：连接文件中已有的 best_fit_check()。

内部函数名可以自行设计，但函数类型必须匹配pmm.h。必须定义与头文件声明一致的best_fit_pmm_manager，并确保pmm.c 实际选择该管理器。实现必须兼容两个原有测试函数，包括它们对free_list和nr_free的直接访问。


4.Specification——前置条件、后置状态与失败行为

（1）管理结构初始化
后置状态：空闲链表为空，nr_free 为 0。

（2）空闲内存登记
前置条件：n > 0，base指向合法、连续且尚未登记的n个保留页。
后置状态：清除这些页面的保留状态，引用计数归零；将其登记为空闲块，正确设置首页的property和PG_property，并将nr_free增加n。

（3）连续页分配
前置条件：n > 0。
选择规则：在全部空闲块中，选择长度不小于n且长度最小的块；长度相同时选择地址较低的块。
成功状态：返回所分配连续区域的首页指针，nr_free 减少n；恰好匹配时移除整个空闲块，有剩余时登记剩余块，并正确更新首页标志。
失败行为：总空闲页不足或不存在足够大的连续块时返回NULL，空闲链表、页面状态和nr_free保持不变。

（4）页面释放
前置条件：n > 0，释放范围合法，范围内页面均已分配且不是保留页；允许对已分配的连续区域分段释放。
后置状态：页面引用计数归零，释放区域加入空闲链表，nr_free增加n；若与前后空闲块物理地址连续，则合并，删除多余节点并更新首页标志。
非法输入：按照项目现有约定使用断言检查，不得静默破坏管理状态。

（5）全局状态约束
空闲链表始终按物理地址升序排列，仅链接空闲块首页；空闲块之间不得重叠；有效空闲块首页的property表示块长，PG_property表示首页身份；nr_free始终等于链表中全部空闲块页数之和。块的拆分与合并不得造成页面丢失或重复登记。

```
# [2413330-张子馨]
## 1.
```text
修改kern/mm/pmm.c文件中的static void page_init(void); 函数，实现物理内存探测与 Page 描述符初始化功能。 
 要求：你必须在项目中修改实际文件，保留其他现有代码和注释，只补全指定函数 
 功能与接口说明：根据设备树提供的物理内存信息建立可管理物理页的描述符布局，并把排除 OpenSBI、内核镜像和描述符数组占用空间后的完整空闲页面交给当前pmm_manager管理，为后续页面分配提供正确的初始状态。page_init()不接收参数也不返回结果，由pmm_init()调用；成功返回时应正确设置va_pa_offset、npage和pages，输出探测到的物理内存范围，并完成当前物理内存管理器初始空闲区的注册 
 实现约束与可用资源：必须区分虚拟地址、物理地址、物理页号和Page描述符地址，正确处理可管理上界和页面对齐，并确保内核及描述符数组不会进入空闲区；设备树信息无效时应终止初始化，没有可用完整页面时不得调用init_memmap()。实现过程中可以使用get_memory_base()、get_memory_size()、panic()、cprintf()、init_memmap()、pa2page()、链接符号end、struct Page及相关全局变量，并使用框架提供的内存上界、地址转换、页面对齐和页面状态宏完成初始化 
```

## 2.
```text
[PROMPT]

**任务**：修改 `kern/mm/pmm.c` 文件，实现物理内存探测与 Page 描述符初始化功能。目标函数为 `static void page_init(void)`。

**操作要求**：你必须在项目中修改实际文件，保留其他现有代码和注释，只补全指定函数。所有回复和代码注释必须使用中文。

**输出要求**：直接进行文件操作。严格按照下面的 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的真实代码与行为规格进行实现，不要引入无关功能。

[RELY]

// 可用函数
uint64_t get_memory_base(void); // 从设备树获取物理内存基址
uint64_t get_memory_size(void); // 从设备树获取物理内存大小
void panic(const char *fmt, ...); // 终止内核初始化
int cprintf(const char *fmt, ...); // 格式化输出
void init_memmap(struct Page *base, size_t n); // 向当前 pmm_manager 注册空闲物理页
struct Page *pa2page(uintptr_t pa); // 物理地址转换为 Page 描述符指针

// 全局变量与链接符号
extern char end[];              // 链接脚本定义的符号，指向内核镜像结束的虚拟地址
struct Page *pages;             // 指向 Page 描述符数组的起始位置
size_t npage;                   // 可管理物理内存的页数上界
uint64_t va_pa_offset;          // 虚拟地址与物理地址的偏移量

// 数据结构
struct Page;                    // 物理页描述符

[GUARANTEE]

必须实现或修改的接口：
```c
static void page_init(void);

[SPECIFICATION]

## page_init

**Pre-Condition**:
- `pmm_init()` 已调用 `init_pmm_manager()`，当前 `pmm_manager` 已就绪。
- 设备树已初始化，`get_memory_base()` 和 `get_memory_size()` 可返回探测到的内存信息。
- 链接符号 `end` 已由链接器正确确定。

**Post-Condition**:
- `va_pa_offset` 被正确设置，反映虚拟地址到物理地址的映射关系。
- `npage` 被正确设置为可管理物理内存的页数上界。
- `pages` 指向正确布局的 Page 描述符数组，且数组位于 `end` 之后并按页对齐。
- 探测到的物理内存范围已通过 `cprintf()` 输出。
- 当前 `pmm_manager` 只接管了排除 OpenSBI、内核镜像和描述符数组占用空间后、按页对齐的完整空闲页面。

**Case 1（正常情况）**:
- 触发条件：设备树提供的物理内存信息有效（基址和大小合法），且有足够的完整空闲页面。
- 执行行为：计算可管理物理内存上界，设置 `va_pa_offset`；计算描述符数组所需空间，将其起点放在 `end` 之后并按页对齐；将所有描述符初始标记为保留状态；计算描述符数组之后按页对齐的物理地址起点，以及设备树报告的内存末端向下按页对齐的物理地址终点；若两者之间存在完整页面，则通过 `pa2page()` 转换为描述符起点，并调用 `init_memmap()` 注册。
- 最终状态：`va_pa_offset`、`npage`、`pages` 设置正确，内存范围已输出，完整空闲页面已交由 `pmm_manager` 管理。

**Case 2（设备树信息无效）**:
- 触发条件：`get_memory_base()` 或 `get_memory_size()` 返回无效值（如大小为 0）。
- 执行行为：调用 `panic()` 终止初始化。
- 最终状态：内核停止，不会执行后续的描述符布局和空闲区注册。

**Case 3（无可用完整页面）**:
- 触发条件：排除 OpenSBI、内核镜像和描述符数组占用空间后，剩余空间不足一个完整页面。
- 执行行为：不调用 `init_memmap()`，可通过 `cprintf()` 输出警告信息。
- 最终状态：全局变量已设置，但 `pmm_manager` 不会接管任何空闲页面，避免非法注册。

**Requirements**:
- 必须严格区分虚拟地址、物理地址、物理页号和 Page 描述符地址，不能混用。
- 描述符数组本身也要占用物理内存，其占用的页面不能加入空闲页分配器。
- 正确处理可管理上界，设备树报告的内存末端需向下按页对齐，描述符数组之后的可用起点需向上按页对齐。
- 确保 OpenSBI 占用区、内核镜像和描述符数组不会进入空闲区。
- 没有可用完整页面时，禁止调用 `init_memmap()`。
```

## 3
```text
怎么调试该功能模块实现正确？
```

## 4.
```text
这个代码中OS 是提前知道当前硬件的可用物理内存范围吗，请给出相关函数以及功能解释
```



bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	63c50513          	addi	a0,a0,1596 # ffffffffc0201688 <etext+0x4>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	64650513          	addi	a0,a0,1606 # ffffffffc02016a8 <etext+0x24>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	61658593          	addi	a1,a1,1558 # ffffffffc0201684 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	65250513          	addi	a0,a0,1618 # ffffffffc02016c8 <etext+0x44>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	65e50513          	addi	a0,a0,1630 # ffffffffc02016e8 <etext+0x64>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	07658593          	addi	a1,a1,118 # ffffffffc020610c <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	66a50513          	addi	a0,a0,1642 # ffffffffc0201708 <etext+0x84>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00006597          	auipc	a1,0x6
ffffffffc02000ae:	46158593          	addi	a1,a1,1121 # ffffffffc020650b <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	65c50513          	addi	a0,a0,1628 # ffffffffc0201728 <etext+0xa4>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00006517          	auipc	a0,0x6
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0206018 <free_area>
ffffffffc02000e0:	00006617          	auipc	a2,0x6
ffffffffc02000e4:	02c60613          	addi	a2,a2,44 # ffffffffc020610c <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	582010ef          	jal	ra,ffffffffc0201672 <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	65c50513          	addi	a0,a0,1628 # ffffffffc0201758 <etext+0xd4>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	673000ef          	jal	ra,ffffffffc0200f7e <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	11c010ef          	jal	ra,ffffffffc020125c <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	0e6010ef          	jal	ra,ffffffffc020125c <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00006317          	auipc	t1,0x6
ffffffffc02001c6:	efe30313          	addi	t1,t1,-258 # ffffffffc02060c0 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	58650513          	addi	a0,a0,1414 # ffffffffc0201778 <etext+0xf4>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	54850513          	addi	a0,a0,1352 # ffffffffc0201750 <etext+0xcc>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	3c20106f          	j	ffffffffc02015de <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	57650513          	addi	a0,a0,1398 # ffffffffc0201798 <etext+0x114>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00006597          	auipc	a1,0x6
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	55850513          	addi	a0,a0,1368 # ffffffffc02017a8 <etext+0x124>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00006417          	auipc	s0,0x6
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0206008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	55250513          	addi	a0,a0,1362 # ffffffffc02017b8 <etext+0x134>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	55a50513          	addi	a0,a0,1370 # ffffffffc02017d0 <etext+0x14c>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9de1>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	4f090913          	addi	s2,s2,1264 # ffffffffc0201820 <etext+0x19c>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	4da48493          	addi	s1,s1,1242 # ffffffffc0201818 <etext+0x194>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	50650513          	addi	a0,a0,1286 # ffffffffc0201898 <etext+0x214>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	53250513          	addi	a0,a0,1330 # ffffffffc02018d0 <etext+0x24c>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	41250513          	addi	a0,a0,1042 # ffffffffc02017f0 <etext+0x16c>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	20c010ef          	jal	ra,ffffffffc02015f8 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	252010ef          	jal	ra,ffffffffc020164c <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	19e010ef          	jal	ra,ffffffffc020162e <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	38450513          	addi	a0,a0,900 # ffffffffc0201828 <etext+0x1a4>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	2d650513          	addi	a0,a0,726 # ffffffffc0201848 <etext+0x1c4>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	2dc50513          	addi	a0,a0,732 # ffffffffc0201860 <etext+0x1dc>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	2ea50513          	addi	a0,a0,746 # ffffffffc0201880 <etext+0x1fc>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	32e50513          	addi	a0,a0,814 # ffffffffc02018d0 <etext+0x24c>
        memory_base = mem_base;
ffffffffc02005aa:	00006797          	auipc	a5,0x6
ffffffffc02005ae:	b087bf23          	sd	s0,-1250(a5) # ffffffffc02060c8 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00006797          	auipc	a5,0x6
ffffffffc02005b6:	b167bf23          	sd	s6,-1250(a5) # ffffffffc02060d0 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00006517          	auipc	a0,0x6
ffffffffc02005c0:	b0c53503          	ld	a0,-1268(a0) # ffffffffc02060c8 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00006517          	auipc	a0,0x6
ffffffffc02005ca:	b0a53503          	ld	a0,-1270(a0) # ffffffffc02060d0 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005d0:	00006797          	auipc	a5,0x6
ffffffffc02005d4:	a4878793          	addi	a5,a5,-1464 # ffffffffc0206018 <free_area>
ffffffffc02005d8:	e79c                	sd	a5,8(a5)
ffffffffc02005da:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005dc:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005e0:	8082                	ret

ffffffffc02005e2 <best_fit_insert_block>:
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc02005e2:	00006697          	auipc	a3,0x6
ffffffffc02005e6:	a3668693          	addi	a3,a3,-1482 # ffffffffc0206018 <free_area>
ffffffffc02005ea:	669c                	ld	a5,8(a3)

/* Insert a block by address, then merge with its adjacent free blocks. */
static void
best_fit_insert_block(struct Page *base) {
    list_entry_t *le = list_next(&free_list);
    while (le != &free_list && le2page(le, page_link) < base) {
ffffffffc02005ec:	00d78b63          	beq	a5,a3,ffffffffc0200602 <best_fit_insert_block+0x20>
ffffffffc02005f0:	fe878713          	addi	a4,a5,-24
ffffffffc02005f4:	0aa77363          	bgeu	a4,a0,ffffffffc020069a <best_fit_insert_block+0xb8>
ffffffffc02005f8:	679c                	ld	a5,8(a5)
ffffffffc02005fa:	fe878713          	addi	a4,a5,-24
ffffffffc02005fe:	fed79be3          	bne	a5,a3,ffffffffc02005f4 <best_fit_insert_block+0x12>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200602:	6290                	ld	a2,0(a3)
        le = list_next(le);
    }
    list_add_before(le, &base->page_link);
ffffffffc0200604:	01850793          	addi	a5,a0,24
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
ffffffffc0200608:	e29c                	sd	a5,0(a3)
ffffffffc020060a:	e61c                	sd	a5,8(a2)
    elm->next = next;
ffffffffc020060c:	f114                	sd	a3,32(a0)
    elm->prev = prev;
ffffffffc020060e:	ed10                	sd	a2,24(a0)

    le = list_prev(&base->page_link);
    if (le != &free_list) {
ffffffffc0200610:	00006797          	auipc	a5,0x6
ffffffffc0200614:	a0878793          	addi	a5,a5,-1528 # ffffffffc0206018 <free_area>
ffffffffc0200618:	02d60f63          	beq	a2,a3,ffffffffc0200656 <best_fit_insert_block+0x74>
        struct Page *prev = le2page(le, page_link);
        if (prev + prev->property == base) {
ffffffffc020061c:	ff862883          	lw	a7,-8(a2) # fefff8 <kern_entry-0xffffffffbf210008>
        struct Page *prev = le2page(le, page_link);
ffffffffc0200620:	fe860813          	addi	a6,a2,-24
        if (prev + prev->property == base) {
ffffffffc0200624:	02089593          	slli	a1,a7,0x20
ffffffffc0200628:	9181                	srli	a1,a1,0x20
ffffffffc020062a:	00259713          	slli	a4,a1,0x2
ffffffffc020062e:	972e                	add	a4,a4,a1
ffffffffc0200630:	070e                	slli	a4,a4,0x3
ffffffffc0200632:	9742                	add	a4,a4,a6
ffffffffc0200634:	04e50563          	beq	a0,a4,ffffffffc020067e <best_fit_insert_block+0x9c>
            base = prev;
        }
    }

    le = list_next(&base->page_link);
    if (le != &free_list) {
ffffffffc0200638:	00d78f63          	beq	a5,a3,ffffffffc0200656 <best_fit_insert_block+0x74>
ffffffffc020063c:	fe878713          	addi	a4,a5,-24
        struct Page *next = le2page(le, page_link);
        if (base + base->property == next) {
ffffffffc0200640:	490c                	lw	a1,16(a0)
ffffffffc0200642:	02059613          	slli	a2,a1,0x20
ffffffffc0200646:	9201                	srli	a2,a2,0x20
ffffffffc0200648:	00261693          	slli	a3,a2,0x2
ffffffffc020064c:	96b2                	add	a3,a3,a2
ffffffffc020064e:	068e                	slli	a3,a3,0x3
ffffffffc0200650:	96aa                	add	a3,a3,a0
ffffffffc0200652:	00d70363          	beq	a4,a3,ffffffffc0200658 <best_fit_insert_block+0x76>
            ClearPageProperty(next);
            next->property = 0;
            list_del(&next->page_link);
        }
    }
}
ffffffffc0200656:	8082                	ret
            base->property += next->property;
ffffffffc0200658:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(next);
ffffffffc020065c:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200660:	0007b803          	ld	a6,0(a5)
ffffffffc0200664:	6790                	ld	a2,8(a5)
            base->property += next->property;
ffffffffc0200666:	9db5                	addw	a1,a1,a3
ffffffffc0200668:	c90c                	sw	a1,16(a0)
            ClearPageProperty(next);
ffffffffc020066a:	9b75                	andi	a4,a4,-3
ffffffffc020066c:	fee7b823          	sd	a4,-16(a5)
            next->property = 0;
ffffffffc0200670:	fe07ac23          	sw	zero,-8(a5)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200674:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc0200678:	01063023          	sd	a6,0(a2)
}
ffffffffc020067c:	8082                	ret
            prev->property += base->property;
ffffffffc020067e:	490c                	lw	a1,16(a0)
            ClearPageProperty(base);
ffffffffc0200680:	6518                	ld	a4,8(a0)
            prev->property += base->property;
ffffffffc0200682:	011588bb          	addw	a7,a1,a7
ffffffffc0200686:	ff162c23          	sw	a7,-8(a2)
            ClearPageProperty(base);
ffffffffc020068a:	9b75                	andi	a4,a4,-3
ffffffffc020068c:	e518                	sd	a4,8(a0)
            base->property = 0;
ffffffffc020068e:	00052823          	sw	zero,16(a0)
    prev->next = next;
ffffffffc0200692:	e61c                	sd	a5,8(a2)
    next->prev = prev;
ffffffffc0200694:	e390                	sd	a2,0(a5)
            base = prev;
ffffffffc0200696:	8542                	mv	a0,a6
ffffffffc0200698:	b745                	j	ffffffffc0200638 <best_fit_insert_block+0x56>
    __list_add(elm, listelm->prev, listelm);
ffffffffc020069a:	6390                	ld	a2,0(a5)
    list_add_before(le, &base->page_link);
ffffffffc020069c:	01850593          	addi	a1,a0,24
    prev->next = next->prev = elm;
ffffffffc02006a0:	e38c                	sd	a1,0(a5)
ffffffffc02006a2:	e60c                	sd	a1,8(a2)
    elm->next = next;
ffffffffc02006a4:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02006a6:	ed10                	sd	a2,24(a0)
    if (le != &free_list) {
ffffffffc02006a8:	f6d61ae3          	bne	a2,a3,ffffffffc020061c <best_fit_insert_block+0x3a>
ffffffffc02006ac:	bf51                	j	ffffffffc0200640 <best_fit_insert_block+0x5e>

ffffffffc02006ae <best_fit_nr_free_pages>:
}

static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02006ae:	00006517          	auipc	a0,0x6
ffffffffc02006b2:	97a56503          	lwu	a0,-1670(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc02006b6:	8082                	ret

ffffffffc02006b8 <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc02006b8:	c145                	beqz	a0,ffffffffc0200758 <best_fit_alloc_pages+0xa0>
    if (n > nr_free) {
ffffffffc02006ba:	00006597          	auipc	a1,0x6
ffffffffc02006be:	95e58593          	addi	a1,a1,-1698 # ffffffffc0206018 <free_area>
ffffffffc02006c2:	0105a883          	lw	a7,16(a1)
ffffffffc02006c6:	86aa                	mv	a3,a0
ffffffffc02006c8:	02089793          	slli	a5,a7,0x20
ffffffffc02006cc:	9381                	srli	a5,a5,0x20
ffffffffc02006ce:	08a7e363          	bltu	a5,a0,ffffffffc0200754 <best_fit_alloc_pages+0x9c>
    return listelm->next;
ffffffffc02006d2:	659c                	ld	a5,8(a1)
    struct Page *best = NULL;
ffffffffc02006d4:	4501                	li	a0,0
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006d6:	06b78e63          	beq	a5,a1,ffffffffc0200752 <best_fit_alloc_pages+0x9a>
        if (p->property >= n &&
ffffffffc02006da:	ff87a703          	lw	a4,-8(a5)
        struct Page *p = le2page(le, page_link);
ffffffffc02006de:	fe878813          	addi	a6,a5,-24
        if (p->property >= n &&
ffffffffc02006e2:	02071613          	slli	a2,a4,0x20
ffffffffc02006e6:	9201                	srli	a2,a2,0x20
ffffffffc02006e8:	00d66763          	bltu	a2,a3,ffffffffc02006f6 <best_fit_alloc_pages+0x3e>
ffffffffc02006ec:	c501                	beqz	a0,ffffffffc02006f4 <best_fit_alloc_pages+0x3c>
            (best == NULL || p->property < best->property)) {
ffffffffc02006ee:	4910                	lw	a2,16(a0)
ffffffffc02006f0:	00c77363          	bgeu	a4,a2,ffffffffc02006f6 <best_fit_alloc_pages+0x3e>
            best = p;
ffffffffc02006f4:	8542                	mv	a0,a6
ffffffffc02006f6:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006f8:	feb791e3          	bne	a5,a1,ffffffffc02006da <best_fit_alloc_pages+0x22>
    if (best == NULL) {
ffffffffc02006fc:	c939                	beqz	a0,ffffffffc0200752 <best_fit_alloc_pages+0x9a>
    if (best->property > n) {
ffffffffc02006fe:	01052803          	lw	a6,16(a0)
    return listelm->prev;
ffffffffc0200702:	6d18                	ld	a4,24(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200704:	7110                	ld	a2,32(a0)
ffffffffc0200706:	02081793          	slli	a5,a6,0x20
ffffffffc020070a:	9381                	srli	a5,a5,0x20
    prev->next = next;
ffffffffc020070c:	e710                	sd	a2,8(a4)
    next->prev = prev;
ffffffffc020070e:	e218                	sd	a4,0(a2)
        rest->property = best->property - n;
ffffffffc0200710:	0006831b          	sext.w	t1,a3
    if (best->property > n) {
ffffffffc0200714:	02f6f563          	bgeu	a3,a5,ffffffffc020073e <best_fit_alloc_pages+0x86>
        struct Page *rest = best + n;
ffffffffc0200718:	00269793          	slli	a5,a3,0x2
ffffffffc020071c:	97b6                	add	a5,a5,a3
ffffffffc020071e:	078e                	slli	a5,a5,0x3
ffffffffc0200720:	97aa                	add	a5,a5,a0
        SetPageProperty(rest);
ffffffffc0200722:	6794                	ld	a3,8(a5)
        rest->property = best->property - n;
ffffffffc0200724:	4068083b          	subw	a6,a6,t1
ffffffffc0200728:	0107a823          	sw	a6,16(a5)
        SetPageProperty(rest);
ffffffffc020072c:	0026e693          	ori	a3,a3,2
ffffffffc0200730:	e794                	sd	a3,8(a5)
        list_add(prev, &rest->page_link);
ffffffffc0200732:	01878693          	addi	a3,a5,24
    prev->next = next->prev = elm;
ffffffffc0200736:	e214                	sd	a3,0(a2)
ffffffffc0200738:	e714                	sd	a3,8(a4)
    elm->next = next;
ffffffffc020073a:	f390                	sd	a2,32(a5)
    elm->prev = prev;
ffffffffc020073c:	ef98                	sd	a4,24(a5)
    ClearPageProperty(best);
ffffffffc020073e:	651c                	ld	a5,8(a0)
    best->property = 0;
ffffffffc0200740:	00052823          	sw	zero,16(a0)
    nr_free -= n;
ffffffffc0200744:	406888bb          	subw	a7,a7,t1
    ClearPageProperty(best);
ffffffffc0200748:	9bf5                	andi	a5,a5,-3
ffffffffc020074a:	e51c                	sd	a5,8(a0)
    nr_free -= n;
ffffffffc020074c:	0115a823          	sw	a7,16(a1)
    return best;
ffffffffc0200750:	8082                	ret
}
ffffffffc0200752:	8082                	ret
        return NULL;
ffffffffc0200754:	4501                	li	a0,0
ffffffffc0200756:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc0200758:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc020075a:	00001697          	auipc	a3,0x1
ffffffffc020075e:	18e68693          	addi	a3,a3,398 # ffffffffc02018e8 <etext+0x264>
ffffffffc0200762:	00001617          	auipc	a2,0x1
ffffffffc0200766:	18e60613          	addi	a2,a2,398 # ffffffffc02018f0 <etext+0x26c>
ffffffffc020076a:	04400593          	li	a1,68
ffffffffc020076e:	00001517          	auipc	a0,0x1
ffffffffc0200772:	19a50513          	addi	a0,a0,410 # ffffffffc0201908 <etext+0x284>
best_fit_alloc_pages(size_t n) {
ffffffffc0200776:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200778:	a4bff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020077c <best_fit_check>:
    free_page(p1);
    free_page(p2);
}

static void
best_fit_check(void) {
ffffffffc020077c:	715d                	addi	sp,sp,-80
ffffffffc020077e:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc0200780:	00006417          	auipc	s0,0x6
ffffffffc0200784:	89840413          	addi	s0,s0,-1896 # ffffffffc0206018 <free_area>
ffffffffc0200788:	641c                	ld	a5,8(s0)
ffffffffc020078a:	e486                	sd	ra,72(sp)
ffffffffc020078c:	fc26                	sd	s1,56(sp)
ffffffffc020078e:	f84a                	sd	s2,48(sp)
ffffffffc0200790:	f44e                	sd	s3,40(sp)
ffffffffc0200792:	f052                	sd	s4,32(sp)
ffffffffc0200794:	ec56                	sd	s5,24(sp)
ffffffffc0200796:	e85a                	sd	s6,16(sp)
ffffffffc0200798:	e45e                	sd	s7,8(sp)
ffffffffc020079a:	e062                	sd	s8,0(sp)
    int score = 0, sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc020079c:	26878963          	beq	a5,s0,ffffffffc0200a0e <best_fit_check+0x292>
    int count = 0, total = 0;
ffffffffc02007a0:	4481                	li	s1,0
ffffffffc02007a2:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc02007a4:	ff07b703          	ld	a4,-16(a5)
ffffffffc02007a8:	8b09                	andi	a4,a4,2
ffffffffc02007aa:	26070663          	beqz	a4,ffffffffc0200a16 <best_fit_check+0x29a>
        count++, total += p->property;
ffffffffc02007ae:	ff87a703          	lw	a4,-8(a5)
ffffffffc02007b2:	679c                	ld	a5,8(a5)
ffffffffc02007b4:	2905                	addiw	s2,s2,1
ffffffffc02007b6:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02007b8:	fe8796e3          	bne	a5,s0,ffffffffc02007a4 <best_fit_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc02007bc:	89a6                	mv	s3,s1
ffffffffc02007be:	7b4000ef          	jal	ra,ffffffffc0200f72 <nr_free_pages>
ffffffffc02007c2:	33351a63          	bne	a0,s3,ffffffffc0200af6 <best_fit_check+0x37a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02007c6:	4505                	li	a0,1
ffffffffc02007c8:	792000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02007cc:	8a2a                	mv	s4,a0
ffffffffc02007ce:	36050463          	beqz	a0,ffffffffc0200b36 <best_fit_check+0x3ba>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02007d2:	4505                	li	a0,1
ffffffffc02007d4:	786000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02007d8:	89aa                	mv	s3,a0
ffffffffc02007da:	32050e63          	beqz	a0,ffffffffc0200b16 <best_fit_check+0x39a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02007de:	4505                	li	a0,1
ffffffffc02007e0:	77a000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02007e4:	8aaa                	mv	s5,a0
ffffffffc02007e6:	2c050863          	beqz	a0,ffffffffc0200ab6 <best_fit_check+0x33a>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc02007ea:	253a0663          	beq	s4,s3,ffffffffc0200a36 <best_fit_check+0x2ba>
ffffffffc02007ee:	24aa0463          	beq	s4,a0,ffffffffc0200a36 <best_fit_check+0x2ba>
ffffffffc02007f2:	24a98263          	beq	s3,a0,ffffffffc0200a36 <best_fit_check+0x2ba>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc02007f6:	000a2783          	lw	a5,0(s4)
ffffffffc02007fa:	24079e63          	bnez	a5,ffffffffc0200a56 <best_fit_check+0x2da>
ffffffffc02007fe:	0009a783          	lw	a5,0(s3)
ffffffffc0200802:	24079a63          	bnez	a5,ffffffffc0200a56 <best_fit_check+0x2da>
ffffffffc0200806:	411c                	lw	a5,0(a0)
ffffffffc0200808:	24079763          	bnez	a5,ffffffffc0200a56 <best_fit_check+0x2da>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020080c:	00006797          	auipc	a5,0x6
ffffffffc0200810:	8d47b783          	ld	a5,-1836(a5) # ffffffffc02060e0 <pages>
ffffffffc0200814:	40fa0733          	sub	a4,s4,a5
ffffffffc0200818:	870d                	srai	a4,a4,0x3
ffffffffc020081a:	00002597          	auipc	a1,0x2
ffffffffc020081e:	8765b583          	ld	a1,-1930(a1) # ffffffffc0202090 <error_string+0x38>
ffffffffc0200822:	02b70733          	mul	a4,a4,a1
ffffffffc0200826:	00002617          	auipc	a2,0x2
ffffffffc020082a:	87263603          	ld	a2,-1934(a2) # ffffffffc0202098 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc020082e:	00006697          	auipc	a3,0x6
ffffffffc0200832:	8aa6b683          	ld	a3,-1878(a3) # ffffffffc02060d8 <npage>
ffffffffc0200836:	06b2                	slli	a3,a3,0xc
ffffffffc0200838:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc020083a:	0732                	slli	a4,a4,0xc
ffffffffc020083c:	22d77d63          	bgeu	a4,a3,ffffffffc0200a76 <best_fit_check+0x2fa>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200840:	40f98733          	sub	a4,s3,a5
ffffffffc0200844:	870d                	srai	a4,a4,0x3
ffffffffc0200846:	02b70733          	mul	a4,a4,a1
ffffffffc020084a:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc020084c:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc020084e:	3ed77463          	bgeu	a4,a3,ffffffffc0200c36 <best_fit_check+0x4ba>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200852:	40f507b3          	sub	a5,a0,a5
ffffffffc0200856:	878d                	srai	a5,a5,0x3
ffffffffc0200858:	02b787b3          	mul	a5,a5,a1
ffffffffc020085c:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc020085e:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200860:	3ad7fb63          	bgeu	a5,a3,ffffffffc0200c16 <best_fit_check+0x49a>
    assert(alloc_page() == NULL);
ffffffffc0200864:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200866:	00043c03          	ld	s8,0(s0)
ffffffffc020086a:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc020086e:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc0200872:	e400                	sd	s0,8(s0)
ffffffffc0200874:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc0200876:	00005797          	auipc	a5,0x5
ffffffffc020087a:	7a07a923          	sw	zero,1970(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc020087e:	6dc000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc0200882:	36051a63          	bnez	a0,ffffffffc0200bf6 <best_fit_check+0x47a>
    free_page(p0);
ffffffffc0200886:	4585                	li	a1,1
ffffffffc0200888:	8552                	mv	a0,s4
ffffffffc020088a:	6dc000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    free_page(p1);
ffffffffc020088e:	4585                	li	a1,1
ffffffffc0200890:	854e                	mv	a0,s3
ffffffffc0200892:	6d4000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    free_page(p2);
ffffffffc0200896:	4585                	li	a1,1
ffffffffc0200898:	8556                	mv	a0,s5
ffffffffc020089a:	6cc000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    assert(nr_free == 3);
ffffffffc020089e:	4818                	lw	a4,16(s0)
ffffffffc02008a0:	478d                	li	a5,3
ffffffffc02008a2:	32f71a63          	bne	a4,a5,ffffffffc0200bd6 <best_fit_check+0x45a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02008a6:	4505                	li	a0,1
ffffffffc02008a8:	6b2000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02008ac:	89aa                	mv	s3,a0
ffffffffc02008ae:	30050463          	beqz	a0,ffffffffc0200bb6 <best_fit_check+0x43a>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02008b2:	4505                	li	a0,1
ffffffffc02008b4:	6a6000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02008b8:	8aaa                	mv	s5,a0
ffffffffc02008ba:	2c050e63          	beqz	a0,ffffffffc0200b96 <best_fit_check+0x41a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02008be:	4505                	li	a0,1
ffffffffc02008c0:	69a000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02008c4:	8a2a                	mv	s4,a0
ffffffffc02008c6:	2a050863          	beqz	a0,ffffffffc0200b76 <best_fit_check+0x3fa>
    assert(alloc_page() == NULL);
ffffffffc02008ca:	4505                	li	a0,1
ffffffffc02008cc:	68e000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02008d0:	28051363          	bnez	a0,ffffffffc0200b56 <best_fit_check+0x3da>
    free_page(p0);
ffffffffc02008d4:	4585                	li	a1,1
ffffffffc02008d6:	854e                	mv	a0,s3
ffffffffc02008d8:	68e000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    assert(!list_empty(&free_list));
ffffffffc02008dc:	641c                	ld	a5,8(s0)
ffffffffc02008de:	1a878c63          	beq	a5,s0,ffffffffc0200a96 <best_fit_check+0x31a>
    assert((p = alloc_page()) == p0);
ffffffffc02008e2:	4505                	li	a0,1
ffffffffc02008e4:	676000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02008e8:	52a99763          	bne	s3,a0,ffffffffc0200e16 <best_fit_check+0x69a>
    assert(alloc_page() == NULL);
ffffffffc02008ec:	4505                	li	a0,1
ffffffffc02008ee:	66c000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02008f2:	50051263          	bnez	a0,ffffffffc0200df6 <best_fit_check+0x67a>
    assert(nr_free == 0);
ffffffffc02008f6:	481c                	lw	a5,16(s0)
ffffffffc02008f8:	4c079f63          	bnez	a5,ffffffffc0200dd6 <best_fit_check+0x65a>
    free_page(p);
ffffffffc02008fc:	854e                	mv	a0,s3
ffffffffc02008fe:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200900:	01843023          	sd	s8,0(s0)
ffffffffc0200904:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc0200908:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc020090c:	65a000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    free_page(p1);
ffffffffc0200910:	4585                	li	a1,1
ffffffffc0200912:	8556                	mv	a0,s5
ffffffffc0200914:	652000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    free_page(p2);
ffffffffc0200918:	4585                	li	a1,1
ffffffffc020091a:	8552                	mv	a0,s4
ffffffffc020091c:	64a000ef          	jal	ra,ffffffffc0200f66 <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200920:	4515                	li	a0,5
ffffffffc0200922:	638000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc0200926:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0200928:	48050763          	beqz	a0,ffffffffc0200db6 <best_fit_check+0x63a>
    assert(!PageProperty(p0));
ffffffffc020092c:	651c                	ld	a5,8(a0)
ffffffffc020092e:	8b89                	andi	a5,a5,2
ffffffffc0200930:	46079363          	bnez	a5,ffffffffc0200d96 <best_fit_check+0x61a>
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200934:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200936:	00043b03          	ld	s6,0(s0)
ffffffffc020093a:	00843a83          	ld	s5,8(s0)
ffffffffc020093e:	e000                	sd	s0,0(s0)
ffffffffc0200940:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200942:	618000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc0200946:	42051863          	bnez	a0,ffffffffc0200d76 <best_fit_check+0x5fa>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc020094a:	4589                	li	a1,2
ffffffffc020094c:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc0200950:	01042b83          	lw	s7,16(s0)
    free_pages(p0 + 4, 1);
ffffffffc0200954:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc0200958:	00005797          	auipc	a5,0x5
ffffffffc020095c:	6c07a823          	sw	zero,1744(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0200960:	606000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0200964:	8562                	mv	a0,s8
ffffffffc0200966:	4585                	li	a1,1
ffffffffc0200968:	5fe000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc020096c:	4511                	li	a0,4
ffffffffc020096e:	5ec000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc0200972:	3e051263          	bnez	a0,ffffffffc0200d56 <best_fit_check+0x5da>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200976:	0309b783          	ld	a5,48(s3)
ffffffffc020097a:	8b89                	andi	a5,a5,2
ffffffffc020097c:	3a078d63          	beqz	a5,ffffffffc0200d36 <best_fit_check+0x5ba>
ffffffffc0200980:	0389a703          	lw	a4,56(s3)
ffffffffc0200984:	4789                	li	a5,2
ffffffffc0200986:	3af71863          	bne	a4,a5,ffffffffc0200d36 <best_fit_check+0x5ba>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc020098a:	4505                	li	a0,1
ffffffffc020098c:	5ce000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc0200990:	8a2a                	mv	s4,a0
ffffffffc0200992:	38050263          	beqz	a0,ffffffffc0200d16 <best_fit_check+0x59a>
    assert(alloc_pages(2) != NULL);
ffffffffc0200996:	4509                	li	a0,2
ffffffffc0200998:	5c2000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc020099c:	34050d63          	beqz	a0,ffffffffc0200cf6 <best_fit_check+0x57a>
    assert(p0 + 4 == p1);
ffffffffc02009a0:	334c1b63          	bne	s8,s4,ffffffffc0200cd6 <best_fit_check+0x55a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc02009a4:	854e                	mv	a0,s3
ffffffffc02009a6:	4595                	li	a1,5
ffffffffc02009a8:	5be000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02009ac:	4515                	li	a0,5
ffffffffc02009ae:	5ac000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02009b2:	89aa                	mv	s3,a0
ffffffffc02009b4:	30050163          	beqz	a0,ffffffffc0200cb6 <best_fit_check+0x53a>
    assert(alloc_page() == NULL);
ffffffffc02009b8:	4505                	li	a0,1
ffffffffc02009ba:	5a0000ef          	jal	ra,ffffffffc0200f5a <alloc_pages>
ffffffffc02009be:	2c051c63          	bnez	a0,ffffffffc0200c96 <best_fit_check+0x51a>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc02009c2:	481c                	lw	a5,16(s0)
ffffffffc02009c4:	2a079963          	bnez	a5,ffffffffc0200c76 <best_fit_check+0x4fa>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc02009c8:	4595                	li	a1,5
ffffffffc02009ca:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc02009cc:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc02009d0:	01643023          	sd	s6,0(s0)
ffffffffc02009d4:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc02009d8:	58e000ef          	jal	ra,ffffffffc0200f66 <free_pages>
    return listelm->next;
ffffffffc02009dc:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02009de:	00878963          	beq	a5,s0,ffffffffc02009f0 <best_fit_check+0x274>
        struct Page *p = le2page(le, page_link);
        count--, total -= p->property;
ffffffffc02009e2:	ff87a703          	lw	a4,-8(a5)
ffffffffc02009e6:	679c                	ld	a5,8(a5)
ffffffffc02009e8:	397d                	addiw	s2,s2,-1
ffffffffc02009ea:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02009ec:	fe879be3          	bne	a5,s0,ffffffffc02009e2 <best_fit_check+0x266>
    }
    assert(count == 0);
ffffffffc02009f0:	26091363          	bnez	s2,ffffffffc0200c56 <best_fit_check+0x4da>
    assert(total == 0);
ffffffffc02009f4:	e0ed                	bnez	s1,ffffffffc0200ad6 <best_fit_check+0x35a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
}
ffffffffc02009f6:	60a6                	ld	ra,72(sp)
ffffffffc02009f8:	6406                	ld	s0,64(sp)
ffffffffc02009fa:	74e2                	ld	s1,56(sp)
ffffffffc02009fc:	7942                	ld	s2,48(sp)
ffffffffc02009fe:	79a2                	ld	s3,40(sp)
ffffffffc0200a00:	7a02                	ld	s4,32(sp)
ffffffffc0200a02:	6ae2                	ld	s5,24(sp)
ffffffffc0200a04:	6b42                	ld	s6,16(sp)
ffffffffc0200a06:	6ba2                	ld	s7,8(sp)
ffffffffc0200a08:	6c02                	ld	s8,0(sp)
ffffffffc0200a0a:	6161                	addi	sp,sp,80
ffffffffc0200a0c:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200a0e:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200a10:	4481                	li	s1,0
ffffffffc0200a12:	4901                	li	s2,0
ffffffffc0200a14:	b36d                	j	ffffffffc02007be <best_fit_check+0x42>
        assert(PageProperty(p));
ffffffffc0200a16:	00001697          	auipc	a3,0x1
ffffffffc0200a1a:	f0a68693          	addi	a3,a3,-246 # ffffffffc0201920 <etext+0x29c>
ffffffffc0200a1e:	00001617          	auipc	a2,0x1
ffffffffc0200a22:	ed260613          	addi	a2,a2,-302 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200a26:	0b400593          	li	a1,180
ffffffffc0200a2a:	00001517          	auipc	a0,0x1
ffffffffc0200a2e:	ede50513          	addi	a0,a0,-290 # ffffffffc0201908 <etext+0x284>
ffffffffc0200a32:	f90ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200a36:	00001697          	auipc	a3,0x1
ffffffffc0200a3a:	f7a68693          	addi	a3,a3,-134 # ffffffffc02019b0 <etext+0x32c>
ffffffffc0200a3e:	00001617          	auipc	a2,0x1
ffffffffc0200a42:	eb260613          	addi	a2,a2,-334 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200a46:	08200593          	li	a1,130
ffffffffc0200a4a:	00001517          	auipc	a0,0x1
ffffffffc0200a4e:	ebe50513          	addi	a0,a0,-322 # ffffffffc0201908 <etext+0x284>
ffffffffc0200a52:	f70ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200a56:	00001697          	auipc	a3,0x1
ffffffffc0200a5a:	f8268693          	addi	a3,a3,-126 # ffffffffc02019d8 <etext+0x354>
ffffffffc0200a5e:	00001617          	auipc	a2,0x1
ffffffffc0200a62:	e9260613          	addi	a2,a2,-366 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200a66:	08300593          	li	a1,131
ffffffffc0200a6a:	00001517          	auipc	a0,0x1
ffffffffc0200a6e:	e9e50513          	addi	a0,a0,-354 # ffffffffc0201908 <etext+0x284>
ffffffffc0200a72:	f50ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200a76:	00001697          	auipc	a3,0x1
ffffffffc0200a7a:	fa268693          	addi	a3,a3,-94 # ffffffffc0201a18 <etext+0x394>
ffffffffc0200a7e:	00001617          	auipc	a2,0x1
ffffffffc0200a82:	e7260613          	addi	a2,a2,-398 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200a86:	08500593          	li	a1,133
ffffffffc0200a8a:	00001517          	auipc	a0,0x1
ffffffffc0200a8e:	e7e50513          	addi	a0,a0,-386 # ffffffffc0201908 <etext+0x284>
ffffffffc0200a92:	f30ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0200a96:	00001697          	auipc	a3,0x1
ffffffffc0200a9a:	00a68693          	addi	a3,a3,10 # ffffffffc0201aa0 <etext+0x41c>
ffffffffc0200a9e:	00001617          	auipc	a2,0x1
ffffffffc0200aa2:	e5260613          	addi	a2,a2,-430 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200aa6:	09e00593          	li	a1,158
ffffffffc0200aaa:	00001517          	auipc	a0,0x1
ffffffffc0200aae:	e5e50513          	addi	a0,a0,-418 # ffffffffc0201908 <etext+0x284>
ffffffffc0200ab2:	f10ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200ab6:	00001697          	auipc	a3,0x1
ffffffffc0200aba:	eda68693          	addi	a3,a3,-294 # ffffffffc0201990 <etext+0x30c>
ffffffffc0200abe:	00001617          	auipc	a2,0x1
ffffffffc0200ac2:	e3260613          	addi	a2,a2,-462 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200ac6:	08000593          	li	a1,128
ffffffffc0200aca:	00001517          	auipc	a0,0x1
ffffffffc0200ace:	e3e50513          	addi	a0,a0,-450 # ffffffffc0201908 <etext+0x284>
ffffffffc0200ad2:	ef0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == 0);
ffffffffc0200ad6:	00001697          	auipc	a3,0x1
ffffffffc0200ada:	0fa68693          	addi	a3,a3,250 # ffffffffc0201bd0 <etext+0x54c>
ffffffffc0200ade:	00001617          	auipc	a2,0x1
ffffffffc0200ae2:	e1260613          	addi	a2,a2,-494 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200ae6:	0f600593          	li	a1,246
ffffffffc0200aea:	00001517          	auipc	a0,0x1
ffffffffc0200aee:	e1e50513          	addi	a0,a0,-482 # ffffffffc0201908 <etext+0x284>
ffffffffc0200af2:	ed0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200af6:	00001697          	auipc	a3,0x1
ffffffffc0200afa:	e3a68693          	addi	a3,a3,-454 # ffffffffc0201930 <etext+0x2ac>
ffffffffc0200afe:	00001617          	auipc	a2,0x1
ffffffffc0200b02:	df260613          	addi	a2,a2,-526 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200b06:	0b700593          	li	a1,183
ffffffffc0200b0a:	00001517          	auipc	a0,0x1
ffffffffc0200b0e:	dfe50513          	addi	a0,a0,-514 # ffffffffc0201908 <etext+0x284>
ffffffffc0200b12:	eb0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200b16:	00001697          	auipc	a3,0x1
ffffffffc0200b1a:	e5a68693          	addi	a3,a3,-422 # ffffffffc0201970 <etext+0x2ec>
ffffffffc0200b1e:	00001617          	auipc	a2,0x1
ffffffffc0200b22:	dd260613          	addi	a2,a2,-558 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200b26:	07f00593          	li	a1,127
ffffffffc0200b2a:	00001517          	auipc	a0,0x1
ffffffffc0200b2e:	dde50513          	addi	a0,a0,-546 # ffffffffc0201908 <etext+0x284>
ffffffffc0200b32:	e90ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200b36:	00001697          	auipc	a3,0x1
ffffffffc0200b3a:	e1a68693          	addi	a3,a3,-486 # ffffffffc0201950 <etext+0x2cc>
ffffffffc0200b3e:	00001617          	auipc	a2,0x1
ffffffffc0200b42:	db260613          	addi	a2,a2,-590 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200b46:	07e00593          	li	a1,126
ffffffffc0200b4a:	00001517          	auipc	a0,0x1
ffffffffc0200b4e:	dbe50513          	addi	a0,a0,-578 # ffffffffc0201908 <etext+0x284>
ffffffffc0200b52:	e70ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200b56:	00001697          	auipc	a3,0x1
ffffffffc0200b5a:	f2268693          	addi	a3,a3,-222 # ffffffffc0201a78 <etext+0x3f4>
ffffffffc0200b5e:	00001617          	auipc	a2,0x1
ffffffffc0200b62:	d9260613          	addi	a2,a2,-622 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200b66:	09b00593          	li	a1,155
ffffffffc0200b6a:	00001517          	auipc	a0,0x1
ffffffffc0200b6e:	d9e50513          	addi	a0,a0,-610 # ffffffffc0201908 <etext+0x284>
ffffffffc0200b72:	e50ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200b76:	00001697          	auipc	a3,0x1
ffffffffc0200b7a:	e1a68693          	addi	a3,a3,-486 # ffffffffc0201990 <etext+0x30c>
ffffffffc0200b7e:	00001617          	auipc	a2,0x1
ffffffffc0200b82:	d7260613          	addi	a2,a2,-654 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200b86:	09900593          	li	a1,153
ffffffffc0200b8a:	00001517          	auipc	a0,0x1
ffffffffc0200b8e:	d7e50513          	addi	a0,a0,-642 # ffffffffc0201908 <etext+0x284>
ffffffffc0200b92:	e30ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200b96:	00001697          	auipc	a3,0x1
ffffffffc0200b9a:	dda68693          	addi	a3,a3,-550 # ffffffffc0201970 <etext+0x2ec>
ffffffffc0200b9e:	00001617          	auipc	a2,0x1
ffffffffc0200ba2:	d5260613          	addi	a2,a2,-686 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200ba6:	09800593          	li	a1,152
ffffffffc0200baa:	00001517          	auipc	a0,0x1
ffffffffc0200bae:	d5e50513          	addi	a0,a0,-674 # ffffffffc0201908 <etext+0x284>
ffffffffc0200bb2:	e10ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200bb6:	00001697          	auipc	a3,0x1
ffffffffc0200bba:	d9a68693          	addi	a3,a3,-614 # ffffffffc0201950 <etext+0x2cc>
ffffffffc0200bbe:	00001617          	auipc	a2,0x1
ffffffffc0200bc2:	d3260613          	addi	a2,a2,-718 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200bc6:	09700593          	li	a1,151
ffffffffc0200bca:	00001517          	auipc	a0,0x1
ffffffffc0200bce:	d3e50513          	addi	a0,a0,-706 # ffffffffc0201908 <etext+0x284>
ffffffffc0200bd2:	df0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 3);
ffffffffc0200bd6:	00001697          	auipc	a3,0x1
ffffffffc0200bda:	eba68693          	addi	a3,a3,-326 # ffffffffc0201a90 <etext+0x40c>
ffffffffc0200bde:	00001617          	auipc	a2,0x1
ffffffffc0200be2:	d1260613          	addi	a2,a2,-750 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200be6:	09500593          	li	a1,149
ffffffffc0200bea:	00001517          	auipc	a0,0x1
ffffffffc0200bee:	d1e50513          	addi	a0,a0,-738 # ffffffffc0201908 <etext+0x284>
ffffffffc0200bf2:	dd0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200bf6:	00001697          	auipc	a3,0x1
ffffffffc0200bfa:	e8268693          	addi	a3,a3,-382 # ffffffffc0201a78 <etext+0x3f4>
ffffffffc0200bfe:	00001617          	auipc	a2,0x1
ffffffffc0200c02:	cf260613          	addi	a2,a2,-782 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200c06:	09000593          	li	a1,144
ffffffffc0200c0a:	00001517          	auipc	a0,0x1
ffffffffc0200c0e:	cfe50513          	addi	a0,a0,-770 # ffffffffc0201908 <etext+0x284>
ffffffffc0200c12:	db0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200c16:	00001697          	auipc	a3,0x1
ffffffffc0200c1a:	e4268693          	addi	a3,a3,-446 # ffffffffc0201a58 <etext+0x3d4>
ffffffffc0200c1e:	00001617          	auipc	a2,0x1
ffffffffc0200c22:	cd260613          	addi	a2,a2,-814 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200c26:	08700593          	li	a1,135
ffffffffc0200c2a:	00001517          	auipc	a0,0x1
ffffffffc0200c2e:	cde50513          	addi	a0,a0,-802 # ffffffffc0201908 <etext+0x284>
ffffffffc0200c32:	d90ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200c36:	00001697          	auipc	a3,0x1
ffffffffc0200c3a:	e0268693          	addi	a3,a3,-510 # ffffffffc0201a38 <etext+0x3b4>
ffffffffc0200c3e:	00001617          	auipc	a2,0x1
ffffffffc0200c42:	cb260613          	addi	a2,a2,-846 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200c46:	08600593          	li	a1,134
ffffffffc0200c4a:	00001517          	auipc	a0,0x1
ffffffffc0200c4e:	cbe50513          	addi	a0,a0,-834 # ffffffffc0201908 <etext+0x284>
ffffffffc0200c52:	d70ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(count == 0);
ffffffffc0200c56:	00001697          	auipc	a3,0x1
ffffffffc0200c5a:	f6a68693          	addi	a3,a3,-150 # ffffffffc0201bc0 <etext+0x53c>
ffffffffc0200c5e:	00001617          	auipc	a2,0x1
ffffffffc0200c62:	c9260613          	addi	a2,a2,-878 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200c66:	0f500593          	li	a1,245
ffffffffc0200c6a:	00001517          	auipc	a0,0x1
ffffffffc0200c6e:	c9e50513          	addi	a0,a0,-866 # ffffffffc0201908 <etext+0x284>
ffffffffc0200c72:	d50ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200c76:	00001697          	auipc	a3,0x1
ffffffffc0200c7a:	e6268693          	addi	a3,a3,-414 # ffffffffc0201ad8 <etext+0x454>
ffffffffc0200c7e:	00001617          	auipc	a2,0x1
ffffffffc0200c82:	c7260613          	addi	a2,a2,-910 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200c86:	0ea00593          	li	a1,234
ffffffffc0200c8a:	00001517          	auipc	a0,0x1
ffffffffc0200c8e:	c7e50513          	addi	a0,a0,-898 # ffffffffc0201908 <etext+0x284>
ffffffffc0200c92:	d30ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200c96:	00001697          	auipc	a3,0x1
ffffffffc0200c9a:	de268693          	addi	a3,a3,-542 # ffffffffc0201a78 <etext+0x3f4>
ffffffffc0200c9e:	00001617          	auipc	a2,0x1
ffffffffc0200ca2:	c5260613          	addi	a2,a2,-942 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200ca6:	0e400593          	li	a1,228
ffffffffc0200caa:	00001517          	auipc	a0,0x1
ffffffffc0200cae:	c5e50513          	addi	a0,a0,-930 # ffffffffc0201908 <etext+0x284>
ffffffffc0200cb2:	d10ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200cb6:	00001697          	auipc	a3,0x1
ffffffffc0200cba:	eea68693          	addi	a3,a3,-278 # ffffffffc0201ba0 <etext+0x51c>
ffffffffc0200cbe:	00001617          	auipc	a2,0x1
ffffffffc0200cc2:	c3260613          	addi	a2,a2,-974 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200cc6:	0e300593          	li	a1,227
ffffffffc0200cca:	00001517          	auipc	a0,0x1
ffffffffc0200cce:	c3e50513          	addi	a0,a0,-962 # ffffffffc0201908 <etext+0x284>
ffffffffc0200cd2:	cf0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 + 4 == p1);
ffffffffc0200cd6:	00001697          	auipc	a3,0x1
ffffffffc0200cda:	eba68693          	addi	a3,a3,-326 # ffffffffc0201b90 <etext+0x50c>
ffffffffc0200cde:	00001617          	auipc	a2,0x1
ffffffffc0200ce2:	c1260613          	addi	a2,a2,-1006 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200ce6:	0db00593          	li	a1,219
ffffffffc0200cea:	00001517          	auipc	a0,0x1
ffffffffc0200cee:	c1e50513          	addi	a0,a0,-994 # ffffffffc0201908 <etext+0x284>
ffffffffc0200cf2:	cd0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(2) != NULL);
ffffffffc0200cf6:	00001697          	auipc	a3,0x1
ffffffffc0200cfa:	e8268693          	addi	a3,a3,-382 # ffffffffc0201b78 <etext+0x4f4>
ffffffffc0200cfe:	00001617          	auipc	a2,0x1
ffffffffc0200d02:	bf260613          	addi	a2,a2,-1038 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200d06:	0da00593          	li	a1,218
ffffffffc0200d0a:	00001517          	auipc	a0,0x1
ffffffffc0200d0e:	bfe50513          	addi	a0,a0,-1026 # ffffffffc0201908 <etext+0x284>
ffffffffc0200d12:	cb0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200d16:	00001697          	auipc	a3,0x1
ffffffffc0200d1a:	e4268693          	addi	a3,a3,-446 # ffffffffc0201b58 <etext+0x4d4>
ffffffffc0200d1e:	00001617          	auipc	a2,0x1
ffffffffc0200d22:	bd260613          	addi	a2,a2,-1070 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200d26:	0d900593          	li	a1,217
ffffffffc0200d2a:	00001517          	auipc	a0,0x1
ffffffffc0200d2e:	bde50513          	addi	a0,a0,-1058 # ffffffffc0201908 <etext+0x284>
ffffffffc0200d32:	c90ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200d36:	00001697          	auipc	a3,0x1
ffffffffc0200d3a:	df268693          	addi	a3,a3,-526 # ffffffffc0201b28 <etext+0x4a4>
ffffffffc0200d3e:	00001617          	auipc	a2,0x1
ffffffffc0200d42:	bb260613          	addi	a2,a2,-1102 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200d46:	0d700593          	li	a1,215
ffffffffc0200d4a:	00001517          	auipc	a0,0x1
ffffffffc0200d4e:	bbe50513          	addi	a0,a0,-1090 # ffffffffc0201908 <etext+0x284>
ffffffffc0200d52:	c70ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200d56:	00001697          	auipc	a3,0x1
ffffffffc0200d5a:	dba68693          	addi	a3,a3,-582 # ffffffffc0201b10 <etext+0x48c>
ffffffffc0200d5e:	00001617          	auipc	a2,0x1
ffffffffc0200d62:	b9260613          	addi	a2,a2,-1134 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200d66:	0d600593          	li	a1,214
ffffffffc0200d6a:	00001517          	auipc	a0,0x1
ffffffffc0200d6e:	b9e50513          	addi	a0,a0,-1122 # ffffffffc0201908 <etext+0x284>
ffffffffc0200d72:	c50ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d76:	00001697          	auipc	a3,0x1
ffffffffc0200d7a:	d0268693          	addi	a3,a3,-766 # ffffffffc0201a78 <etext+0x3f4>
ffffffffc0200d7e:	00001617          	auipc	a2,0x1
ffffffffc0200d82:	b7260613          	addi	a2,a2,-1166 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200d86:	0ca00593          	li	a1,202
ffffffffc0200d8a:	00001517          	auipc	a0,0x1
ffffffffc0200d8e:	b7e50513          	addi	a0,a0,-1154 # ffffffffc0201908 <etext+0x284>
ffffffffc0200d92:	c30ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200d96:	00001697          	auipc	a3,0x1
ffffffffc0200d9a:	d6268693          	addi	a3,a3,-670 # ffffffffc0201af8 <etext+0x474>
ffffffffc0200d9e:	00001617          	auipc	a2,0x1
ffffffffc0200da2:	b5260613          	addi	a2,a2,-1198 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200da6:	0c100593          	li	a1,193
ffffffffc0200daa:	00001517          	auipc	a0,0x1
ffffffffc0200dae:	b5e50513          	addi	a0,a0,-1186 # ffffffffc0201908 <etext+0x284>
ffffffffc0200db2:	c10ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != NULL);
ffffffffc0200db6:	00001697          	auipc	a3,0x1
ffffffffc0200dba:	d3268693          	addi	a3,a3,-718 # ffffffffc0201ae8 <etext+0x464>
ffffffffc0200dbe:	00001617          	auipc	a2,0x1
ffffffffc0200dc2:	b3260613          	addi	a2,a2,-1230 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200dc6:	0c000593          	li	a1,192
ffffffffc0200dca:	00001517          	auipc	a0,0x1
ffffffffc0200dce:	b3e50513          	addi	a0,a0,-1218 # ffffffffc0201908 <etext+0x284>
ffffffffc0200dd2:	bf0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200dd6:	00001697          	auipc	a3,0x1
ffffffffc0200dda:	d0268693          	addi	a3,a3,-766 # ffffffffc0201ad8 <etext+0x454>
ffffffffc0200dde:	00001617          	auipc	a2,0x1
ffffffffc0200de2:	b1260613          	addi	a2,a2,-1262 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200de6:	0a400593          	li	a1,164
ffffffffc0200dea:	00001517          	auipc	a0,0x1
ffffffffc0200dee:	b1e50513          	addi	a0,a0,-1250 # ffffffffc0201908 <etext+0x284>
ffffffffc0200df2:	bd0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200df6:	00001697          	auipc	a3,0x1
ffffffffc0200dfa:	c8268693          	addi	a3,a3,-894 # ffffffffc0201a78 <etext+0x3f4>
ffffffffc0200dfe:	00001617          	auipc	a2,0x1
ffffffffc0200e02:	af260613          	addi	a2,a2,-1294 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200e06:	0a200593          	li	a1,162
ffffffffc0200e0a:	00001517          	auipc	a0,0x1
ffffffffc0200e0e:	afe50513          	addi	a0,a0,-1282 # ffffffffc0201908 <etext+0x284>
ffffffffc0200e12:	bb0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200e16:	00001697          	auipc	a3,0x1
ffffffffc0200e1a:	ca268693          	addi	a3,a3,-862 # ffffffffc0201ab8 <etext+0x434>
ffffffffc0200e1e:	00001617          	auipc	a2,0x1
ffffffffc0200e22:	ad260613          	addi	a2,a2,-1326 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200e26:	0a100593          	li	a1,161
ffffffffc0200e2a:	00001517          	auipc	a0,0x1
ffffffffc0200e2e:	ade50513          	addi	a0,a0,-1314 # ffffffffc0201908 <etext+0x284>
ffffffffc0200e32:	b90ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200e36 <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc0200e36:	1141                	addi	sp,sp,-16
ffffffffc0200e38:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200e3a:	c5bd                	beqz	a1,ffffffffc0200ea8 <best_fit_free_pages+0x72>
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc0200e3c:	00259693          	slli	a3,a1,0x2
ffffffffc0200e40:	96ae                	add	a3,a3,a1
ffffffffc0200e42:	068e                	slli	a3,a3,0x3
ffffffffc0200e44:	96aa                	add	a3,a3,a0
ffffffffc0200e46:	87aa                	mv	a5,a0
ffffffffc0200e48:	00a68f63          	beq	a3,a0,ffffffffc0200e66 <best_fit_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e4c:	6798                	ld	a4,8(a5)
ffffffffc0200e4e:	8b0d                	andi	a4,a4,3
ffffffffc0200e50:	ef05                	bnez	a4,ffffffffc0200e88 <best_fit_free_pages+0x52>
        p->flags = p->property = 0;
ffffffffc0200e52:	0007a823          	sw	zero,16(a5)
ffffffffc0200e56:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200e5a:	0007a023          	sw	zero,0(a5)
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc0200e5e:	02878793          	addi	a5,a5,40
ffffffffc0200e62:	fef695e3          	bne	a3,a5,ffffffffc0200e4c <best_fit_free_pages+0x16>
    SetPageProperty(base);
ffffffffc0200e66:	6518                	ld	a4,8(a0)
    nr_free += n;
ffffffffc0200e68:	00005697          	auipc	a3,0x5
ffffffffc0200e6c:	1b068693          	addi	a3,a3,432 # ffffffffc0206018 <free_area>
ffffffffc0200e70:	4a9c                	lw	a5,16(a3)
    base->property = n;
ffffffffc0200e72:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200e74:	00276713          	ori	a4,a4,2
    base->property = n;
ffffffffc0200e78:	c90c                	sw	a1,16(a0)
}
ffffffffc0200e7a:	60a2                	ld	ra,8(sp)
    SetPageProperty(base);
ffffffffc0200e7c:	e518                	sd	a4,8(a0)
    nr_free += n;
ffffffffc0200e7e:	9dbd                	addw	a1,a1,a5
ffffffffc0200e80:	ca8c                	sw	a1,16(a3)
}
ffffffffc0200e82:	0141                	addi	sp,sp,16
    best_fit_insert_block(base);
ffffffffc0200e84:	f5eff06f          	j	ffffffffc02005e2 <best_fit_insert_block>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200e88:	00001697          	auipc	a3,0x1
ffffffffc0200e8c:	d5868693          	addi	a3,a3,-680 # ffffffffc0201be0 <etext+0x55c>
ffffffffc0200e90:	00001617          	auipc	a2,0x1
ffffffffc0200e94:	a6060613          	addi	a2,a2,-1440 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200e98:	06900593          	li	a1,105
ffffffffc0200e9c:	00001517          	auipc	a0,0x1
ffffffffc0200ea0:	a6c50513          	addi	a0,a0,-1428 # ffffffffc0201908 <etext+0x284>
ffffffffc0200ea4:	b1eff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200ea8:	00001697          	auipc	a3,0x1
ffffffffc0200eac:	a4068693          	addi	a3,a3,-1472 # ffffffffc02018e8 <etext+0x264>
ffffffffc0200eb0:	00001617          	auipc	a2,0x1
ffffffffc0200eb4:	a4060613          	addi	a2,a2,-1472 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200eb8:	06700593          	li	a1,103
ffffffffc0200ebc:	00001517          	auipc	a0,0x1
ffffffffc0200ec0:	a4c50513          	addi	a0,a0,-1460 # ffffffffc0201908 <etext+0x284>
ffffffffc0200ec4:	afeff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200ec8 <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc0200ec8:	1141                	addi	sp,sp,-16
ffffffffc0200eca:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200ecc:	c5bd                	beqz	a1,ffffffffc0200f3a <best_fit_init_memmap+0x72>
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc0200ece:	00259693          	slli	a3,a1,0x2
ffffffffc0200ed2:	96ae                	add	a3,a3,a1
ffffffffc0200ed4:	068e                	slli	a3,a3,0x3
ffffffffc0200ed6:	96aa                	add	a3,a3,a0
ffffffffc0200ed8:	87aa                	mv	a5,a0
ffffffffc0200eda:	00a68f63          	beq	a3,a0,ffffffffc0200ef8 <best_fit_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200ede:	6798                	ld	a4,8(a5)
ffffffffc0200ee0:	8b05                	andi	a4,a4,1
ffffffffc0200ee2:	cf05                	beqz	a4,ffffffffc0200f1a <best_fit_init_memmap+0x52>
        p->flags = p->property = 0;
ffffffffc0200ee4:	0007a823          	sw	zero,16(a5)
ffffffffc0200ee8:	0007b423          	sd	zero,8(a5)
ffffffffc0200eec:	0007a023          	sw	zero,0(a5)
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc0200ef0:	02878793          	addi	a5,a5,40
ffffffffc0200ef4:	fef695e3          	bne	a3,a5,ffffffffc0200ede <best_fit_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200ef8:	6518                	ld	a4,8(a0)
    nr_free += n;
ffffffffc0200efa:	00005697          	auipc	a3,0x5
ffffffffc0200efe:	11e68693          	addi	a3,a3,286 # ffffffffc0206018 <free_area>
ffffffffc0200f02:	4a9c                	lw	a5,16(a3)
    base->property = n;
ffffffffc0200f04:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200f06:	00276713          	ori	a4,a4,2
    base->property = n;
ffffffffc0200f0a:	c90c                	sw	a1,16(a0)
}
ffffffffc0200f0c:	60a2                	ld	ra,8(sp)
    SetPageProperty(base);
ffffffffc0200f0e:	e518                	sd	a4,8(a0)
    nr_free += n;
ffffffffc0200f10:	9dbd                	addw	a1,a1,a5
ffffffffc0200f12:	ca8c                	sw	a1,16(a3)
}
ffffffffc0200f14:	0141                	addi	sp,sp,16
    best_fit_insert_block(base);
ffffffffc0200f16:	eccff06f          	j	ffffffffc02005e2 <best_fit_insert_block>
        assert(PageReserved(p));
ffffffffc0200f1a:	00001697          	auipc	a3,0x1
ffffffffc0200f1e:	cee68693          	addi	a3,a3,-786 # ffffffffc0201c08 <etext+0x584>
ffffffffc0200f22:	00001617          	auipc	a2,0x1
ffffffffc0200f26:	9ce60613          	addi	a2,a2,-1586 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200f2a:	03800593          	li	a1,56
ffffffffc0200f2e:	00001517          	auipc	a0,0x1
ffffffffc0200f32:	9da50513          	addi	a0,a0,-1574 # ffffffffc0201908 <etext+0x284>
ffffffffc0200f36:	a8cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200f3a:	00001697          	auipc	a3,0x1
ffffffffc0200f3e:	9ae68693          	addi	a3,a3,-1618 # ffffffffc02018e8 <etext+0x264>
ffffffffc0200f42:	00001617          	auipc	a2,0x1
ffffffffc0200f46:	9ae60613          	addi	a2,a2,-1618 # ffffffffc02018f0 <etext+0x26c>
ffffffffc0200f4a:	03600593          	li	a1,54
ffffffffc0200f4e:	00001517          	auipc	a0,0x1
ffffffffc0200f52:	9ba50513          	addi	a0,a0,-1606 # ffffffffc0201908 <etext+0x284>
ffffffffc0200f56:	a6cff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200f5a <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200f5a:	00005797          	auipc	a5,0x5
ffffffffc0200f5e:	18e7b783          	ld	a5,398(a5) # ffffffffc02060e8 <pmm_manager>
ffffffffc0200f62:	6f9c                	ld	a5,24(a5)
ffffffffc0200f64:	8782                	jr	a5

ffffffffc0200f66 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200f66:	00005797          	auipc	a5,0x5
ffffffffc0200f6a:	1827b783          	ld	a5,386(a5) # ffffffffc02060e8 <pmm_manager>
ffffffffc0200f6e:	739c                	ld	a5,32(a5)
ffffffffc0200f70:	8782                	jr	a5

ffffffffc0200f72 <nr_free_pages>:
}

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void) {
    return pmm_manager->nr_free_pages();
ffffffffc0200f72:	00005797          	auipc	a5,0x5
ffffffffc0200f76:	1767b783          	ld	a5,374(a5) # ffffffffc02060e8 <pmm_manager>
ffffffffc0200f7a:	779c                	ld	a5,40(a5)
ffffffffc0200f7c:	8782                	jr	a5

ffffffffc0200f7e <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200f7e:	00001797          	auipc	a5,0x1
ffffffffc0200f82:	cb278793          	addi	a5,a5,-846 # ffffffffc0201c30 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200f86:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(free_start_pa), nr_free);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0200f88:	715d                	addi	sp,sp,-80
ffffffffc0200f8a:	f84a                	sd	s2,48(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200f8c:	00001517          	auipc	a0,0x1
ffffffffc0200f90:	cdc50513          	addi	a0,a0,-804 # ffffffffc0201c68 <best_fit_pmm_manager+0x38>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200f94:	00005917          	auipc	s2,0x5
ffffffffc0200f98:	15490913          	addi	s2,s2,340 # ffffffffc02060e8 <pmm_manager>
void pmm_init(void) {
ffffffffc0200f9c:	e486                	sd	ra,72(sp)
ffffffffc0200f9e:	e0a2                	sd	s0,64(sp)
ffffffffc0200fa0:	f44e                	sd	s3,40(sp)
ffffffffc0200fa2:	f052                	sd	s4,32(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200fa4:	00f93023          	sd	a5,0(s2)
void pmm_init(void) {
ffffffffc0200fa8:	fc26                	sd	s1,56(sp)
ffffffffc0200faa:	ec56                	sd	s5,24(sp)
ffffffffc0200fac:	e85a                	sd	s6,16(sp)
ffffffffc0200fae:	e45e                	sd	s7,8(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200fb0:	99cff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc0200fb4:	00093783          	ld	a5,0(s2)
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200fb8:	00005997          	auipc	s3,0x5
ffffffffc0200fbc:	14898993          	addi	s3,s3,328 # ffffffffc0206100 <va_pa_offset>
    pmm_manager->init();
ffffffffc0200fc0:	679c                	ld	a5,8(a5)
ffffffffc0200fc2:	9782                	jalr	a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200fc4:	57f5                	li	a5,-3
ffffffffc0200fc6:	07fa                	slli	a5,a5,0x1e
ffffffffc0200fc8:	00f9b023          	sd	a5,0(s3)
    uint64_t mem_base = get_memory_base();
ffffffffc0200fcc:	df0ff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0200fd0:	8a2a                	mv	s4,a0
    uint64_t mem_size = get_memory_size();
ffffffffc0200fd2:	df4ff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    uint64_t mem_end = mem_base + mem_size;
ffffffffc0200fd6:	00aa0433          	add	s0,s4,a0
    if (mem_base == 0 || mem_size == 0) {
ffffffffc0200fda:	140a0863          	beqz	s4,ffffffffc020112a <pmm_init+0x1ac>
ffffffffc0200fde:	862a                	mv	a2,a0
ffffffffc0200fe0:	14050563          	beqz	a0,ffffffffc020112a <pmm_init+0x1ac>
    npage = PPN(mem_end);
ffffffffc0200fe4:	00c45793          	srli	a5,s0,0xc
ffffffffc0200fe8:	00005497          	auipc	s1,0x5
ffffffffc0200fec:	0f048493          	addi	s1,s1,240 # ffffffffc02060d8 <npage>
    cprintf("memory: base=0x%016lx size=0x%016lx end=0x%016lx\n",
ffffffffc0200ff0:	86a2                	mv	a3,s0
ffffffffc0200ff2:	85d2                	mv	a1,s4
ffffffffc0200ff4:	00001517          	auipc	a0,0x1
ffffffffc0200ff8:	cd450513          	addi	a0,a0,-812 # ffffffffc0201cc8 <best_fit_pmm_manager+0x98>
    npage = PPN(mem_end);
ffffffffc0200ffc:	e09c                	sd	a5,0(s1)
    cprintf("memory: base=0x%016lx size=0x%016lx end=0x%016lx\n",
ffffffffc0200ffe:	94eff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("npage: %lu\n", npage);
ffffffffc0201002:	608c                	ld	a1,0(s1)
ffffffffc0201004:	00001517          	auipc	a0,0x1
ffffffffc0201008:	cfc50513          	addi	a0,a0,-772 # ffffffffc0201d00 <best_fit_pmm_manager+0xd0>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020100c:	00005a17          	auipc	s4,0x5
ffffffffc0201010:	0d4a0a13          	addi	s4,s4,212 # ffffffffc02060e0 <pages>
    cprintf("npage: %lu\n", npage);
ffffffffc0201014:	938ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    size_t nr_manage = npage - nbase;
ffffffffc0201018:	609c                	ld	a5,0(s1)
ffffffffc020101a:	00006597          	auipc	a1,0x6
ffffffffc020101e:	0f158593          	addi	a1,a1,241 # ffffffffc020710b <end+0xfff>
ffffffffc0201022:	76fd                	lui	a3,0xfffff
ffffffffc0201024:	8eed                	and	a3,a3,a1
ffffffffc0201026:	fff805b7          	lui	a1,0xfff80
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020102a:	00da3023          	sd	a3,0(s4)
    size_t nr_manage = npage - nbase;
ffffffffc020102e:	00b78633          	add	a2,a5,a1
    for (size_t i = 0; i < nr_manage; i++) {
ffffffffc0201032:	c21d                	beqz	a2,ffffffffc0201058 <pmm_init+0xda>
ffffffffc0201034:	00279513          	slli	a0,a5,0x2
ffffffffc0201038:	953e                	add	a0,a0,a5
ffffffffc020103a:	050e                	slli	a0,a0,0x3
ffffffffc020103c:	fec007b7          	lui	a5,0xfec00
ffffffffc0201040:	953e                	add	a0,a0,a5
ffffffffc0201042:	9536                	add	a0,a0,a3
ffffffffc0201044:	87b6                	mv	a5,a3
        SetPageReserved(pages + i);
ffffffffc0201046:	6798                	ld	a4,8(a5)
    for (size_t i = 0; i < nr_manage; i++) {
ffffffffc0201048:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9f9f1c>
        SetPageReserved(pages + i);
ffffffffc020104c:	00176713          	ori	a4,a4,1
ffffffffc0201050:	fee7b023          	sd	a4,-32(a5)
    for (size_t i = 0; i < nr_manage; i++) {
ffffffffc0201054:	fef519e3          	bne	a0,a5,ffffffffc0201046 <pmm_init+0xc8>
    uintptr_t pages_end_va = (uintptr_t)pages + nr_manage * sizeof(struct Page);
ffffffffc0201058:	00261593          	slli	a1,a2,0x2
ffffffffc020105c:	95b2                	add	a1,a1,a2
ffffffffc020105e:	058e                	slli	a1,a1,0x3
    uintptr_t free_start_va = ROUNDUP(pages_end_va, PGSIZE);
ffffffffc0201060:	6b05                	lui	s6,0x1
    uintptr_t pages_end_va = (uintptr_t)pages + nr_manage * sizeof(struct Page);
ffffffffc0201062:	95b6                	add	a1,a1,a3
    uintptr_t free_start_va = ROUNDUP(pages_end_va, PGSIZE);
ffffffffc0201064:	fffb0693          	addi	a3,s6,-1 # fff <kern_entry-0xffffffffc01ff001>
ffffffffc0201068:	95b6                	add	a1,a1,a3
ffffffffc020106a:	767d                	lui	a2,0xfffff
ffffffffc020106c:	8df1                	and	a1,a1,a2
    uintptr_t free_start_pa = PADDR(free_start_va);
ffffffffc020106e:	c02007b7          	lui	a5,0xc0200
ffffffffc0201072:	0cf5e863          	bltu	a1,a5,ffffffffc0201142 <pmm_init+0x1c4>
ffffffffc0201076:	0009b683          	ld	a3,0(s3)
    uintptr_t free_end_pa = ROUNDDOWN(mem_end, PGSIZE);
ffffffffc020107a:	8e61                	and	a2,a2,s0
    cprintf("free region: pa=0x%016lx - 0x%016lx (%lu pages)\n",
ffffffffc020107c:	00001517          	auipc	a0,0x1
ffffffffc0201080:	cbc50513          	addi	a0,a0,-836 # ffffffffc0201d38 <best_fit_pmm_manager+0x108>
    size_t nr_free = (free_end_pa - free_start_pa) / PGSIZE;
ffffffffc0201084:	40b68ab3          	sub	s5,a3,a1
ffffffffc0201088:	9ab2                	add	s5,s5,a2
    uintptr_t free_start_pa = PADDR(free_start_va);
ffffffffc020108a:	40d58433          	sub	s0,a1,a3
    size_t nr_free = (free_end_pa - free_start_pa) / PGSIZE;
ffffffffc020108e:	00cadb93          	srli	s7,s5,0xc
    cprintf("free region: pa=0x%016lx - 0x%016lx (%lu pages)\n",
ffffffffc0201092:	86de                	mv	a3,s7
ffffffffc0201094:	85a2                	mv	a1,s0
ffffffffc0201096:	8b6ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    if (nr_free > 0) {
ffffffffc020109a:	076af263          	bgeu	s5,s6,ffffffffc02010fe <pmm_init+0x180>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc020109e:	00093783          	ld	a5,0(s2)
ffffffffc02010a2:	7b9c                	ld	a5,48(a5)
ffffffffc02010a4:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc02010a6:	00001517          	auipc	a0,0x1
ffffffffc02010aa:	cfa50513          	addi	a0,a0,-774 # ffffffffc0201da0 <best_fit_pmm_manager+0x170>
ffffffffc02010ae:	89eff0ef          	jal	ra,ffffffffc020014c <cprintf>
    slub_init();
ffffffffc02010b2:	0dc000ef          	jal	ra,ffffffffc020118e <slub_init>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc02010b6:	00004597          	auipc	a1,0x4
ffffffffc02010ba:	f4a58593          	addi	a1,a1,-182 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc02010be:	00005797          	auipc	a5,0x5
ffffffffc02010c2:	02b7bd23          	sd	a1,58(a5) # ffffffffc02060f8 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc02010c6:	c02007b7          	lui	a5,0xc0200
ffffffffc02010ca:	08f5e963          	bltu	a1,a5,ffffffffc020115c <pmm_init+0x1de>
ffffffffc02010ce:	0009b603          	ld	a2,0(s3)
}
ffffffffc02010d2:	6406                	ld	s0,64(sp)
ffffffffc02010d4:	60a6                	ld	ra,72(sp)
ffffffffc02010d6:	74e2                	ld	s1,56(sp)
ffffffffc02010d8:	7942                	ld	s2,48(sp)
ffffffffc02010da:	79a2                	ld	s3,40(sp)
ffffffffc02010dc:	7a02                	ld	s4,32(sp)
ffffffffc02010de:	6ae2                	ld	s5,24(sp)
ffffffffc02010e0:	6b42                	ld	s6,16(sp)
ffffffffc02010e2:	6ba2                	ld	s7,8(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc02010e4:	40c58633          	sub	a2,a1,a2
ffffffffc02010e8:	00005797          	auipc	a5,0x5
ffffffffc02010ec:	00c7b423          	sd	a2,8(a5) # ffffffffc02060f0 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc02010f0:	00001517          	auipc	a0,0x1
ffffffffc02010f4:	cd050513          	addi	a0,a0,-816 # ffffffffc0201dc0 <best_fit_pmm_manager+0x190>
}
ffffffffc02010f8:	6161                	addi	sp,sp,80
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc02010fa:	852ff06f          	j	ffffffffc020014c <cprintf>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc02010fe:	609c                	ld	a5,0(s1)
ffffffffc0201100:	00c45593          	srli	a1,s0,0xc
ffffffffc0201104:	06f5f963          	bgeu	a1,a5,ffffffffc0201176 <pmm_init+0x1f8>
    pmm_manager->init_memmap(base, n);
ffffffffc0201108:	00093703          	ld	a4,0(s2)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020110c:	fff80437          	lui	s0,0xfff80
ffffffffc0201110:	95a2                	add	a1,a1,s0
ffffffffc0201112:	000a3503          	ld	a0,0(s4)
ffffffffc0201116:	00259793          	slli	a5,a1,0x2
ffffffffc020111a:	95be                	add	a1,a1,a5
ffffffffc020111c:	6b18                	ld	a4,16(a4)
ffffffffc020111e:	00359793          	slli	a5,a1,0x3
ffffffffc0201122:	953e                	add	a0,a0,a5
ffffffffc0201124:	85de                	mv	a1,s7
ffffffffc0201126:	9702                	jalr	a4
}
ffffffffc0201128:	bf9d                	j	ffffffffc020109e <pmm_init+0x120>
        panic("page_init: invalid physical memory info from DTB");
ffffffffc020112a:	00001617          	auipc	a2,0x1
ffffffffc020112e:	b5660613          	addi	a2,a2,-1194 # ffffffffc0201c80 <best_fit_pmm_manager+0x50>
ffffffffc0201132:	08100593          	li	a1,129
ffffffffc0201136:	00001517          	auipc	a0,0x1
ffffffffc020113a:	b8250513          	addi	a0,a0,-1150 # ffffffffc0201cb8 <best_fit_pmm_manager+0x88>
ffffffffc020113e:	884ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t free_start_pa = PADDR(free_start_va);
ffffffffc0201142:	86ae                	mv	a3,a1
ffffffffc0201144:	00001617          	auipc	a2,0x1
ffffffffc0201148:	bcc60613          	addi	a2,a2,-1076 # ffffffffc0201d10 <best_fit_pmm_manager+0xe0>
ffffffffc020114c:	09d00593          	li	a1,157
ffffffffc0201150:	00001517          	auipc	a0,0x1
ffffffffc0201154:	b6850513          	addi	a0,a0,-1176 # ffffffffc0201cb8 <best_fit_pmm_manager+0x88>
ffffffffc0201158:	86aff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc020115c:	86ae                	mv	a3,a1
ffffffffc020115e:	00001617          	auipc	a2,0x1
ffffffffc0201162:	bb260613          	addi	a2,a2,-1102 # ffffffffc0201d10 <best_fit_pmm_manager+0xe0>
ffffffffc0201166:	0c600593          	li	a1,198
ffffffffc020116a:	00001517          	auipc	a0,0x1
ffffffffc020116e:	b4e50513          	addi	a0,a0,-1202 # ffffffffc0201cb8 <best_fit_pmm_manager+0x88>
ffffffffc0201172:	850ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc0201176:	00001617          	auipc	a2,0x1
ffffffffc020117a:	bfa60613          	addi	a2,a2,-1030 # ffffffffc0201d70 <best_fit_pmm_manager+0x140>
ffffffffc020117e:	06a00593          	li	a1,106
ffffffffc0201182:	00001517          	auipc	a0,0x1
ffffffffc0201186:	c0e50513          	addi	a0,a0,-1010 # ffffffffc0201d90 <best_fit_pmm_manager+0x160>
ffffffffc020118a:	838ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020118e <slub_init>:
    return NULL;
}

void
slub_init(void) {
    if (initialized) {
ffffffffc020118e:	00005617          	auipc	a2,0x5
ffffffffc0201192:	f7a60613          	addi	a2,a2,-134 # ffffffffc0206108 <initialized>
ffffffffc0201196:	421c                	lw	a5,0(a2)
    return list->next == list;
ffffffffc0201198:	00005697          	auipc	a3,0x5
ffffffffc020119c:	e9868693          	addi	a3,a3,-360 # ffffffffc0206030 <all_slabs>
ffffffffc02011a0:	c781                	beqz	a5,ffffffffc02011a8 <slub_init+0x1a>
        assert(list_empty(&all_slabs));
ffffffffc02011a2:	669c                	ld	a5,8(a3)
ffffffffc02011a4:	02d79463          	bne	a5,a3,ffffffffc02011cc <slub_init+0x3e>
ffffffffc02011a8:	00005797          	auipc	a5,0x5
ffffffffc02011ac:	e9878793          	addi	a5,a5,-360 # ffffffffc0206040 <partial>
ffffffffc02011b0:	00005717          	auipc	a4,0x5
ffffffffc02011b4:	f1070713          	addi	a4,a4,-240 # ffffffffc02060c0 <is_panic>
    elm->prev = elm->next = elm;
ffffffffc02011b8:	e79c                	sd	a5,8(a5)
ffffffffc02011ba:	e39c                	sd	a5,0(a5)
    }
    for (unsigned int i = 0; i < SLUB_CLASSES; i++) {
ffffffffc02011bc:	07c1                	addi	a5,a5,16
ffffffffc02011be:	fee79de3          	bne	a5,a4,ffffffffc02011b8 <slub_init+0x2a>
        list_init(&partial[i]);
    }
    list_init(&all_slabs);
    initialized = 1;
ffffffffc02011c2:	4785                	li	a5,1
ffffffffc02011c4:	e694                	sd	a3,8(a3)
ffffffffc02011c6:	e294                	sd	a3,0(a3)
ffffffffc02011c8:	c21c                	sw	a5,0(a2)
ffffffffc02011ca:	8082                	ret
slub_init(void) {
ffffffffc02011cc:	1141                	addi	sp,sp,-16
        assert(list_empty(&all_slabs));
ffffffffc02011ce:	00001697          	auipc	a3,0x1
ffffffffc02011d2:	c6268693          	addi	a3,a3,-926 # ffffffffc0201e30 <best_fit_pmm_manager+0x200>
ffffffffc02011d6:	00000617          	auipc	a2,0x0
ffffffffc02011da:	71a60613          	addi	a2,a2,1818 # ffffffffc02018f0 <etext+0x26c>
ffffffffc02011de:	04800593          	li	a1,72
ffffffffc02011e2:	00001517          	auipc	a0,0x1
ffffffffc02011e6:	c3e50513          	addi	a0,a0,-962 # ffffffffc0201e20 <best_fit_pmm_manager+0x1f0>
slub_init(void) {
ffffffffc02011ea:	e406                	sd	ra,8(sp)
        assert(list_empty(&all_slabs));
ffffffffc02011ec:	fd7fe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02011f0 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc02011f0:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02011f4:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc02011f6:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02011fa:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc02011fc:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201200:	f022                	sd	s0,32(sp)
ffffffffc0201202:	ec26                	sd	s1,24(sp)
ffffffffc0201204:	e84a                	sd	s2,16(sp)
ffffffffc0201206:	f406                	sd	ra,40(sp)
ffffffffc0201208:	e44e                	sd	s3,8(sp)
ffffffffc020120a:	84aa                	mv	s1,a0
ffffffffc020120c:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc020120e:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0201212:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0201214:	03067e63          	bgeu	a2,a6,ffffffffc0201250 <printnum+0x60>
ffffffffc0201218:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc020121a:	00805763          	blez	s0,ffffffffc0201228 <printnum+0x38>
ffffffffc020121e:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0201220:	85ca                	mv	a1,s2
ffffffffc0201222:	854e                	mv	a0,s3
ffffffffc0201224:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201226:	fc65                	bnez	s0,ffffffffc020121e <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201228:	1a02                	slli	s4,s4,0x20
ffffffffc020122a:	00001797          	auipc	a5,0x1
ffffffffc020122e:	c1e78793          	addi	a5,a5,-994 # ffffffffc0201e48 <best_fit_pmm_manager+0x218>
ffffffffc0201232:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201236:	9a3e                	add	s4,s4,a5
}
ffffffffc0201238:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020123a:	000a4503          	lbu	a0,0(s4)
}
ffffffffc020123e:	70a2                	ld	ra,40(sp)
ffffffffc0201240:	69a2                	ld	s3,8(sp)
ffffffffc0201242:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201244:	85ca                	mv	a1,s2
ffffffffc0201246:	87a6                	mv	a5,s1
}
ffffffffc0201248:	6942                	ld	s2,16(sp)
ffffffffc020124a:	64e2                	ld	s1,24(sp)
ffffffffc020124c:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020124e:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201250:	03065633          	divu	a2,a2,a6
ffffffffc0201254:	8722                	mv	a4,s0
ffffffffc0201256:	f9bff0ef          	jal	ra,ffffffffc02011f0 <printnum>
ffffffffc020125a:	b7f9                	j	ffffffffc0201228 <printnum+0x38>

ffffffffc020125c <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc020125c:	7119                	addi	sp,sp,-128
ffffffffc020125e:	f4a6                	sd	s1,104(sp)
ffffffffc0201260:	f0ca                	sd	s2,96(sp)
ffffffffc0201262:	ecce                	sd	s3,88(sp)
ffffffffc0201264:	e8d2                	sd	s4,80(sp)
ffffffffc0201266:	e4d6                	sd	s5,72(sp)
ffffffffc0201268:	e0da                	sd	s6,64(sp)
ffffffffc020126a:	fc5e                	sd	s7,56(sp)
ffffffffc020126c:	f06a                	sd	s10,32(sp)
ffffffffc020126e:	fc86                	sd	ra,120(sp)
ffffffffc0201270:	f8a2                	sd	s0,112(sp)
ffffffffc0201272:	f862                	sd	s8,48(sp)
ffffffffc0201274:	f466                	sd	s9,40(sp)
ffffffffc0201276:	ec6e                	sd	s11,24(sp)
ffffffffc0201278:	892a                	mv	s2,a0
ffffffffc020127a:	84ae                	mv	s1,a1
ffffffffc020127c:	8d32                	mv	s10,a2
ffffffffc020127e:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201280:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0201284:	5b7d                	li	s6,-1
ffffffffc0201286:	00001a97          	auipc	s5,0x1
ffffffffc020128a:	bf6a8a93          	addi	s5,s5,-1034 # ffffffffc0201e7c <best_fit_pmm_manager+0x24c>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020128e:	00001b97          	auipc	s7,0x1
ffffffffc0201292:	dcab8b93          	addi	s7,s7,-566 # ffffffffc0202058 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201296:	000d4503          	lbu	a0,0(s10)
ffffffffc020129a:	001d0413          	addi	s0,s10,1
ffffffffc020129e:	01350a63          	beq	a0,s3,ffffffffc02012b2 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc02012a2:	c121                	beqz	a0,ffffffffc02012e2 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc02012a4:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012a6:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc02012a8:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012aa:	fff44503          	lbu	a0,-1(s0) # fffffffffff7ffff <end+0x3fd79ef3>
ffffffffc02012ae:	ff351ae3          	bne	a0,s3,ffffffffc02012a2 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012b2:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc02012b6:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc02012ba:	4c81                	li	s9,0
ffffffffc02012bc:	4881                	li	a7,0
        width = precision = -1;
ffffffffc02012be:	5c7d                	li	s8,-1
ffffffffc02012c0:	5dfd                	li	s11,-1
ffffffffc02012c2:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc02012c6:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012c8:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02012cc:	0ff5f593          	zext.b	a1,a1
ffffffffc02012d0:	00140d13          	addi	s10,s0,1
ffffffffc02012d4:	04b56263          	bltu	a0,a1,ffffffffc0201318 <vprintfmt+0xbc>
ffffffffc02012d8:	058a                	slli	a1,a1,0x2
ffffffffc02012da:	95d6                	add	a1,a1,s5
ffffffffc02012dc:	4194                	lw	a3,0(a1)
ffffffffc02012de:	96d6                	add	a3,a3,s5
ffffffffc02012e0:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc02012e2:	70e6                	ld	ra,120(sp)
ffffffffc02012e4:	7446                	ld	s0,112(sp)
ffffffffc02012e6:	74a6                	ld	s1,104(sp)
ffffffffc02012e8:	7906                	ld	s2,96(sp)
ffffffffc02012ea:	69e6                	ld	s3,88(sp)
ffffffffc02012ec:	6a46                	ld	s4,80(sp)
ffffffffc02012ee:	6aa6                	ld	s5,72(sp)
ffffffffc02012f0:	6b06                	ld	s6,64(sp)
ffffffffc02012f2:	7be2                	ld	s7,56(sp)
ffffffffc02012f4:	7c42                	ld	s8,48(sp)
ffffffffc02012f6:	7ca2                	ld	s9,40(sp)
ffffffffc02012f8:	7d02                	ld	s10,32(sp)
ffffffffc02012fa:	6de2                	ld	s11,24(sp)
ffffffffc02012fc:	6109                	addi	sp,sp,128
ffffffffc02012fe:	8082                	ret
            padc = '0';
ffffffffc0201300:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0201302:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201306:	846a                	mv	s0,s10
ffffffffc0201308:	00140d13          	addi	s10,s0,1
ffffffffc020130c:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201310:	0ff5f593          	zext.b	a1,a1
ffffffffc0201314:	fcb572e3          	bgeu	a0,a1,ffffffffc02012d8 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201318:	85a6                	mv	a1,s1
ffffffffc020131a:	02500513          	li	a0,37
ffffffffc020131e:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201320:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201324:	8d22                	mv	s10,s0
ffffffffc0201326:	f73788e3          	beq	a5,s3,ffffffffc0201296 <vprintfmt+0x3a>
ffffffffc020132a:	ffed4783          	lbu	a5,-2(s10)
ffffffffc020132e:	1d7d                	addi	s10,s10,-1
ffffffffc0201330:	ff379de3          	bne	a5,s3,ffffffffc020132a <vprintfmt+0xce>
ffffffffc0201334:	b78d                	j	ffffffffc0201296 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201336:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc020133a:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020133e:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201340:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201344:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201348:	02d86463          	bltu	a6,a3,ffffffffc0201370 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc020134c:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201350:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201354:	0186873b          	addw	a4,a3,s8
ffffffffc0201358:	0017171b          	slliw	a4,a4,0x1
ffffffffc020135c:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc020135e:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201362:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201364:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201368:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020136c:	fed870e3          	bgeu	a6,a3,ffffffffc020134c <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201370:	f40ddce3          	bgez	s11,ffffffffc02012c8 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201374:	8de2                	mv	s11,s8
ffffffffc0201376:	5c7d                	li	s8,-1
ffffffffc0201378:	bf81                	j	ffffffffc02012c8 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc020137a:	fffdc693          	not	a3,s11
ffffffffc020137e:	96fd                	srai	a3,a3,0x3f
ffffffffc0201380:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201384:	00144603          	lbu	a2,1(s0)
ffffffffc0201388:	2d81                	sext.w	s11,s11
ffffffffc020138a:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020138c:	bf35                	j	ffffffffc02012c8 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc020138e:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201392:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201396:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201398:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc020139a:	bfd9                	j	ffffffffc0201370 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc020139c:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020139e:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013a2:	01174463          	blt	a4,a7,ffffffffc02013aa <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc02013a6:	1a088e63          	beqz	a7,ffffffffc0201562 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc02013aa:	000a3603          	ld	a2,0(s4)
ffffffffc02013ae:	46c1                	li	a3,16
ffffffffc02013b0:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc02013b2:	2781                	sext.w	a5,a5
ffffffffc02013b4:	876e                	mv	a4,s11
ffffffffc02013b6:	85a6                	mv	a1,s1
ffffffffc02013b8:	854a                	mv	a0,s2
ffffffffc02013ba:	e37ff0ef          	jal	ra,ffffffffc02011f0 <printnum>
            break;
ffffffffc02013be:	bde1                	j	ffffffffc0201296 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc02013c0:	000a2503          	lw	a0,0(s4)
ffffffffc02013c4:	85a6                	mv	a1,s1
ffffffffc02013c6:	0a21                	addi	s4,s4,8
ffffffffc02013c8:	9902                	jalr	s2
            break;
ffffffffc02013ca:	b5f1                	j	ffffffffc0201296 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02013cc:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02013ce:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013d2:	01174463          	blt	a4,a7,ffffffffc02013da <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc02013d6:	18088163          	beqz	a7,ffffffffc0201558 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc02013da:	000a3603          	ld	a2,0(s4)
ffffffffc02013de:	46a9                	li	a3,10
ffffffffc02013e0:	8a2e                	mv	s4,a1
ffffffffc02013e2:	bfc1                	j	ffffffffc02013b2 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013e4:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc02013e8:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013ea:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02013ec:	bdf1                	j	ffffffffc02012c8 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc02013ee:	85a6                	mv	a1,s1
ffffffffc02013f0:	02500513          	li	a0,37
ffffffffc02013f4:	9902                	jalr	s2
            break;
ffffffffc02013f6:	b545                	j	ffffffffc0201296 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013f8:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc02013fc:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013fe:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201400:	b5e1                	j	ffffffffc02012c8 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0201402:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201404:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201408:	01174463          	blt	a4,a7,ffffffffc0201410 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc020140c:	14088163          	beqz	a7,ffffffffc020154e <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0201410:	000a3603          	ld	a2,0(s4)
ffffffffc0201414:	46a1                	li	a3,8
ffffffffc0201416:	8a2e                	mv	s4,a1
ffffffffc0201418:	bf69                	j	ffffffffc02013b2 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc020141a:	03000513          	li	a0,48
ffffffffc020141e:	85a6                	mv	a1,s1
ffffffffc0201420:	e03e                	sd	a5,0(sp)
ffffffffc0201422:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201424:	85a6                	mv	a1,s1
ffffffffc0201426:	07800513          	li	a0,120
ffffffffc020142a:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc020142c:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc020142e:	6782                	ld	a5,0(sp)
ffffffffc0201430:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201432:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201436:	bfb5                	j	ffffffffc02013b2 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201438:	000a3403          	ld	s0,0(s4)
ffffffffc020143c:	008a0713          	addi	a4,s4,8
ffffffffc0201440:	e03a                	sd	a4,0(sp)
ffffffffc0201442:	14040263          	beqz	s0,ffffffffc0201586 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201446:	0fb05763          	blez	s11,ffffffffc0201534 <vprintfmt+0x2d8>
ffffffffc020144a:	02d00693          	li	a3,45
ffffffffc020144e:	0cd79163          	bne	a5,a3,ffffffffc0201510 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201452:	00044783          	lbu	a5,0(s0)
ffffffffc0201456:	0007851b          	sext.w	a0,a5
ffffffffc020145a:	cf85                	beqz	a5,ffffffffc0201492 <vprintfmt+0x236>
ffffffffc020145c:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201460:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201464:	000c4563          	bltz	s8,ffffffffc020146e <vprintfmt+0x212>
ffffffffc0201468:	3c7d                	addiw	s8,s8,-1
ffffffffc020146a:	036c0263          	beq	s8,s6,ffffffffc020148e <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc020146e:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201470:	0e0c8e63          	beqz	s9,ffffffffc020156c <vprintfmt+0x310>
ffffffffc0201474:	3781                	addiw	a5,a5,-32
ffffffffc0201476:	0ef47b63          	bgeu	s0,a5,ffffffffc020156c <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc020147a:	03f00513          	li	a0,63
ffffffffc020147e:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201480:	000a4783          	lbu	a5,0(s4)
ffffffffc0201484:	3dfd                	addiw	s11,s11,-1
ffffffffc0201486:	0a05                	addi	s4,s4,1
ffffffffc0201488:	0007851b          	sext.w	a0,a5
ffffffffc020148c:	ffe1                	bnez	a5,ffffffffc0201464 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc020148e:	01b05963          	blez	s11,ffffffffc02014a0 <vprintfmt+0x244>
ffffffffc0201492:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201494:	85a6                	mv	a1,s1
ffffffffc0201496:	02000513          	li	a0,32
ffffffffc020149a:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc020149c:	fe0d9be3          	bnez	s11,ffffffffc0201492 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02014a0:	6a02                	ld	s4,0(sp)
ffffffffc02014a2:	bbd5                	j	ffffffffc0201296 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02014a4:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02014a6:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc02014aa:	01174463          	blt	a4,a7,ffffffffc02014b2 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc02014ae:	08088d63          	beqz	a7,ffffffffc0201548 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc02014b2:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc02014b6:	0a044d63          	bltz	s0,ffffffffc0201570 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc02014ba:	8622                	mv	a2,s0
ffffffffc02014bc:	8a66                	mv	s4,s9
ffffffffc02014be:	46a9                	li	a3,10
ffffffffc02014c0:	bdcd                	j	ffffffffc02013b2 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc02014c2:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02014c6:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc02014c8:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc02014ca:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc02014ce:	8fb5                	xor	a5,a5,a3
ffffffffc02014d0:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02014d4:	02d74163          	blt	a4,a3,ffffffffc02014f6 <vprintfmt+0x29a>
ffffffffc02014d8:	00369793          	slli	a5,a3,0x3
ffffffffc02014dc:	97de                	add	a5,a5,s7
ffffffffc02014de:	639c                	ld	a5,0(a5)
ffffffffc02014e0:	cb99                	beqz	a5,ffffffffc02014f6 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc02014e2:	86be                	mv	a3,a5
ffffffffc02014e4:	00001617          	auipc	a2,0x1
ffffffffc02014e8:	99460613          	addi	a2,a2,-1644 # ffffffffc0201e78 <best_fit_pmm_manager+0x248>
ffffffffc02014ec:	85a6                	mv	a1,s1
ffffffffc02014ee:	854a                	mv	a0,s2
ffffffffc02014f0:	0ce000ef          	jal	ra,ffffffffc02015be <printfmt>
ffffffffc02014f4:	b34d                	j	ffffffffc0201296 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc02014f6:	00001617          	auipc	a2,0x1
ffffffffc02014fa:	97260613          	addi	a2,a2,-1678 # ffffffffc0201e68 <best_fit_pmm_manager+0x238>
ffffffffc02014fe:	85a6                	mv	a1,s1
ffffffffc0201500:	854a                	mv	a0,s2
ffffffffc0201502:	0bc000ef          	jal	ra,ffffffffc02015be <printfmt>
ffffffffc0201506:	bb41                	j	ffffffffc0201296 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201508:	00001417          	auipc	s0,0x1
ffffffffc020150c:	95840413          	addi	s0,s0,-1704 # ffffffffc0201e60 <best_fit_pmm_manager+0x230>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201510:	85e2                	mv	a1,s8
ffffffffc0201512:	8522                	mv	a0,s0
ffffffffc0201514:	e43e                	sd	a5,8(sp)
ffffffffc0201516:	0fc000ef          	jal	ra,ffffffffc0201612 <strnlen>
ffffffffc020151a:	40ad8dbb          	subw	s11,s11,a0
ffffffffc020151e:	01b05b63          	blez	s11,ffffffffc0201534 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201522:	67a2                	ld	a5,8(sp)
ffffffffc0201524:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201528:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc020152a:	85a6                	mv	a1,s1
ffffffffc020152c:	8552                	mv	a0,s4
ffffffffc020152e:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201530:	fe0d9ce3          	bnez	s11,ffffffffc0201528 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201534:	00044783          	lbu	a5,0(s0)
ffffffffc0201538:	00140a13          	addi	s4,s0,1
ffffffffc020153c:	0007851b          	sext.w	a0,a5
ffffffffc0201540:	d3a5                	beqz	a5,ffffffffc02014a0 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201542:	05e00413          	li	s0,94
ffffffffc0201546:	bf39                	j	ffffffffc0201464 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201548:	000a2403          	lw	s0,0(s4)
ffffffffc020154c:	b7ad                	j	ffffffffc02014b6 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc020154e:	000a6603          	lwu	a2,0(s4)
ffffffffc0201552:	46a1                	li	a3,8
ffffffffc0201554:	8a2e                	mv	s4,a1
ffffffffc0201556:	bdb1                	j	ffffffffc02013b2 <vprintfmt+0x156>
ffffffffc0201558:	000a6603          	lwu	a2,0(s4)
ffffffffc020155c:	46a9                	li	a3,10
ffffffffc020155e:	8a2e                	mv	s4,a1
ffffffffc0201560:	bd89                	j	ffffffffc02013b2 <vprintfmt+0x156>
ffffffffc0201562:	000a6603          	lwu	a2,0(s4)
ffffffffc0201566:	46c1                	li	a3,16
ffffffffc0201568:	8a2e                	mv	s4,a1
ffffffffc020156a:	b5a1                	j	ffffffffc02013b2 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc020156c:	9902                	jalr	s2
ffffffffc020156e:	bf09                	j	ffffffffc0201480 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201570:	85a6                	mv	a1,s1
ffffffffc0201572:	02d00513          	li	a0,45
ffffffffc0201576:	e03e                	sd	a5,0(sp)
ffffffffc0201578:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc020157a:	6782                	ld	a5,0(sp)
ffffffffc020157c:	8a66                	mv	s4,s9
ffffffffc020157e:	40800633          	neg	a2,s0
ffffffffc0201582:	46a9                	li	a3,10
ffffffffc0201584:	b53d                	j	ffffffffc02013b2 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201586:	03b05163          	blez	s11,ffffffffc02015a8 <vprintfmt+0x34c>
ffffffffc020158a:	02d00693          	li	a3,45
ffffffffc020158e:	f6d79de3          	bne	a5,a3,ffffffffc0201508 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201592:	00001417          	auipc	s0,0x1
ffffffffc0201596:	8ce40413          	addi	s0,s0,-1842 # ffffffffc0201e60 <best_fit_pmm_manager+0x230>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020159a:	02800793          	li	a5,40
ffffffffc020159e:	02800513          	li	a0,40
ffffffffc02015a2:	00140a13          	addi	s4,s0,1
ffffffffc02015a6:	bd6d                	j	ffffffffc0201460 <vprintfmt+0x204>
ffffffffc02015a8:	00001a17          	auipc	s4,0x1
ffffffffc02015ac:	8b9a0a13          	addi	s4,s4,-1863 # ffffffffc0201e61 <best_fit_pmm_manager+0x231>
ffffffffc02015b0:	02800513          	li	a0,40
ffffffffc02015b4:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02015b8:	05e00413          	li	s0,94
ffffffffc02015bc:	b565                	j	ffffffffc0201464 <vprintfmt+0x208>

ffffffffc02015be <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015be:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc02015c0:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015c4:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02015c6:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015c8:	ec06                	sd	ra,24(sp)
ffffffffc02015ca:	f83a                	sd	a4,48(sp)
ffffffffc02015cc:	fc3e                	sd	a5,56(sp)
ffffffffc02015ce:	e0c2                	sd	a6,64(sp)
ffffffffc02015d0:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc02015d2:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc02015d4:	c89ff0ef          	jal	ra,ffffffffc020125c <vprintfmt>
}
ffffffffc02015d8:	60e2                	ld	ra,24(sp)
ffffffffc02015da:	6161                	addi	sp,sp,80
ffffffffc02015dc:	8082                	ret

ffffffffc02015de <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02015de:	4781                	li	a5,0
ffffffffc02015e0:	00005717          	auipc	a4,0x5
ffffffffc02015e4:	a3073703          	ld	a4,-1488(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc02015e8:	88ba                	mv	a7,a4
ffffffffc02015ea:	852a                	mv	a0,a0
ffffffffc02015ec:	85be                	mv	a1,a5
ffffffffc02015ee:	863e                	mv	a2,a5
ffffffffc02015f0:	00000073          	ecall
ffffffffc02015f4:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc02015f6:	8082                	ret

ffffffffc02015f8 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02015f8:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02015fc:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02015fe:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201600:	cb81                	beqz	a5,ffffffffc0201610 <strlen+0x18>
        cnt ++;
ffffffffc0201602:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201604:	00a707b3          	add	a5,a4,a0
ffffffffc0201608:	0007c783          	lbu	a5,0(a5)
ffffffffc020160c:	fbfd                	bnez	a5,ffffffffc0201602 <strlen+0xa>
ffffffffc020160e:	8082                	ret
    }
    return cnt;
}
ffffffffc0201610:	8082                	ret

ffffffffc0201612 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201612:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201614:	e589                	bnez	a1,ffffffffc020161e <strnlen+0xc>
ffffffffc0201616:	a811                	j	ffffffffc020162a <strnlen+0x18>
        cnt ++;
ffffffffc0201618:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc020161a:	00f58863          	beq	a1,a5,ffffffffc020162a <strnlen+0x18>
ffffffffc020161e:	00f50733          	add	a4,a0,a5
ffffffffc0201622:	00074703          	lbu	a4,0(a4)
ffffffffc0201626:	fb6d                	bnez	a4,ffffffffc0201618 <strnlen+0x6>
ffffffffc0201628:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc020162a:	852e                	mv	a0,a1
ffffffffc020162c:	8082                	ret

ffffffffc020162e <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020162e:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201632:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201636:	cb89                	beqz	a5,ffffffffc0201648 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201638:	0505                	addi	a0,a0,1
ffffffffc020163a:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020163c:	fee789e3          	beq	a5,a4,ffffffffc020162e <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201640:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201644:	9d19                	subw	a0,a0,a4
ffffffffc0201646:	8082                	ret
ffffffffc0201648:	4501                	li	a0,0
ffffffffc020164a:	bfed                	j	ffffffffc0201644 <strcmp+0x16>

ffffffffc020164c <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020164c:	c20d                	beqz	a2,ffffffffc020166e <strncmp+0x22>
ffffffffc020164e:	962e                	add	a2,a2,a1
ffffffffc0201650:	a031                	j	ffffffffc020165c <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201652:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201654:	00e79a63          	bne	a5,a4,ffffffffc0201668 <strncmp+0x1c>
ffffffffc0201658:	00b60b63          	beq	a2,a1,ffffffffc020166e <strncmp+0x22>
ffffffffc020165c:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201660:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201662:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201666:	f7f5                	bnez	a5,ffffffffc0201652 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201668:	40e7853b          	subw	a0,a5,a4
}
ffffffffc020166c:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020166e:	4501                	li	a0,0
ffffffffc0201670:	8082                	ret

ffffffffc0201672 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201672:	ca01                	beqz	a2,ffffffffc0201682 <memset+0x10>
ffffffffc0201674:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201676:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201678:	0785                	addi	a5,a5,1
ffffffffc020167a:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc020167e:	fec79de3          	bne	a5,a2,ffffffffc0201678 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201682:	8082                	ret

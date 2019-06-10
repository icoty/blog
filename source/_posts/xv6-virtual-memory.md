---
title: XV6源代码阅读-虚拟内存管理
date: 2019-06-09 03:18:06
tags: [虚拟内存, XV6]
categories:
  - [操作系统]
copyright: true
mathjax: true
---

## Exercise1 源代码阅读

1. 内存管理部分: kalloc.c vm.c 以及相关其他文件代码
- 	kalloc.c：char * kalloc(void)负责在需要的时候为用户空间、内核栈、页表页以及缓冲区分配物理内存，将物理地址转为虚拟地址返回，物理页大小为4k。void kfree(char * v)接收一个虚拟地址，找对对应的物理地址进行释放。xv6使用空闲内存的前部分作为指针域来指向下一页空闲内存，物理内存管理是以页（4K）为单位进行分配的。物理内存空间上空闲的每一页，都有一个指针域（虚拟地址）指向下一个空闲页，最后一个空闲页为NULL ，通过这种方式，kmem只需要保存着虚拟地址空间上的freelist地址即可；

```bash
// kalloc.c
// Physical memory allocator, intended to allocate
// memory for user processes, kernel stacks, page table pages,
// and pipe buffers. Allocates 4096-byte pages.

void freerange(void *vstart, void *vend);
extern char end[]; // first address after kernel loaded from ELF file

struct run {
  struct run *next;
};

struct {
  struct spinlock lock;
  int use_lock;
  struct run *freelist;
} kmem;
```

- xv6让每个进程都有独立的页表结构，在切换进程时总是需要切换页表，switchkvm设置cr3寄存器的值为kpgdir首地址，kpgdir仅仅在scheduler内核线程中使用。页表和内核栈都是每个进程独有的，xv6使用结构体proc将它们统一起来，在进程切换的时候，他们也往往随着进程切换而切换，内核中模拟出了一个内核线程，它独占内核栈和内核页表kpgdir，它是所有进程调度的基础。switchuvm通过传入的proc结构负责切换相关的进程独有的数据结构，其中包括TSS相关的操作，然后将进程特有的页表载入cr3寄存器，完成设置进程相关的虚拟地址空间环境；

```bash
// vm.c

……

// Switch h/w page table register to the kernel-only page table,
// for when no process is running.
void
switchkvm(void)
{
  lcr3(v2p(kpgdir));   // switch to the kernel page table
}

// Switch TSS and h/w page table to correspond to process p.
void
switchuvm(struct proc *p)
{
  pushcli();
  cpu->gdt[SEG_TSS] = SEG16(STS_T32A, &cpu->ts, sizeof(cpu->ts)-1, 0);
  cpu->gdt[SEG_TSS].s = 0;
  cpu->ts.ss0 = SEG_KDATA << 3;
  cpu->ts.esp0 = (uint)proc->kstack + KSTACKSIZE;
  ltr(SEG_TSS << 3);
  if(p->pgdir == 0)
    panic("switchuvm: no pgdir");
  lcr3(v2p(p->pgdir));  // switch to new address space
  popcli();
}
```
- 进程的页表在使用前往往需要初始化，其中必须包含内核代码的映射，这样进程在进入内核时便不需要再次切换页表，进程使用虚拟地址空间的低地址部分，高地址部分留给内核，主要接口：
   - pde_t * setupkvm(void)通过kalloc分配一页内存作为页目录，然后将按照kmap数据结构映射内核虚拟地址空间到物理地址空间，期间调用了工具函数mappages；
   - 	int allocuvm(pde_t * pgdir, uint oldsz, uint newsz)在设置页表的同时分配虚拟地址oldsz到newsz的以页为单位的内存；
   - 	int deallocuvm(pde_t * pgdir, uint oldsz, uint newsz)则将newsz到oldsz对应的虚拟地址空间内存置为空闲；
   - 	int loaduvm(pde_t * pgdir, char * addr, struct inode * ip, uint offset, uint sz)将文件系统上的i节点内容读取载入到相应的地址上，通过allocuvm接口为用户进程分配内存和设置页表，然后调用loaduvm接口将文件系统上的程序载入到内存，便能够为exec系统调用提供接口，为用户进程的正式运行做准备；
   - 	当进程销毁需要回收内存时，调用void freevm(pde_t * pgdir)清除用户进程相关的内存环境，其首先调用将0到KERNBASE的虚拟地址空间回收，然后销毁整个进程的页表；
   - pde_t * copyuvm(pde_t * pgdir, uint sz)负责复制一个新的页表并分配新的内存，新的内存布局和旧的完全一样，xv6使用这个函数作为fork()底层实现。

## Exercise2 带着问题阅读

1. XV6初始化之后到执行main.c时，内存布局是怎样的(其中已有哪些内容)?

- 内核代码存在于物理地址低地址的0x100000处，页表为main.c文件中的entrypgdir数组，其中虚拟地址低4M映射物理地址低4M，虚拟地址 [KERNBASE, KERNBASE+4MB) 映射到 物理地址[0, 4MB)；

- 紧接着调用kinit1初始化内核末尾到物理内存4M的物理内存空间为未使用，然后调用kinit2初始化剩余内核空间到PHYSTOP为未使用。kinit1调用前使用的还是最初的页表（也就是是上面的内存布局），所以只能初始化4M，同时由于后期再构建新页表时也要使用页表转换机制来找到实际存放页表的物理内存空间，这就构成了自举问题，xv6通过在main函数最开始处释放内核末尾到4Mb的空间来分配页表，由于在最开始时多核CPU还未启动，所以没有设置锁机制。kinit2在内核构建了新页表后，能够完全访问内核的虚拟地址空间，所以在这里初始化所有物理内存，并开始了锁机制保护空闲内存链表；
- 然后main函数通过调用void kvmalloc(void)函数来实现内核新页表的初始化；
- 最后内存布局和地址空间如下：内核末尾物理地址到物理地址PHYSTOP的内存空间未使用，虚拟地址空间KERNBASE以上部分映射到物理内存低地址相应位置。

```bash
// kalloc.c
// Initialization happens in two phases.
// 1. main() calls kinit1() while still using entrypgdir to place just
// the pages mapped by entrypgdir on free list.
// 2. main() calls kinit2() with the rest of the physical pages
// after installing a full page table that maps them on all cores.
void
kinit1(void *vstart, void *vend)
{
  initlock(&kmem.lock, "kmem");
  kmem.use_lock = 0;
  freerange(vstart, vend);
}

void
kinit2(void *vstart, void *vend)
{
  freerange(vstart, vend);
  kmem.use_lock = 1;
}

// kmap.c
……
// This table defines the kernel's mappings, which are present in
// every process's page table.
static struct kmap {
  void *virt;
  uint phys_start;
  uint phys_end;
  int perm;
} kmap[] = {
 { (void*)KERNBASE, 0,             EXTMEM,    PTE_W}, // I/O space
 { (void*)KERNLINK, V2P(KERNLINK), V2P(data), 0},     // kern text+rodata
 { (void*)data,     V2P(data),     PHYSTOP,   PTE_W}, // kern data+memory
 { (void*)DEVSPACE, DEVSPACE,      0,         PTE_W}, // more devices
};
……
```
2.	 XV6 的动态内存管理是如何完成的? 有一个kmem(链表)，用于管理可分配的物理内存页。(vend=0x00400000，也就是可分配的内存页最大为4Mb)
	详见“Exercise 1  源代码阅读”部分，已经作出完整解答。

3.	 XV6的虚拟内存是如何初始化的? 画出XV6的虚拟内存布局图，请说出每一部分对应的内容是什么。见memlayout.h和vm.c的kmap上的注释?

- main函数通过调用void kinit1(void * vstart, void * vend), void kinit2(void * vstart, void * vend), void kvmalloc(void)函数来实现内核新页表的初始化。虚拟地址与物理地址的转换接口：
```bash
// memlayout.h
// Memory layout

#define EXTMEM  0x100000            // Start of extended memory
#define PHYSTOP 0xE000000           // Top physical memory
#define DEVSPACE 0xFE000000         // Other devices are at high addresses

// Key addresses for address space layout (see kmap in vm.c for layout)
#define KERNBASE 0x80000000         // First kernel virtual address
#define KERNLINK (KERNBASE+EXTMEM)  // Address where kernel is linked

#ifndef __ASSEMBLER__

static inline uint v2p(void *a) { return ((uint) (a))  - KERNBASE; }
static inline void *p2v(uint a) { return (void *) ((a) + KERNBASE); }

#endif

#define V2P(a) (((uint) (a)) - KERNBASE)
#define P2V(a) (((void *) (a)) + KERNBASE)

#define V2P_WO(x) ((x) - KERNBASE)    // same as V2P, but without casts
#define P2V_WO(x) ((x) + KERNBASE)    // same as V2P, but without casts
```

- 内存布局：

![聊天窗口模型](xv6-virtual-memory/memlayout)

4. 关于XV6 的内存页式管理。发生中断时，用哪个页表? 一个内存页是多大? 页目录有多少项? 页表有多少项? 最大支持多大的内存? 画出从虚拟地址到物理地址的转换图。在XV6中，是如何将虚拟地址与物理地址映射的(调用了哪些函数实现了哪些功能)?

- 发生中断时，将换入cpu的进程的页表首地址存入cr3寄存器；一个内存页为4k；XV6页表采用的二级目录，一级目录有$2^{10}$条，二级目录有$2^{10} * 2^{10}$条；页表项为$2^2$Bytes，故页表有$2^{12} / 2^2 = 2^{10} = 1024$项；最大支持4G内存；

![聊天窗口模型](xv6-virtual-memory/V2P)

- 	物理内存页的申请与释放，虚拟地址与物理地址如何映射等在“Exercise 1  源代码阅读”都已经详述了，在此主要说下mappages接口，虚拟地址 * va与物理地址 * pa映射size个字节，同时赋予该页的权限perm，如下:

```bash
// vm.c
……
// Create PTEs for virtual addresses starting at va that refer to
// physical addresses starting at pa. va and size might not
// be page-aligned.
static int
mappages(pde_t *pgdir, void *va, uint size, uint pa, int perm)
{
  char *a, *last;
  pte_t *pte;
  
  a = (char*)PGROUNDDOWN((uint)va);
  last = (char*)PGROUNDDOWN(((uint)va) + size - 1);
  for(;;){
    if((pte = walkpgdir(pgdir, a, 1)) == 0)
      return -1;
    if(*pte & PTE_P)
      panic("remap");
    *pte = pa | perm | PTE_P;
    if(a == last)
      break;
    a += PGSIZE;
    pa += PGSIZE;
  }
  return 0;
}
……
```

## 参考文献

[1] [xv6虚拟内存-博客园](https://www.cnblogs.com/hehao98/p/10683588.html)
[2] [xv6 virtual memory-hexo](http://linbo.github.io/2017/10/01/xv6-vm)
[3] [xv6内存管理-简书](https://www.jianshu.com/p/13921afe0fde)
[4] [xv6内存管理-CSDN](https://blog.csdn.net/qq_25426415/article/details/54633843)


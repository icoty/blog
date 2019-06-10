---
title: XV6源代码阅读-同步机制
date: 2019-06-08 15:28:40
tags: [XV6, 自旋锁, 中断]
categories:
  - [同步机制]
  - [操作系统]
copyright: true
---

## Exercise1 源代码阅读

锁部分：spinlock.h/spinlock.c以及相关其他文件代码

```bash
// Mutual exclusion lock.
struct spinlock {
  uint locked; // 0未被占用, 1已被占用
  
  // For debugging:
  char *name;        // Name of lock.
  struct cpu *cpu;   // The cpu holding the lock.
  uint pcs[10];      // The call stack (an array of program counters)
                     // that locked the lock.
};

// 初始化自旋锁
void initlock(struct spinlock *lk, char *name)
{
  lk->name = name;
  lk->locked = 0;
  lk->cpu = 0;
}

// Acquire the lock.
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void acquire(struct spinlock *lk)
{
  // 关中断
  pushcli(); // disable interrupts to avoid deadlock.
  if(holding(lk)) // 判断锁的持有是否为当前cpu
    panic("acquire");

  // The xchg is atomic.
  // It also serializes, so that reads after acquire are not
  // reordered before it. 
  while(xchg(&lk->locked, 1) != 0); // 拿不到锁开始自旋

  // Record info about lock acquisition for debugging.
  lk->cpu = cpu;
  getcallerpcs(&lk, lk->pcs);
}

// Release the lock.
void release(struct spinlock *lk)
{
  if(!holding(lk))
    panic("release");

  lk->pcs[0] = 0;
  lk->cpu = 0;

  // The xchg serializes, so that reads before release are 
  // not reordered after it.  The 1996 PentiumPro manual (Volume 3,
  // 7.2) says reads can be carried out speculatively and in
  // any order, which implies we need to serialize here.
  // But the 2007 Intel 64 Architecture Memory Ordering White
  // Paper says that Intel 64 and IA-32 will not move a load
  // after a store. So lock->locked = 0 would work here.
  // The xchg being asm volatile ensures gcc emits it after
  // the above assignments (and after the critical section).
  xchg(&lk->locked, 0);

  popcli();
}
```

## Exercise2 带着问题阅读

1. 什么是临界区? 什么是同步和互斥? 什么是竞争状态? 临界区操作时中断是否应该开启? 中断会有什么影响? XV6的锁是如何实现的，有什么操作? xchg 是什么指令，该指令有何特性?

- 临界区(Critical Section)：访问临界区的那段代码，多个进程/线程必须互斥进入临界区；
- 同步(Synchronization)：指多个进程/线程能够按照程序员期望的方式来协调执行顺序，为了实现这个目的，必须要借助于同步机制(如信号量，条件变量，管程等)；
- 互斥(Mutual Exclusion)：互斥的目的是保护临界区；
- 竞争状态：竞争是基于并发环境下的，单个进程/线程不存在竞争，在并发环境下，多个进程/线程都需要请求某资源的时候，只有竞争到该资源的进程/线程才能够执行，释放资源后，剩余进程/线程按照预定的算法策略重新竞争；
- 操作临界区必须关中断，对临界区的操作是原子性的；
- 中断影响：中断降低了并发性能，同时中断也会导致频繁的上下文切换，上下文切换会导致tlb快表失效，因此要尽可能的缩减中断处理的时间；
- 自旋锁(Spinlock)：xv6中利用该数据结构实现多个进程/线程同步和互斥访问临界区。当进程/线程请求锁失败时进入循环，直至锁可用并成功拿到后返回，对于单cpu系统自旋锁浪费CPU资源，不利于并发，自旋锁的优势体现在多CPU系统下，XV6支持多CPU。主要接口有void initlock(struct spinlock * lk, char * name)、void initlock(struct spinlock * lk, char * name)、void release(struct spinlock * lk)；
- xchg：xchg()函数使用GCC的内联汇编语句，该函数中通过xchg原子性交换spinlock.locked和newval，并返回spinlock.locked原来的值。当返回值为1时，说明其他线程占用了该锁，继续循环等待；当返回值为0时，说明其他地方没有占用该锁，同时locked本设置成1了，所以该锁被此处占用。

```bash
// x86.h 调用方式如xchg(&lk->locked, 1)
static inline uint xchg(volatile uint *addr, uint newval)
{
  uint result;
  
  // The + in "+m" denotes a read-modify-write operand.
  asm volatile("lock; xchgl %0, %1" :
               "+m" (*addr), "=a" (result) :
               "1" (newval) :
               "cc");
  return result;
}
```

2. 基于XV6的spinlock, 请给出实现信号量、读写锁、信号机制的设计方案(三选二，请写出相应的伪代码)?

- 信号量实现

```bash
struct semaphore {
  int value;
  struct spinlock lock;
  struct proc *queue[NPROC]; // 进程等待队列,这是一个循环队列
  int end;   // 队尾
  int start; // 队头
};

// 初始化信号量
void sem_init(struct semaphore *s, int value) {
  s->value = value;
  initlock(&s->lock, "semaphore_lock");
  end = start = 0;
}

void sem_wait(struct semaphore *s) {
  acquire(&s->lock); // 竞争锁,如果竞争不到进入自旋
  s->value--; 
  if (s->value < 0) {
    s->queue[s->end] = myproc(); // myproc()获取当前进程, 放入队尾
    s->end = (s->end + 1) % NPROC; // 循环队列计算新的队尾
    // 1. 释放锁(下一个sem_wait的进程才能进入acquire),
    // 2. 然后进入睡眠等待, 被唤醒时重新竞争锁
    sleep(myproc(), &s->lock); 
  }
  release(&s->lock);
}

void sem_signal(struct semaphore *s) {
  acquire(&s->lock); // 竞争锁
  s->value++;
  if (s->value <= 0) {
    wakeup(s->queue[s->start]); // 唤醒循环队列头的进程
    s->queue[s->start] = 0; 
    s->start = (s->start + 1) % NPROC; // 重新计算队头
  }
  release(&s->lock);
}

// proc.h
// Per-process state
struct proc {
  uint sz;                     // Size of process memory (bytes)
  pde_t* pgdir;                // Page table
  char *kstack;                // Bottom of kernel stack for this process
  enum procstate state;        // Process state
  volatile int pid;            // Process ID
  struct proc *parent;         // Parent process
  struct trapframe *tf;        // Trap frame for current syscall
  struct context *context;     // swtch() here to run process
  void *chan;                  // If non-zero, sleeping on chan
  int killed;                  // If non-zero, have been killed
  struct file *ofile[NOFILE];  // Open files
  struct inode *cwd;           // Current directory
  char name[16];               // Process name (debugging)
};
```

## 参考文献

[1] [xv6锁-博客园](https://www.cnblogs.com/hehao98/p/10678493.html)
[2] [xv6锁-xchg](https://www.cnblogs.com/hygblog/p/9361888.html)
[3] [xv6锁-CSDN](https://blog.csdn.net/qq_25426415/article/details/54631192)
[4] [xv6整体报告-百度文库](https://wenku.baidu.com/view/339ba16e7e21af45b307a8e6.html)

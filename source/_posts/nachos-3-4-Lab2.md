---
title: Nachos-Lab2-线程调度模块实现
date: 2019-05-14 04:57:24
tags: [时间片轮转调度策略, FIFO线程调度策略, 基于优先级的可抢占式调度策略, Nachos-3.4]
categories:
  - [操作系统]
copyright: true
---

## 源码获取
https://github.com/icoty/nachos-3.4-Lab

## 内容一：总体概述

本实习希望通过修改Nachos系统平台的底层源代码，达到“扩展调度算法”的目标。本次实验主要是要理解Timer、Scheduler和Interrupt之间的关系，从而理解线程之间是如何进行调度的。

## 内容二：任务完成情况

### 任务完成列表（Y/N）

|          | Exercise1 | Exercise2 | Exercise3 | Challenge1 |
| -------- | --------- | --------- | --------- | --------- |
| 第一部分 | Y         | Y         | Y         | Y         |


### 具体Exercise的完成情况

#### Exercise1  调研

调研Linux或Windows中采用的进程/线程调度算法。具体内容见课堂要求。

1. **linux-4.19.23进程调度策略**：**SCHED_OTHER**分时调度策略，**SCHED_FIFO**实时调度策略（先到先服务），**SCHED_RR**实时调度策略（时间片轮转）。
   - RR调度和FIFO调度的进程属于实时进程，以分时调度的进程是非实时进程。
   - 当实时进程准备就绪后，如果当前cpu正在运行非实时进程，则实时进程立即抢占非实时进程。
   - RR进程和FIFO进程都采用实时优先级做为调度的权值标准，RR是FIFO的一个延伸。FIFO时，如果两个进程的优先级一样，则这两个优先级一样的进程具体执行哪一个是由其在队列中的位置决定的，这样导致一些不公正性(优先级是一样的，为什么要让你一直运行?)，如果将两个优先级一样的任务的调度策略都设为RR，则保证了这两个任务可以循环执行，保证了公平。


2. **内核代码**：内核为每个cpu维护一个进程就绪队列，cpu只调度由其维护的队列上的进程：

**vi linux-4.19.23/kernel/sched/core.c**：
```bash
……
#define CREATE_TRACE_POINTS
#include <trace/events/sched.h>

DEFINE_PER_CPU_SHARED_ALIGNED(struct rq, runqueues);
……
```

​	**vi linux-4.19.23/kernel/sched/sched.h**：
```bash
/*
 * This is the main, per-CPU runqueue data structure.
 *
 * Locking rule: those places that want to lock multiple runqueues
 * (such as the load balancing or the thread migration code), lock
 * acquire operations must be ordered by ascending &runqueue.
 */
struct rq {
	/* runqueue lock: */
	raw_spinlock_t		lock;	// 锁保证互斥访问runqueue
	……
	struct cfs_rq		cfs;	// 所有普通进程的集合，采用cfs调度策略
	struct rt_rq		rt;	// 所有实时进程的集合，采用实时调度策略
	struct dl_rq		dl;	// struct dl_rq空闲进程集合
	……
};

// cfs_rq就绪队列是一棵红黑树。
/* CFS-related fields in a runqueue */
struct cfs_rq {
	……
	struct rb_root_cached	tasks_timeline;	// 红黑树的树根

	/*
	 * 'curr' points to currently running entity on this cfs_rq.
	 * It is set to NULL otherwise (i.e when none are currently running).
	 */
	struct sched_entity	*curr;	// 指向当前正运行的进程
	struct sched_entity	*next;	// 指向将被唤醒的进程
	struct sched_entity	*last;	// 指向唤醒next进程的进程
	struct sched_entity	*skip;
	……
};
```

​	**vi linux-4.19.23/include/linux/sched.h**：实时进程调度实体**struct sched_rt_entity**，双向链表组织形式；空闲进程调度实体**struct sched_dl_entity**，红黑树组织形式；普通进程的调度实体sched_entity，每个进程描述符中均包含一个该结构体变量，该结构体有两个作用：
   1. 包含有进程调度的信息（比如进程的运行时间，睡眠时间等等，调度程序参考这些信息决定是否调度进程）；
   2. 使用该结构体来组织进程，struct rb_node类型结构体变量run_node是红黑树节点，struct sched_entity调度实体将被组织成红黑树的形式，同时意味着普通进程也被组织成红黑树的形式。parent指向了当前实体的上一级实体，cfs_rq指向了该调度实体所在的就绪队列。my_q指向了本实体拥有的就绪队列（调度组），该调度组（包括组员实体）属于下一个级别，和本实体不在同一个级别，该调度组中所有成员实体的parent域指向了本实体，depth代表了此队列（调度组）的深度，每个调度组都比其parent调度组深度大1。内核依赖my_q域实现组调度。

```bash
……
// 普通进程的调度实体sched_entity，使用红黑树组织
struct sched_entity {
	/* For load-balancing: */
	struct load_weight		load;
	unsigned long			runnable_weight;
	struct rb_node			run_node;	// 红黑树节点
	struct list_head		group_node;
	unsigned int			on_rq;
	……
#ifdef CONFIG_FAIR_GROUP_SCHED
	int				depth;
	struct sched_entity		*parent;	// 当前节点的父节点
	/* rq on which this entity is (to be) queued: */
	struct cfs_rq			*cfs_rq;	// 当前节点所在的就绪队列
	/* rq "owned" by this entity/group: */
	struct cfs_rq			*my_q;
#endif
	……
};

// 实时进程调度实体，采用双向链表组织
struct sched_rt_entity {
	struct list_head		run_list;	// 链表组织
	unsigned long			timeout;
	unsigned long			watchdog_stamp;
	unsigned int			time_slice;
	unsigned short			on_rq;
	unsigned short			on_list;

	struct sched_rt_entity		*back;
#ifdef CONFIG_RT_GROUP_SCHED
	struct sched_rt_entity		*parent;
	/* rq on which this entity is (to be) queued: */
	struct rt_rq			*rt_rq;	// 当前节点所在的就绪队列
	/* rq "owned" by this entity/group: */
	struct rt_rq			*my_q;
#endif
} __randomize_layout;

// 空闲进程调度实体，采用红黑树组织
struct sched_dl_entity {
	struct rb_node			rb_node;
	……
};
……
```

​	**vi linux-4.19.23/kernel/sched/sched.h**：内核声明了一个调度类sched_class的结构体类型，用来实现不同的调度策略，可以看到该结构体成员都是函数指针，这些指针指向的函数就是调度策略的具体实现，所有和进程调度有关的函数都直接或者间接调用了这些成员函数，来实现进程调度。此外，每个进程描述符中都包含一个指向该结构体类型的指针sched_class，指向了所采用的调度类。

```bash
……
struct sched_class {
	const struct sched_class *next;

	void (*enqueue_task) (struct rq *rq, struct task_struct *p, int flags);
	void (*dequeue_task) (struct rq *rq, struct task_struct *p, int flags);
	void (*yield_task)   (struct rq *rq);
	bool (*yield_to_task)(struct rq *rq, struct task_struct *p, bool preempt);

	void (*check_preempt_curr)(struct rq *rq, struct task_struct *p, int flags);
	……
};
……
```

#### Exercise2 源代码阅读

**code/threads/scheduler.h和code/threads/scheduler.cc**：scheduler类是nachos中的进程调度器，维护了一个挂起的中断队列，通过FIFO进行调度。
   - void ReadyToRun(Thread* thread)；设置线程状态为READY，并放入就绪队列readyList。
   - Thread* FindNextToRun(int source); 从就绪队列中取出下一个上CPU的线程，实现基于优先级的抢占式调度和FIFO调度。
   - void Run(Thread* nextThread); 把下CPU的线程的寄存器和堆栈信息从CPU保存到线程本身的寄存器数据结构中， 执行线程切换，把上CPU的线程的寄存器和堆栈信息从线程本身的寄存器中拷贝到CPU的寄存器中，运行新线程。

**code/threads/switch.s**：switch.s模拟内容是汇编代码，负责CPU上进程的切换。切换过程中，首先保存当前进程的状态，然后恢复新运行进程的状态，之后切换到新进程的栈空间，开始运行新进程。

**code/machine/timer.h和code/machine/timer.cc**：Timer类用以模拟硬件的时间中断。在TimerExired中，会调用TimeOfNextInterrupt，计算出下次时间中断的时间，并将中断插入中断队列中。初始化时会调用TimerExired，然后每次中断处理函数中都会调用一次TimerExired，从而时间系统时间一步步向前走。需要说明的是，在运行nachos时加入-rs选项，会初始化一个随机中断的Timer。当然你也可以自己声明一个非随机的Timer，每隔固定的时间片执行中断。时间片大小的定义位于ststs.h中，每次开关中断会调用OneTick()，当Ticks数目达到时间片大小时，会出发一次时钟中断。

#### Exercise3 **线程调度算法扩展**

扩展线程调度算法，实现基于优先级的抢占式调度算法。

**思路**：更改Thread类，加入priority成员变量，同时更改初始化函数对其初始化，并完成对应的set和get函数。scheduler中的FindNextToRun负责找到下一个运行的进程，默认是FIFO，找到队列最开始时的线程返回。我们现在要实现的是根据优先级来返回，仅需将插入readyList队列的方法按照优先级从高到低顺序插入SortedInsert，那么插入时会维护队列中的Thread按照优先级排序，每次依旧从头取出第一个，即为优先级最高的队列。抢占式调度则需要在每次中断发生时尝试进行进程切换，如果有优先级更高的进程，则运行高优先级进程。
```bash
// 基于优先级的可抢占式调度策略和FIFO调度策略
Thread * Scheduler::FindNextToRun (bool bySleep)
{
	// called by threadsleep，直接调度，不用判断时间片
  if(bySleep){ 
    lastSwitchTick = stats->systemTicks;
    return (Thread *)readyList->SortedRemove(NULL);  // 与Remove()等价，都是从队头取
  }else{
    int ticks = stats->systemTicks - lastSwitchTick;
    
    // 这里设置了运行的最短时间TimerSlice，防止频繁切换消耗CPU资源
    // 测试优先级抢占调度时需要屏蔽这句，因为调用Yield()的线程运行时间很短
    // 会直接返回NULL
    /*if(ticks < TimerSlice){
    	// 不用切换
    	return NULL; 
    }else*/{
      if(readyList->IsEmpty()){
      	return NULL;
      }
      Thread * next = (Thread *)readyList->SortedRemove(NULL);
// 基于优先级可抢占调度策略,自己添加的宏，Makefile编译添加： -DSCHED_PRIORITY
#ifdef SCHED_PRIORITY  
      // nextThread优先级高于当前线程则切换，否则不切换
      if(next->getPriority() < currentThread->getPriority()){
      	lastSwitchTick = stats->systemTicks;
      	return next;
      }else{
        readyList->SortedInsert(next, next->getPriority());
        return NULL;
      }
#else	// FIFO策略需要取消Makefile编译选项：-DSCHED_PRIORITY
      lastSwitchTick = stats->systemTicks;
      return next;
#endif
    }
  }
}

// 线程主动让出cpu,在FIFO调度策略下能够看到多个线程按顺序运行
void SimpleThread(int which)
{
  for (int num = 0; num < 5; num++) {
    int ticks = stats->systemTicks - scheduler->getLastSwitchTick();
    printf("userId=%d,threadId=%d,prio=%d,loop:%d,lastSwitchTick=%d,systemTicks=%d,usedTicks=%d,TimerSlice=%d\n",currentThread->getUserId(),currentThread->getThreadId(),currentThread->getPriority(),num,scheduler->getLastSwitchTick(),stats->systemTicks,ticks,TimerSlice);
    // 时间片轮转算法，判断时间片是否用完，
    // 如果用完主动让出cpu，针对nachos内核线程算法
    /*if(ticks >= TimerSlice){ 
    	//printf("threadId=%d Yield\n",currentThread->getThreadId());
    	currentThread->Yield();
    }*/

    // 非抢占模式下，多个线程同时执行该接口的话，会交替执行，交替让出cpu
    // 基于优先级抢占模式下，优先级高的线程运行结束后才调度低优先级线程
    currentThread->Yield();
  }
}

threadtest.cc:
// 创建四个线程，加上主线程共五个，优先值越小优先级越高
void ThreadPriorityTest()
{
    Thread* t1 = new Thread("forkThread1", 1);
    printf("-->name=%s,threadId=%d\n",t1->getName(),t1->getThreadId());
    t1->Fork(SimpleThread, (void*)1);
    
    Thread* t2 = new Thread("forkThread2", 2);
    printf("-->name=%s,threadId=%d\n",t2->getName(),t2->getThreadId());
    t2->Fork(SimpleThread, (void*)2);
    
    Thread* t3 = new Thread("forkThread3", 3);
    printf("-->name=%s,threadId=%d\n",t3->getName(),t3->getThreadId());
    t3->Fork(SimpleThread, (void*)3);
    
    Thread* t4 = new Thread("forkThread4", 4);
    printf("-->name=%s,threadId=%d\n",t4->getName(),t4->getThreadId());
    t4->Fork(SimpleThread, (void*)4);
    
    currentThread->Yield();
    SimpleThread(0);
}

// 运行结果，优先级1最高，最先执行完，其次是优先为2的线程，直到所有线程结束
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# ./nachos -q 3
-->name=forkThread1,threadId=1
-->name=forkThread2,threadId=2
-->name=forkThread3,threadId=3
-->name=forkThread4,threadId=4
userId=0,threadId=1,prio=1,loop:0,lastSwitchTick=50,systemTicks=60,usedTicks=10,TimerSlice=30
userId=0,threadId=1,prio=1,loop:1,lastSwitchTick=50,systemTicks=70,usedTicks=20,TimerSlice=30
userId=0,threadId=1,prio=1,loop:2,lastSwitchTick=50,systemTicks=80,usedTicks=30,TimerSlice=30
userId=0,threadId=1,prio=1,loop:3,lastSwitchTick=50,systemTicks=90,usedTicks=40,TimerSlice=30
userId=0,threadId=1,prio=1,loop:4,lastSwitchTick=50,systemTicks=100,usedTicks=50,TimerSlice=30
userId=0,threadId=2,prio=2,loop:0,lastSwitchTick=110,systemTicks=120,usedTicks=10,TimerSlice=30
userId=0,threadId=2,prio=2,loop:1,lastSwitchTick=110,systemTicks=130,usedTicks=20,TimerSlice=30
userId=0,threadId=2,prio=2,loop:2,lastSwitchTick=110,systemTicks=140,usedTicks=30,TimerSlice=30
userId=0,threadId=2,prio=2,loop:3,lastSwitchTick=110,systemTicks=150,usedTicks=40,TimerSlice=30
userId=0,threadId=2,prio=2,loop:4,lastSwitchTick=110,systemTicks=160,usedTicks=50,TimerSlice=30
userId=0,threadId=3,prio=3,loop:0,lastSwitchTick=170,systemTicks=180,usedTicks=10,TimerSlice=30
userId=0,threadId=3,prio=3,loop:1,lastSwitchTick=170,systemTicks=190,usedTicks=20,TimerSlice=30
userId=0,threadId=3,prio=3,loop:2,lastSwitchTick=170,systemTicks=200,usedTicks=30,TimerSlice=30
userId=0,threadId=3,prio=3,loop:3,lastSwitchTick=170,systemTicks=210,usedTicks=40,TimerSlice=30
userId=0,threadId=3,prio=3,loop:4,lastSwitchTick=170,systemTicks=220,usedTicks=50,TimerSlice=30
userId=0,threadId=4,prio=4,loop:0,lastSwitchTick=230,systemTicks=240,usedTicks=10,TimerSlice=30
userId=0,threadId=4,prio=4,loop:1,lastSwitchTick=230,systemTicks=250,usedTicks=20,TimerSlice=30
userId=0,threadId=4,prio=4,loop:2,lastSwitchTick=230,systemTicks=260,usedTicks=30,TimerSlice=30
userId=0,threadId=4,prio=4,loop:3,lastSwitchTick=230,systemTicks=270,usedTicks=40,TimerSlice=30
userId=0,threadId=4,prio=4,loop:4,lastSwitchTick=230,systemTicks=280,usedTicks=50,TimerSlice=30
userId=0,threadId=0,prio=6,loop:0,lastSwitchTick=290,systemTicks=300,usedTicks=10,TimerSlice=30
userId=0,threadId=0,prio=6,loop:1,lastSwitchTick=290,systemTicks=310,usedTicks=20,TimerSlice=30
userId=0,threadId=0,prio=6,loop:2,lastSwitchTick=290,systemTicks=320,usedTicks=30,TimerSlice=30
userId=0,threadId=0,prio=6,loop:3,lastSwitchTick=290,systemTicks=330,usedTicks=40,TimerSlice=30
userId=0,threadId=0,prio=6,loop:4,lastSwitchTick=290,systemTicks=340,usedTicks=50,TimerSlice=30
No threads ready or runnable, and no pending interrupts.
Assuming the program completed.
Machine halting!

Ticks: total 350, idle 0, system 350, user 0
Disk I/O: reads 0, writes 0
Console I/O: reads 0, writes 0
Paging: faults 0
Network I/O: packets received 0, sent 0

Cleaning up...
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
```

#### Challenge **线程调度算法扩展**（至少实现一种算法）

可实现“时间片轮转算法”、“多级队列反馈调度算法”，或将Linux或Windows采用的调度算法应用到Nachos上。

**思路：**nachos启动时在system.cc中会new一个timer类，每隔一个TimerTicks大小触发时钟中断，从而让时钟向前走，时间片的大下定义在stats.h中。同时在stats.h中定义一个时间片大小变量TimerSlice，每个线程运行时间只要大于等于TimerSlice，立即放弃CPU。

``` bash
stats.h：
……
// nachos执行每条用户指令的时间为1Tick
#define UserTick 	1
// 系统态无法进行指令计算，
// 所以nachos系统态的一次中断调用或其他需要进行时间计算的单位设置为10Tick
#define SystemTick 	10

// 磁头寻找超过一个扇区的时间
#define RotationTime 	500

// 磁头寻找超过一个磁道的时间
#define SeekTime	500
#define ConsoleTime 	100	// time to read or write one character
#define NetworkTime 	100	// time to send or receive one packet

// 时钟中断间隔
#define TimerTicks	5	// (average) time between timer interrupts

// 时间片轮转算法一个时间片大小
#define TimerSlice	10	
……

threadtest.cc:
void SimpleThread(int which)
{
  for (int num = 0; num < 5; num++) {
    int ticks = stats->systemTicks - scheduler->getLastSwitchTick();
    printf("userId=%d,threadId=%d,prio=%d,loop:%d,lastSwitchTick=%d,systemTicks=%d,usedTicks=%d,TimerSlice=%d\n",currentThread->getUserId(),currentThread->getThreadId(),currentThread->getPriority(),num,scheduler->getLastSwitchTick(),stats->systemTicks,ticks,TimerSlice);
    // 时间片轮转算法，判断时间片是否用完
    // 如果用完主动让出cpu，针对nachos内核线程算法
    if(ticks >= TimerSlice){
      printf("threadId=%d Yield\n",currentThread->getThreadId());
      currentThread->Yield();
    }

    // 非抢占模式下，多个线程同时执行该接口的话，会交替执行，交替让出cpu
    // currentThread->Yield();
  }
}

threadtest.cc:
// 创建四个线程，加上主线程共五个，时间片轮转调度策略，不可抢占
void ThreadPriorityTest()
{
    Thread* t1 = new Thread("forkThread1", 1);
    printf("-->name=%s,threadId=%d\n",t1->getName(),t1->getThreadId());
    t1->Fork(SimpleThread, (void*)1);
    
    Thread* t2 = new Thread("forkThread2", 2);
    printf("-->name=%s,threadId=%d\n",t2->getName(),t2->getThreadId());
    t2->Fork(SimpleThread, (void*)2);
    
    Thread* t3 = new Thread("forkThread3", 3);
    printf("-->name=%s,threadId=%d\n",t3->getName(),t3->getThreadId());
    t3->Fork(SimpleThread, (void*)3);
    
    Thread* t4 = new Thread("forkThread4", 4);
    printf("-->name=%s,threadId=%d\n",t4->getName(),t4->getThreadId());
    t4->Fork(SimpleThread, (void*)4);
    
    currentThread->Yield();
    SimpleThread(0);
}

// 运行结果，可看到usedTicks >= TimserSlice时都让出cpu
// 并且线程执行顺序为1 2 3 4 0，直到结束
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# ./nachos -q 3
-->name=forkThread1,threadId=1
-->name=forkThread2,threadId=2
-->name=forkThread3,threadId=3
-->name=forkThread4,threadId=4
userId=0,threadId=1,prio=1,loop:0,lastSwitchTick=50,systemTicks=60,usedTicks=10,TimerSlice=10
threadId=1 Yield
userId=0,threadId=2,prio=2,loop:0,lastSwitchTick=60,systemTicks=70,usedTicks=10,TimerSlice=10
threadId=2 Yield
userId=0,threadId=3,prio=3,loop:0,lastSwitchTick=70,systemTicks=80,usedTicks=10,TimerSlice=10
threadId=3 Yield
userId=0,threadId=4,prio=4,loop:0,lastSwitchTick=80,systemTicks=90,usedTicks=10,TimerSlice=10
threadId=4 Yield
userId=0,threadId=0,prio=6,loop:0,lastSwitchTick=90,systemTicks=100,usedTicks=10,TimerSlice=10
threadId=0 Yield
userId=0,threadId=1,prio=1,loop:1,lastSwitchTick=100,systemTicks=110,usedTicks=10,TimerSlice=10
threadId=1 Yield
userId=0,threadId=2,prio=2,loop:1,lastSwitchTick=110,systemTicks=120,usedTicks=10,TimerSlice=10
threadId=2 Yield
userId=0,threadId=3,prio=3,loop:1,lastSwitchTick=120,systemTicks=130,usedTicks=10,TimerSlice=10
threadId=3 Yield
userId=0,threadId=4,prio=4,loop:1,lastSwitchTick=130,systemTicks=140,usedTicks=10,TimerSlice=10
threadId=4 Yield
userId=0,threadId=0,prio=6,loop:1,lastSwitchTick=140,systemTicks=150,usedTicks=10,TimerSlice=10
threadId=0 Yield
userId=0,threadId=1,prio=1,loop:2,lastSwitchTick=150,systemTicks=160,usedTicks=10,TimerSlice=10
threadId=1 Yield
userId=0,threadId=2,prio=2,loop:2,lastSwitchTick=160,systemTicks=170,usedTicks=10,TimerSlice=10
threadId=2 Yield
userId=0,threadId=3,prio=3,loop:2,lastSwitchTick=170,systemTicks=180,usedTicks=10,TimerSlice=10
threadId=3 Yield
userId=0,threadId=4,prio=4,loop:2,lastSwitchTick=180,systemTicks=190,usedTicks=10,TimerSlice=10
threadId=4 Yield
userId=0,threadId=0,prio=6,loop:2,lastSwitchTick=190,systemTicks=200,usedTicks=10,TimerSlice=10
threadId=0 Yield
userId=0,threadId=1,prio=1,loop:3,lastSwitchTick=200,systemTicks=210,usedTicks=10,TimerSlice=10
threadId=1 Yield
userId=0,threadId=2,prio=2,loop:3,lastSwitchTick=210,systemTicks=220,usedTicks=10,TimerSlice=10
threadId=2 Yield
userId=0,threadId=3,prio=3,loop:3,lastSwitchTick=220,systemTicks=230,usedTicks=10,TimerSlice=10
threadId=3 Yield
userId=0,threadId=4,prio=4,loop:3,lastSwitchTick=230,systemTicks=240,usedTicks=10,TimerSlice=10
threadId=4 Yield
userId=0,threadId=0,prio=6,loop:3,lastSwitchTick=240,systemTicks=250,usedTicks=10,TimerSlice=10
threadId=0 Yield
userId=0,threadId=1,prio=1,loop:4,lastSwitchTick=250,systemTicks=260,usedTicks=10,TimerSlice=10
threadId=1 Yield
userId=0,threadId=2,prio=2,loop:4,lastSwitchTick=260,systemTicks=270,usedTicks=10,TimerSlice=10
threadId=2 Yield
userId=0,threadId=3,prio=3,loop:4,lastSwitchTick=270,systemTicks=280,usedTicks=10,TimerSlice=10
threadId=3 Yield
userId=0,threadId=4,prio=4,loop:4,lastSwitchTick=280,systemTicks=290,usedTicks=10,TimerSlice=10
threadId=4 Yield
userId=0,threadId=0,prio=6,loop:4,lastSwitchTick=290,systemTicks=300,usedTicks=10,TimerSlice=10
threadId=0 Yield
No threads ready or runnable, and no pending interrupts.
Assuming the program completed.
Machine halting!

Ticks: total 350, idle 0, system 350, user 0
Disk I/O: reads 0, writes 0
Console I/O: reads 0, writes 0
Paging: faults 0
Network I/O: packets received 0, sent 0

Cleaning up...
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
```

## 内容三：遇到的困难以及解决方法

### 困难1

切换线程过程中，产生段错误，通过定位，误把销毁的线程挂入就绪对了所致。

## 内容四：收获及感想

自己动手实现后，发现时间片轮转算法，线程调度，FIFO，时钟中断等其实并不陌生。一切只要你不懒和肯付出实际行动的难题都是纸老虎。

## 内容五：对课程的意见和建议

暂无。

## 内容六：参考文献

暂无。
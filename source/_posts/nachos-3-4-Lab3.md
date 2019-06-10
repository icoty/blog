---
title: Nachos-Lab3-同步与互斥机制模块实现
date: 2019-05-14 08:39:17
tags: [锁, 信号量, 条件变量,  生产者消费者问题, 读者写者问题, Barrier, Nachos-3.4]
categories:
  - [同步机制]
  - [互斥机制]
copyright: true
---

## 源码获取

https://github.com/icoty/nachos-3.4-Lab

## 内容一：总体概述

本实习希望通过修改Nachos系统平台的底层源代码，达到“扩展同步机制，实现同步互斥实例”的目标。

## 内容二：任务完成情况

### 任务完成列表（Y/N）

|          | Exercise1 | Exercise2 | Exercise3 |Exercise4|Challenge1| Challenge2 |Challenge3 |
| -------- | --------- | --------- | --------- | ---------- |---------- |---------- |---------- |
| 第一部分 | Y         | Y         | Y         | Y          | Y          | Y          |N          |


### 具体Exercise的完成情况

#### Exercise1  调研

调研Linux或Windows中采用的进程/线程调度算法。具体内容见课堂要求。

- 同步是指用于实现控制多个进程按照一定的规则或顺序访问某些系统资源的机制，进程间的同步方式有共享内存，套接字，管道，信号量，消息队列，条件变量；线程间的同步有套接字，消息队列，全局变量，条件变量，信号量。

- 互斥是指用于实现控制某些系统资源在任意时刻只能允许一个进程访问的机制。互斥是同步机制中的一种特殊情况。进程间的互斥方式有锁，信号量，条件变量；线程间的互斥方式有信号量，锁，条件变量。此外，通过硬件也能实现同步与互斥。
- linux内核中提供的同步机制
  - [原子操作](https://blog.csdn.net/FreeeLinux/article/details/54267446#原子操作)
  - [自旋锁](https://blog.csdn.net/FreeeLinux/article/details/54267446#自旋锁)
  - [读写自旋锁](https://blog.csdn.net/FreeeLinux/article/details/54267446#读写自旋锁)
  - [信号量](https://blog.csdn.net/FreeeLinux/article/details/54267446#信号量)
  - [读写信号量](https://blog.csdn.net/FreeeLinux/article/details/54267446#读写信号量)
  - [互斥量](https://blog.csdn.net/FreeeLinux/article/details/54267446#互斥量)
  - [完成变量](https://blog.csdn.net/FreeeLinux/article/details/54267446#完成变量)
  - [大内核锁](https://blog.csdn.net/FreeeLinux/article/details/54267446#大内核锁)
  - [顺序锁](https://blog.csdn.net/FreeeLinux/article/details/54267446#顺序锁)
  - [禁止抢占](https://blog.csdn.net/FreeeLinux/article/details/54267446#禁止抢占)
  - [顺序和屏障](https://blog.csdn.net/FreeeLinux/article/details/54267446#顺序和屏障)

#### Exercise2 源代码阅读

**code/threads/synch.h和code/threads/synch.cc**：Condition和Lock仅仅声明了未定义；Semaphore既声明又定义了。
- **Semaphore**有一个初值和一个等待队列，提供P、V操作：
  - P操作：当value等于0时，将当前运行线程放入线程等待队列，当前进程进入睡眠状态，并切换到其他线程运行；当value大于0时，value--。
  - V操作：如果线程等待队列中有等待该信号量的线程，取出其中一个将其设置成就绪态，准备运行，value++。

- **Lock**：Nachos中没有给出锁机制的实现，接口有获得锁(Acquire)和释放锁(Release)，他们都是原子操作。
  - Acquire：当锁处于BUSY态，进入睡眠状态。当锁处于FREE态，当前进程获得该锁，继续运行。
  - Release：释放锁（只能由拥有锁的线程才能释放锁），将锁的状态设置为FREE态，如果有其他线程等待该锁，将其中的一个唤醒，进入就绪态。

- **Condition**：条件变量同信号量、锁机制不一样，条件变量没值。当一个线程需要的某种条件没有得到满足时，可以将自己作为一个等待条件变量的线程插入所有等待该条件变量的队列，只要条件一旦得到满足，该线程就会被唤醒继续运行。条件变量总是和锁机制一起使。主要接口Wait、Signal、BroadCast，这三个操作必须在当前线程获得一个锁的前提下，而且所有对一个条件变量进行的操作必须建立在同一个锁的前提下。
  - Wait(Lock *conditionLock)：线程等待在条件变量上，把线程放入条件变量的等待队列上。
  - Signal(Lock *conditionLock)：从条件变量的等待队列中唤醒一个等待该条件变量的线程。
  - BroadCast(Lock *conditionLock)：唤醒所有等待该条件变量的线程。

**code/threads/synchlist.h和code/threads/synchlist.cc**：利用锁、条件变量实现的一个消息队列，使多线程达到互斥访问和同步通信的目的，类内有一个Lock和List成员变量。提供了对List的Append()，Remove()和Mapcar()操作。每个操作都要先获得该锁，然后才能对List进行相应的操作。

#### Exercise3 **实现锁和条件变量**

可以使用sleep和wakeup两个原语操作（注意屏蔽系统中断），也可以使用Semaphore作为唯一同步原语（不必自己编写开关中断的代码）。

这里选择用1值信号量实现锁功能，Lock添加成员变量lock和owner，请求锁和释放锁都必须关中断，Condition添加一个成员变量queue，用于存放所有等待在该条件变量上的线程。代码如下：

```bash
// synch.h Lock声明部分
class Lock {
……
private:
  char* name;	// for debugging
  // add by yangyu
  Semaphore *lock;
  Thread* owner;
};

class Condition {
……
private:
  char* name;
  // add by yangyu
  List* queue;
};

// synch.cc Lock定义部分
Lock::Lock(char* debugName) 
:lock(new Semaphore("lock", 1))
,name(debugName)
,owner(NULL)
{}

Lock::~Lock() 
{
    delete lock;
}

bool Lock::isHeldByCurrentThread()
{ 
    return currentThread == owner;
}

void Lock::Acquire() 
{
    IntStatus prev = interrupt->SetLevel(IntOff);
    lock->P();
    owner = currentThread;
    (void)interrupt->SetLevel(prev);
}

void Lock::Release() {
    IntStatus prev = interrupt->SetLevel(IntOff);
    ASSERT(currentThread == owner);
    lock->V();
    owner = NULL;
    (void)interrupt->SetLevel(prev);
}

// synch.cc Condition定义部分
Condition::Condition(char* debugName)
:name(debugName)
,queue(new List)
{ }

Condition::~Condition()
{ }

void Condition::Wait(Lock* conditionLock) 
{
  //ASSERT(FALSE);
  // 关中断
  IntStatus prev = interrupt->SetLevel(IntOff);
  // 锁和信号量不同，谁加锁必须由谁解锁，因此做下判断
  ASSERT(conditionLock->isHeldByCurrentThread());
  // 进入睡眠前把锁的权限释放掉，然后放到等待队列，直到被唤醒时重新征用锁
  conditionLock->Release();
  queue->Append(currentThread);
  currentThread->Sleep();
  conditionLock->Acquire();
  (void)interrupt->SetLevel(prev);
}

void Condition::Signal(Lock* conditionLock) 
{
  IntStatus prev = interrupt->SetLevel(IntOff);
  ASSERT(conditionLock->isHeldByCurrentThread()); 
  if(!queue->IsEmpty())
  {
		// 唤醒一个等待的线程，挂入倒就绪队列中
    Thread* next = (Thread*)queue->Remove();
    scheduler->ReadyToRun(next);
  }
  (void)interrupt->SetLevel(prev);
}

void Condition::Broadcast(Lock* conditionLock) 
{
  IntStatus prev = interrupt->SetLevel(IntOff);
  ASSERT(conditionLock->isHeldByCurrentThread()); 
  // 唤醒等待在该条件变量上的所有线程
  while(!queue->IsEmpty())
  {
		Signal(conditionLock);
  }    
  (void)interrupt->SetLevel(prev);
}
```
#### Exercise4 **实现同步互斥实例**

基于Nachos中的信号量、锁和条件变量，采用两种方式实现同步和互斥机制应用（其中使用条件变量实现同步互斥机制为必选题目）。具体可选择“生产者-消费者问题”、“读者-写者问题”、“哲学家就餐问题”、“睡眠理发师问题”等。（也可选择其他经典的同步互斥问题）。

##### 生产者-消费者问题(Condition实现)

```bash
// threadtest.cc
// 条件变量实现生产者消费者问题
Condition* condc = new Condition("ConsumerCondition");
Condition* condp = new Condition("ProducerCondition");
Lock* pcLock = new Lock("producerConsumerLock");
int shareNum = 0; // 共享内容，生产+1，消费-1，互斥访问

// lab3 条件变量实现生产者消费者问题
void Producer1(int val){
  while(1){
    pcLock->Acquire();
    // 缓冲区已满则等待在条件变量上，停止生产，等待消费后再生产
    while(shareNum >= N){ 
      printf("Product alread full:[%d],threadId:[%d],wait consumer.\n",shareNum,currentThread->getThreadId());
      condp->Wait(pcLock);
    }
    printf("name:[%s],threadId:[%d],before:[%d],after:[%d]\n",currentThread->getName(),currentThread->getThreadId(),shareNum,shareNum+1);
    ++shareNum;

		// 生产一个通知可消费，唤醒一个等待在condc上的消费者
    condc->Signal(pcLock);
    pcLock->Release();
    sleep(val);
  }
}

void Customer1(int val){
  while(1){
    pcLock->Acquire();
    // 为零表示已经消费完毕,等待在条件变量上，等待生产后再消费
    while(shareNum <= 0){ 
      printf("-->Product alread empty:[%d],threadId:[%d],wait producer.\n",shareNum,currentThread->getThreadId());
      condc->Wait(pcLock);
  	}
    printf("-->name:[%s],threadId:[%d],before:[%d],after:[%d]\n",currentThread->getName(),currentThread->getThreadId(),shareNum,shareNum-1);
    --shareNum;
    // 消费一个后通知生产者缓冲区不为满，可以生产
    condp->Signal(pcLock);
    pcLock->Release();
    //sleep(val);
  }
}

void ThreadProducerConsumerTest1(){
  DEBUG('t', "Entering ThreadProducerConsumerTest1");
  // 两个生产者循环生产
  Thread* p1 = new Thread("Producer1");
  Thread* p2 = new Thread("Producer2");
  p1->Fork(Producer1, 1);
  p2->Fork(Producer1, 3);

	// 两个消费者循环消费
  Thread* c1 = new Thread("Consumer1");
  Thread* c2 = new Thread("Consumer2");
  c1->Fork(Customer1, 1);
  c2->Fork(Customer1, 2);
}

void ThreadTest()
{
  switch (testnum) {
  case 1:
    ThreadTest1();
    break;
  case 2:
    ThreadCountLimitTest();
    break;
  case 3:
    ThreadPriorityTest();
    break;
  case 4:
    ThreadProducerConsumerTest();
    break;
  case 5:
    ThreadProducerConsumerTest1();
    break;
  case 6:
    barrierThreadTest();
    break;
  case 7:
    readWriteThreadTest();
    break;
  default:
    printf("No test specified.\n");
    break;
  }
}

// 运行结果，需要-rs，否则可能没有中断发生，永远是一个线程在运行
// 通过结果可以明确看出生产前和生产后，消费前和消费后的数值变化
// 可以通过修改Producer1和Consumer1内的sleep(val)来调整不同的速度
// 当生产满了会停止生产，消费完了也会停止消费
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# ./nachos -rs -q 5
name:[Producer1],threadId:[1],before:[0],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
-->name:[Consumer1],threadId:[3],before:[2],after:[1]
name:[Producer1],threadId:[1],before:[1],after:[2]
-->name:[Consumer2],threadId:[4],before:[2],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
-->name:[Consumer1],threadId:[3],before:[2],after:[1]
name:[Producer1],threadId:[1],before:[1],after:[2]
-->name:[Consumer2],threadId:[4],before:[2],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
-->name:[Consumer1],threadId:[3],before:[2],after:[1]
-->name:[Consumer2],threadId:[4],before:[1],after:[0]
name:[Producer1],threadId:[1],before:[0],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
-->name:[Consumer1],threadId:[3],before:[2],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
name:[Producer1],threadId:[1],before:[2],after:[3]
-->name:[Consumer2],threadId:[4],before:[3],after:[2]
-->name:[Consumer1],threadId:[3],before:[2],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
name:[Producer1],threadId:[1],before:[2],after:[3]
-->name:[Consumer2],threadId:[4],before:[3],after:[2]
-->name:[Consumer1],threadId:[3],before:[2],after:[1]
name:[Producer2],threadId:[2],before:[1],after:[2]
^C
Cleaning up...
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
```

##### 生产者-消费者问题(Semaphore实现)

```bash
// threadtest.cc
// 信号量解决生产者消费者问题
#define N 1024 // 缓冲区大小
Semaphore* empty = new Semaphore("emptyBuffer", N);
Semaphore* mutex = new Semaphore("lockSemaphore", 1);
Semaphore* full = new Semaphore("fullBuffer", 0);
int msgQueue = 0;

void Producer(int val){
  while(1) {
    empty->P();
    mutex->P();
    if(msgQueue >= N){ // 已经满了则停止生产
    	printf("-->Product alread full:[%d],wait consumer.",msgQueue);
    }else{
      printf("-->name:[%s],threadId:[%d],before:[%d],after:[%d]\n",\
      currentThread->getName(),currentThread->getThreadId(),msgQueue,msgQueue+1);
      ++msgQueue;
    }
    mutex->V();
    full->V();

    sleep(val); // 休息下再生产
  }
}

void Customer(int val){
  while(1) {
    full->P();
    mutex->P();
    if(msgQueue <= 0){
    	printf("Product alread empty:[%d],wait Producer.",msgQueue);
    }else{
      printf("name:[%s] threadId:[%d],before:[%d],after:[%d]\n",\
      currentThread->getName(),currentThread->getThreadId(),msgQueue,msgQueue-1);
      --msgQueue;
    }
    mutex->V();
    empty->V();

    sleep(val); // 休息下再消费
    }
}

void ThreadProducerConsumerTest(){
  DEBUG('t', "Entering ThreadProducerConsumerTest");
  // 两个生产者
  Thread* p1 = new Thread("Producer1");
  Thread* p2 = new Thread("Producer2");
  p1->Fork(Producer, 1);
  p2->Fork(Producer, 3);

	// 两个消费者，可以关掉一个消费者，查看生产速率和消费速率的变化
  Thread* c1 = new Thread("Consumer1");
  //Thread* c2 = new Thread("Consumer2");
  c1->Fork(Customer, 1);
  //c2->Fork(Customer, 2);
}


// 通过结果可以明确看出生产前和生产后，消费前和消费后的数值变化
// 可以通过修改Producer和Consumer内的sleep(val)来调整不同的速度
// 当生产满了会停止生产，消费完了也会停止消费
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# ./nachos -rs -q 4
-->name:[Producer1],threadId:[1],before:[0],after:[1]
-->name:[Producer2],threadId:[2],before:[1],after:[2]
name:[Consumer1] threadId:[3],before:[2],after:[1]
-->name:[Producer1],threadId:[1],before:[1],after:[2]
-->name:[Producer2],threadId:[2],before:[2],after:[3]
-->name:[Producer1],threadId:[1],before:[3],after:[4]
name:[Consumer1] threadId:[3],before:[4],after:[3]
-->name:[Producer2],threadId:[2],before:[3],after:[4]
name:[Consumer1] threadId:[3],before:[4],after:[3]
-->name:[Producer1],threadId:[1],before:[3],after:[4]
-->name:[Producer2],threadId:[2],before:[4],after:[5]
name:[Consumer1] threadId:[3],before:[5],after:[4]
-->name:[Producer1],threadId:[1],before:[4],after:[5]
-->name:[Producer2],threadId:[2],before:[5],after:[6]
-->name:[Producer1],threadId:[1],before:[6],after:[7]
-->name:[Producer2],threadId:[2],before:[7],after:[8]
name:[Consumer1] threadId:[3],before:[8],after:[7]
^C
Cleaning up...
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads#  
```

#### Challenge1 实现barrier(至少选做一个Challenge)

可以使用Nachos 提供的同步互斥机制（如条件变量）来实现barrier，使得当且仅当若干个线程同时到达某一点时方可继续执行。
```bash
// threadtest.cc
// 条件变量实现barrier
Condition* barrCond = new Condition("BarrierCond");
Lock* barrLock = new Lock("BarrierLock");
int barrierCnt = 0;
// 当且仅当barrierThreadNum个线程同时到达时才能往下运行
const int barrierThreadNum = 5; 

void barrierFun(int num)
{
  /*while(1)*/
  {
    barrLock->Acquire();
    ++barrierCnt;
    
    if(barrierCnt == barrierThreadNum){
			// 最后一个线程到达后判断，条件满足则发送一个广播信号
			// 唤醒等待在该条件变量上的所有线程
      printf("threadName:[%s%d],barrierCnt:[%d],needCnt:[%d],Broadcast.\n",\
      currentThread->getName(),num,barrierCnt,barrierThreadNum);
      barrCond->Broadcast(barrLock);
      barrLock->Release();
    }else{
    	// 每一个线程都执行判断，若条件不满足，线程等待在条件变量上
      printf("threadName:[%s%d],barrierCnt:[%d],needCnt:[%d],Wait.\n",\
      currentThread->getName(),num,barrierCnt,barrierThreadNum);
      barrCond->Wait(barrLock);
      barrLock->Release();
    }
    printf("threadName:[%s%d],continue to run.\n", currentThread->getName(),num);
  }
}

void barrierThreadTest(){
  DEBUG('t', "Entering barrierThreadTest");
  for(int i = 0; i < barrierThreadNum; ++i){
    Thread* t = new Thread("barrierThread");
    t->Fork(barrierFun,i+1);
  }
}

// 运行结果，当第五个线程进入后判断条件满足，唤醒所有线程
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# ./nachos -rs -q 6
threadName:[barrierThread1],barrierCnt:[1],needCnt:[5],Wait.
threadName:[barrierThread2],barrierCnt:[2],needCnt:[5],Wait.
threadName:[barrierThread3],barrierCnt:[3],needCnt:[5],Wait.
threadName:[barrierThread4],barrierCnt:[4],needCnt:[5],Wait.
threadName:[barrierThread5],barrierCnt:[5],needCnt:[5],Broadcast.
threadName:[barrierThread5],continue to run.
threadName:[barrierThread2],continue to run.
threadName:[barrierThread1],continue to run.
threadName:[barrierThread4],continue to run.
threadName:[barrierThread3],continue to run.
No threads ready or runnable, and no pending interrupts.
Assuming the program completed.
Machine halting!

Ticks: total 814, idle 4, system 810, user 0
Disk I/O: reads 0, writes 0
Console I/O: reads 0, writes 0
Paging: faults 0
Network I/O: packets received 0, sent 0

Cleaning up...
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
```

#### Challenge2 实现read/write lock

基于Nachos提供的lock(synch.h和synch.cc)，实现read/write lock。使得若干线程可以同时读取某共享数据区内的数据，但是在某一特定的时刻，只有一个线程可以向该共享数据区写入数据。

```bash
// threadtest.cc
// Lab3 锁实现读者写者问题
int rCnt = 0; // 记录读者数量
Lock* rLock = new Lock("rlock");
// 必须用信号量，不能用锁，因为锁只能由加锁的线程解锁
Semaphore* wLock = new Semaphore("wlock",1); 
int bufSize = 0;
// Lab3 锁实现读者写者问题
void readFunc(int num){
  while(1) {
    rLock->Acquire();
    ++rCnt;
    // 如果是第一个读者进入，需要竞争1值信号量wLock，竞争成功才能进入临界区
    // 一旦竞争到wLock，由最后一个读者出临界区后释放，保证了读者优先
    if(rCnt == 1){ 
    	wLock->P();
    }
    rLock->Release();
    if(0 == bufSize){
			// 没有数据可读
      printf("threadName:[%s],bufSize:[%d],current not data.\n",currentThread->getName(),bufSize);
    }else{
			// 读取数据
			printf("threadName:[%s],bufSize:[%d],exec read operation.\n",currentThread->getName(),bufSize);
    }
    rLock->Acquire();
    --rCnt;
    // 最后一个读者释放wLock
    if(rCnt == 0){
    	wLock->V();
    }
    rLock->Release();
    currentThread->Yield();
    sleep(num);
  }
}

void writeFunc(int num){
  while(1) {
    wLock->P();
    ++bufSize;
    printf("writerThread:[%s],before:[%d],after:[%d]\n", currentThread->getName(), bufSize, bufSize+1);
    wLock->V();
    currentThread->Yield();
    sleep(num);
  }
}

void readWriteThreadTest()
{
  DEBUG('t', "Entering readWriteThreadTest");
  Thread * r1 = new Thread("read1");
  Thread * r2 = new Thread("read2");
  Thread * r3 = new Thread("read3");
  Thread * w1 = new Thread("write1");
  Thread * w2 = new Thread("write2");

	// 3个读者2个写者
  r1->Fork(readFunc,1);
  w1->Fork(writeFunc,1);
  r2->Fork(readFunc,1);
  w2->Fork(writeFunc,1);
  r3->Fork(readFunc,1);
}

// 运行结果，第一个读者进入无数据可读
// 可以发现读操作比写操作多
// 一旦开始读，就要等所有线程读取完毕后，写线程才进入
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# 
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads# ./nachos -rs -q 7
threadName:[read1],Val:[0],current not data.
writerThread:[write1],before:[0],after:[1]
writerThread:[write2],before:[1],after:[2]
writerThread:[write1],before:[2],after:[3]
writerThread:[write2],before:[3],after:[4]
threadName:[read2],readVal:[4],exec read operation.
threadName:[read1],readVal:[4],exec read operation.
threadName:[read3],readVal:[4],exec read operation.
writerThread:[write1],before:[4],after:[5]
threadName:[read2],readVal:[5],exec read operation.
threadName:[read3],readVal:[5],exec read operation.
threadName:[read2],readVal:[5],exec read operation.
threadName:[read3],readVal:[5],exec read operation.
threadName:[read2],readVal:[5],exec read operation.
threadName:[read3],readVal:[5],exec read operation.
threadName:[read1],readVal:[5],exec read operation.
writerThread:[write2],before:[5],after:[6]
writerThread:[write1],before:[6],after:[7]
^C
Cleaning up...
root@yangyu-ubuntu-32:/mnt/nachos-3.4-Lab/nachos-3.4/threads#  
```

## 内容三：遇到的困难以及解决方法

### 困难1

刚开始没有加-rs参数，导致永远都只有一个线程在运行，原因是没有中断发生，运行的线程永远在执行循环体，加-rs参数，会在一个固定的时间短内发一个时钟中断，然后调度其他线程运行。

## 内容四：收获及感想

可以说实际操作后，对信号量，条件变量的应用更加清晰了。

## 内容五：对课程的意见和建议

暂无。

## 内容六：参考文献

https://blog.csdn.net/FreeeLinux/article/details/54267446


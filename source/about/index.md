---
title: 杨宇
subtitle: 18640301517 | icoty.yangy@gamil.com
date: 2019-04-12 22:41:48
type: "about"
---
## ME
* 男 / 1992
* QQ/WeChat：604381117
*  1864030**** / icoty.yangy@gmail.com
*  技术博客：https://icoty.github.io
*  Leetcode：https://github.com/icoty/LeetCode

## EDUCATION

- 北京大学 - 软件工程 / 2018.09～至今
- 东北大学 - 工业工程 / 2011.09～2015.07

## EXPERIENCE

### 浙江大华（ 2018年2月 ~ 2018年9月 ）

#### 第三方SDK集成
- 项目说明：客户的平台通过调用中间SDK API与公司内部平台通信。
- 功能实现：
   1. 在SDK进程中嵌入一个RTSP Client从公司内部平台拉取音视频流之后调用客户的SDK API接口直接推给客户的平台；
   2. 在SDK进程中开启一个RPC Client与公司的内部平台通信，SDK进程接收到SDK API的通知消息（由客户的平台发送过来）后立即封装成RPC请求交给RPC Client处理。 
- 相关技术：RTSP拉流，RPC，网络编程，函数指针与函数回调。

#### 第三方智能算法集成
- 项目说明：内部应用采集的音视频流，需要进行智能算法分析（如人脸检测，区域检测，车辆检测等），客户自己提供了一套算法库来分析这些过程，同时客户也自己开发了一个web界面需要与其自己的算法库通信，由于网络安全限制，客户的web请求不能直接与其自己的算法库通信，必须经由内部应用转发。
- 功能实现：
   1. 三方算法库进程集成HttpServer专职接受第三方web请求，然后回调至算法库内部；
   2. 三方算法库进程集成RpcClient专职接受经算法库处理后的元数据，然后发送到内部应用的RpcServer端口进行处理；
   3. 开辟两个共享内存专职把内部采集的到音视频传送到算法库进程。
- 相关技术：Http，共享内存，SDK。

### 矩阵元（深圳）技术 （ 2017年4月 ~ 2017年10月 ）

#### Jenkins持续集成工具
- 项目说明：通过Jenkins管理产品分支，持续集成工具部署
-  功能实现：
   1. Jenkins搭建与配置；
   2. Redhat与Centos平台的版本功能持续验证，Docker平台的探索；
   3. Shell脚本，集代码分支、编译、测试、安装、Docker镜像制作和版本发布为一体；
   4. 对接Android、IOS、Web端联调、输出详细设计文档。

## ARTICLE

- [进程间通信-利用共享内存和管道通信实现聊天窗口](https://icoty.github.io/2019/04/18/ipc-chat/)

## SKILLS
- Linux/vim/Makefile/gcc/gdb
- Mysql
- C/C++/STL
- TCP/Socket/Epoll/IPC
- Shell
- Docker
- Http
- Nginx
- 数据结构
- 微信小程序开发
- Python/MVP框架
- ThinkPHP/MVC框架
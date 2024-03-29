---
title: 常用加密算法的应用
date: 2019-05-20 13:58:36
tags: [对称加密算法,非对称加密算法/公钥算法,Hash函数/散列函数/摘要函数,消息认证,流密码,数字签名/指纹/消息摘要]
categories:
  - [密码学与信息安全]
copyright: true
mathjax: true
---

实际工作和开发过程中，网络通信过程中的数据传输和存储大多需要经过严格的加解密设计，比如用户的登陆与注册，敏感信息传输，支付网站和银行的交易信息，甚至为了防止被拖库，数据库的敏感信息存储也需要经过精心的设计。在进行安全设计过程中，或多或少涉及到密码学的一些概念，比如对称加密算法，非对称加密算法(也名公钥算法)，消息认证，Hash函数(也名散列函数或摘要算法)，数字签名(也名指纹或摘要)，流密码等。

一直以来，对于这些概念，你是否有一种模棱两可，似懂非懂的感觉？下面咱们一起揭开密码学这层神秘的面纱。

### 基本概念
#### 密码体制
密码体制是满足以下5个条件的五元组(P, C, K, E, D)，满足条件: 
1. P(Plaintext)是可能明文的有限集(明文空间); 

2. C(Ciphertext)是可能密文的有限集(密文空间); 

3. K(Key)是一切可能密钥构成的有限集(密钥空间);

4. E(Encrtption)和D(Decryption)是分别由密钥决定的所有加密算法和解密算法的集合;

5. 存在：

	$k \in K$ ,有加密算法 $e_k:P \rightarrow C$ , $e_k \in E$；同时有由 $ {k_1} \in K$ 决定的解密算法 $d_{k_1} : C \rightarrow P，d_{k_1} \in D$；满足关系 $d_{k_1} (e_k(x)) = x, x \in P$。

#### 密码破译

密码破译根本目的在于破译出密钥或密文，假设破译者Oscar是在已知密码体制的前提下来破译Bob使用的密钥。这个假设被称为Kerckhoff准则，最常见的破解类型有如下5种，从1～5，Oscar的破译难度逐渐降低。

1. 唯密文攻击：Oscar仅具有密文串c，Oscar只能通过统计特性分析密文串p的规律；
2. 已知明文攻击：Oscar具有一些明文串p和相应的密文c，{p，c}可以是{P，C}的任意非空子集；
3. 选择明文攻击：Oscar可获得对加密机的暂时访问，因此他能选择特定明文串p并构造出相应的密文串c；
4. 选择密文攻击：Oscar可暂时接近解密机，因此他能选择特定密文串c并构造出相应的明文串p。
5. 选择文本攻击：Oscar可以制造任意明文(p) / 密文(c)并得到对应的密文(c) / 明文(p)。


### 加密算法
#### 对称加密算法

对称加密算法的加密密钥和解密密钥相同，常见的对称加密算法有：AES、DES、2DES、3DES、RC4、RC5、RC6，Blowfish和IDEA，目前使用最广泛的是DES、AES。
```mermaid
graph LR
A[发送方Bob<br>输入明文P] -->|P|B["发送方Bob与接收方Alice<br>共用相同密钥K<br>加密算法(如DES)<br>C=E(K,P)"];
B -->|传输密文C|C["接收方Alice与发送方Bob<br>共用相同密钥K<br>解密算法(如DES)<br>P=D(K,C)"];
C -->|P|D["Alice接收方<br>输出明文P"];
```

#### 非对称加密算法(公钥算法)

公钥算法的加密算法和解密算法使用不同的密钥，分别为公钥和私钥，这两个密钥中的任何一个都可以用来加密，而另一个用来解密。常见的公钥算法有：椭圆曲线(ECC)、RSA、Diffie-Hellman、El Gamal(安全性建立在基于求解离散对数是困难的)、DSA(适用于数字签名)。

##### 公钥算法的应用

1. 发送方Bob用接收方Alice的公钥对消息进行加密，接收方Alice用自己的私钥进行解密，可提供消息传输过程中的保密性。

```mermaid
graph LR
A[Bob<br>输入明文P] -->|P|B["Bob的公钥环{PUalice,……}<br>加密算法<br>C=E(PUalice,P)"];
B -->|传输密文C|C["Alice私钥PRalice<br>解密算法<br>P=D(PRalice,C)"];
C -->|P|D["Alice<br>输出明文P"];
```

2. 发送方Bob采用自己的私钥对明文进行加密，虽然任何持有Bob公钥的人都能够解密，但是只有拥有Bob私钥的人才能产生密文C，而Bob的私钥只有自己知道，因此密文C也叫做数字签名，数字签名C可用于认证源和数据的完整性。

```mermaid
graph LR
A[Bob<br>输入明文P] -->|P|B["Bob的私钥PRbob<br>加密算法(如RSA)<br>C=E(PRbob,P)"];
B -->|传输数字签名C|C["Alice的公钥环{PUbob,……}<br>解密算法(如RSA)<br>P=D(PUbob,C)"];
C -->|P|D["Alice<br>输出明文P"];
```

3. 发送方Bob首先采用自己的私钥对明文进行加密，然后使用接收方Alice的公钥再进行一次加密后传输，则既可提供认证功能，又可提供消息传输过程中的保密性。

```mermaid
graph LR
A[Bob<br>输入明文P] -->|P|B["Bob的私钥PRbob<br>加密算法(如RSA)<br>C=E(PRbob,P)"];
B -->|数字签名C|C["Bob的公钥环{PUalice,……}<br>加密算法(如RSA)<br>C1=E(PUalice,C)"];
C -->|传输密文C1|D["Alice的私钥PRalice<br>解密算法(如RSA)<br>C=D(PRalice,C1)"];
D -->|数字签名C|E["Alice的公钥环{PUbob,……}<br>解密算法(如RSA)<br>P=D(PUbob,C)"];
E -->|P|F["Alice<br>输出明文P"];
```

4. 发送方Bob用接收方Alic的公钥对自己的私钥进行加密，然后发送给Alice，Alic用自己的私钥解密即可得到发送方Bob的私钥，从而实现密钥交换功能。

```mermaid
graph LR
A[Bob的私钥<br>PRbob] -->|Bob的私钥PRbob|B["Bob的公钥环{PUalice,……}<br>加密算法(如RSA)<br>C=E(PUalice,PRbob)"];
B -->|传输密文C|C["Alice的私钥PRalice<br>解密算法(如RSA)<br>PRbob=D(PRalice,C)"];
C -->|PRbob|D["Alice<br>Bob的私钥PRbob"];
```

另外需要说明一下，Diffie-Hellman的密钥交换算法与此方法不同，如果你学过密码学，应该清楚其中的差异。并且并不是所有的公钥算法都支持加密/解密、数字签名和密钥交换功能，有的公钥算法只支持其中的一种或两种，下表列出部分公钥算法锁支持的应用。

| 算法 | 加密/解密 | 数字签名 | 密钥交换 |
| :---------: | :---------: | :---------: | :---------: |
| RSA<br>安全性建立在基于大素数分解是困难的 | Y         | Y         | Y         |
| 椭圆曲线/ECC<br>安全性建立在椭圆曲线对数问题之上<br>(即由kP和P确定k是困难的) | Y         | Y         | Y         |
| Diff-Hellman<br>安全性建立在计算离散对数是很困难的 | N         | Y         | Y         |
| DSS         | N         | Y         | N         |

#### Hash函数(散列函数或摘要函数)

Hash函数将可变长度的消息映射为固定长度的**Hash值**或**消息摘要**，常见的Hash算法有：MD2、MD4、MD5、SHA-1、SHA-224、SHA-256、SHA-384、SHA-512、HAVAL、HMAC、HMAC-MD5、HMAC-SHA1。对于给定的密码学Hash函数y=Hash(x)，要求如下两种情况再计算上不可行：
1. 对给定的y，找到对应的x；
2. 找到两个不同的x1和x2，使得Hash(x1)=Hash(x2)，具有抗碰撞性的特点。

##### Hash函数的应用
1. **消息认证**是用来验证消息完整性的一种机制或服务，消息认证确认收到的数据确实和发送时的一样(即**防篡改**)，并且还要确保发送方的身份是真实有效的的(即**防冒充**)。下图以对称加密算法为例，因为对称密钥K只有Bob和Alice才有，保证了发送方的合法有效性，同时比较C3与C是否相等，可以确定传输过程中是否被篡改过。

```mermaid
graph LR
A[Bob<br>输入明文P] -->|P|B["Bob<br>Hash函数<br>(如sha256)<br>C=Hash(P)"];
B -->|C|C["Bob<br>C1=P||C"];
A -->|P|C;
C -->|"C1=P||C"|D["Bob和Alice公用的密钥K<br>对称加密算法(如DES)<br>C2=E(K,C1)"];
D -->|传输密文C2|E["Alice和Bob公用的密钥K<br>对称解密算法(如DES)<br>C1=D(K,C2)"];
E -->|"C1=P||C"|F["Alice<br>1.Hash函数(如sha256)<br>C3=Hash(P)<br>2.比较C3与C是否相等"];
```

2. **数字签名(也名指纹或摘要)**是一种认证机制，它使得消息的产生者可以添加一个起签名作用的码字，通过计算消息的Hash值并用产生者的私钥加密Hash值来生成签名，签名保证了消息和来源和完整性。下图最后一步比较C3与C如果不相等，认证失败，该图没有提供保密性，因为传输过程中只是将P和C1简单的连接在一起，并没有对C2进行加密，如果需要提供保密性，可以使用Alic的私钥对C2加密后再传输。
```mermaid
graph LR
A[Bob<br>输入明文P] -->|P|B["Bob<br>Hash函数<br>(如sha256)<br>C=Hash(P)"];
B -->|C|C["Bob的私钥PRbob<br>加密算法(如RSA)<br>C1=E(PRbob,C)"];
C -->|C1|D["Bob<br>C2=P||C1"];
A -->|P|D;
D -->|传输C2|E["Alice的公钥环{PUbob,……}<br>1.解密算法(如RSA)<br>C=D(PUbob,C1)<br>2.Hash函数(如sha256)<br>C3=Hash(P)<br>3.比较C3与C是否相等"];
```

3. 用于产生单向口令文件，比如操作系统存储的都是口令的Hah值而不是口令本身，当用户输入口令时，计算其Hash值和之前存储的口令比对，这样即使操作系统被黑之后，也能保证用户口令的安全性。同样适用于入侵检测和病毒检测，如将你需要保护的文件的Hash值存储到安全系统中(比如只读设备中，不可修改也不可删除)，这样病毒入侵后只能修改文件而不能修改Hash值，于是可以通过重新计算文件的Hash值和之前保存的Hash值比对。

### 加密方式

#### 流密码

典型的流密码是每次加密一个字节的密文，加密长度可以按需求设计，比如每次只加密一位或者大于一个字节的单元都行。实质上$Ci=Pi \oplus K1i，Pi=Ci \oplus K2i$，就是简单的异或，加密异或一次，解密再异或一次，即可恢复明文字节流。

```mermaid
graph LR
A["Bob<br>明文字节流P1~Pn"] -->|"P1~Pn"|C["Bob<br>加密函数<br>Ci=E(K1i,Pi)"];
B["Bob 由密钥K1控制的<br>密钥流发生器K11～K1n<br>其中K1i=K2i"] -->|"K11～K1n"|C;
C -->|"传输密文C1～Cn"|E["Alice<br>解密函数<br>Pi=D(K2i,Ci)"];
D["Alice 由密钥K2控制的<br>密钥流发生器K21～K2n<br>其中K1i=K2i"] -->|"K21～K2n"|E;
E -->|"明文字节流P1～Pn"|F["Alice<br>明文字节流P1~Pn"];
```

### 参考文献

[MathJax语法规则](https://math.meta.stackexchange.com/questions/5020/mathjax-basic-tutorial-and-quick-reference/5044%20MathJax%20basic%20tutorial%20and%20quick%20reference)
[Mermaid语法规则](https://www.jianshu.com/p/7ddbb7dc8fec)
[Mermaid官方教程](https://mermaidjs.github.io/demos.html)
[Mermaid Github仓库](https://github.com/webappdevelp/hexo-filter-mermaid-diagrams)
[MathJax Github仓库](https://github.com/mathjax/MathJax)
[常用加密算法概述](https://www.cnblogs.com/colife/p/5566789.html)
[HTTPS建立过程](https://blog.csdn.net/u011779724/article/details/80776776)


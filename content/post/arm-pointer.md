---
title: "ARM指针的一些安全功能"
date: 2020-10-19T13:12:59+08:00
draft: false
categories: [Kernel]
tags: [安全,Linux,Kernel]
---

伴随着 ARM 平台的越来越普及，Linux 内核对其的支持也逐渐丰富。而且 ARM 的设计也有很多独特的优点，本文将介绍在 ARM 平台关于指针操作的一些安全方面的设计。

## Pointer Authentication
很多攻击都是通过骇客设计的不安全指针进行的。比如 `buffer-overflow` 和 `return-oriented programming`, 都是通过在返回地址放置一个指针来进行的。内核已经针对这个问题做了很多改善，ARM 提供了 `pointer authentication` 来检测和拒绝这种插入的非法指针。

简单来说，就是在指针上附加一个签名，要想使用一个指针，先得签名验证通过。如果是外部的攻击者，它没法伪造这种签名，那么自己就不能制造指针来进行攻击了。

目前一般指针都是64位，但一般都不是所有bit都是用了。ARM64的系统，如果是三级页表，那么只有低位的40bit用来存放地址，那么其他的bit就可以用来干其他事情。 签名一般是通过以下几个参数确定:
* pointer 本身
* process context 里的一个 secret key, kernel生成 这个肯定是攻击者无法获取到的
* current stack pointer。防止签名过的pointer泄露被复用

使用的话，需要先重新计算一下签名，确保二者对的上，然后把签名部署的数据清理掉，这时候就是一个正常的指针了。不然的话，就认为其非法。


## Memory Tagging
`Memory Tagging`的做法与`Pointer Authentication`类似，都是利用指针里未利用的 bits 去存储一些信息。`Memory Tagging` 是利用 4bit 的信息存储了一个 key, 同时在 pointer 指向的内存地址里也存储了同样的 key. 当对指针进行解引用操作时，需要对比 pointer 里的 key 与实际内存地址里的 key 是否一致。如果不一致将会报错。这个功能有以下用处：
* 被释放的内存可以修改其 key, 防止被二次引用
* 每个 stack frame 分配一个 key, 越界访问也会报错
* 野指针也能检测到
* ....

这些 keys 可以用应用层来管理，也可以用 CPU 来随机生成。当用应用层来管理的时候，可以提前检测出内存方便的 bug. 



## 总结
上面两个功能是可以一起协同工作的，因为他们都分别占用了 pointer 里不用的一些 bits, 只要规划好分给各自的部分就好。如果 glibc 等相关部分的工作完善好，理论上应用层是不需要做任何改动就能享受到这些好处了。



## Links
1. [ARM pointer authentication](https://lwn.net/Articles/718888/)
2. [Pointer Authentication on ARMv8.3](https://www.qualcomm.com/media/documents/files/whitepaper-pointer-authentication-on-armv8-3.pdf)
3. [Armv8.5-A  Memory Tagging Extension](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/Arm_Memory_Tagging_Extension_Whitepaper.pdf)
4. [The Arm64 memory tagging extension in Linux](https://lwn.net/Articles/834289/)

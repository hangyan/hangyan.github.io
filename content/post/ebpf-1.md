---
title: "eBPF系列1 - 介绍"
date: 2020-09-22T22:39:41+08:00
draft: true
---

一直想写(整理)一些关于 eBPF 的文章。在我眼中，它是 `未来技术` 之一。 最近零零碎碎看了一些，感觉信息太多，怕是永远也看不完，索性开始一遍看一边记笔记吧。这一篇是介绍。


## eBPF 是什么
先介绍下 eBPF 的前身: BPF -> `Berkeley Packet Filter`. 看名字就知道，主要是用于网络 packat 的过滤用的。 eBPF extend 了 BPF, 将其机制大大地泛化，不止用于网络数据包的处理，而是可以 hook 在任意的系统调用上, 这样它就变成了一个几乎具有无限功能的系统。

![](https://ebpf.io/static/syscall_hook-b4f7d64d4d04806a1de60126926d5f3a.png)

![](https://ebpf.io/static/hook_overview-99c69bbff092c35b9c83f00a80fed240.png)


## 如何开发 eBPF 程序
通过 llvm 等工具，可以使用各种高级语言的 package 或者 binding 来开发 eBPF 程序.

![](https://ebpf.io/static/clang-a7160cd231b062b321f2a479a4d0848f.png)

## 运行

![](https://ebpf.io/static/loader-7eec5ccd8f6fbaf055256da4910acd5a.png)

### 校验
当 eBPF 程序被加载进内核之后，要先做一些程序校验工作, 比如:
* 权限是否具备。 加载 eBPF 的程序是否有权限加载.一般来讲，程序必须得是 root 用户运行的或者有 `CAP_BPF` 权限才能加载。 如果开启了 `unprivileged eBPF`, 那么普通程序也可以加载一些功能受限的 eBPF 程序。 
* eBPF 程序是否有可能 crash
* 不能有为未初始化的变量或者越界访问
* 程序大小有 limit.
* 复杂程度有 limit. 检查程序会估算所有的执行路径以评估其复杂程度。
* eBPF 是否会无法终止运行(比如 loop forever)
* ...

之所以有这么多检查，就是因为它能做的事情太多了，也太有可能造成破坏了，所以在校验阶段就尽量多做一些。

### 加固

### JIT编译
将 eBPF 程序编译为机器码。 这也是 eBPF 程序的巨大优势之一，性能很高，不会给各种上层系统带来太多的性能上的 overhead.

## 数据结构

MAP 是 eBPF 程序中最为重要的数据结构，依赖于它来存取状态。

![](https://ebpf.io/static/map_architecture-e7909dc59d2b139b77f901fce04f60a1.png)

这个 MAP 跟我们通常理解的 map 不太一样，它分很多类型:

TODO



## Links
1. 


---
title: "eBPF系列1 - 介绍"
date: 2020-09-22T22:39:41+08:00
draft: false
tags: [eBPF]
categories: [eBPF]
---

一直想写(整理)一些关于 eBPF 的文章。在我眼中，它是 `未来技术` 之一。 最近零零碎碎看了一些，感觉信息太多，怕是永远也看不完，索性开始一遍看一边记笔记吧。这一篇是介绍。


## eBPF 是什么
先介绍下 eBPF 的前身: BPF -> `Berkeley Packet Filter`. 看名字就知道，主要是用于网络 packet 的过滤用的。 过滤程序是运行于基于寄存器的虚拟机之上．　BPF 展示了在内核中运行用户程序的良好开端．但它的缺点也很明显，虚拟机的设计以及指令集都比较落后，跟不上现代处理器的发展(尤其是多核方面)，也无法利用现在的 64bit 寄存器．
 
 eBPF extend 了 BPF, 将其机制大大地泛化，不止用于网络数据包的处理，而是可以 hook 在任意的系统调用上, 这样它就变成了一个几乎具有无限功能的系统。 在硬件上，它跟现代的处理器的指令集更为贴近,并且能充分利用现在数量众多的 64bit 寄存器．这样就使 JIT 编译器的产生变为了可能，大大提升了性能.

![](https://ebpf.io/static/syscall_hook-b4f7d64d4d04806a1de60126926d5f3a.png)

![](https://ebpf.io/static/hook_overview-99c69bbff092c35b9c83f00a80fed240.png)

在没有　eBPF 只之前，如果我们想对内核行为进行修改，基本上就是往内核里添加代码或者通过 kernel modules 进行．这二者的门槛都不低，所以影响有限．eBPF 提供了一种新的可能性，通过普通的编程方式，去控制内核的行为，同时保证了高性能．这就是它之所以独特和具有极大潜力的主要原因．

![](https://img2020.cnblogs.com/blog/1334952/202008/1334952-20200806131434176-1093013946.png)





## 程序校验

![](https://ebpf.io/static/loader-7eec5ccd8f6fbaf055256da4910acd5a.png)

当 eBPF 程序被加载进内核之后，要先做一些程序校验工作, 比如:
* 权限是否具备。 加载 eBPF 的程序是否有权限加载.一般来讲，程序必须得是 root 用户运行的或者有 `CAP_BPF` 权限才能加载。 如果开启了 `unprivileged eBPF`, 那么普通程序也可以加载一些功能受限的 eBPF 程序(比如不允许指针操作)。 
* eBPF 程序是否有可能 crash
* 在每次指令执行前后都需要校验虚拟机的状态，保证寄存器和栈的状态都是有效的. 校验器不会检查程序的每条路径，它能够知道程序的当前状态是否是已经检查过的程序的子集。由于前面的所有路径都必须是有效的(否则程序会加载失败)，当前的路径也必须是有效的，因此允许验证器“修剪”当前分支并跳过其模拟阶段。
* 不能访问未初始化的变量或者越界访问
* 程序大小有 limit.
* 复杂程度有 limit. 检查程序会估算所有的执行路径以评估其复杂程度。
* eBPF 是否会无法终止运行(比如 loop forever)
* 不同类型的 eBPF 程序只能访问特定类型的系统调用

之所以有这么多检查，就是因为它能做的事情太多了，也太有可能造成破坏了，所以在校验阶段就尽量多做一些。

## 数据结构

### bpf()

使用`bpf()`系统调用和`BPF_PROG_LOAD`命令加载程序。该系统调用的原型为：
```c
int bpf(int cmd, union bpf_attr *attr, unsigned int size);
```
其中 attr 用于在 user space 和 kernel 之间传递数据
, size 是 `bpf_attr` 的大小.



### eBPF MAP

上述的 `cmd` 支持如下类型:

    BPF_MAP_CREATE
              Create a map and return a file descriptor that refers to the
              map.  The close-on-exec file descriptor flag (see fcntl(2)) is
              automatically enabled for the new file descriptor.

       BPF_MAP_LOOKUP_ELEM
              Look up an element by key in a specified map and return its
              value.

       BPF_MAP_UPDATE_ELEM
              Create or update an element (key/value pair) in a specified
              map.

       BPF_MAP_DELETE_ELEM
              Look up and delete an element by key in a specified map.

       BPF_MAP_GET_NEXT_KEY
              Look up an element by key in a specified map and return the
              key of the next element.

       BPF_PROG_LOAD
              Verify and load an eBPF program, returning a new file descrip‐
              tor associated with the program.  The close-on-exec file
              descriptor flag (see fcntl(2)) is automatically enabled for
              the new file descriptor.


`attr` 主要是 eBPF MAP. MAP 是 eBPF 程序中最为重要的数据结构，依赖于它来存取状态。

![](https://ebpf.io/static/map_architecture-e7909dc59d2b139b77f901fce04f60a1.png)

使用`bpf()`系统调用创建和管理map。当成功创建一个map后，会返回与该map关联的文件描述符。关闭相应的文件描述符的同时会销毁map。每个map定义了4个值：类型，元素最大数目，数值的字节大小，以及key的字节大小。eBPF提供了不同的map类型，不同类型的map提供了不同的特性。



    BPF_MAP_TYPE_HASH: a hash table
    BPF_MAP_TYPE_ARRAY: an array map, optimized for fast lookup speeds, often used for counters
    BPF_MAP_TYPE_PROG_ARRAY: an array of file descriptors corresponding to eBPF programs; used to implement jump tables and sub-programs to handle specific packet protocols
    BPF_MAP_TYPE_PERCPU_ARRAY: a per-CPU array, used to implement histograms of latency
    BPF_MAP_TYPE_PERF_EVENT_ARRAY: stores pointers to struct perf_event, used to read and store perf event counters
    BPF_MAP_TYPE_CGROUP_ARRAY: stores pointers to control groups
    BPF_MAP_TYPE_PERCPU_HASH: a per-CPU hash table
    BPF_MAP_TYPE_LRU_HASH: a hash table that only retains the most recently used items
    BPF_MAP_TYPE_LRU_PERCPU_HASH: a per-CPU hash table that only retains the most recently used items
    BPF_MAP_TYPE_LPM_TRIE: a longest-prefix match trie, good for matching IP addresses to a range
    BPF_MAP_TYPE_STACK_TRACE: stores stack traces
    BPF_MAP_TYPE_ARRAY_OF_MAPS: a map-in-map data structure
    BPF_MAP_TYPE_HASH_OF_MAPS: a map-in-map data structure
    BPF_MAP_TYPE_DEVICE_MAP: for storing and looking up network device references
    BPF_MAP_TYPE_SOCKET_MAP: stores and looks up sockets and allows socket redirection with BPF helper functions 

### eBPF 程序类型
使用BPF_PROG_LOAD加载的程序类型确定了四件事：附加的程序的位置，验证器允许调用的内核辅助函数，是否可以直接访问网络数据报文，以及传递给程序的第一个参数对象的类型。实际上，程序类型本质上定义了一个API。创建新的程序类型甚至纯粹是为了区分不同的可调用函数列表(例如，BPF_PROG_TYPE_CGROUP_SKB 和BPF_PROG_TYPE_SOCKET_FILTER)。
目前内核支持的程序类型有:

    BPF_PROG_TYPE_SOCKET_FILTER: a network packet filter
    BPF_PROG_TYPE_KPROBE: determine whether a kprobe should fire or not
    BPF_PROG_TYPE_SCHED_CLS: a network traffic-control classifier
    BPF_PROG_TYPE_SCHED_ACT: a network traffic-control action
    BPF_PROG_TYPE_TRACEPOINT: determine whether a tracepoint should fire or not
    BPF_PROG_TYPE_XDP: a network packet filter run from the device-driver receive path
    BPF_PROG_TYPE_PERF_EVENT: determine whether a perf event handler should fire or not
    BPF_PROG_TYPE_CGROUP_SKB: a network packet filter for control groups
    BPF_PROG_TYPE_CGROUP_SOCK: a network packet filter for control groups that is allowed to modify socket options
    BPF_PROG_TYPE_LWT_*: a network packet filter for lightweight tunnels
    BPF_PROG_TYPE_SOCK_OPS: a program for setting socket parameters
    BPF_PROG_TYPE_SK_SKB: a network packet filter for forwarding packets between sockets
    BPF_PROG_CGROUP_DEVICE: determine if a device operation should be permitted or not 

## 如何开发 eBPF 程序
通过 llvm 等工具，可以使用各种高级语言的 package 或者 binding 来开发 eBPF 程序.

![](https://ebpf.io/static/clang-a7160cd231b062b321f2a479a4d0848f.png)



### bcc

![](https://ebpf.io/static/bcc-def942c66b8c7565f0cfeab1c1017a80.png)

### bpftrace

![](https://ebpf.io/static/bpftrace-c53dfcbff6ea67a8f00896bd76e4c07c.png)

### language library

![](https://ebpf.io/static/go-1a1bb6f1e64b1ad5597f57dc17cf1350.png)
![](https://ebpf.io/static/libbpf-f4991ee40f74df260dbb3e0541855044.png)

## Links
1. [eBPF Documentation](https://ebpf.io/what-is-ebpf#what-is-ebpf)
2. [A thorough introduction to eBPF](https://lwn.net/Articles/740157/)
3. [全面介绍eBPF-概念](https://www.cnblogs.com/charlieroro/p/13403672.html)


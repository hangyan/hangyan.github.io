---
title: "eBPF Loop"
date: 2021-12-03T15:54:37+08:00
draft: false
categories: [eBPF]
tags: [Linux,eBPF]
---

eBPF Loop 是个老大难问题，只要实际开发大概率都会遇到。Kernel 版本越高，loop 的支持也越多。最近在 LWN 上又看到一篇关于 bpf loop 的新实现，如果能合并进去，那么就有三种 loop 得方式了:

1. bounded loop: 跟传统编程模式很像，但loop的count必须是已知的
2. map iterator: 针对 bpf map 的迭代器，可以用来遍历 map
3. bpf_loop 函数: 最新的提议，能让 verifier 处理的更快

目前的 verifier 的策略是比较激进的，因为它没法验证所有的场景，所以有可能会对一些实际正确的程序验证不通过。`bpf_loop` 主要就是从这个角度来考虑问题，相当于对最开始的 bounded loop 做的一个优化。下面将详细介绍。

## Bounded Loop
Kernel 5.3 之前, eBPF 不支持 loop. 要想实现类似功能，而且前提是明确 loop 的次数，那么基本上只能靠 `unroll` 来实现。示例如下:

```c
#pragma clang loop unroll(full)
        for (i = 0; i < 4; i++) {
            /* Do stuff ... */
        }
```

相当于把 loop 展开。5.3 及之后，就不用这样了。


## MAP Iterator

Bounded Loop 只能解决一部分的问题。总会有 unbounded loop 的场景。5.13 引入了 map iterator, 支持对 bpf map做遍历。考虑到 bpf map 在 eBPF 程序中的普遍性，算是一个比较好的解决方案了.

具体可参考: https://lwn.net/Articles/826058/


## bpf_loop

bpf_loop 仍然是 bounded loop 范畴。但从 verifier 的角度考虑，大大简化了 verify 的逻辑。相当于把 loop 从普通的函数流程里抽取了出来，单独用一个 bpf 函数来实现:

```c
 long bpf_loop(u32 iterations, long (*loop_fn)(u32 index, void *ctx),
    		  void *ctx, u64 flags);
```

这个 patch 还没合并。




Links:

1. [Are loops allowed in Linux's BPF programs?](https://stackoverflow.com/questions/56107380/are-loops-allowed-in-linuxs-bpf-programs)
2. [A different approach to BPF loops](https://lwn.net/Articles/877062/)

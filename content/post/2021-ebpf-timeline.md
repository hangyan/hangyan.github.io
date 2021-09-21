---
title: "eBPF Timeline"
date: 2021-09-21T10:42:52+08:00
draft: false
categories: [eBPF]
tags: [eBPF]
---

bcc 的文档已经做了很多详细的介绍，关于 kernel 中 eBPF 的变化: https://github.com/iovisor/bcc/blob/master/docs/kernel-versions.md. 本文记录的是我在测试过程中发现的几个比较重要的节点。


## 5.2
这块没找到详细描述，是根据程序实测出来的。在运行包含 map 的 eBPF 程序时，有如下错误:

```text
failed to load objects: field Ingress: program _ingress: map .rodata: map create: read- and write-only maps not supported (requires >= v5.2)
```

错误信息提示的比较清楚，5.2内核及以上的就可以。不太确定为啥用上了 read/write only的 maps, 猜测是 libbpf 内部的实现机制导致的。因为这个问题，我目前将我测试的 eBPF 程序支撑的最低内核设定为 5.2 了。这点挺可惜的，因为 4.x 的内核对 eBPF 的很多支持已经很完善了， ubuntu 18.04 就是 4.18 的内核。


## 5.8

kernel 默认带了 BTF 文件。这个 5.8 是不准确的，但确实没查到具体在哪个 kernel 版本默认带的。ubuntu 20.04 没有， 20.10 有了，暂且将其作为开始版本。kernel 对 BTF 的支持从 4.x 就有了，只不过最开始不是默认带的，如果需要，需要自己 打开开关并重新编译内核。如果考虑生产环境，这个其实挺麻烦的。如果设定为只支持自带 BTF 文件的版本，那就省事多了。


## 5.13

5.13 开始支持 map 的遍历了。最开始的 eBPF 是不支持 loop 之类的操作的，防止 crash kernel等等。但是因为程序开发离不了这个，后面又加入了 bounded loop, 但仍然是不够用的。因为很多复杂程序是没法提前知道需要 loop 多少次的。5.13 才开始支持了 map iterator. 不过要注意以下两点:

* 这里所说的支持只是指 kernel space. 用户态的很早就支持了
* 因为 libbpf 有了自己单独 sync 出来的代码库。所以也是可以在较老的 kernel 是链接 5.13+ 的 libbpf 来使用此功能。



Links:

1. [Crash because of TUN/TAP do not support ebpf](https://github.dihe.moe/aojea/netkat/issues/1)

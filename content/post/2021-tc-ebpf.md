---
title: "TC 的一些有趣功能"
date: 2021-12-18T19:29:35+08:00
draft: false
categories: [Network]
tags: [TC, eBPF, Linux]
---

最近在看 TC 和 eBPF 相关的一些介绍。TC 本身的概念比较复杂，想要理清并不容易。加上 eBPF 的引入就更复杂了。本文用来记录与此相关的一些发现。






## clsact

`clsact` 即是用来给 TC + eBPF 是使用的一个 `qdisc`. `qdisc` 可以简单理解为使用某种算法(FIFO)的 Queue. `clsact` 的特点是:

* 不用排队
* 主要就是为了 attach ebpf 用的
* 在 ingress/egress 都提供了 hook
* lock free


## ingress 与 egress 的不同

不太确定直接的原因是啥，目前的 qdisc 只在 egress 方向上有。一般的 rate-limiting 都是在 egress 上实现， ingress上的比较困难。一个原因是难以对源头进行限速。


## multiple qdisc

多个 qdisc 在 egress 上是很常见的。加了 clasact 之后就更常见了。那么 clsact 和他们什么关系？ 

![](https://oss-emcsprod-public.modb.pro/wechatSpider/modb_20211020_493eb7be-31a1-11ec-920d-fa163eb4f6be.png)

这是我从另一个 Topic 摘过来的图。可以看出来， clsact 是在普通的 qdisc 之前的。


## direct-action mode
 
请参考: [Understanding tc “direct action” mode for BPF](https://qmonnet.github.io/whirl-offload/2020/04/11/tc-bpf-direct-action/)

简单来说，传统的 TC 使用需要 filter 和 action 两个 module. 但是因为 bpf 本身的功能比较丰富，可以将二者合二为一。这就是 direct-action mode.


## EDT Solution

egress 的 rate-limiting 方案可以优化的地方很多，涉及到 lock, cpu scheudler, 不同的 qdisc 算法等等。字节有一篇文章详细列举了几种常见的方案:

![Linux 内核 | 网络流量限速方案大 PK](https://www.modb.pro/db/142271)

其中最有的意思就是最后的 EDT 方案。这个也是目前 Cilium 在用的 bandwidth 方案。CNI的参考实现里用了 IFB 方案（支持ingress)。


## tcng
代表 `traffic control next generation`. 可以用 code/config 的方式来设置 TC 的相关功能。具体可参考: http://tcng.sourceforge.net/

## TC Flower
针对 openvswitch hardware offload 的方案. TC 的可扩展性很强，可以接入不同的 classifier ( 上面的 bpf 也算一例). Openflow 规则也可以映射成 TC 规则。

![OpenVSwitch 硬件加速浅谈](https://zhuanlan.zhihu.com/p/57870521)


## Links
1. [Cilium: BPF and XDP Reference Guide](https://docs.cilium.io/en/latest/bpf/)
2. [Bandwidth Manager (beta)](https://docs.cilium.io/en/stable/gettingstarted/bandwidth-manager/)

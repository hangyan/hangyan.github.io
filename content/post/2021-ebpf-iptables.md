---
title: "eBPF, iptables, nftables"
date: 2021-09-20T19:56:17+08:00
draft: false
categories: [eBPF]
tags: [eBPF, iptables]
---

把它们三个列在一起，是因为确实有错综复杂的关系。我也想理一理他们在网络方面的前景,比较侧重于 K8s 和 CNI 方面.

* `iptables`: kube-proxy最开始基于 iptables 来实现了 service 的负载均衡，只支持随机算法。因为 iptables 本身的局限性，目前提供了 ipvs 模式.
* `nftables`: 可以说是 iptables 的替代品，更好的API及性能，但是因为 iptables 的遗留使用率太高，暂时难以看到全面替代的可能。
* ` eBPF`: 影响越来越多，有可能会在很多场景下替代 iptables

这是简要的说明。下面将根据不同侧面来详细分析一下。


## iptables

两个主要问题:
1. 规则数量线性增长
2. 更新规则需要整个替换掉，无法保证原子性。更新规则的效率也很低。

## ipset

ipset 是 iptables 的一个扩展，主要解决的问题是 iptables 的线性增长问题。考虑到 iptables 的现实中的普及性以及大家求稳的心态， ipset 在很多场景下仍是一个不错的选择。其基本思想是用 hash 等数据结构来替代原来的线性匹配，这种设计我们在很多地方都可以见到，比如 ovs, eBPF等等。

nftables 作为 iptables 的继任者，很多设计已经了 ipset 里的设计。二者有一定的相似性。

## ipvs
没找到太好的深入介绍的资料，但根据网上找的测试数据，比 iptables 好很多.

![](https://www.tigera.io/wp-content/uploads/2019/04/Picture1.png)

Service 数量少时不明显，数量很大时差距就出来了。


## kube-proxy
eBPF, iptables, nftables,ipvs, ipset这些东西，最终在 k8s 上的落脚点都是 kube-proxy. kube-proxy实现了各种 Service 的功能，底层用什么，是可能会变的，从最开始的 iptables 到现在的 ipvs, 以后真用其他的东西也说不准. 除了 iptables 和 ipvs, 我们也能找到其他方面的尝试:

* `ipset`: ipvs就是基于 ipset的，所以已经算是用上了。iptables + ipset 也有可能，比如这个 issue: https://github.com/kubernetes/kubernetes/issues/54203
* `nftables`: https://github.com/sbezverk/nfproxy 有一个示例的项目了。


这其实也导致了一个问题，就是假设我们扩展 kube-proxy，因为流程上的问题，会非常慢。所以各个 CNI 都在致力于开发自己的 proxy, 以取代 kube-proxy. 这时候各个 CNI 就完全可以基于自己的 dataplane 来实现 kube-proxy的功能，虽然麻烦了些，但好处也是巨大的。cilium不用说了，一开始就是完全基于 eBPF 来做的，calico 也有自己的基于 eBPF 的 Service 实现，等等。


## eBPF
eBPF发展下去，很有可能会成为所有 CNI 的 dataplane的选择之一。除了 cilium, 其他 CNI 都有可能需要发展出一个 plugin 架构，用来支持多种 dataplane. 这里面最典型的例子就是 calico, 已经在这样做了。所以参考的价值也比较大。如果想引入 eBPF，切入点其实并不好找。如果想直接开始实现整个 dataplane, 工作量巨大，而且不一定比原有的 dataplane 有太大的性能及功能优势。那只能从小到大，慢慢来。就像 calico 现在做的那样，非常深入研究。

eBPF 和 iptables 还有一层关系就是内核有尝试在保留 iptables API 的同时，用 eBPF 来实现底层逻辑。目前只是在 POC阶段，争议也不小。一个主要的原因还是这样做不一定值得。iptables API 是否还应该被续命？或者说应该把精力放在推广 nftables, 反正需要考虑的因素比较多。不过在 CNI 层面上，eBPF 对 iptables 的优势会越来越明显。

这其实引入了另一个问题。既然大家都有了类似的需求，都是做 CNI 的，都想基于 eBPF 做一个 dataplane, 不管是主要的还是 optional 的，那么这块能否共享呢？ cilium 做的很早很全，但现在没法说单把这块拉出来让大家公用。calico 也在做，但这块也不能直接说被第三方引用。这有点像搜索引擎面临的类似的问题，大家底层的逻辑都是类似的，都需要用爬虫抓来数据，具体怎么用，不同的搜索引擎不一样。在 CNI + eBPF 里面也是，dataplane 可以类似，但上层的差异化能做的东西是很多的。

也有可能等 eBPF 非常成熟之后，官方下场开始自己做，也是有可能的。不过在这之前，只能自己做了。


## Links
1. [IPSET with IPTABLES](https://malware.expert/howto/ipset-with-iptables/)
2. [nftables初体验](https://owent.net/2020/2002.html#nftables%E4%B8%8Eipset)
3. [kubernetes: ipvs](https://github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md)

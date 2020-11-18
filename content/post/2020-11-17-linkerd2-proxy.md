---
title: "Linkerd系列1 - Linkerd2-proxy"
date: 2020-11-17T18:48:42+08:00
draft: false
categories: [ServiceMesh]
tags: [linkderd, proxy, lb]
---

ServiceMesh这块属于 k8s 的一个大热门，但据我所知，落地的并不是太多。看文章大概理解为 overhead 以及部署都比较重，对一般的企业来讲，要考虑的东西比较多，所以落地难度比较大。有的建议是说，先上 envoy，其他的先搁置，这也是个思路。envoy 轻量级一些，可以先作为一个 proxy 去体验一下 ServiceMesh 架构下的 proxy 设计。然后再逐步看看怎么引入 ServiceMesh.

另一个方面，Istio vs Linkerd 应该还没完全分出胜负，对于企业的选型来说，仍然是个难点。好处是，我们可以去对比二者在各个功能点上的设计思路差异，然后加深理解。在 ServiceMesh 的组件中，毫无疑问 proxy 是核心组件之一。linkderd 的 linkderd2-proxy 也是一个经过深思熟虑并且设计良好的组件，可以作为切入点研究下 linkderd 的整体设计。


## 语言选型
envoy 是 C++ 写的，而 linkderd2-proxy 是 Rust. 语言的选型不仅对于实现者来说很重要，对于用户来说也是。想一下 marathon 用的 scala 以及它的失败就知道了。为什么选 Rust, 这跟它最开始的目标有关
* 资源占用低。因为 ServiceMesh 场景下的 proxy, 经常是以 sidecar 方式挂载在业务组件的 Pod 里，所以一定不能有太多的资源占用。
* 延迟低。因为要转发所有的请求，不能有太多的 overhead.
* 安全。同上，因为要转发所有的请求，如果 proxy 本身有安全漏洞，那就影响太大了。

因为 linkderd2-proxy 主要的设计思路是简单，只定义为 ServiceMesh 场景，那么上面几个条件几乎都是硬性的，符合上面几个条件的语言基本上就只有 Rust了。因为上面几个条件意味着:
* 不能有GC. GC会带来 worst case tail latency。Go/Java不符合
* 不能太重了。JVM再经过调优也不符合。linkderd2-proxy第一版就是用 Scala 写的，被抛弃了。
* 有内存安全保障。C/C++不符合。历史经验表明，很多组件一大半的安全漏洞都是跟内存安全有关的。


## 自动协议检测及 mTLS 
这点跟 envoy 的差别也比较大。envoy 的配置文件上来一看还是挺吓人的，虽然可维护性更好。而linkderd2-proxy的设计思路是尽可能的少配置，基本上能做到插入即用，不需要额外配置什么。

当 proxy 收到一个请求的时候，先做一下 protocol detection, 比如:
* 是一个 http 请求吗
* 是一个 TLS Client Hello 请求吗

如果是 TSL Client Hello 请求，查一下 SNI 的 值，如果是此 proxy 注入的 app, 那么就转发过去。如果是其他未知的http或者tcp请求，proxy 会直接转发。


![](https://linkerd.io/uploads/flow-chart.png)

mTLS 是指双向的 TLS 检查。一般我们场景都是检查 Server的，比如浏览器。但是像这种 client 如果是有已知合集的话，可以做双向的检测。比如 ServiceMesh场景下， Proxy-Proxy 的流量就可以做 mTLS. linkderd2实现了自动的 mTLS, 程序无感知。

每个 proxy 都会收到 control panel 下发的证书，24小时轮替。proxy的时候用不用 mTLS，很大程度上也是 control-panel 来帮助决策，这里不过多涉及。

另外，在proxy-proxy的场景下，还可以将 HTTP/1.X 自动升级为 HTTP/2, 以利用其多路复用的能力。在 dest 端再自动降为 HTTP/1.X.


## 负载均衡算法
转发请求的时候，control panel协助找到 endpoints列表。那么需要 proxy 选定一种负载均衡算法转发。这其实是一个分布式的负载均衡场景了，因为每个proxy都是一个LB.与单个LB的场景相比，常用的算法可能效果不好或者计算起来太过复杂。比如最小负载或者轮询。而 linkderd2-proxy 提供了一种实测性能更优秀的算法:

* `Power of Two Choices`: 简称为`P2C`, 转发时，随机从backend里选择两个实例，并选择其中负载最小的一个，然后转发。这种算法实现起来比较简单，而且实际效果也很好。有一种群体智慧的感觉。

至于如何计算实例的负载，使用的是`EWMA`: exponentially weighted moving averages。通过测算每个实例的一段时间内的RTT, 并且通过加权算法给予最近的数据更高的权重来判断每个实例哪个更快一些。

![](https://linkerd.io/uploads/2017/07/buoyant-latency-experiment-results.png)

上图展示了单个LB场景下EWMA的实测数据，一般来说比Round Robin 和 Least Loaded 的更好

## Links
1. [Automatic mTLS](https://linkerd.io/2/features/automatic-mtls/)
2. [Under the hood of Linkerd's state-of-the-art Rust proxy, Linkerd2-proxy](https://linkerd.io/2020/07/23/under-the-hood-of-linkerds-state-of-the-art-rust-proxy-linkerd2-proxy/)
3. [Beyond Round Robin: Load Balancing for Latency](https://linkerd.io/2016/03/16/beyond-round-robin-load-balancing-for-latency/)
4. [NGINX and the “Power of Two Choices” Load-Balancing Algorithm](https://www.nginx.com/blog/nginx-power-of-two-choices-load-balancing-algorithm/)
5. [I Wanna Go Fast - Load Balancing Dynamic Steering](https://blog.cloudflare.com/i-wanna-go-fast-load-balancing-dynamic-steering/)

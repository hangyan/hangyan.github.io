---
title: "Promethus 的高可用方案"
date: 2020-11-24T16:22:28+08:00
draft: true
categories: [Kubernetes]
tags: [promethus]
---

Promethus 属于云原生生态的一个标配。之前一直不怎么关注的原因是因为感觉它可以研究的内容不多，就是那么个架子，比较清晰。最近看了看发现性能这块还是值得看一看的，毕竟规模上来了之后，才是真正考验架构的时候。

Promethus 本身对高可用方案的支持很弱，所以目前的各个方案都是某种场景下的权衡，没有什么比较完美的统一方案。跟其他分布式系统类似，我们说高可用，都要考虑一下几个问题:

* 高可用: 无单点故障
* 数据一致性
* 水平可扩展
* 数据持久化

优先级及精准性有不同的侧重点而已。

对于 Promethus 来说，因为主要是 Pull 模型，那么最简单的高可用方式就是部署多个实例，然后采集相同的数据:

![](/images/k8s/prom/prom-1.png)

缺点也很明显:
* 不满足数据一致性，多个实例可能抓到的数据不一致(细微差异)，还要考虑延迟问题
* 持久化问题: 都是本地存储，没有持久化
* 浪费资源，重复抓取数据

如果是小规模的监控规模来说，这种方式是可行的。因为监控本身就不是需要数据强一致性，偶尔down掉影响也不太大。

如果要考虑持久化：

![](/images/k8s/prom/prom-st.png)


可以通过增加一个远端存储来对接 promethus 实例。热数据存储在本地，冷数据同步到远程存储。对于大型集群来说，多个实例的 Pull 代价还是太大了。所以可以考虑用类似 k8s 的 controller 模式， 每个实例去不断尝试获取锁的方式来保证高可用:

![](/images/k8s/prom/prom-pv.png)

缺点就是要改代码，或许可以用独立进程来控制promethus实例的启停，不过还是比较麻烦。而且对于大型集群来说，一个 working 的实例压力还是太大了。


## Federation
Promethus 还提供了一种联邦方案，用于对数据进行分片:

![](/images/k8s/prom/prom-fed.png)

不同的 Promethus 实例负责不同的数据指标，最终有上层的实例进行数据汇总。具体怎么分，要看具体业务。比如上万个节点的监控数据，单个实例可能压力就比较大，可以按 hash 取模 + relabel 的方式进行均分。当然更常见的场景是按功能分区，每个实例抓取不同组件的指标。




## Push Mode


## Thanos



## Links
1. [使用 Thanos 实现 Prometheus 的高可用](https://cloud.tencent.com/developer/article/1645040)
2. [高可用Prometheus集群](https://www.cyningsun.com/09-13-2019/micro-service-monitor-prometheus-ha.html)
3. [prometheus学习4：多集群高可用](https://blog.csdn.net/login_sonata/article/details/89891844)
4. [详细教程丨使用Prometheus和Thanos进行高可用K8S监控](https://my.oschina.net/u/3330830/blog/4555843)

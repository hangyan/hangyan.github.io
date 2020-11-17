---
title: "etcd 的 clock diff 问题"
date: 2020-11-17T15:19:38+08:00
draft: false
categories: [Kubernetes]
tags: [debug, Kubernetes]
---

最近碰到一个客户问题，最初始的现象是一个resource的处理逻辑一直不生效，看 k8s apiserver 的日志如下:

![](/images/k8s/etcd/api-log-1.jpg)

这里面没有 call webhook 相关的日志。主要的错误有两类，一是超时，暂时不清楚为啥。另一类是 object conflict, 这个比较奇怪。因为一般 obejct conflict 不会这么普遍，而且一般 controller 都会对此种情况做特殊处理，会自动恢复。从这个日志中能看出来的问题不多，继续排查一下业务相关的 contrller看看线索:

![](/images/k8s/etcd/olm-log-1.jpg)

也是大量的 object conflict,非常异常的场景。而且还有一个 `invalid object`。到这只能怀疑是不是 etcd 出问题了，因为正常的 controller/apiserver 逻辑不太会触发这么多的此类错误。看 etcd 的日志:

![](/images/k8s/etcd/etcd-log-1.jpg)

大量的 `clock diff` 日志，日志意思应该是有一台节点的时间不同步。盲猜可能会导致数据存储的异常，修复时间问题后重启了 apiserver以及相应的 contorller 之后问题修复。看官方提到的 issue 里: [Is there any other side effects when the system clock differs on each node](https://github.com/etcd-io/etcd/issues/9768), 只说了会影响设置有 TTL 的 object，目前看起来影响远远大于这个。

这个问题的警示是，ETCD的作用太核心了，基于 Kubernetes 的容器平台在监控层面应该尽可能收集多的 etcd 的 metrics 信息，以供管理员决策和提供告警。如果日志不好收集，apiserver 的错误码应该也能提供不少信息。

另一方面，NTP等服务应该作为默认部署的组件，以确保 master 节点在进行调整，维护，扩容或者新增 master 节点的时候，保证时间同步。而不是一次性地校准一次就不管了。


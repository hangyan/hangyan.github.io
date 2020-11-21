---
title: "OpenKruise 简介"
date: 2020-11-21T10:51:37+08:00
draft: false
categories: [Kubernetes]
tags: [Kubernetes]
---

Kubernetes 作为一个 building blocks 来说，已经逐渐趋于稳定。大家对于其功能的增强，已经逐渐开始以 CRD + Controller Pattern 为主。另一方面，仍然有不少尝试是针对像 Deployment/StatefulSet/DaemonSet 这样的原始功能的。OpenKruise项目就是专注于此。原生的三种 Workload 能满足于日常的需求，但并不完善。在 OpenKruise 项目中，我们可以看到，多种 Workload 之间提供的功能是有很多共性的，我们可以提炼出他们的一些共同的功能模块, 比如:

* 分批升级
* 灰度更新
* 原地升级
* SideCar管理
* PVC管理
* Pod 固定名字
* ...

这些原子功能有些原生的 workload 已经具有，有些没有。OpenKruise项目通过将这些原子功能排列组合，提供了一些功能增强型的 workload.下面将一一介绍。

## SidecarSet
`SidecarSet` 定义了一些 sidecar 模板，然后通过 webhook 的方式注入到通过标签匹配的 Pod 中，这和 istio 等的方式比较像。它比较有用的地方在于，假设你希望给很多 Pod 注入一些通用的附加功能，比如 log, metrics或者init等功能，那么通过 SidecarSet 是一种比较好的方式。下面是一个 yaml 示例:

```yaml
# sidecarset.yaml
apiVersion: apps.kruise.io/v1alpha1
kind: SidecarSet
metadata:
  name: test-sidecarset
spec:
  selector:
    matchLabels:
      app: nginx
  strategy:
    rollingUpdate:
      maxUnavailable: 2
  containers:
  - name: sidecar1
    image: centos:6.7
    command: ["sleep", "999d"] # do nothing at all
    volumeMounts:
    - name: log-volume
      mountPath: /var/log
  volumes: # this field will be merged into pod.spec.volumes
  - name: log-volume
    emptyDir: {}
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: nginx # matches the SidecarSet's selector
  name: test-pod
spec:
  containers:
  - name: app
    image: nginx:1.15.1
```

这个示例给 `test-pod` 注入了一个 `sidecar1`, 同时也加入了一个 log-volume. 
另外，依据对 SidecarSet 不同字段的更新，相应的 Pod 有两种更新方式

* 更新 image: 被注入的 Pod 会被原地升级
* 更新其他字段： Pod 被重建时才会被更新


## Advanced StatefulSet

`Advanced StatefulSet` 是对普通的 StatefulSet 的一个功能增强，提供了如下功能:
* `MaxUnavailable` 策略: StatefulSet 的升级策略是 one-by-one, `MaxUnavailable` 提供了并行升级的策略。
* 原地升级: 如果更新的是镜像或者 metadata信息，那么可以支持原地升级
* 无序升级: 不按 order 的升级，而是按预定义的优先级

具体细节不再详述，可参考: [Advanced StatefulSet](https://openkruise.io/zh-cn/docs/advanced_statefulset.html)

## Advanced DaemonSet
`Advanced Daemonset` 是对 DaemonSet 的一个增强。提供了如下功能:

* 升级方式： DamonSet 的升级方式是先删除旧的再起新的，`Advanced DaemonSet` 提供了另一种方式，先起新的，再删旧的(参考Deployment的滚动升级)。也可以设置 `MaxSurge`.
* 灰度升级: 通过标签选择，只升级部分节点上的 Pod
* 分批灰度升级: 只更新部分数量的 Pod (参考 StatefulSet 的功能)

可以看到,通过从其他的 workload 借来的一些功能， DaemonSet 的适用范围被大大增强了。

更详细的信息可参考: [Advanced DaemonSet](https://openkruise.io/zh-cn/docs/advanced_daemonset.html)


## UnitedDeployment
`UnitedDeployment` 于 pod 的分布策略有关。这里先介绍下 Kubernetes 提供的 Pod 拓扑分布概念。AWS提供了像AZ这样的功能，其他的公有云和私有云也多多少少有类似的概念，当我们在部署 Pod 的时候，希望能将 Pod 均衡地部署到不同的AZ之中以保证可用性。如下图所示的集群结构:

![]()








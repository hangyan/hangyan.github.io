---
title: "CNI Notes: IPAM"
date: 2021-09-17T14:05:47+08:00
draft: false
categories: [CNI]
tags: [network, kubernetes]
---

CNI相关笔记，本文主要记录下 IPAM 功能相关。

CNI的职责包括给 Container 分配网络设备，并且分配IP. IPAM(IP Address Management)就是指IP分配相关的功能和规范。

CNI本身只是一个规范，不同的实现在 IPAM 方面的功能集也不尽相同。下面将首先尝试说明下不同 CNI在这块的实现。


## CNI实现


### Calico
calico开发的IPAM组件叫 `calico-ipam`, 它使用 calico 的 IP pool resource来管理 IP. 它的主要优势就是可以将 pool 分割成小的 block, 并且可以动态对分配给不同的 node. node 上的 ip 利用率会更高，并且可扩展性也很好。calico 目前也支持给不同的 namespace分配不同的 ip pool. 从大的方面来看，其实最终 各个CNI 实现要解决的问题都是类似的，一般区别只是 dataplane 以及具体的 CRD的设计不太一样。所以这些功能很可能(已经有了或者以后会有)出现在其他的 CNI 上面。

下面看一个实际的例子:

```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: external-pool
spec:
  cidr: 172.16.0.0/26
  blockSize: 29
  ipipMode: Always
  natOutgoing: true

---


apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: internal-pool
spec:
  cidr: 192.169.0.0/24
  blockSize: 29
  ipipMode: Always
  natOutgoing: true
```

这里面可以创建两个 IPPool, 并且可以通过给 NS 打 label 的方式，分配给不同的 NS.




### Host-local IPAM
`host-local` 算是比较简单的一个实现，可以根据静态文件配置来实现ip分配。flannel 默认用的就是 host-local ipam.
示例配置:

```yaml
{
  "name": "cni0",
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/24",
    "dataDir": "/var/lib/cni/networks"
  }
}
```


### Cilium

cilium 本身支持多种 ipam (calico也是，既支持calico-ipam, 也支持host-local)：

* cluster scope: 这种比较有意思的地方它用一个自定义的 Node 资源，`v2.CilumNode`来管理 CIDR. 虽然没有看到详细的文档说具体有什么特别的功能，但这样做的好处很明显: 自定义程度比较高，不再受限于官方的 `Node` 资源。相当于把这部分功能完全拿到 CNI 来控制了。

* CRD-backed: 提供了一个 CRD 来记录 ip 的使用。这样可以允许第三方的组件来管理 ip.



### Antrea
Antrea目前用的也是 host-local ipam. 在一些 host-local 不可用的场景下，它也支持在内部启用这块相关的 controller 代码来启用相同的功能。


## 总结
本文只是概要总结，涉及的并不深入。总体趋势是 CNI 实现会趋向于使用 plugin-in的架构，以便于支持多种IPAM机制。一般会包括 host-local, CRD based等等。从功能上来说，会有单个 Node 多个 IP Range的需求，以及不同 Namespace 使用不同 ip pool的需求。

## Links
1. [Calico: Get started with IP address management](https://docs.projectcalico.org/networking/get-started-ip-addresses)
2. [Calico IPAM: Explained and Enhance](https://www.tigera.io/blog/calico-ipam-explained-and-enhanced/)
3. [Cilium IPAM](https://docs.cilium.io/en/v1.8/concepts/networking/ipam/)
4. [How a Kubernetes Pod Gets an IP Address](https://ronaknathani.com/blog/2020/08/how-a-kubernetes-pod-gets-an-ip-address/)
5. [Kubernetes 1.12.0 Kube-controller-manager之node-ipam-controller源码阅读分析](https://blog.csdn.net/choucou19790207/article/details/101007315)
6. [Antrea NodeIPAMController](https://docs.google.com/document/d/1bXa7e6BdlzNN7ZnXekHAu1t6aZx911H8VsU6FYbf4DM/edit#)

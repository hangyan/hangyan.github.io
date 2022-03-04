---
title: "Cilium 的 Host Firewall 功能"
date: 2021-12-10T22:29:53+08:00
draft: false
categories: [eBPF]
tags: [cilium, eBPF]
---

Cilium CNI 之前一直看文档，功能大概了解，eBPF也大略看过。但一直没有深入从代码角度去研究。它的 bpf 相关代码做的比较全，而且比较老，跟现在网上的 BCC, CO-RW 还不太一样，而且代码量又大，所以读起来并不容易。这次借着 Host Firewall 功能的探究，深入看下。不可能面面俱到，但尽量多涉及一些。这篇文章在后面可能会继续更新，如果有新的发现的话。


## 一些基本概念

* `Endpoint`: 可以理解为跟 device 挂钩的概念(host, pod 等等)，还有特殊的 health endpoint等等。Endpoint有ID,也有对应的 Identity 和自己的 Policy. Endpoint 是 Node Scope 的概念。
* `Identity`: 跟 label 挂钩。同一个deploy的两个Pod, 有不同的endpoint,但有同样的 identity. K8s Node共用同样的 Identity. Cilium 的 NetworkPolicy 即是针对于 Identity的。这个很好理解，二者主要都是使用 label 来做 filter. 跟 Endpoint 不同， Identity 是 Cluster Scope 的概念(label当然跟node无关)。
* `KV Store`: 用来存储一些映射关系。Labels, Identity, Address, Node等这些元素之间的各种映射关系。Cilium 要实现 NetworkPolicy, 那么就需要这些映射关系。比如 Address -> Identity 等等。

不同的 CNI 在架构方面的差别还是挺大的。比如 KV Store 的需求，有的 CNI 就完全不需要。对 Cilium 来说，当有新的 NetworkPolicy时, agent 来计算 NetworkPolicy,如果发现自己所在的 Node 上有 Endpoint 受影响，那么就需要对此 Endpoint 做一些 Update (Regenerate BPF Programs等等)，其他的 Node 则不需要。不同的 agent 则依赖于 KV Store 来互相交换一些数据。
引用一篇架构图所示:

![](https://arthurchiao.art/assets/img/cilium-code-cni/client-scaleup-cnp.png)
(图片来自于: https://arthurchiao.art)


Cilium 选择使用 Identity 跟它的架构有关。因为使用 agent 来计算 NetworkPolicy. 如果没有 Identity, 那么每次新增加一个 Pod, 所有的 Pod 都需要计算一下 Policy. Identity 是基于 Labels, 相同的 Labels 的 Pod(比如一个 Workload 下的)共享一个 Identity, 那么在很多新增 Pod 的场景下 Policy 没有变更，减少了 agent 的工作量。那么如果从 Identity 获取 Pod 的 address 呢？就要用到上面所说的 KVStore.。所以上面图中的每个 Node 都需要 watch kvstore 中的数据。


## Host Firewall 是什么

K8s 的 Network Policy 以及各个 CNI 的 Network Policy, 主要都是针对于 Pod/Service/Remote 的，最开始都不涉及到 Host相关的。我理解一般这块都有现成的其他工具在做。但将其纳入 NetworkPolicy 之内，也是自然发展趋势。这样方便用户。我们看一个 Cilium NetworkPolicy 的例子:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: "demo-host-policy"
spec:
  description: ""
  nodeSelector:
    matchLabels:
      node-access: ssh
  ingress:
  - fromEntities:
    - cluster
  - toPorts:
    - ports:
      - port: "22"
        protocol: TCP
```

`nodeSelector` 即指定了此 Policy 所涉及到的 Node. 其他部分跟一般的 Pod NetworkPolicy 差别并不大。其他的 `fromEntities` 字段没考证过是否是 Host Policy 所独有，其取值取值范围如下:

* cluster: 当前集群的所有 Endpoint (Endpoint的概念需另外细讲)
* host: local host 以及当前 host 上所有使用 host network 的 pod
* remote-node: cluster 减去 host 的内容
* health: cilium 管理的 health endpoint
* ...

可以看到，其 target 是针对 `Endpoint` 这个概念的。Endpoint 可以理解包含了 Pod, Host, 以及一些特殊的 Endpoint 的概念。我们可以通过下面的 Output 看下。这是一个 2 Nodes 的 Cilium 集群:

```bash
# exec it in worker node's cilium pod:
# cilium endpoint list

ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                                                  IPv6   IPv4         STATUS
           ENFORCEMENT        ENFORCEMENT
456        Disabled           Disabled          4          reserved:health                                                                     10.0.0.68    ready
972        Disabled           Disabled          63615      k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name=kube-system          10.0.0.69    ready
                                                           k8s:io.cilium.k8s.policy.cluster=default
                                                           k8s:io.cilium.k8s.policy.serviceaccount=coredns
                                                           k8s:io.kubernetes.pod.namespace=kube-system
                                                           k8s:k8s-app=kube-dns
1307       Disabled           Disabled          63615      k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name=kube-system          10.0.0.135   ready
                                                           k8s:io.cilium.k8s.policy.cluster=default
                                                           k8s:io.cilium.k8s.policy.serviceaccount=coredns
                                                           k8s:io.kubernetes.pod.namespace=kube-system
                                                           k8s:k8s-app=kube-dns
1723       Disabled           Disabled          1380       k8s:io.cilium.k8s.namespace.labels.kubernetes.io/metadata.name=default              10.0.0.220   ready
                                                           k8s:io.cilium.k8s.policy.cluster=default
                                                           k8s:io.cilium.k8s.policy.serviceaccount=default
                                                           k8s:io.kubernetes.pod.namespace=default
                                                           k8s:run=nginx
3015       Disabled           Disabled          1          reserved:host                                                                                    ready
```

这是 Worker Node 上的输出，可以看到如下内容:

1. 包含了Pod,Host,Health. 其中Host,Health都是reserverd的label
2. 每个 Endpoint 都有一个 ID, 并且都有一个 ID. 这个 ID 如其名，在很多地方用来做 Policy 决策。

Master Node 上的数据如下:


```yaml
# exec it on master node's cilium pod

ENDPOINT   POLICY (ingress)   POLICY (egress)   IDENTITY   LABELS (source:key[=value])                                   IPv6   IPv4         STATUS
           ENFORCEMENT        ENFORCEMENT
386        Disabled (Audit)   Disabled          1          k8s:node-access=ssh                                                               ready
                                                           k8s:node-role.kubernetes.io/control-plane
                                                           k8s:node-role.kubernetes.io/master
                                                           k8s:node.kubernetes.io/exclude-from-external-load-balancers
                                                           reserved:host
565        Disabled           Disabled          4          reserved:health                                                      10.0.1.230   ready
```


Master Node 上一般没有 Workload, 所以只有 health 和 node 两个 Endpoint.

Cilium 主要通过 TC bpf 来实现其 datapath, 我们可以在 host 上的 device 里看到 tc bpf prog list:

```bash
# cmd: tc filter show dev eth0 ingress
filter protocol all pref 1 bpf chain 0
filter protocol all pref 1 bpf chain 0 handle 0x1 bpf_netdev_eth0.o:[from-netdev] direct-action not_in_hw id 510 tag ec099af6e42d92d6 jited
```

`from-netdev` 就是这个 bpf object 的 entrypoint. 实现 Host Firewall 这个功能，对 Cilium 来说，相当于只是在 Policy 决断的时候加了一些规则，整体的 datapth 还是不变的。下面将对 golang code 以及 bpf code 做一个简要的 walkthrough.


## Golang 相关代码
注： 参考的代码版本为 v1.11

Golang 部分的代码会比 BPF 相关的代码多很多，此处尽量挑最相关的说。真正在阅读此类代码时，结合着 DEBUG LOG 是比较好的策略。我们的场景是：Add NetworkPolicy, 这部分最开始的处理跟其他的 Operator 方式一样，Controller Watch CRD + Handler.


### policyAdd
File: `daemon/cmd/policy.go`

Cilium 中大量地用到了 EventQueue. Add NetworkPolicy 的事件，最终在 `RepositoryChangeQueue` 里增加了一个 Event, 并且交由 `policyAdd` 处理。其工作如下:
* 处理 CIDR 相关的 Rule. 本例中没有用到
* 根据 Rules 选出需要 Update 的 Endpoint.代码中一般叫 Regeneration (其中涉及到重新生成 eBPF 程序).

选出相应的 Endpoints 之后，生成另一个 Event 中，并 Push 到 RuleReactionQueue 中。


### reactToRuleUpdates
File: `daemon/cmd/policy.go`

此函数便是 RuleReactionQueue 的最终 Handler.  主要任务就是 Regenerat 相关的 Endpoint. 方法仍然是通过 EventQueue.


### EndpointRegenerationEvent.Handle

File: `pkg/endpoint/events.go`

regenerate endpoint. 涉及到一些本地文件操作(`/var/run/cilium`),生成新的 BPF Program 并 attch 上去。这部分涵盖的内容很多，最好结合DEBUG日志看下，此处不再细说。







## 相关 BPF 代码

注: 参考的代码版本为 v1.11. 比较短的函数就直接全贴出来了。

### from-netdev

入口即是 `from-net-dev`:


```c
//  FIle: bpf/bpf_host.c
/*
 * from-netdev is attached as a tc ingress filter to one or more physical devices
 * managed by Cilium (e.g., eth0). This program is only attached when:
 * - the host firewall is enabled, or
 * - BPF NodePort is enabled
 */
__section("from-netdev")
int from_netdev(struct __ctx_buff *ctx)
{
	__u32 __maybe_unused vlan_id;

	/* Filter allowed vlan id's and pass them back to kernel.
	 */
	if (ctx->vlan_present) {
		vlan_id = ctx->vlan_tci & 0xfff;
		if (vlan_id) {
			if (allow_vlan(ctx->ifindex, vlan_id))
				return CTX_ACT_OK;
			else
				return send_drop_notify_error(ctx, 0, DROP_VLAN_FILTERED,
							      CTX_ACT_DROP, METRIC_INGRESS);
		}
	}

	return handle_netdev(ctx, false);
}
```

注释里解释的比较清楚，这个只应用于 TC 的 Ingress. 开启条件是 Host Firewall 功能或者 NodePort 功能打开。本例中打开了 Host Firewall 功能。所以能看到上面的 bpf object.

### handle_netdev
```c
/**
 * handle_netdev
 * @ctx		The packet context for this program
 * @from_host	True if the packet is from the local host
 *
 * Handle netdev traffic coming towards the Cilium-managed network.
 */
static __always_inline int
handle_netdev(struct __ctx_buff *ctx, const bool from_host)
{
	__u16 proto;

	if (!validate_ethertype(ctx, &proto)) {
#ifdef ENABLE_HOST_FIREWALL
		int ret = DROP_UNSUPPORTED_L2;

		return send_drop_notify(ctx, SECLABEL, WORLD_ID, 0, ret,
					CTX_ACT_DROP, METRIC_EGRESS);
#else
		send_trace_notify(ctx, TRACE_TO_STACK, HOST_ID, 0, 0, 0,
				  REASON_FORWARDED, 0);
		/* Pass unknown traffic to the stack */
		return CTX_ACT_OK;
#endif /* ENABLE_HOST_FIREWALL */
	}

	return do_netdev(ctx, proto, from_host);
}
```

这里主要的代码是处理ethertype不合法的情况，如果开启了 audit 之类的功能的话可以上报一些事件。我们假定 ethertype 合法，跳过这部分。这里也获取了 proto (v4,v6)的值。


### do_netdev

`do_netdev` 比较长，部分原因是需要根据上层的 feature gate 来定义 marco (bpf程序里很常见)。其中包括了是否开启 IPSEC, IPV6等等功能以及相应的处理代码。这里我们简单起见，只看 IPV4 及 HOST_FIREWALL 相关的情况:

```c
#ifdef ENABLE_IPV4
	case bpf_htons(ETH_P_IP):
		identity = resolve_srcid_ipv4(ctx, identity, &ipcache_srcid,
					      from_host);
		ctx_store_meta(ctx, CB_SRC_IDENTITY, identity);
		if (from_host) {
# if defined(ENABLE_HOST_FIREWALL) && !defined(ENABLE_MASQUERADE)
			/* If we don't rely on BPF-based masquerading, we need
			 * to pass the srcid from ipcache to host firewall. See
			 * comment in ipv4_host_policy_egress() for details.
			 */
			ctx_store_meta(ctx, CB_IPCACHE_SRC_LABEL, ipcache_srcid);
# endif
			ep_tail_call(ctx, CILIUM_CALL_IPV4_FROM_HOST);
		} else {
			ep_tail_call(ctx, CILIUM_CALL_IPV4_FROM_LXC);
		}
		/* We are not returning an error here to always allow traffic to
		 * the stack in case maps have become unavailable.
		 *
		 * Note: Since drop notification requires a tail call as well,
		 * this notification is unlikely to succeed.
		 */
		return send_drop_notify_error(ctx, identity, DROP_MISSED_TAIL_CALL,
					      CTX_ACT_OK, METRIC_INGRESS);
#endif
```

这里面需要关注的是：
1. 取出了 Identity, 这个在上面的 Endpoint 里提到。具体涉及到的逻辑比较多，有机会再细说。
2. 通过 eBPF 的 tail call 继续往下走。


### tail_handle_ipv4

tail call 调用了此函数。然后继续走到 `handle_ipv4`

```c
static __always_inline int
tail_handle_ipv4(struct __ctx_buff *ctx, __u32 ipcache_srcid, const bool from_host)
{
	__u32 proxy_identity = ctx_load_meta(ctx, CB_SRC_IDENTITY);
	int ret;

	ctx_store_meta(ctx, CB_SRC_IDENTITY, 0);

	ret = handle_ipv4(ctx, proxy_identity, ipcache_srcid, from_host);
	if (IS_ERR(ret))
		return send_drop_notify_error(ctx, proxy_identity,
					      ret, CTX_ACT_DROP, METRIC_INGRESS);
	return ret;
}
```

### handle_ipv4
比较长，截取相关部分

```c
#ifdef ENABLE_HOST_FIREWALL
	if (from_host) {
		/* We're on the egress path of cilium_host. */
		ret = ipv4_host_policy_egress(ctx, secctx, ipcache_srcid, &monitor);
		if (IS_ERR(ret))
			return ret;
	} else if (!ctx_skip_host_fw(ctx)) {
		/* We're on the ingress path of the native device. */
		ret = ipv4_host_policy_ingress(ctx, &remote_id);
		if (IS_ERR(ret))
			return ret;
	}
#endif /* ENABLE_HOST_FIREWALL */
```
后面就是实际计算 Policy 的地方了。




## Links
1. [https://docs.cilium.io/en/v1.9/gettingstarted/host-firewall/](https://docs.cilium.io/en/v1.9/gettingstarted/host-firewall/)
2. [Layer 3 Examples](https://docs.cilium.io/en/v1.9/policy/language/#labels-based)
3. [Cilium Code Walk Through: Agent Start](https://arthurchiao.art/blog/cilium-codee-agent-start/)
4. [Cilium PR: Network policies for the host endpoint](https://github.com/cilium/cilium/pull/11507)
5. [Endpoint Lifecycle](https://docs.cilium.io/en/stable/policy/lifecycle/)
6. [Cilium Code Walk Through: Cilium Operator](https://arthurchiao.art/blog/cilium-code-cilium-operator/)
7. [Cilium Code Walk Through: Restore Endpoints and Identities](https://arthurchiao.art/blog/cilium-code-restore-endpoints/)
8. [Cilium Code Walk Through: CNI Create Network](https://arthurchiao.art/blog/cilium-code-cni-create-network/#4-create-endpoint)


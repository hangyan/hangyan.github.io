---
title: "LB系列1 - Bandaid"
date: 2021-01-18T13:33:12+08:00
draft: false
categories: [Network]
tags: [LB,Network]
---

很多大厂的LB都是自研的，而且设计考量都不相同。本文介绍 Dropbox自研的LB，名字叫 Bandaid.参考链接: [Meet Bandaid, the Dropbox service proxy](https://dropbox.tech/infrastructure/meet-bandaid-the-dropbox-service-proxy).

## Queue设计

![](https://dropbox.tech/cms/content/dam/dropbox/tech-blog/en-us/2018/03/1st.png)



Bandaid 处理 Queue 中的 Request 的思路是后近先出(Last in, First out)。当系统负载不高的时候，Queue中的数据其实不多，那么先进后出或者后进先出其实区别不大。如果负载过高，考虑到先进的排队太久，可能很快就timeout了，还不如优先处理后进来的 request. 



## User Space的 Read Queue

Read Requests 会被放到一个用户态的 Queue 中，而不是 kernel 里的 queue中。这样做的原因是， 可以在用户态提前关闭已经被 client close的 request, 而不是等到真正的request经由 kernel, 然后 application 在处理的时候才发现 request 已经 close 了。尤其是 client 一般还带有重试，很容易把 Kernel queue打满。User Space 的 Queue 能够通过处理只把正常的 request 传给后面。

![](https://dropbox.tech/cms/content/dam/dropbox/tech-blog/en-us/2018/03/2nd.png)



## 权重以及 Route划分

![](https://dropbox.tech/cms/content/dam/dropbox/tech-blog/en-us/2018/03/4th.png)



精细程度可以做到按照 Route 将一个 Service 的重要的 Route 以及不重要的 Route 按权重定向到不同的 Backend上。不同的 Queue 可以有不同的权重，rate limit, 并发度。






---
title: 失败博物馆 - Jenkins
toc: true
categories: [产品]
date: 2019-08-22 17:02:37
excerpt: ...
tags: [Jenkins,CI/CD,架构]
---

我想记录一下工作中使用过的软件里的一些在设计上比较失败的。因为它们，工作中多了很多痛苦。

Jenkins 便是其中之一。跟很多软件一样，Jenkins 在商业上是成功的，成功的原因就是用户并没有什么选择。对 Jenkins 非常了解的人来说，能很容易列举出非常多的详细的jenkins 的问题。从一个普通使用者的角度来看，最直观的两个感觉就是: Jenkinsfile 难写，流水线很慢。

对我来讲，Jenkinsfile 就是最大的设计败笔。从工作中的反馈来看，即使看了文档，也没人知道怎么去写一个正确的 Jenkinsfile。用户想描述好一些流水线步骤，最直观的想法应该就是贴近于 Makefile, 每个步骤几条命令，清清楚楚。再加上其他一些并发控制，产出物管理即可。用 YAML 或者 TOML 这样的配置文件即可。

几乎除了 Jenkins 之外的所有 CI/CD 工具，都选择了 用YAML。而 Jenkins 使用了 Jenkinsfile, Groovy 语言，意味着用户需要首先了解 Groovy，在学习 jenkins的语法，才能写好 Jenkinsfile。一些自作聪明的开发人员在类似的设计问题时，会有一种炫技的想法，总想用 DSL 来解决问题。结果通常是不好的，既给用户带来了沉重的负担，也让系统变得难以理解。基于 JVM 的很多语言都是如此命运。

即使你费劲千辛万苦，终于写出了一个能跑通的 Jenkinsfile,这时候你会发现，在 Jenkins 的流水线里面，有很多复杂的难以理解的东西。为什么多出来很多莫名其妙的步骤？系统日志和构建日志怎么这么杂乱无章地堆在一块？为什么速度总是这么慢？界面为什么这么丑？不一而足。

想深刻地理解这些问题在哪，当然可以去好好探究一下它的架构，然后了解这些问题的根源。但这是在没有必要了，对于一个将死的系统来说。作为用户来讲，在已经有了替代品之后，赶快逃离就是了。








---
title: "Hugo 的优点"
date: 2020-09-12T12:30:28+08:00
draft: false
tags: [产品,互联网]
categories: [产品]
---

经历了 N 次在各个不同的环境里初始化 Hexo 的环境失败之后，我终于换了 Hugo.

从 Jekyll -> Hexo -> Hugo 我算是发现了，依赖不好处理的平台根本不适合做 static blog generator.想在一个新的环境里部署好一个这样的软件，而且你又没有这个语言的比较多的经验的时候，大量的时间会被浪费在配置环境上。这时候，像 hugo 这样的 static binary 就是一个 killer feature, 我根本不用看它有什么优缺点，就直接切换过来了。

事实上也是，从互联网的内容检索上来看，大部分的迁移路线基本上就是 Jekyll,Hexo -> Hugo, 基本上没有反着来的。 先不说 Golang 语言设计的怎么样，但说能如此方便地 build 出来一个 cross-platform 的 static binary, 简直是造福程序员。

曾经，我以为 Hexo 的 theme 与 content 分离已经很优秀了。没想到它还是个垃圾。

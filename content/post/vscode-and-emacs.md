---
title: "VScode 和 Emacs"
date: 2020-09-27T12:28:55+08:00
draft: true
tags: [Emacs, Vscode]
categories: [产品]
---

除了 Emacs 和 Vim 之外的 Editor 战争，现在看起来 Vscode 已经赢了。

先不说现存的一些 Editor 的现状和对比，我们直接猜想一下一个比较完美的 editor 应该是什么样子的

1. modern look. 就是好看，让人想用.
2. 易上手: 不需要学太多才能才能用好
3. 易扩展: 就是 plugin 多到满足常用需求
4. 跨平台，方便配置

这几点就差不多了，能做到这几点基本上就能做到广受欢迎了。下面一个一个细拆开讲讲.

## Modern Look
这点最成功的案例就是 JetBrains 的一系列产品，单是其 `Darcula  theme` 就让多少人愿意试一试。Atom 和 Vscode, LightTable， Sublime 做的也都不错， Vim 和 Emacs 做的不行，太古老了。虽然可以配置好的好看，但默认配置太劝退了。

## 易上手
这点 vim 和 Emacs 还是做的最差，虽然最终效率最高，但学习曲线太漫长了。VsCode 和 Atom 比较像，做的都不错。


## 易扩展
但从扩展性上来讲，Atom/VsCode/Vim/Emacs都差不多，该有的插件都有，安装也不难。不过前两个明显使用起来更方便些，是真正的`易`扩展,直接在 UI上就可以点点安装 plugin。也有方便的介绍和使用说明。LightTable 插件太少，半死不活的。Sublime 插件也不算多。

## 跨平台
跨平台的能力不难做，前面提到的几个都能做到。难的是尽量保证一致性的体验和性能。这里面 VsCode 做的最好， Atom 是在哪个平台性能都不咋样.Emacs在Linux下性能最好，Mac下 UI 效果一般, Windows 下配置着更麻烦。Vim 主要是 Terminal 领域了。

综合来看，VsCode 还是当之无愧的最受欢迎的 Editor, 每个方面都做的不错。Atom 算是因为性能等原因被击败。LightTable 差不多死了， Sublime 也是被老大老二打架的时候弄死了(自己还收费), Vim 和 Emacs 比较特殊，因为本身历史比较久，不可替代性比较强，属于不在一个竞争层面上的。因为但从 Editor 的设计来讲，VsCode 之类的根本没法和 Vim/Emacs 比，前者是属于产品层面的胜利，不是属于技术方面的胜利。

Emacs 比较特殊一点，我自己一直在用。社区最近也一直在讨论如何让其现代化一点，能吸引到更多用户，其中的策略就是内置一个比较好的 Theme, 多加一些 intro 或者 默认比较好的配置之类的，不出上面提到的几个关键点。这点本身也算是 Emacs 被开源社区的模式坑了，Fork 的版本在那瞎改不往回 contribute, 一部分人不希望改变 Emacs 的现状等等。但 Emacs 的存在的一个很重要的意义仍然在于告诉我们 ,VsCode 仍然是有巨大缺陷的产品，我们离最终的完美的 Editor 还差的很远。后面肯定会有更优秀的产品出现。不只好用，还厉害。







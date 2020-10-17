---
title: "Semantic Web"
date: 2020-10-17T11:56:20+08:00
draft: false
categories: [互联网]
tags: [知识图谱]
toc: false
---

最近开始关注`Semantic Web`的原因是`Abstract Wikipedia`项目的发展．作为一个很老的互联网课题，大家的愿景都是很清楚的：想要一个语义更加清晰，更方便机器处理的互联网，然后构建一个真正的`互联网`．但是市场的行为总是与技术理想有很大偏差，想要用后期的技术来补救，其成功的概率是很低的．`Abstract Wikipedia` 的让人期待的地方在于，它成功的可能性更高，带来的改善也可能不止局限于`Wikipedia`.

先说什么是 `Abstract Wikipedia`, 首先目前维基百科的内容结构大家基本上也都了解:不同语言分别维护，体量差异巨大．从一个程序设计的结构来讲，这种模式是很糟糕的，因为它抽象的程度太低，大量的内容无法复用，造成的 interface 对很多用户不友好: 不同语言内容差别大，同步不及时，维护工作繁重等等．之前的低地苏格兰语被一个美国小哥`勤奋`地填充了大量的错误内容就是一例．

如何解决? 按程序设计的思路来看，需要分清`数据`和`算法`两部分，数据是什么，是语言无关的抽象知识，用抽象符号来表述知识．算法是什么？怎么来组织这些数据，让他们构成合理的语句．最后可能再需要一个`Render`层，将结果最终呈现给用户．这基本上就是一个`MVC`结构了．

`Abstract Wikipedia`就是想做这个事情.数据部分，由`wikidata`维护，大致如下所示的模式:
![](https://en.wikipedia.org/wiki/File:Datamodel_in_Wikidata.svg)
可以打开这个[Hawaii State Public Library System](https://www.wikidata.org/wiki/Q5684409)的链接看下实际的数据是什么样子的．这部分的内容跟`RDF`的结构很像,可以预见的是，以后`wikidata`的内容越来越多，也能促进`Semantic Web`本身的发展．

算法部分，由`wikilambda`维护，这部分暂时还没有现成的实现，但是已经有初步的概要设计．一个完整的示例如下:
假设原始语句为:
```bash
San Francisco is the cultural, commercial, and financial center of Northern California. It is the fourth-most populous
city in California, after Los Angeles, San Diego and San Jose
```
我们想把这个语句专为通用的结构化内容,那么数据部分如下:
![](/images/posts/semantic-web/data.png)
(这部分数据完全可以用 RDF 表示出来)
注意上面的 `Q62`等，就代表着它们目前在`wikidata`中的链接.有了这些数据，那么我们可以通过一个简单的函数把它们拼接成一句英语:
![](/images/posts/semantic-web/func.png)
这是个比较简单的示例，真实的情况肯定会比目前复杂一些．但是理论上都可以通过更丰富的数据和算法来组合出所有目前常用的句式．

对维基百科来说，这是一条看起来很有希望的路．期待的场景是人类的大部分的知识，都能通过这样的方式，以不同的语言展示给读者．当然，也不会局限于此．稍微展望一下，我们就可以发现它带来的变革几乎是无限的．我们能用它来做各种各样的事:
1. 知识图谱．有了维基百科的数据，我们可以更方便地构建各种知识图谱
2. `wikidata`和`wikilambda`的内容可以以各种方式直接给其他系统集成，提供各种编程语言的 binding.
3. 机器学习系统以及学术界可以利用维基百科的内容做各种数据研究
4. ....

期望这个美好的愿景能实现吧．






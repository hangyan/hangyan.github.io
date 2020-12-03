---
title: "算法笔记(1): 链表及其应用"
date: 2020-12-03T16:27:39+08:00
draft: false
categories: [算法]
tags: [linked-list]
---

最近准备系统的过一遍算法。一是因为看的很多项目最终多多少少都会涉及到算法，如果提前了解好会理解的更深入。二是之前也没有系统的看过，最近想定一个比较长久的学习计划。看文章的话网上质量参差不齐，有些东西只能这样弄，自己花时间慢慢找，总结，记录。算法这类前两天想看 LevelDB, 然后又得先看 LSM Tree, 然后发现还是得看红黑树。然后在网上找，发现文章一大堆，但写的都不行。我觉得想要了解红黑树的基本上肯定都会有一个疑惑“为啥要两种颜色”，可惜基本上没几篇文章能把这个东西讲清楚，知其然而不知其所以然。所以最终决定第一次在网上买了一个电子课，因为发现能讲的清楚的一篇文章是从这门课里摘录的。

所以后面会尝试更新一个持续的算法系列，笔记性质的。记录一些感兴趣的点。然后才是其他的一些感兴趣的项目和技术。本身作为第一篇，跳过了一些更基础的，直接从链表开始了。

链表本身也比较简单，基本原理都清楚。我觉得从应用层来看更有意思一点。主要就是两个

* 约瑟夫问题
* LRU等算法

## 约瑟夫问题

**阿橋问题**（有时也称为**约瑟夫斯置换**），是一个出现在[计算机科学](https://zh.wikipedia.org/wiki/计算机科学)和[数学](https://zh.wikipedia.org/wiki/数学)中的问题。在计算机[编程](https://zh.wikipedia.org/wiki/编程)的算法中，类似问题又称为**约瑟夫环**。

人们站在一个等待被处决的圈子里。 计数从圆圈中的指定点开始，并沿指定方向围绕圆圈进行。 在跳过指定数量的人之后，处刑下一个人。 对剩下的人重复该过程，从下一个人开始，朝同一方向跳过相同数量的人，直到只剩下一个人，并被释放。 

问题即，给定人数、起点、方向和要跳过的数字，选择初始圆圈中的位置以避免被处决。

或者更加数学的问法: 已知 n 个人（以编号1，2，3…n分别表示）围坐在一张圆桌周围。从编号为 k 的人开始报数，数到 m 的那个人出圈；他的下一个人又从 1 开始报数，数到 m 的那个人又出圈；依此规律重复下去，直到剩余最后一个胜利者。

这个问题可能是与单项循环链表最贴近的一个问题模型了。每个人都是一个节点，然后出局的人可以用操作指针的方法将其从链表中移除即可，最后剩下一个人的时候就是答案。下面是C代码



```c
#include <stdio.h>
#include <stdlib.h>

/*声明一个链表节点*/
typedef struct node  
{
    int number;//数据域，存储编号数值
    struct node *next;//指针域，指向下一个节点
}Node;

/*创建链表节点的函数*/ 
Node* CreatNode(int x) 
{
    Node *p;
    p = (Node*)malloc(sizeof(Node));
    p->number = x;//将链表节点的数据域赋值为编号
    p->next = NULL;
    return p;
}

/*创建环形链表，存放整数1到n*/
Node* CreatJoseph(int n) 
{
    Node *head,*p,*q;
    int i;
    for(i = 1;  i <= n; i++)
    {
        p = CreatNode(i);//创建链表节点，并完成赋值
        if(i == 1)//如果是头结点
            head = p;
        else//不是头结点，则指向下一个节点
            q->next = p;
            q = p;
    }
    q->next = head;//末尾节点指向头结点，构成循环链表
    return head;
}

/*模拟运行约瑟夫环，每数到一个数，将它从环形链表中删除，并打印出来*/
void RunJoseph(int n,int m) 
{
    Node *p,*q;
    p = CreatJoseph(n);//创建循环链表形式的约瑟夫环
    int i;
    while(p->next != p)//循环条件，当前链表数目大于1
    {
        for(i = 1; i < m-1; i++)//开始计数
        {
            p = p->next;
        }
        //第m个人出圈
        q = p->next;
        p->next = q->next;
        p = p->next;
        printf("%d--",q->number);//输出出圈的序号
        free(q);
    }
    printf("n最后剩下的数为：%dn",p->number);
}

int main()
{
    int n,m;
    scanf("%d %d",&n,&m);
    RunJoseph(n,m);
    return 0;
}
```

## LRU算法

不考虑各种优化算法的话，LRU场景本身也是很适合用来链表实现。需求描述如下:

1. 如果此数据之前已经在缓存中，需要找到它，并且把它挪到表头
2. 如果数据尚不在缓存中
   1. 缓存未满，直接插入表头即可
   2. 缓存已满，将表尾节点删除，将新数据插入表头

当然如果基于单向链表来实现的话，访问的时间复杂度都是O(n)。不过本文暂不涉及优化方式，后续再说。下面是一个示例的 go 实现



```go
package main

import "fmt"

// LRU缓存淘汰策略的demo

// 这是一个单向链表的节点
type Node struct {
	Next *Node
	Value interface{}
}


// 缓存模型
type Memory struct {
	Head *Node // 头节点
	Max int32 // 链表的最大长度
}

// 向内存中插入变量的指针，若链表为空，则插入头节点
func (m *Memory) Insert(newNode interface{})  {
	if m.Head == nil {
		m.Head = &Node {
			Next: nil,
			Value: newNode,
		}
	        return
	}

	var pre *Node // 前节点的指针
	current := m.Head // 当前节点位置
	var i int32 = 1 // 计数，第一个节点

	n := &Node {
		Next: m.Head,
		Value: newNode,
	}

	for {
		// 若该记录在内存中存在，则将其在链表相应位置删除，并插入链表的头部，若已在头部，则不变
		if current.Value == newNode {
			if pre != nil {
				pre.Next = current.Next
				m.Head = n
			}
			break
		}

		// 若当前节点是尾节点，则将变量指针插入链表头部，若长度超出了链表长度，则将链表最后一个节点删除
		if current.Next == nil {
			if i >= m.Max {
				pre.Next = nil
				m.Head = n
			} else {
				m.Head = n
			}
			break
		}

		pre = current
		current = current.Next
		i++
	}
}

func main()  {
	 m := &Memory{
	 	Max: 10,
	 }
	 for i := 0; i <= 11; i ++ {
	 	v := i
		m.Insert(&v)
	 	fmt.Printf("==========\n")
	 	fmt.Printf("head is %+v\n", m.Head)
	 	fmt.Printf("head value is %v\n", *m.Head.Value.(*int))
	 	fmt.Printf("==========\n")
	 }
}
```



## Links

1. [算法科普：什么是约瑟夫环](https://www.cxyxiaowu.com/1159.html)
2. [Go基于单向链表实现LRU缓存淘汰算法](https://juejin.cn/post/6844904106046259213)




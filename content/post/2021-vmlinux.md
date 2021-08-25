---
title: "如何生成 vmlinux.h"
date: 2021-08-25T13:28:21+08:00
draft: false
categories: [eBPF]
tags: [Linux]
---

eBPF 的一些开发方案里涉及到 vmlinux.h, 它包含了kernel里所有用到的data structure等等。有了它可以方便地替代其他一大堆杂七杂八的头文件。网上基本上都提到了如何用 `vmlinux` 来生成 `vmlinux.h`, 但最开始的
`vmlinux` 怎么来的并没有找到比较明确的文档。本来将提供一个比较全面的如何生成 `vmlinux.h` 的文档. 


## 环境说明

* OS: ubuntu 20.04.1
* Kernel: 5.4.0-70


## 安装 vmlinux

需要添加 ddeb 的源

```bash
echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
echo -e "deb http://ddebs.ubuntu.com $(lsb_release -cs)-updates main restricted universe multiverse\ndeb http://ddebs.ubuntu.com $(lsb_release -cs)-proposed main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/ddebs.list
```

repo key相关的 

```bash
sudo apt install ubuntu-dbgsym-keyring
```

安装

```bash
apt-get update
sudo apt-get install linux-image-$(uname -r)-dbgsym
```

最后安装好的文件在 `/usr/lib/debug/boot/` 目录下。

注意 `/boot` 下面有类似的文件，但那是压缩过的，不能直接用。所以最好还是按上述方法直接下载。


## 安装 bpftool

bpftool 需要从 kernel source code里生成,或者直接从repo里安装.

```bash
# 自己 download 相应version的kernel或者用git仓库
cd linu
cd tools/bpf/bpftool/
make install
```


如果从 repo 里安装

```bash
apt install linux-tools-common
```

## 生成 vmlinux.h

可能是我从source里build出来的bpftool有问题，这一步只是用repo里安装的bpftool成功了

```bash
bpftool btf dump file <vmlinux-path> format c > vmlinux.h
```

libbpf提供了一些功能，可以保证vmlinux.h在不同kernel version之间的兼容性.








## Links

1. [DebuggingProgramCrash](https://wiki.ubuntu.com/DebuggingProgramCrash#Non-built-in_debug_symbol_packages_.28.2A-dbgsym.29)
2. [Where is vmlinux on my Ubuntu installation?](https://superuser.com/questions/62575/where-is-vmlinux-on-my-ubuntu-installation)

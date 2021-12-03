---
title: "eBPF 的安全性问题"
date: 2021-12-03T16:39:17+08:00
draft: true
categories: []
tags: []
---

在考虑引入 eBPF 之前，安全性是一个必须要考虑的问题，毕竟是一些在 kernel 中执行的代码。虽然说 verifier 已经做了很多的检查，但一旦它有 bug 或者功能不完善，那么就有可能引入安全问题。在网上查了一圈，发现相关的讨论还不多，但是已经有一些 CVE 在了。这里想大概总结下看看有哪些地方容易出CVE.


## CVE-2021-3490

> The eBPF ALU32 bounds tracking for bitwise ops (AND, OR and XOR) in the Linux kernel did not properly update 32-bit bounds, which could be turned into out of bounds reads and writes in the Linux kernel and therefore, arbitrary code execution. This issue was fixed via commit 049c4e13714e ("bpf: Fix alu32 const subreg bound tracking on bitwise operations") (v5.13-rc4) and backported to the stable kernels in v5.12.4, v5.11.21, and v5.10.37. The AND/OR issues were introduced by commit 3f50f132d840 ("bpf: Verifier, do explicit ALU32 bounds tracking") (5.7-rc1) and the XOR variant was introduced by 2921c90d4718 ("bpf:Fix a verifier failure with xor") ( 5.10-rc1). 


## CVE-2021-31440

> This vulnerability allows local attackers to escalate privileges on affected installations of Linux Kernel 5.11.15. An attacker must first obtain the ability to execute low-privileged code on the target system in order to exploit this vulnerability. The specific flaw exists within the handling of eBPF programs. The issue results from the lack of proper validation of user-supplied eBPF programs prior to executing them. An attacker can leverage this vulnerability to escalate privileges and execute arbitrary code in the context of the kernel. Was ZDI-CAN-13661. 

这里是有示例代码: https://github.com/bsauce/kernel-exploit-factory/blob/main/CVE-2021-31440/exp/CVE-2021-31440.c



## CVE-2017-16995

> The check_alu_op function in kernel/bpf/verifier.c in the Linux kernel through 4.4 allows local users to cause a denial of service (memory corruption) or possibly have unspecified other impact by leveraging incorrect sign extension. 


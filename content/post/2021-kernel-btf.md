---
title: "Rebuild Kernel 生成 BTF 文件"
date: 2021-09-01T11:42:02+08:00
toc: false
draft: false
categories: [eBPF]
tags: [Kernel]
---

在测试 golang + libbpf + ebpf 的时候发现一个问题，load ebpf object时，报错说找不到 BTF 文件。这个很奇怪，我已经 include 了 `vmlinux.h`, 按说不应该再依赖于 BTF 文件。看了下 libbpf 的代码,大概出错的地方在:

```c

/*
 * Probe few well-known locations for vmlinux kernel image and try to load BTF
 * data out of it to use for target BTF.
 */
struct btf *btf__load_vmlinux_btf(void)
{
	struct {
		const char *path_fmt;
		bool raw_btf;
	} locations[] = {
		/* try canonical vmlinux BTF through sysfs first */
		{ "/sys/kernel/btf/vmlinux", true /* raw BTF */ },
		/* fall back to trying to find vmlinux ELF on disk otherwise */
		{ "/boot/vmlinux-%1$s" },
		{ "/lib/modules/%1$s/vmlinux-%1$s" },
		{ "/lib/modules/%1$s/build/vmlinux" },
		{ "/usr/lib/modules/%1$s/kernel/vmlinux" },
		{ "/usr/lib/debug/boot/vmlinux-%1$s" },
		{ "/usr/lib/debug/boot/vmlinux-%1$s.debug" },
		{ "/usr/lib/debug/lib/modules/%1$s/vmlinux" },
	};
	char path[PATH_MAX + 1];
	struct utsname buf;
	struct btf *btf;
	int i, err;

	uname(&buf);

	for (i = 0; i < ARRAY_SIZE(locations); i++) {
		snprintf(path, PATH_MAX, locations[i].path_fmt, buf.release);

		if (access(path, R_OK))
			continue;

		if (locations[i].raw_btf)
			btf = btf__parse_raw(path);
		else
			btf = btf__parse_elf(path, NULL);
		err = libbpf_get_error(btf);
		pr_debug("loading kernel BTF '%s': %d\n", path, err);
		if (err)
			continue;

		return btf;
	}

	pr_warn("failed to find valid kernel BTF\n");
	return libbpf_err_ptr(-ESRCH);
}
```

猜测是用到了 CO-RE 相关的功能，走到了这块逻辑。奇怪的是我已经通过 `ddeb` repo安装了相关的 vmlinux 文件。但还是不行。这个后续还是要查查，比较快的解决方案就是 rebuild kernel 带上 BTF 先跑通。

ubuntu 的话算是比较容易了，官方的方法是:
1. 从 src repo 里 download source
2. copy old config, 加上 BTF 开关
3. fakeroot build 成 deb 包
4. install deb package 即可。重启。

还是比较简单的，但是有个问题。第三步骤依赖于 `pahole` 这个 binary. 如果用 fakeroot 就找不到了，也没看到相关文档说怎么在fakeroot的时候配置 `PATH`. 所以我的方法就是去掉了 fakeroot, 大概步骤代码如下

```bash
# 1.  comment out deb-src repo in /etc/apt/source.list
# 2.  update repo
apt update
# 3. download kernel source package
apt-get source linux-image-unsigned-$(uname -r)

# 4. 下载完之后已经自动解压好了
cd <linux-source-dir>
# 5. copy old config
cp /boot/config-`uname -r` .config
# 6. 搜索BTF,打开开关
# 7. 开始编译，大概需要一个多小时，20-30G左右的磁盘
make  -j `getconf _NPROCESSORS_ONLN` deb-pkg
# 8. install debpackages
# 9. reboot
reboot
```

Links:
1. [UbuntuWiki:BuildYourOwnKernel](https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel)
2. [How to compile kernel in ubuntu](https://wiki.ubuntu.com/Kernel/BuildYourOwnKernel)

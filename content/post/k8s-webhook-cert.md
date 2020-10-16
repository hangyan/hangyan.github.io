---
title: "Kubernetes Webhook Cert 方案"
date: 2020-10-16T16:53:17+08:00
draft: false
categories: [Kubernetes]
tags: [Kubernetes]
---

Kubernetes 里的 Cert 数据是挺零散的一块，而 Webhook 中又强制要求必须是 HTTPS, 在实际使用的过程中尝试了几种方案，发现各有优劣，也都有不少问题．下面将分别详述一下:

## Cert Manager

Cert Manager 可能是最成熟的方案了，使用 Let's Encrypt 来签发证书．只需要配置好响应的 CR (Issuer, Cert...等), Cert Manager会自动生成证书，比较方便．

缺点也很多，首先是引入了一个比较重的依赖，Cert Manager本身的稳定性也是一个问题．实际用的时候经常发现它的 apiservice Not Ready等问题．假设本来环境中已经有 Cert Manager,那么直接用它是一个比较好的选项，否则并不建议使用．

## 脚本 + CSR Resource
这种方式是利用 Kubernetes 内置的 CSR 资源来管理证书，最终 caBundle 就可以直接用　Kubernetes 集群自带的 cert 数据，但 Server CRT 和 Server KEY 需要自己用脚本生成．Github 上有现成的项目演示了这种用法: [k8s-webhook-cert-manager](https://github.com/newrelic/k8s-webhook-cert-manager). 

其基本使用方式如下:
```bash
./generate_certificate.sh --service ${WEBHOOK_SERVICE_NAME} --webhook
${WEBHOOK_NAME} --secret ${SECRET_NAME} --namespace ${WEBHOOK_NAMESPACE} 
```
我们需要提供`SVC`的名字和`NS`以生成`cert`数据．脚本也可以根據自己需求進行適當裁剪.当数据生成之后，使用的 CSR 资源我们还可以通过集群看到(一段时间后会被GC):

```bash
[core@bastion ~]$ kubectl  get csr 
NAME        AGE     REQUESTOR             CONDITION
csr-w6ldh   5m56s   system:node:master3   Approved,Issued
```
需要注意的细节如下:
1. 生成证书默认的有效时间是一年，可以通过 controller-manager 的参数调节
2. webhook caBundle　里的数据默认可以从 POD 挂在的 default token里获取到 (`/run/secrets/kubernetes.io/serviceaccount`), 也可以从系统的一个 ConfigMap 里读取到　(`kubectl  get cm -n kube-system extension-apiserver-authentication`)

这种方式是比较忙简单的，而且利用了原生 k8s 的一些功能，是比较理想的一些形式．它的不足之处如下:
1. 一般需要用一个 initContainer 之类的方式来提前生成 cert 数据，并且在`webhook`主程序中手工读取数据，整体流程比较原始，容易出错．
2. 多实例的 webhook 程序其 initContainer里脚本的数据冲突也是个问题，需要单独处理．

另外，对原生 k8s 来说，这是一种比较理想的形式，但是对于一些特定的发行版来说，可能会遇到其他问题，下面举两个例子


### AWS
AWS的特殊之处在于，它的 `extension-apiserver-authentication` 与`Pod`里挂载的默认的 CA 数据不是一个．所以在 AWS 中，caBundle的数据只能从默认token里读取．这样的问题主要原因在于缺乏明确的文档说明，一旦默认其一致，难以DEBUG.

### OpenShift
OpenShift的默认token里的CA数据是一个证书链，而且如果用上述方式生成，由CSR请求到的 CERT 数据也无法被`kube-apiserver`认证．目前此问题暂无特别好的方法，只能通过下面使用自签名的证书的方式绕开．


## 自签名证书
这种方式是完全用 cli 程序生成自签名的证书，不使用`k8s CSR`的方式．好处就是能避开像上面的依赖于标准 k8s 的行为，防止未知的错误．[如何部署自己的webhook admission](https://zhuanlan.zhihu.com/p/137070531)这篇文章讲了大致的流程，将其脚本化并且做成镜像应该也比较简单．

它使用的工具并不是 openssl, 而是新的工具．我觉得一个原因就是 openssl 应该算是常用软件里使用非常不友好的一个工具了，基本上都不知道怎么用，网上也没多少好的介绍文章．新的工具至少能改善一下这方面的体验．










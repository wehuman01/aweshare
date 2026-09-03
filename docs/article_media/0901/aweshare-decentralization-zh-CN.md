# aweshare 设计哲学2：去中心化 —— hub 只是个平台，不是整个世界

![aweshare](../../logo/logo.png)

上一篇讲了 aweshare 的三个角色：出算力的生产者、用算力的消费者、守门的运营者。留了一个没展开的问题：那个守门的 hub，会不会只是把「平台的中心」从 OpenAI 换成了另一个人？

答案写在设计里：hub 是个平台，但不是中心。它轻到随时可以被替换——而且本来就该被替换。这篇文章不讲安装和命令，只说清楚三件事：hub 为什么轻、平台为什么不止一个、以及未来怎么把多个平台连起来。

## hub 很轻：它手里没有任何秘密

先看 hub 掌握什么：一份目录（谁共享了什么）、一本账（谁用了多少）、一串身份（谁能进门）。再看它不掌握什么：

- **上游的 key 和订阅凭据，hub 从来摸不到。** 请求由生产者电脑主动拨回来、拿钥匙去敲上游的门，hub 只见到转发的流量。hub 被攻破，泄露的是「谁在用」的账本，不是任何能调模型的凭据。
- **请求和响应的内容，一行不存。** 账本记的是谁、哪个模型、多少 token、多久，没有对话本身。
- **随时可以部署。** 一台小服务器，就能跑起一个一模一样的 hub；hub 之外，谁都不被绑定。

这三条决定了 hub 的地位：它是个**可替换的协调点**，不是不可或缺的中心。关掉任何一个 hub，生产者的 key 还在自己机器上，消费者的工具还是那些工具，换个地址就能重新开始。

## 平台不止一个：wehuman 的 hub 只是其中之一

`https://aweshare.wehuman.top` 是项目作者运营的一个社区平台——它不是「aweshare 网络」本身，只是用 aweshare 搭起来的诸多平台中的一个。

这句话值得展开说：**aweshare 是框架，hub 是实例。** 部署只要一台小服务器，于是：

- 一群朋友可以搭一个，只给熟人用；
- 一个团队可以搭一个，内部共享几份订阅和一台闲置显卡；
- 一个社区、一间高校实验室、一个开源项目，都可以搭自己的，定自己的门槛和规矩。

每个平台自己决定邀请谁、限多少、封不封——**信任是本地的**。你不需要信任 wehuman，也不需要信任任何一家「共享经济平台」；你只需要信任给你发邀请码的那个人。这和自建邮件服务器、自建 Mastodon 实例是同一种思路：协议公开，实例林立，谁也不垄断。

生产者的体验也印证了这种轻：无公网 IP、无端口映射，一台家用笔记本拨出去就能接入任何一个 hub。从一个平台换到另一个平台，改一行配置里的地址而已。

## 退出自由：换平台是一次「改地址」

去中心化是否成立，不看宣言，看退出成本。在 aweshare 里：

- **生产者**换 hub：改配置里的 hub 地址和令牌，重新 `join` 一次。模型目录跟着人走，key 从头到尾没离开过自己的机器。
- **消费者**换 hub：换一个令牌、改两行环境变量。工具还是 Claude Code、Codex、OpenCode，什么都不用重学。
- **运营者**关平台：删掉容器就行。账本随 hub 走，但没有任何人的凭据在里面。

没有「全网唯一账号」，没有「平台专属余额」，没有锁定。一个平台做得不好，用户用脚投票——这是对运营者最实在的约束，也比任何服务条款都管用。

## 未来的贯通：让平台之间连得起来

只有一个平台时，「共享经济」的范围就是那个平台的朋友圈。多平台并存之后，一个自然的问题是：这几个岛能不能连起来？

这是我们正在认真考虑的方向（注意：还在设想阶段，没有上线）。大致想到了几种形态：

- **目录的贯通。** A 平台的消费者能看到 B 平台开放出来的目录，像联邦时间线那样——每个平台依然自己守门，但视野不再局限于一墙之内。
- **枢纽互联。** 一个 hub 以「生产者」的身份接入另一个 hub，把自家的目录作为一条 offering 挂过去。链式接起来，小平台也能对外提供能力，而不必每个都直接面对公网。
- **身份的携带。** 在一个平台积累的信誉（用量记录、守规矩的历史）能否跟着人走，免去在每个新平台重新排队。

诚实地说，贯通比独立难得多：跨平台的信任怎么计算、账怎么分、滥用怎么隔离，都是真问题。去中心化先保证的是「谁都可以起一扇门」，贯通希望做到的是「门和门之间修路」——路要修，但每扇门后面的规矩，依然由守门人自己定。

## 设计哲学

**平台可替换，才是真平台。** 判断一个系统去不去中心化，就问一句：把它关了，用户怎么办？在 aweshare 里，答案是「换个地址，继续用」。

**信任本地化。** 你信任的应该是给你发码的那个人，而不是一个远方的公司。平台越小，信任越具体。

**随时可部署，实例自然林立。** 「自建一个」不是口号——一台小服务器，一个下午的工作量。

**先有退出，再谈互联。** 门可以随便开，是因为退出成本接近零；将来修路，也不能把退出成本重新抬上去。

## 试试

### 让 AI agent 帮你装

在 Claude Code、Codex 或任何编程 agent 里说一句：

```text
阅读 https://github.com/wehuman01/aweshare/blob/main/README.ai.md 并按它安装和配置 aweshare。
```

### 或者自己起一扇门

```bash
npm install -g aweshare

# 运营者：一台小服务器，起自己的平台
aweshare hub init && aweshare hub serve

# 生产者：拨出去，接入任何一个 hub（包括你自己的）
aweshare producer init && aweshare producer start
```

想用现成的？社区平台在 [aweshare.wehuman.top](https://aweshare.wehuman.top)；想自己开一个？文档都在 [GitHub](https://github.com/wehuman01/aweshare)。

## 现在就申请

消费者 10 个名额，先到先得；生产者不设限，随时欢迎。

发邮件到 [peng@wehuman.top](mailto:peng@wehuman.top)，说明你是谁、想共享还是使用，以及准备接入什么后端。aweshare 本身的 bug 请提交至 [GitHub issues](https://github.com/wehuman01/aweshare/issues)。

## aweshare 系列文章

- [aweshare：迈入共享token 时代](https://mp.weixin.qq.com/s/zFRIuxdLj6F5vPj9P7rXAQ)

## Awesome Ecosystem

aweshare 是一个不断壮大的 "awesome" 工具家族的一员 — CLI 优先、local-first，可被 AI agent 直接操作。

### CLI 工具

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI 优先的技能包管理器，支持 47+ AI 编程 agent。
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Claude Code、Codex、OpenCode 的 agent 配置切换器。
- **[awerouter](https://github.com/mugpeng/awerouter)** — 智能路由器，用结构信号把请求分给 Flash 或 Pro 模型，减少不必要的模型开销。
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — 收藏、分类、恢复 AI 编程会话，还能搭配 aweswitch 实现保存配置，一键启动。
- **[aweshare](https://github.com/wehuman01/aweshare)** — 通过自建 Hub 共享本地 Ollama/vLLM 或已授权的 OpenAI/Anthropic 后端，实现 token 的共享经济。
- **[awewarm](https://github.com/wehuman01/awewarm)** — 订阅窗口保持器，让 AI 编程套餐的窗口持续激活，无论是本地设置，还是通过远程连接的服务器。
- **[awescholar](https://github.com/Webioinfo01/awescholar)** — AI agent 可自主执行的科学文献发现与策展，搜索、标注、筛选和报告学术论文。

### 桌面应用

- **[awedot](https://awedot.wehuman.top/)** — 悬浮球驻留屏幕边缘，实时追踪当前 AI 会话；一键收藏、随时恢复，并可搭配 aweswitch 固定 agent 配置（比如用 GLM 模型启动）。

### 项目合集

- **[Awesome AI Meets Biology](https://github.com/Webioinfo01/Awesome-AI-Meets-Biology)** — AI 在生物学、生物信息学和生物医学研究中应用的精选综述。由 awescholar 驱动。
- **[Awesome AI Virtual Tumor](https://github.com/Webioinfo01/Awesome-AI-Virtual-Tumor)** — 面向虚拟肿瘤建模与仿真的前沿 AI 系统精选合集：静态模型、动态模型、agent、基准与综述。

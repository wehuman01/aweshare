# aweshare 社区 hub 开测：消费者 10 个名额，生产者不设限

![aweshare](../../../logo/logo.png)

aweshare 的思路，是把闲置的 AI 能力接到统一接口上：你在自己的机器上运行一个轻量 producer，上游 key 始终留在 `secrets.json`；朋友把普通的 OpenAI / Anthropic SDK 指向 hub，请求会通过出站 WebSocket 回到你的机器，调用时才注入 key。整套系统都可以自建——一条 `aweshare hub serve` 就能启动。真正的门槛只有中转服务器：需要公网 IP、TLS 配置，还要有人维护进程。社区版 hub 解决的正是这一环：服务器已经准备好了。

今天开始，`https://aweshare.wehuman.top` 这个社区 hub 招第一批测试用户：**消费者 10 个名额，先到先得；生产者不设名额上限，随时欢迎。**

需要说明的是：hub 只接管「中转站」这一环，key 和模型仍然由你的机器提供。要让别人使用你的模型，运行 producer 的机器必须保持在线。这正是 aweshare 的设计初衷：key 不离开你的机器。

## 怎么申请

发一封邮件即可：

- **收件人**：[peng@wehuman.top](mailto:peng@wehuman.top)
- **请说明**：你是谁、想成为哪种角色（生产者 / 消费者），以及准备共享什么——闲置 GPU 上的 Ollama / vLLM、某个 OpenAI Chat / OpenAI Responses / Anthropic 兼容的 API 账号（提供 base URL + API key 即可）；或者你想调用哪类模型。

我会回复一张一次性邀请码（`asi_...`）。消费者名额发完即止；之后收到的邮件会自动进入下一轮等候名单。生产者不设名额上限。

## 拿到邀请码之后

从未用过 aweshare？可以让你的 agent 帮你安装：

> "Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare."

自己操作也很简单，分两种角色。**生产者**（共享能力）：

```bash
npm install -g aweshare                                        # Node ≥ 22
aweshare producer join --hub https://aweshare.wehuman.top --code asi_...
# 编辑 ~/.aweshare/config.toml 注册 backends / offerings，key 放 secrets.json——它不会离开这台机器
aweshare producer doctor                 # 修好第一个 FAIL，重跑到全绿
aweshare producer start --background     # 你的终端，不是 agent 的
```

**消费者**（用别人共享出来的模型）：

```bash
npm install -g aweshare
aweshare consumer join --hub https://aweshare.wehuman.top --code asi_...
# asc_ token 只打印一次，存好；机器上没有 Node，一条 curl 也能兑换
export OPENAI_BASE_URL=https://aweshare.wehuman.top/v1
export OPENAI_API_KEY=asc_...
```

之后，Claude Code、Codex、OpenCode，以及任何支持 OpenAI Chat / Anthropic Messages / Responses 的工具，都可以直接指向 hub；模型名填写别名（如 `peng/qwen2.5.7b`）即可。日常需要在多个供应商间切换时，可交给 [aweswitch](https://github.com/Webioinfo01/aweswitch) 管理 profile。

## 测试用户能拿到什么

- **不用自建服务器。** 公网入口、TLS、中转和用量统计都由 hub 提供；你只需在自己的机器上运行 producer。
- **key 不出门。** 上游 key 只存在你机器上的 `secrets.json`（权限 600），由本地 agent 在转发那一刻注入——hub 从头到尾看不到。
- **随时可以退出。** 配置和 key 始终保留在你自己的机器上，没有任何锁定。无需继续时，运行 `aweshare producer stop`，再请我吊销邀请码，名额就会让给等候名单。

## 我会尽量保护（和你要掂量的）

hub 中转流量但从不经手你的 key——这是架构保证，不是一句口头承诺。要诚实交代的反而是另外三件事：

- **对生产者：** 把个人订阅制的 API key 中转给第三方，可能违反该上游的服务条款。自建开源模型（Ollama / vLLM）没有这个问题；拿不准就别共享那个后端，后果由发布者承担。
- **对消费者：** 你发送的所有内容都会以明文经过 hub——运维者（我）能看到流经的提示词与回复，并据此进行用量统计；你的 token 在 hub 上只以哈希形式保存。请把共享模型视作「在我眼皮底下使用的服务」，而不是私密通道。
- **对所有人：** 如果你不信任我运营的服务器，就不要使用它——你可以在自己控制的任意机器上运行 [`aweshare hub serve`](https://github.com/wehuman01/aweshare)。代码完全开源，没有隐藏内容。

## hub 欢迎什么样的后端

| 你想共享什么 | 能上 hub 吗？ |
|---|---|
| 本地开源模型（Ollama / vLLM，闲置 GPU） | **最欢迎**——干净，没有条款烦恼 |
| API 账号（OpenAI Chat / OpenAI Responses / Anthropic 兼容） | 能——key 留在你自己的机器上 |
| 个人订阅制的 key | 技术上能接，但 ToS 风险自负——拿不准就别 |

一个别名只对应一种协议，hub 不做协议转换：调用方应按该别名的 protocol 选择对应端点；若用错端点，会收到明确的报错提示，不会得到被悄悄转换后的错误结果。

## 合规与免责

有些话得写成条款，而不只是 FAQ 里的一句提醒：

- aweshare 是中继软件，它无法、也不判断你是否有权共享某个上游 key 或订阅——这是你与上游提供商之间的事。能自己调用 ≠ 有权转授第三方。
- 两类后端的情形完全不同：**自建开源模型**（在自己的 GPU 上运行 Ollama / vLLM）共享的是自己的硬件和开源权重，不涉及任何上游账号；**第三方 API 账号、个人订阅 key**（包括各类 coding plan）则应在共享前先阅读上游条款，包括账号规则、订阅与席位限制、转发及商用约束。将其转供第三方很可能违反这些条款；拿不准就不要共享。
- 共享的后果（key 被吊销、账号被暂停或终止）由生产者自行承担；hub 运营者（我）对自己的合法运营负责，并有义务让每个消费者知晓「流量明文过 hub」这条边界。
- 软件依据[专有许可](https://github.com/wehuman01/aweshare/blob/main/LICENSE)（可自由使用与自托管，禁止再分发）"按原样"提供，不附带任何保证；作者与贡献者不为 aweshare 的使用方式、以及通过它共享访问所导致的任何损失承担责任。

## 你可能想问的

**为什么是 10 个？** hub 当前的全局准入上限是给消费者的——10 个；生产者不设限。想当消费者要趁早，想当生产者，随时来。

**有没有可用性保证？** 没有，hub 是我个人在运营。哪天它停了，生产者损失的只是连接本身（配置和 key 都在本地）；消费者另找 hub 或者自建。真要停，我也会提前通知大家。

**调用模型返回 503。** 这表示该别名对应的生产者已离线，只能等待其恢复；可查看 `consumer list` 中的 STATUS。对生产者来说，若希望全天候可用，需要一台持续运行 producer 的机器；夜间关机的笔记本无法提供整晚服务。

**token 丢了。** 消费者的 `asc_` token 找不回来（hub 只存哈希）——说一声，重新发一张邀请码就好。

**有人滥用我共享的能力。** 从配置中删除对应 offering，再运行 `aweshare producer reload`，即可立即下架，无需重启，目录也会马上更新。情况更严重时直接联系我，吊销身份只需一条命令。

**撞上限流了。** 单模型的护栏（`maxConcurrencyPerUser`、`maxConcurrentUsers`、每日 token 预算）由发布者设定，`consumer list` 里可见；hub 另有限流。触顶时的 429 会写明白原因。

## 一起共创

这个 hub 不止想当一台中转服务器。我邀请有想法的用户一起，把它做成更实用的东西：

- **把闲置算力分享出来。** 角落里的 GPU、跑不满的订阅，接上来就是 hub 上的一条 offering——生产者不设名额上限，有闲置就欢迎。
- **可持续的模式仍在探索。** 后续可能考虑广告收入，或参考科研通以积分奖励生产者：你贡献算力获得积分，积分未来或可兑换权益。目前都还只是设想，欢迎一起参与定义。
- **有想法就来聊。** 最缺什么模型、限额怎么设才公平、积分该值多少——发邮件到 [peng@wehuman.top](mailto:peng@wehuman.top)，或提 [GitHub issue](https://github.com/wehuman01/aweshare/issues)，都行。

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

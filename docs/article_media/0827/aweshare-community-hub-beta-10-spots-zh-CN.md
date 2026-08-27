# aweshare 社区 hub 开测：10 个名额，先到先得

![aweshare](../../logo/logo.png)

aweshare 的原理是把手头闲着的 AI 能力挂上一个标准门面：你在自己机器上跑一个轻量 producer，上游 key 待在 `secrets.json` 里不出门；朋友把普通的 OpenAI / Anthropic SDK 指向 hub，请求经一条出站 WebSocket 转回你这台机器，调用的那一刻才注入 key。整套东西都能自建——`aweshare hub serve` 一条命令就能起。它唯一的门槛是那台中转服务器：要有公网 IP、配好 TLS、还得有人盯着进程。社区版 hub 补上的就是这一环：这台机器已经有了。

今天开始，`https://aweshare.wehuman.top` 这个社区 hub 招第一批测试用户：**10 个名额，先到先得。**

有一说一：hub 只是替你扛下「中转站」这一环，key 和模型仍然从你的机器出发——想让别人用上你的模型，你的机器得开着 producer。这是 aweshare 的设计本意：key 不出门。

## 怎么申请

发封邮件就行：

- **收件人**：[peng@wehuman.top](mailto:peng@wehuman.top)
- **写清楚**：你是谁，想当哪种角色（生产者 / 消费者），以及打算共享什么——闲置 GPU 上的 Ollama / vLLM，某个 OpenAI Chat / OpenAI Responses / Anthropic 兼容的 API 账号（base URL + API key 就算），或者你想调用哪类模型。

我会回你一张一次性邀请码（`asi_...`）。10 个名额发完即止——后来的邮件自动进下一轮的等候名单。

## 拿到邀请码之后

完全没用过 aweshare？让你家 agent 装一下：

> "Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare."

自己动手也就两条路。**生产者**（把能力共享出去）：

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

之后 Claude Code、Codex、OpenCode、任何会说 OpenAI Chat / Anthropic Messages / Responses 的工具都能直接指向 hub，模型名填别名（如 `peng/qwen2.5.7b`）就行；日常在多个供应商之间切换可以交给 [aweswitch](https://github.com/Webioinfo01/aweswitch) 管 profile。

## 测试用户能拿到什么

- **不用架服务器。** 公网入口、TLS、中转、用量统计，hub 已经在了；你只管在自己机器上跑 producer。
- **key 不出门。** 上游 key 只存在你机器上的 `secrets.json`（权限 600），由本地 agent 在转发那一刻注入——hub 从头到尾看不到。
- **随时能走。** 配置和 key 的原件从头到尾都在你自己机器上，没有任何东西被锁死。不想玩了 `aweshare producer stop`，请我吊销邀请码，名额让给等候名单。

## 我会尽量保护（和你要掂量的）

hub 中转流量但从不经手你的 key——这是架构保证，不是一句口头承诺。要诚实交代的反而是另外三件事：

- **对生产者：** 把个人订阅制的 API key 中转给第三方，可能违反该上游的服务条款。自建开源模型（Ollama / vLLM）没有这个问题；拿不准就别共享那个后端，后果由发布者承担。
- **对消费者：** 你发送的一切都会明文经过 hub——运维者（我）看得到流经的提示词与回复，并据此做用量统计；你的 token 在 hub 上只存哈希。把共享模型当作「在我眼皮底下」，而不是私密通道。
- **对所有人：** 你不信任我运营的服务器，就别用它——在自己控制的任意机器上跑 [`aweshare hub serve`](https://github.com/wehuman01/aweshare)，代码开源，一行不少。

## hub 欢迎什么样的后端

| 你想共享什么 | 能上 hub 吗？ |
|---|---|
| 本地开源模型（Ollama / vLLM，闲置 GPU） | **最欢迎**——干净，没有条款烦恼 |
| API 账号（OpenAI Chat / OpenAI Responses / Anthropic 兼容） | 能——key 留在你自己的机器上 |
| 个人订阅制的 key | 技术上能接，但 ToS 风险自负——拿不准就别 |

一个别名讲一种协议，hub 不做翻译：调用方按该别名的 protocol 选对应端点，打错了会得到明确的报错指路，不会被静默搅乱。

## 你可能想问的

**为什么是 10 个？** hub 对生产者设有全局准入上限，当前就是 10——首批名额与之对齐。消费者走同一封邮件申请，确认后发邀请码。

**有没有可用性保证？** 没有，hub 是我个人在运营。哪天它停了，生产者损失的只是连接本身（配置和 key 都在本地）；消费者另找 hub 或者自建。真要停，我也会提前通知大家。

**调模型返回 503。** 说明这条别名的生产者掉线了，只能等——看 `consumer list` 里的 STATUS。反过来说给生产者听：想要全天候可用，得有一台常开的机器跑 producer；夜里关机的笔记本 serve 不了一整晚。

**token 丢了。** 消费者的 `asc_` token 找不回来（hub 只存哈希）——说一声，重新发一张邀请码就好。

**有人滥用我共享的东西。** 改配置删掉对应 offering，然后 `aweshare producer reload`——即时下架，不用重启，目录马上更新。更严重的情况直接找我，吊销身份是一条命令的事。

**撞上限流了。** 单模型的护栏（`maxConcurrencyPerUser`、`maxConcurrentUsers`、每日 token 预算）由发布者设定，`consumer list` 里可见；hub 另有限流。触顶时的 429 会写明白原因。

## 现在就申请

10 个名额，先到先得。

发邮件到 [peng@wehuman.top](mailto:peng@wehuman.top)——你是谁、想共享还是想使用、打算接什么后端。aweshare 本身的 bug 请提 [GitHub issues](https://github.com/wehuman01/aweshare/issues)。

## More from mugpeng

aweshare 是 aweteam 生态的一部分：

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI 优先的技能包管理器，支持 47+ AI 编程 agent
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Claude Code、Codex、OpenCode 的 agent 配置切换器
- **[awerouter](https://github.com/mugpeng/awerouter)** — 智能路由器，用结构信号把请求分给 Flash 或 Pro 模型
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — AI 编程会话管理器，按 profile 恢复现场
- **[aweshare](https://github.com/wehuman01/aweshare)** — 本地优先的 AI 能力中继：共享你的 GPU 和 API key，但 key 不出门
- **[awewarm](https://github.com/mugpeng/awewarm)** — 订阅窗口保温器，让 AI 编程套餐的窗口 predictable 地开着

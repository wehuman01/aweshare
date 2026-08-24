# 社区 Hub —— 不用自己架服务器，也能共享、使用 AI 模型

<a href="./README.md">English</a> · <strong>简体中文</strong>

`https://aweshare.wehuman.top` 是由项目开发者运营的社区 [aweshare](https://github.com/wehuman01/aweshare) hub。aweshare 让大家互相共享 AI 模型能力：**生产者**把自己的后端（本地 Ollama、某个 API 账号）接到 hub 上，**消费者**用一个标准 URL 加普通的说 OpenAI 或 Anthropic 方言的 SDK 调用这些模型——就像多了一家 API 供应商。

两种角色都采用邀请制——邀请码的获取方式见[联系方式](#联系方式)。

## 先读这条 —— 信任规则

**如果你是生产者：** 上游 API key 永不离开你的机器。它只存在于你机器上的 `~/.aweshare/secrets.json`（权限 600）；hub 只经手中转流量，永远看不到 key。但把个人订阅制的 API key 中转给第三方，可能违反该上游的服务条款——自建开源模型（Ollama/vLLM）没有这个问题。拿不准就别共享那个后端。后果由生产者承担（key 被封、账号被停）。

**如果你是消费者：** 你发送的一切都会经过 hub 中转——运维者能看到流经的提示词与回复，并据此做用量统计（你的 token 在 hub 上只存哈希）。把共享模型当作"在运维者眼皮底下"，而不是私密通道。

**对所有人：** 运维者可以随时吊销邀请码来停用任何身份。你不信任的人运营的服务器，不是放敏感流量的地方——这种情况请自建：在你控制的任意机器上跑 [`aweshare hub serve`](../../README_cn.md#运维)。

## 现在共享了什么

别问本页，问 hub——列表会变：

```bash
npm install -g aweshare            # Node ≥ 22
aweshare consumer list --hub https://aweshare.wehuman.top --token asc_...   # 拿到 token 后
```

## 生产者快速开始

### 1. 安装

Node ≥ 22：

```bash
npm install -g aweshare
```

### 2. 兑换生产者邀请码

```bash
aweshare producer join --hub https://aweshare.wehuman.top --code asi_...
```

它会先探测 hub（探测通过才消耗邀请码），写入 `~/.aweshare/config.toml` 和空的 `secrets.json`（都是 600 权限），并打印你的生产者名——这个名字就是你的**命名空间**：你发布的每个模型都叫 `<你的名字>/<模型>`。

### 3. 把配置指向你的后端

编辑 `~/.aweshare/config.toml`：每个上游写一个 `[[backends]]`，每个想共享的模型写一个 `[[offerings]]`。protocol 决定 agent 如何拨号上游（差异见[消费者端点表](#2-把-sdk-指向-hub)）：

```toml
hubUrl  = "https://aweshare.wehuman.top"
token   = "asp_..."                # join 已自动填好

[[backends]]
id = "stepfun"
protocol = "openai"                # openai 型的 baseUrl 要含 /v1
baseUrl = "https://api.stepfun.com/v1"
keyRef = "stepfun-key"

[[offerings]]
alias = "peng1/step-flash"         # 命名空间必须等于你的生产者名
backend = "stepfun"
upstreamModel = "step-3.7-flash"
maxConcurrency = 2
```

真正的 key 放进 `secrets.json`——它不会离开这台机器：

```json
{ "stepfun-key": "sk-..." }
```

### 4. 预检，然后启动

```bash
aweshare producer doctor               # 修好第一个 FAIL，重跑到全绿
aweshare producer start --background   # 后台运行；日志 → ~/.aweshare/producer.log
aweshare producer doctor --status      # pid、uptime、最近日志——秒回
```

停止用 `aweshare producer stop`。生产者一停或崩溃，其别名立刻下线，消费者收到 503——哪一环断了，`doctor` 会告诉你。

## 消费者快速开始

### 1. 兑换消费者邀请码

任何机器都行——日常使用甚至不需要装 Node：

```bash
aweshare consumer join --hub https://aweshare.wehuman.top --code asi_...
```

它会打印一次你的 `asc_` token 和可直接粘贴的环境变量——**存好**；hub 上只有它的哈希。

### 2. 把 SDK 指向 hub

base URL 恒为 `https://aweshare.wehuman.top`；路径取决于该别名的 protocol（用 `consumer list` / `/v1/catalog` 查）:

| 别名 protocol | 调用方式 | SDK 配置 |
| --- | --- | --- |
| `openai` | `POST /v1/chat/completions` | `OPENAI_BASE_URL=https://aweshare.wehuman.top/v1`<br>`OPENAI_API_KEY=asc_...` |
| `anthropic` | `POST /v1/messages` | `ANTHROPIC_BASE_URL=https://aweshare.wehuman.top`<br>`ANTHROPIC_AUTH_TOKEN=asc_...` |
| `responses` | `POST /v1/responses` | 同 OpenAI 式 base URL，走 Responses API |

调错端点会明确报错并指路——不存在静默翻译。

### 3. 一条 curl 验证通路

```bash
curl https://aweshare.wehuman.top/v1/chat/completions \
  -H "Authorization: Bearer asc_..." -H "content-type: application/json" \
  -d '{"model":"peng1/step-flash","messages":[{"role":"user","content":"ping"}]}'
```

之后把任何支持自定义 OpenAI/Anthropic base URL 的工具指到 hub，模型名填别名即可。

## 配额与公平使用

单模型的护栏由生产者设定（`maxConcurrency`、并发消费者数、每日 token 预算——`consumer list` 里可见）。hub 另有全局准入上限（生产者名额当前 10 个）和限流。触顶时 429 报错会写明原因。

## 常见问题

**消费者 token 丢了。** 无法从 hub 找回（只存哈希）——找运维者重新发一个邀请码。

**某个模型返回 503。** 它的生产者掉线了。只能等——看 `consumer list` 里的 STATUS。

**我的 Claude Code 只会说 Anthropic 方言，别名却是 `openai`。** 正常——hub 不做协议翻译。按别名的 protocol 列选对应端点；工具实在不支持切换的话，本地加一层翻译代理。

**我共享的东西被滥用了。** 收回你发布的：停掉 producer，改配置，重启。更严重的情况联系运维者，他可以停用身份。

**服务哪天没了怎么办？** 这是开发者个人运营的服务，没有可用性承诺。生产者损失的只是连接本身（配置和 key 都在本地）；消费者需要另找 hub。

**不想用了。** 生产者：`aweshare producer stop`。消费者：删掉环境变量。请运维者吊销你的邀请码，把名额让出来。

## 联系方式

- **邀请码（两种角色）**：发邮件到 **peng@wehuman.top**——说明你是谁、想共享还是想使用。
- **aweshare 本身的 bug**：[GitHub issues](https://github.com/wehuman01/aweshare/issues)。

# 社区 Hub —— 不用自己架服务器，也能共享、使用 AI 模型

<a href="./README.md">English</a> · <strong>简体中文</strong>

`https://aweshare.wehuman.top` 是由项目开发者运营的社区 [aweshare](https://github.com/wehuman01/aweshare) hub。aweshare 让大家互相共享 AI 模型能力：**生产者**把自己的后端（本地 Ollama、某个 API 账号）接到 hub 上，**消费者**用一个标准 URL 加普通的说 OpenAI 或 Anthropic 方言的 SDK 调用这些模型——就像多了一家 API 供应商。

两种角色都采用邀请制——邀请码的获取方式见[联系方式](#联系方式)。

## 先读这条 —— 信任规则

**如果你是生产者：** 上游 API key 永不离开你的机器。它只存在于你机器上的 `~/.aweshare/secrets.json`（权限 600）；hub 只经手中转流量，永远看不到 key。但把个人订阅制的 API key 中转给第三方，可能违反该上游的服务条款——自建开源模型（Ollama/vLLM）没有这个问题。拿不准就别共享那个后端。后果由生产者承担（key 被封、账号被停）。

**如果你是消费者：** 你发送的一切都会经过 hub 中转——运维者能看到流经的提示词与回复，并据此做用量统计（你的 token 在 hub 上只存哈希）。把共享模型当作"在运维者眼皮底下"，而不是私密通道。

**对所有人：** 运维者可以随时吊销邀请码来停用任何身份。你不信任的人运营的服务器，不是放敏感流量的地方——这种情况请自建：在你控制的任意机器上跑 [`aweshare hub serve`](../../README_cn.md#运维)。

## 合规与免责

aweshare 是中继软件：它无法、也不判断你是否有权共享某个上游 key 或订阅——这是你与上游提供商之间的事。能自己调用 ≠ 有权转授第三方。两类后端的合规处境完全不同：

| 后端类型 | 合规处境 |
|---|---|
| 自建开源模型（Ollama / vLLM 跑在自己的 GPU 上） | 干净——共享的是自己的硬件与开源权重，不涉及任何上游账号 |
| 第三方 API 账号 / 个人订阅 key（含各类 coding plan） | 共享前先读上游条款（账号规则、订阅与席位限制、转发、商用约束）；转授第三方大概率违反这些条款。**拿不准就不要共享。** |

其余条款与主 [README](https://github.com/wehuman01/aweshare/blob/main/README_cn.md#合规与免责) 一致：

- 共享的后果（key 被吊销、账号被暂停或终止）由生产者自行承担；hub 运营者对自己的合法运营负责，并有义务让消费者知晓上面的明文中转边界。
- 本软件依据[专有许可](https://github.com/wehuman01/aweshare/blob/main/LICENSE)（可自由使用与自托管，禁止再分发）"按原样"提供，不附带任何保证。作者与贡献者不为 aweshare 的使用方式、以及通过它共享访问所导致的任何损失承担责任。

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
maxConcurrencyPerUser = 2          # 每个消费者的并发请求数
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

兑换要走 aweshare CLI——先安装（Node ≥ 22）：

```bash
npm install -g aweshare
aweshare consumer join --hub https://aweshare.wehuman.top --code asi_...
```

机器上没有 Node 也不想装？一条 curl 也能兑换：

```bash
curl -s -X POST https://aweshare.wehuman.top/invites/v1/redeem \
  -H 'content-type: application/json' -d '{"code":"asi_..."}'
```

不管哪种方式，`asc_` token 都只打印**一次**——存好；hub 上只有它的哈希。

### 2. 把 SDK 指向 hub

base URL 恒为 `https://aweshare.wehuman.top`；路径取决于该别名的 protocol（用 `consumer list` / `/v1/catalog` 查）:

| 别名 protocol | 调用方式 | SDK 配置 |
| --- | --- | --- |
| `openai` | `POST /v1/chat/completions` | `OPENAI_BASE_URL=https://aweshare.wehuman.top/v1`<br>`OPENAI_API_KEY=asc_...` |
| `anthropic` | `POST /v1/messages` | `ANTHROPIC_BASE_URL=https://aweshare.wehuman.top`<br>`ANTHROPIC_AUTH_TOKEN=asc_...` |
| `responses` | `POST /v1/responses` | 同 OpenAI 式 base URL，走 Responses API |

调错端点会明确报错并指路——不存在静默翻译。

典型客户端配对（`consumer list` 的 PROTOCOL 列显示为 `anthropic` / `openai-chat` / `openai-responses`）：`anthropic` ← Claude Code；`openai` ← 任何 OpenAI 兼容工具——opencode、zcode 等编程 agent 通常走这条；`responses` ← Codex CLI（默认 `wire_api`），但不止它——opencode、Cline（OpenAI Native）同样支持 Responses API。一个客户端可能两种 OpenAI 线都说（如 opencode），按你工具会说的方言挑别名的 protocol。

### 3. 一条 curl 验证通路

```bash
curl https://aweshare.wehuman.top/v1/chat/completions \
  -H "Authorization: Bearer asc_..." -H "content-type: application/json" \
  -d '{"model":"peng1/step-flash","messages":[{"role":"user","content":"ping"}]}'
```

之后把任何支持自定义 OpenAI/Anthropic base URL 的工具指到 hub，模型名填别名即可。

### 推荐工具：用 aweswitch 管理供应商切换

日常使用中，hub 大概率只是你多个 API 供应商之一。[aweswitch](https://github.com/Webioinfo01/aweswitch) 把「agent × 供应商」的每种组合存成命名 profile，启动时注入环境变量、不碰全局配置（`pip3 install aweswitch`，需 Python ≥ 3.9）。走 aweshare 的 profile 就是普通的一条：

```json
{
  "profiles": {
    "api": {
      "claude": {
        "cc-aweshare": {
          "env": {
            "ANTHROPIC_BASE_URL": "https://aweshare.wehuman.top",
            "ANTHROPIC_AUTH_TOKEN": "${AWESHARE_ASC_TOKEN}",
            "ANTHROPIC_MODEL": "peng1/step-flash"
          }
        }
      }
    }
  }
}
```

用 `aweswitch cc-aweshare` 启动；Codex / OpenCode profile 与官方账号登录见 [aweswitch README](https://github.com/Webioinfo01/aweswitch)。

## 配额与公平使用

单模型的护栏由生产者设定（`maxConcurrencyPerUser`——每个消费者的并发请求数、`maxConcurrentUsers`——并发消费者数、每日 token 预算及剩余——`consumer list` 里可见）。hub 另有全局准入上限（消费者名额当前 10 个，生产者不设限）和限流。触顶时 429 报错会写明原因。

## 常见问题

**消费者 token 丢了。** 无法从 hub 找回（只存哈希）——找运维者重新发一个邀请码。

**某个模型返回 503。** 它的生产者掉线了。只能等——看 `consumer list` 里的 STATUS。

**我的 Claude Code 只会说 Anthropic 方言，别名却是 `openai`。** 正常——hub 不做协议翻译。按别名的 protocol 列选对应端点；工具实在不支持切换的话，本地加一层翻译代理。

**我共享的东西被滥用了。** 收回你发布的：改配置删掉对应 offering，然后 `aweshare producer reload` 热加载（不用重启；目录会即时从 hub 下架）。更严重的情况联系运维者，他可以停用身份。

**服务哪天没了怎么办？** 这是开发者个人运营的服务，没有可用性承诺。生产者损失的只是连接本身（配置和 key 都在本地）；消费者需要另找 hub。

**不想用了。** 生产者：`aweshare producer stop`。消费者：删掉环境变量。请运维者吊销你的邀请码，把名额让出来。

## 联系方式

- **邀请码（两种角色）**：发邮件到 **peng@wehuman.top**——说明你是谁、想共享还是想使用。
- **aweshare 本身的 bug**：[GitHub issues](https://github.com/wehuman01/aweshare/issues)。

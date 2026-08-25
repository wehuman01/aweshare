<div align="center">
  <img src="./logo/logo.png" alt="aweshare" width="760">
  <h1>aweshare：开源、local-first 的 AI 能力中继</h1>
  <p><strong>开源、local-first 的 AI 能力中继。</strong></p>
  <p>通过自建 Hub 共享本地 Ollama/vLLM 或已授权的 OpenAI/Anthropic 后端，消费者用标准 SDK 以 <code>命名空间/别名</code> 调用。</p>
  <p><strong>上游 API Key 永不离开生产者设备。</strong></p>
  <p>
    <a href="./README.md">English</a> ·
    <strong>简体中文</strong> ·
    <a href="https://www.npmjs.com/package/aweshare">npm</a> ·
    <a href="https://github.com/wehuman01/aweshare">GitHub</a>
  </p>
  <p>
    <a href="https://ko-fi.com/mugpeng"><img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white" alt="Ko-fi"></a>
  </p>
  <p>
     <a href="https://github.com/wehuman01/aweshare-source/releases"><img src="https://img.shields.io/badge/version-0.4.8-7C3AED?style=flat-square" alt="Version"></a>
    <a href="https://github.com/wehuman01/aweshare"><img src="https://img.shields.io/badge/node-%E2%89%A522-0EA5E9?style=flat-square" alt="Node"></a>
    <a href="https://github.com/wehuman01/aweshare/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-proprietary-E34F26?style=flat-square" alt="License"></a>
    <a href="https://www.npmjs.com/package/aweshare"><img src="https://img.shields.io/badge/npm-aweshare-7C3AED?style=flat-square" alt="npm package"></a>
  </p>
  <p>
    <img src="https://img.shields.io/badge/status-beta-c96a3d?style=flat-square" alt="Status">
    <img src="https://img.shields.io/badge/docker-ghcr.io%2Fwehuman01%2Faweshare-2496ED?style=flat-square&logo=docker" alt="Docker image">
    <img src="https://img.shields.io/badge/protocol-OpenAI%20%7C%20Anthropic-0ea5a4?style=flat-square" alt="Protocols">
    <img src="https://img.shields.io/badge/platform-docker%20%7C%20npm%20%7C%20node-334155?style=flat-square" alt="Platform">
    <img src="https://img.shields.io/npm/dt/aweshare?style=flat-square" alt="npm downloads">
    <img src="https://img.shields.io/github/stars/wehuman01/aweshare?style=flat-square" alt="GitHub stars">
    <img src="https://img.shields.io/badge/deploy-self%20hosted-334155?style=flat-square" alt="Self hosted">
  </p>
</div>

生产者在自己的电脑上跑一个轻量 Agent，把本地 Ollama/vLLM 或**已获授权**的 OpenAI/Anthropic 后端共享出去；上游 API Key 只存在生产者设备上，只由本地 Agent 在转发时注入。消费者像用普通模型厂商一样，把标准 OpenAI/Anthropic SDK 指向 Hub，用 `命名空间/别名` 调用模型。

```
消费者（标准 SDK，零改动）                 生产者侧
┌───────────────────────┐            ┌────────────────────────────┐
│ Claude Code           │            │ aweshare producer (Node CLI)   │
│  ANTHROPIC_BASE_URL ──┼──► HTTPS ──┤  ~/.aweshare/config.toml   │
│ OpenAI SDK / Codex    │            │  ~/.aweshare/secrets.json  │
└───────────────────────┘            │   │ 注入上游 Key（唯一位置） │
           │ /v1/messages            │   ▼
           │ /v1/chat/completions    │  Ollama / vLLM / OpenAI / Anthropic
           ▼                         │
┌─────────────────────────────┐      │
│ aweshare hub（公网单实例）    │◄─────── WSS 反向隧道（Agent 主动外连）
│ 鉴权 / 路由 / 计量          │       生产者无需公网 IP、无需端口映射
└─────────────────────────────┘
```

- 邀请码准入制：准入统一走运营者签发的一次性邀请码，被准入的消费者可调用 hub 上全部 offering。无支付、无市场。
- 命名空间别名：`peng/gpt-4o` 全局唯一、属主唯一，路由是确定性查找。
- v1 只做 OpenAI↔OpenAI（chat completions 与 Responses）与 Anthropic↔Anthropic 的**原生透明 SSE 转发**，不做跨协议转换、智能路由、Web 控制台。

## 信任边界（先读这个）

- 为完成路由与计量，**消费者的提示词与模型响应都会经过 Hub，不是端到端加密**。Hub 不持久化任何请求/响应内容，但 Hub 运维者技术上可见明文——请只使用你信得过的 Hub 实例（这也是 Hub 开源 + 自建部署的意义）。
- 上游 API Key 永不离开生产者设备，也不会发给消费者。令牌在库内**有意存两份**：加盐 SHA-256 哈希用于认证，明文同时保留，运维者可用 `hub list --token` 把弄丢的令牌交还本人。邀请码同理——明文可通过 `hub list --reveal` 找回。数据库泄露会暴露全部身份，请妥善保管数据目录。
- 令牌吊销是**可逆挂起**（`hub revoke --id N` / `hub restore --id N`，按邀请码操作），且邀请码与它换出的生产者同进退：撤销已兑换的码即挂起对应生产者（并断开其隧道），从任一侧 restore 都同时救回两者。吊销不删除任何数据——offerings 与用量记录在挂起期间完整保留。

### 合规与免责

- aweshare 是中继软件：它无法、也不判断你是否有权共享某个上游 key 或订阅——这是你与上游提供商之间的事。能自己调用 ≠ 有权转授第三方。
- 共享前请阅读上游条款（账号规则、订阅与席位限制、转发、商用约束）。把个人订阅 key——包括各类 coding plan——共享给第三方，大概率违反这些条款；自部署开源模型无此问题。**拿不准就不要共享。**
- 共享的后果（key 被吊销、账号被暂停或终止）由生产者自行承担；hub 运营者对自己的合法运营负责，并有义务让消费者知晓上面的明文中转边界。
- 本软件依据[专有许可](./LICENSE)（可自由使用与自托管，禁止再分发）"按原样"提供，不附带任何保证。作者与贡献者不为 aweshare 的使用方式、以及通过它共享访问所导致的任何损失承担责任。

## Quickstart

已发布：npm 包 [`aweshare`](https://www.npmjs.com/package/aweshare)（需 Node ≥ 22）和 Docker 镜像（`ghcr.io/wehuman01/aweshare`），无需 clone 源码。

### 1. 启动 Hub（运维者，一台 VPS）

**npm**（最简）：

```bash
npm install -g aweshare
aweshare hub init        # 数据在 ~/.aweshare-hub；打印 admin token，抄下来
aweshare hub serve       # 监听 :8787（前面套 Caddy/nginx 做 TLS）
```

hub 自己也能挂模型，不需要 producer 机器：在 `~/.aweshare-hub/config.toml` 里加 `[[backends]]`/`[[offerings]]` 段（格式与 producer 配置相同，别名命名空间 `hub/…`），上游 key 放 `~/.aweshare-hub/secrets.json`，然后：

```bash
aweshare hub produce    # serve + hub 自有模型；消费者照常调 hub/<name>
```

**docker**：

```bash
docker run -d --name aweshare-hub --restart unless-stopped \
  -p 127.0.0.1:8787:8787 -v "$PWD/data:/data" ghcr.io/wehuman01/aweshare:latest
docker exec aweshare-hub aweshare hub init   # 首次：生成 admin token，抄下来
```

然后拉人进来。生产者自助加入——邀请码（`asi_…`，一次性）。两种模式：

```bash
# 绑定：码锁定某个名字（"邀请某个用户"）
aweshare hub invite --name peng [--expires-in 7d]      # → asi_...，发给生产者

# 不绑定：批量发放；生产者兑换时自己提交 name + email（写入 hub）
aweshare hub invite --count 10 [--expires-in 7d]

# 生产者自行兑换（不需要传递令牌本身）：
aweshare producer join --hub https://hub.example.com --code asi_... [--name NAME --email YOU@EXAMPLE.COM]
```

消费者以同样方式加入——consumer 邀请码兑换后得到消费者自己保管的 `asc_` 密钥：

```bash
aweshare hub invite --role consumer --name alice [--expires-in 7d]   # → asi_...，发给消费者

# 消费者自己兑换（asc_ 只打印一次，附可直接粘贴的 SDK 环境变量——当场保存，之后不再显示）：
aweshare consumer join --hub https://hub.example.com --code asi_...

# 没装 aweshare？一条 curl 也行：
# curl -s -X POST https://hub.example.com/invites/v1/redeem \
#   -H 'content-type: application/json' -d '{"code":"asi_..."}'
```

三种 token 角色，对应三方：

| 角色 | 谁持有 | 怎么用 |
|---|---|---|
| `admin` | Hub 操作者（只有你） | admin REST API（`/admin/v1/*`）；CLI 侧：`hub invite` / `list [invites\|producers\|consumers]` / `revoke` / `restore` |
| `producer`（`asp_...`） | 生产者机器上的 agent | 写进 `~/.aweshare/config.toml` 的 `token` 字段，agent 靠它向 hub 注册 offering |
| `consumer`（`asc_...`） | 调用模型的一方 | 填在 SDK 环境变量（`ANTHROPIC_AUTH_TOKEN` / `OPENAI_API_KEY`）里，hub 靠它识别消费者并做计量、限额与挂起 |

`name` 即生产者的别名命名空间（`peng/gpt-4o` 的 `peng/`）。

**准入完全归运营者**：两种角色统一走一次性邀请码（唯一准入路径，每个身份的全生命周期都带着邀请码这个把手）。兑换成功的消费者密钥可调用 hub 上**全部** offering——放谁进来，谁就能用共享的一切。兜底手段：按消费者的 `hub limits`（限流、并发、token 预算）、按 offering 的限额（`maxConcurrentUsers`、`dailyTokens`）与 `hub revoke` 挂起，全部由 hub 强制执行。

### 2. 生产者首跑（按顺序）

```bash
npm install -g aweshare   # ⓪ 生产者机器上装一次（Node ≥ 22）

# ① join：用邀请码兑换（生成 ~/.aweshare/config.toml + secrets.json，0600）
aweshare producer join --hub https://hub.example.com --code asi_...
#    或拿到现成令牌时：
aweshare producer init --hub https://hub.example.com --token asp_...

# ② 编辑配置（见下文），把上游 key 放进 secrets.json —— 它们不会离开这台机器

# ③ doctor：预检，按「先找第一个失败环节」的顺序
aweshare producer doctor

# ④ 启动（长驻进程；停止即别名下线，消费者会收到 503）
aweshare producer start            # 前台运行；加 --background 转入后台
#    后台实例用 'aweshare producer doctor --status' 查看，
#    用 'aweshare producer stop' 停止
```

### 3. 消费者首跑（按顺序）

```bash
# ⓪ 兑换你的邀请码（操作者直接给 asc_ 密钥的可跳过）
#    令牌只打印一次并附可直接粘贴的环境变量——当场保存，之后不再显示
aweshare consumer join --hub https://hub.example.com --code asi_...

# ① curl 一发小请求确认链路
curl https://hub.example.com/v1/chat/completions \
  -H "Authorization: Bearer asc_..." -H "content-type: application/json" \
  -d '{"model":"peng/qwen2.5.7b","messages":[{"role":"user","content":"ping"}]}'

# ② 配工具（见下）→ 跑一个最小任务
# ③ 确认用量：拿消费者密钥 GET /admin/v1/usage（只能看到自己的记录）
# ④ 再上真实负载
```

## 消费工具配置

**OpenAI SDK / 任何 OpenAI 兼容工具**

```ts
const client = new OpenAI({ baseURL: 'https://hub.example.com/v1', apiKey: 'asc_...' })
await client.chat.completions.create({ model: 'peng/gpt-4o', messages: [...] })
```

**Claude Code**（key 填 `asc_` 消费者密钥，**不是任何上游 x-api-key**）

```bash
export ANTHROPIC_BASE_URL=https://hub.example.com
export ANTHROPIC_API_KEY=asc_...
claude --model peng/sonnet
```

Claude Code 若残留旧 OAuth 登录态会覆盖环境变量配置，用 `/login` 切换或清理 credentials。

**Codex**（默认的 Responses 线协议即可用——别名需挂在 `responses` 协议的 offering 上；`wire_api = "chat"` 对 `openai` 协议的 offering 同样可用）

```toml
[model_providers.aweshare]
base_url = "https://hub.example.com/v1"
```

**发现可用模型**：`GET /v1/models`（OpenAI SDK `client.models.list()`）返回 hub 上已注册的全部别名及在线状态。

## 生产者配置参考（~/.aweshare/config.toml）

```toml
hubUrl = "https://hub.example.com"
token = "asp_..."

[[backends]]
id = "ollama"
protocol = "openai"                      # openai 型 baseUrl 含 /v1（SDK 惯例）
baseUrl = "http://127.0.0.1:11434/v1"

[[backends]]
id = "anthropic-main"
protocol = "anthropic"                   # anthropic 型 baseUrl 不含 /v1（agent 自己拼）
baseUrl = "https://api.anthropic.com"
keyRef = "anthropic-key"                 # 对应 secrets.json 里的键

[[backends]]
id = "glm-responses"
protocol = "responses"                   # responses 型 baseUrl 含版本路径
baseUrl = "https://open.bigmodel.cn/api/v1"
keyRef = "glm-key"                       # 例如 GLM coding plan 的 key（Codex 就绪）

[[offerings]]
alias = "peng/qwen2.5.7b"                # 命名空间必须是你的生产者 name
backend = "ollama"
upstreamModel = "qwen2.5:7b"             # 必须是后端真实 ID（ollama list 的完整 tag）
maxConcurrencyPerUser = 1                # 单个消费者在该别名上的并发请求数
# maxConcurrentUsers = 3                 # 同时在用的不同消费者数（hub 默认 3）
# dailyTokens = 1000000                  # 每日共享 token 额度（UTC 日，默认 100 万；0 = 无上限）
```

一条 offering 恰好暴露一个上游模型：消费者调用别名，hub 在转发前把请求里的 model 强制改写为 `upstreamModel`——他们永远无法选用其他模型。想多开放模型就多写几条 `[[offerings]]`。

一个别名也可以同时说多种线上协议：把 `backend = "…"` 换成列表 `backends = ["a", "b"]`，该块会按 backend 各注册一条 offering。注册以 `别名 + 协议` 为键，因此列出的 backend 协议必须互不相同（重复会被 hub 拒绝）；不做任何协议转换——每条注册只走自己的线上协议。消费者用任意 SDK 调同一个别名即可，`producer list` / `consumer list` 会把多协议行合并成一条显示。

**按别名的用量约束**写在同一段里，后两项可选、由 hub 执行（未设置时套默认值，包括旧版 agent 未上传的场景）：

| 键 | 默认 | 含义 | 执行 |
|---|---|---|---|
| `maxConcurrencyPerUser` | 1 | **单个消费者**在该别名上的并发请求数上限 | 429 `PRODUCER_MAX_CONCURRENCY` |
| `maxConcurrentUsers` | 3 | 该别名上同时有进行中请求的**不同消费者数**上限 | 429 `PRODUCER_MAX_USERS` |
| `dailyTokens` | 1000000 | 该别名每 **UTC 日**跨消费者合计的 token（prompt+completion）额度；`0` = 无上限 | 429 `QUOTA_EXCEEDED`（UTC 午夜重置） |

`maxConcurrencyPerUser` 限的是每个消费者的并发**请求数**，`maxConcurrentUsers` 限的是并发**人数**——某消费者要并发发 5 个请求需要自己的 `maxConcurrencyPerUser ≥ 5`；该别名的总并发理论上限是 `maxConcurrentUsers × maxConcurrencyPerUser`。日额度统计已记录用量（见下文「诚实的限制」）。（v0.4.3 由 `maxConcurrency` 改名而来，旧键限的是别名总并发。）

密钥卫生：用专用最小权限、可撤销、带预算告警的 key；`secrets.json` 保持 0600、不进 git/截图；疑似泄露立即轮换。共享权利自查：账号条款、订阅限制、转发与商用约束。

## 消费者限制（全局默认 + 按消费者覆盖）

每个消费者默认套用全局配置（`AWESHARE_CONSUMER_RPS` / `BURST` / `CONCURRENCY`，见运维一节）。在此之上，hub 管理员可以设置**稀疏的按消费者覆盖**——只设置你关心的项，其余继续走全局默认：

```bash
aweshare hub limits alice --tpm 60000 --max-total-tokens 5000000  # 设置（合并进已有覆盖）
aweshare hub limits alice                                        # 查看当前覆盖
aweshare hub limits alice --clear                                # 清空，回到全局默认

# 同一组开关也可走 admin REST API（PUT / DELETE 同一路径）：
curl -X PUT https://hub.example.com/admin/v1/consumers/alice/limits \
  -H "Authorization: Bearer asa_...（admin 令牌）" -H "content-type: application/json" \
  -d '{"tpm":60000,"maxTotalTokens":5000000}'
```

| 键 | 含义 | 生效方式 |
|---|---|---|
| `rps` / `burst` / `maxConcurrent` | 覆盖该消费者的全局限流/并发默认值 | 429 `RATE_LIMITED` |
| `tpm` | 任意滑动 60 秒窗口内的 token 上限（prompt + completion） | 429 `RATE_LIMITED`（内存窗口，与 RPS 桶一致） |
| `maxTotalTokens` | 该消费者的终身 token 预算 | 429 `QUOTA_EXCEEDED`（对 `usage_events` 求和） |

诚实的限制说明：token 类上限只统计上游报告的用量——Ollama 流式响应不带 usage，按 0 计。TPM 和终身预算都是基于已观测用量的阈值，不是预留式硬上限：单个请求可能跨过阈值，先于已有请求用量落库的并发请求还会进一步超额；已记录用量达到阈值后，新请求才会被拒绝。

## 端点与错误

| 端点 | 说明 |
|---|---|
| `POST /v1/chat/completions` · `POST /v1/messages` · `POST /v1/responses` | 推理入口（Bearer 或 `x-api-key`） |
| `GET /v1/models` | hub 上已注册的全部别名与状态 |
| `GET /v1/catalog` | hub 全部 offering——生产者、别名、协议、状态、按别名的限额、即时在途占用（`activeUsers`/`activeRequests`）及当日已用/剩余 token（`aweshare consumer list` 的发现视图） |
| `GET /healthz` | 存活探测 |
| `GET /admin/v1/offerings` | 已注册 offerings 及实时状态、限额、即时在途占用、当日已用 token——admin 全量，生产者令牌只看自己那份（`aweshare producer list`） |
| `/admin/v1/*` | 令牌/限额/用量管理（admin 或生产者令牌）· 用量：`GET /admin/v1/usage`（新在前的逐请求日志）与 `GET /admin/v1/usage/summary`（`group=consumer-alias\|consumer\|alias`、`since=30m\|12h\|7d\|all`，默认 7d、`consumer`/`producer`/`alias` 过滤；每种角色各看自己那份） · 消费者限制覆盖：`GET`/`PUT`/`DELETE /admin/v1/consumers/{name}/limits`（仅 admin） |

错误语义：`401` 无效密钥 · `401 TOKEN_REVOKED` 令牌被挂起（请联系运维者 restore） · `403 HUB_FULL` 生产者容量已满 · `404` 别名不存在 · `400 PROTOCOL_MISMATCH` 协议/别名不匹配 · `429` 限流、TPM 超限或超生产者并发（`PRODUCER_MAX_USERS` = 不同消费者数上限；`QUOTA_EXCEEDED` = 终身或每日 token 预算用尽） · `502` 上游/隧道错误（上游 4xx/5xx 原样透传） · `503` 生产者离线/后端降级 · `504` 超时。所有错误带 `{error:{code,message,requestId}}`，requestId 贯穿两侧日志。

用量记录：每请求一行（别名、真实模型、状态、时长、字节数、token 数尽力提取），**内容零落库**。`aweshare hub usage`（生产者机器上则是 `aweshare producer usage`，自动限定在自己模型那份）默认就回答"谁用了多少"：聚合在 hub 的 SQLite 上完成，按 消费者 × 模型 一行——同一个人的行聚在一起，最忙的人和最忙的模型排前面——给出请求数、错误数、尽力提取的 token 总量、未知 token 行数（不回报用量的流式后端）与平均耗时。窗口默认 7 天并随表头打印（`--since 30m\|12h\|7d\|…\|all`）；`--group-by consumer` 收粗到每人一行，`--group-by alias` 收粗到每模型一行。`--details` 切到逐请求日志（`GET /admin/v1/usage`；admin 全量，生产者/消费者各看自己那份，行内带消费者/生产者名字）。

## 常用命令

两侧命令速查——细节见上文各节。

**Hub（运营者）**——需要 `aweshare hub init` 输出的 admin token；hub 在远端服务器时，在服务器上执行，或设置 `AWESHARE_HUB_URL` 后本地执行：

| 命令 | 用途 |
|---|---|
| `aweshare hub init` | 创建数据目录和 admin token（只打印一次） |
| `aweshare hub serve [--host H] [--port N]` | 启动 hub |
| `aweshare hub produce [--host H] [--port N]` | 启动 hub 并挂上自有模型——与 `serve` 同一进程；hub config.toml 的 `[[backends]]`/`[[offerings]]` 段注册为 `hub/…` offering，由 hub 进程直接服务（key 在数据目录的 secrets.json；改动热加载） |
| `aweshare hub invite [--role producer\|consumer] [--name NAME] [--count N] [--expires-in D]` | 铸造一次性邀请码（`asi_…`，只打印一次，默认 7 天后过期；可用 `list --reveal` 重新查看）；producer 码：绑定（`--name`）或不绑定（兑换时提交 name + email，可 `--count` 批量）；consumer 码：始终绑定单个名字 |
| `aweshare hub list [invites\|producers\|consumers] [--reveal] [--token] [--json]` | 查看 hub 状态：邀请码生命周期（ROLE + 谁兑换的，`--reveal` 显码、`--token` 显示换出的令牌），或 producers/consumers 名册（状态 + 最近活跃） |
| `aweshare hub limits NAME [--rps N] [--burst N] [--max-concurrent N] [--tpm N] [--max-total-tokens N] [--clear] [--json]` | 查看 / 合并 / 清空某消费者的限额覆盖（未设的键保持全局默认） |
| `aweshare hub usage [--details] [--consumer NAME] [--producer NAME] [--alias ns/model] [--group-by consumer-alias\|consumer\|alias] [--since 7d\|all] [--limit N] [--json]` | 谁用了多少（默认）：按 消费者 ×模型 聚合，同一个人的行聚在一起，最忙在前——请求数、错误数、成功率、尽力提取的 token 总量、未知 token 行数、平均耗时；窗口默认 7d 并随表头打印 · `--details`：逐请求日志，新在前，内容零落库，每行标明消费者 |
| `aweshare hub revoke --id N` · `aweshare hub restore --id N` | 撤销 / 恢复邀请码——撤销已兑换的码会连带挂起它换出的生产者，restore 救回两者 |

令牌签发统一走邀请码（两种角色）。`limits` 与 `usage` 是 admin REST API（`/admin/v1/*`，见「端点与错误」）的薄封装，curl 同样可用。

list 默认输出对齐表格；加 `--json` 可获取原始 API 响应。

**生产者侧**——运行在生产者（即带后端）的那台机器上：

| 命令 | 用途 |
|---|---|
| `aweshare producer init [--hub URL] [--token asp_…]` | 写入 `~/.aweshare` 配置模板 |
| `aweshare producer join --hub URL --code asi_… [--name NAME --email YOU@EXAMPLE.COM]` | 兑换邀请码得到 producer 令牌并写入配置（不绑定码需 `--name`/`--email`；先探测 hub——局域网以外的明文 HTTP 需 `--allow-http`） |
| `aweshare producer config path` · `config show` · `config edit` | 定位 / 查看（密钥打码）/ 编辑配置 |
| `aweshare producer doctor [--status]` | 端到端诊断：后台实例、配置、后端探测、hub（含你的 offerings 有多少已注册）、最近日志（`--status` 跳过网络探测，秒回） |
| `aweshare producer list [--json]` | 查看本 producer 在 hub 上注册了什么——别名、协议、实时状态、限额、即时占用（`IN USE`，此刻在用的不同消费者数）、当日 token 用量——外加本地后台实例状态与和 config.toml 的漂移（hubUrl/token 取自 config.toml） |
| `aweshare producer usage [--details] [--consumer NAME] [--alias ns/model] [--group-by consumer-alias\|consumer\|alias] [--since 7d\|all] [--limit N] [--json]` | 谁用了本 producer 的模型（producer 令牌把 hub 计量限定在自己那份）：默认按 消费者 × 模型 聚合——同一个人的行聚在一起，最忙在前，窗口默认 7d · `--details`：逐请求日志，新在前，每行标明消费者 |
| `aweshare producer start [--background]` | 连接并转发（长驻进程；`--background` 转入后台——日志写 `~/.aweshare/producer.log`，pid 写 `producer.pid`） |
| `aweshare producer reload` | 通知后台 producer（SIGHUP）重读 `config.toml` + `secrets.json`，并在既有隧道上重新注册 offerings——不断连；配置有误时保留旧值继续服务 |
| `aweshare producer stop` | 停止后台 producer（SIGTERM，10 秒后 SIGKILL）并清理 pidfile |

**消费者侧**——两条命令，跑在消费者机器上；日常使用时标准 SDK 直连 hub（见「消费工具配置」）：

| 命令 | 用途 |
|---|---|
| `aweshare consumer join --hub URL --code asi_… [--allow-http]` | 兑换消费码得到 `asc_` 令牌——只打印一次，附可直接粘贴的 SDK 环境变量（当场保存；运维者可用 `hub list --token` 找回） |
| `aweshare consumer list --hub URL --token asc_… [--json]` | hub 发现视图：全部生产者、别名、协议、状态、按别名的限额、即时占用（`IN USE n/max`——此刻有请求在途的不同消费者数；`max/max` 的别名在有人结束前不再放新消费者进）及当日剩余 token |

CLI 维护：`aweshare self-update [--check]` 更新 npm 安装的 CLI（`--check` 只比较版本）。

## 运维

没有常开的机器可以共享，或者想用别人共享的模型？项目开发者运营着一个社区 hub：**https://aweshare.wehuman.top**（邀请制——向 peng@wehuman.top 申请邀请码）；[docs/community-hub/](./docs/community-hub/README_cn.md) 是面向生产者/消费者的逐步接入指南（English version）。

hub 会从数据目录读取 `config.toml`（`~/.aweshare-hub/config.toml`；Docker 内是 `/data/config.toml`）。`aweshare hub init` 会生成模板，全部键注释着——取消注释即覆盖默认值。键名与下表同义、用 camelCase（`consumerRps`、`headTimeoutMs`…）。优先级：`serve` 参数（`--host`/`--port`）> 环境变量 > config.toml > 默认值。文件有问题（非法 TOML、未知键、非正数值）启动即报错并指名键；`AWESHARE_HUB_DATA_DIR` 本身只能用环境变量（它决定文件在哪）。

**热加载**：除 host/port 外，表中所有可调参数都支持运行中 `SIGHUP` 生效（`kill -HUP <pid>`；Docker 用 `docker kill -s HUP aweshare-hub`）——先校验新文件，写坏了只记日志、继续用旧值服务。环境变量在进程启动时就固定了，被 `AWESHARE_*` 钉住的键不受重载影响（与启动时同一优先级）；host/port 仍需重启。生产者侧的 offerings 与限额用 `aweshare producer reload` 热加载。

**hub 自挂模型（`hub produce`）**：同一份 config.toml 可以带 `[[backends]]` 和 `[[offerings]]` 段（producer 格式；别名命名空间 `hub/…`，裸名自动补前缀），上游 key 放同目录的 `secrets.json`（chmod 600）。这些 offering 在目录里挂在 producer `hub` 名下，由 hub 进程直接转发——不走隧道，也不占 `AWESHARE_MAX_PRODUCERS` 席位。限额（`maxConcurrencyPerUser`、`maxConcurrentUsers`、`dailyTokens`）、用量计量和 consumer 限额与远端 producer 完全一致。内置 producer `hub` 不是身份（无令牌、无邀请码、不可撤销）；只有在它名下确实挂着 offering 时才出现在 `hub list producers` 里，状态显示为 `built-in`。目录与 key 改动像其他参数一样热加载；写坏了保留旧目录并记日志。

| 环境变量 | 默认 | 说明 |
|---|---|---|
| `AWESHARE_HUB_DATA_DIR` | `~/.aweshare-hub` | 数据目录（SQLite/pepper/admin token/config.toml，挂卷即备份） |
| `AWESHARE_HUB_PORT` / `HOST` | 8787 / 0.0.0.0 | 监听 |
| `AWESHARE_CONSUMER_RPS` / `BURST` / `CONCURRENCY` | 10 / 20 / 8 | 每消费者限流 |
| `AWESHARE_HEAD_TIMEOUT_MS` / `IDLE_TIMEOUT_MS` | 120000 / 300000 | 响应头超时 / 流空闲超时 |
| `AWESHARE_MAX_BODY_BYTES` | 32MB | 请求体上限 |
| `AWESHARE_INVITE_REDEEM_PER_MIN` | 10 | 兑换端点（免认证）限流 |
| `AWESHARE_MAX_PRODUCERS` | 10 | 活跃生产者上限——令牌签发（admin API）、邀请码兑换与 restore 满员时返回 `403 HUB_FULL` |
| `AWESHARE_NO_UPDATE_CHECK` | 未设置 | 设为 `1` 关闭被动更新提醒 |

健康：Agent 心跳 15s，静默 45s 判死；后端 AUTH/QUOTA 连败 2 次自动降级（别名对消费者显示 degraded，停止派发），30s 探测恢复。同一生产者令牌新连接替换旧连接（latest-wins）。

升级 npm 安装：`aweshare self-update`（安装前会确认；`--check` 只看版本不改动）。npm 上有新版本时，CLI 每天最多提醒一次。

升级 Docker 部署：`docker compose pull && docker compose up -d`。数据都在 `./data` 卷里不受影响；重启期间 producer 会自动重连，consumer 只在短暂的重启窗口内看到 503。

## 已知限制（v1）

- 不做跨协议转换：一个别名只讲一种线协议（openai chat、anthropic messages 或 openai responses）。
- Ollama 流式响应不带 usage → token 数记 NULL（尽力而为）。
- 单 Hub 单实例 + SQLite，无水平扩展。
- 企业代理可能拦截 WebSocket 隧道（环境限制）。

## 开发

```bash
pnpm install
pnpm test        # 197 项测试：协议包/Hub 契约（假Agent打真Hub）/Agent 单测/e2e（真实 SDK）
pnpm build       # tsc -b 全仓
pnpm check       # biome
```

构建后 link 一次，即可免掉 `node apps/.../dist/cli.js`：

```bash
npm link                 # 或 pnpm link --global——只安装唯一的 `aweshare` 命令
aweshare hub serve
aweshare producer doctor
```

发布：push 一个 `v*` tag（`docs/CHANGELOG.md` 需有对应 `## [x.y.z]` 小节），CI 通过 Trusted Publishing（OIDC，无需 token secret）自动发布 `aweshare` 到 npm，推送 Docker 镜像到 `ghcr.io/wehuman01/aweshare`，并将用户文档同步到公开仓库 wehuman01/aweshare。

结构：`packages/protocol`（线协议共享包）· `packages/producer-core`（生产者运行时共享包）· `apps/hub`（HTTP+WS+SQLite+CLI）· `apps/agent`（CLI）。设计文档在 `docs/specs/`，变更记录在 `docs/CHANGELOG.md`，贡献范围见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

## 支持我们

如果 aweshare 帮你省下了一份订阅或一台 GPU 机器，欢迎支持它：

- ⭐ 给仓库点个 Star——让更多人看到它。
- ☕ [Ko-fi](https://ko-fi.com/mugpeng)——请我喝杯咖啡。
- 💬 微信——扫下方二维码。

<p align="center">
  <img src="assets/images/wechat-pay.jpg" alt="WeChat Pay" width="240">
</p>

> aweshare 可免费使用与自托管。赞助让它得以持续维护——谢谢。

依据 aweshare 专有许可发布——可自由使用与自托管，禁止再分发。详见 [LICENSE](./LICENSE)。

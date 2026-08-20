<div align="center">
  <img src="./logo/logo.png" alt="aweshare" width="760">
  <h1>aweshare：开源、local-first 的 AI 能力中继</h1>
  <p><strong>开源、local-first 的 AI 能力中继。</strong></p>
  <p>通过基于授权（grant）的 Hub 共享本地 Ollama/vLLM 或已授权的 OpenAI/Anthropic 后端，消费者用标准 SDK 以 <code>命名空间/别名</code> 调用。</p>
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
    <a href="https://github.com/wehuman01/aweshare-source/releases"><img src="https://img.shields.io/badge/version-0.2.8-7C3AED?style=flat-square" alt="Version"></a>
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
│ Claude Code           │            │ aweshare agent (Node CLI)   │
│  ANTHROPIC_BASE_URL ──┼──► HTTPS ──┤  ~/.aweshare/config.toml   │
│ OpenAI SDK / Codex    │            │  ~/.aweshare/secrets.json  │
└───────────────────────┘            │   │ 注入上游 Key（唯一位置） │
           │ /v1/messages            │   ▼
           │ /v1/chat/completions    │  Ollama / vLLM / OpenAI / Anthropic
           ▼                         │
┌─────────────────────────────┐      │
│ aweshare hub（公网单实例）    │◄─────── WSS 反向隧道（Agent 主动外连）
│ 鉴权 / 授权 / 路由 / 计量     │       生产者无需公网 IP、无需端口映射
└─────────────────────────────┘
```

- 生产者授权制：消费者只能使用被显式授权（grant）的别名，无支付、无市场。
- 命名空间别名：`peng/gpt-4o` 全局唯一、属主唯一，路由是确定性查找。
- v1 只做 OpenAI↔OpenAI（chat completions 与 Responses）与 Anthropic↔Anthropic 的**原生透明 SSE 转发**，不做跨协议转换、智能路由、Web 控制台。

## 信任边界（先读这个）

- 为完成路由与计量，**消费者的提示词与模型响应都会经过 Hub，不是端到端加密**。Hub 不持久化任何请求/响应内容，但 Hub 运维者技术上可见明文——请只使用你信得过的 Hub 实例（这也是 Hub 开源 + 自建部署的意义）。
- 上游 API Key 永不离开生产者设备，也不会发给消费者；Hub 数据库里只存各类令牌的 SHA-256 哈希。

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

**docker**：

```bash
docker run -d --name aweshare-hub --restart unless-stopped \
  -p 127.0.0.1:8787:8787 -v "$PWD/data:/data" ghcr.io/wehuman01/aweshare:latest
docker exec aweshare-hub aweshare hub init   # 首次：生成 admin token，抄下来
```

然后签发令牌：

```bash
aweshare hub token issue --role producer --name peng     # → asp_...，给生产者
aweshare hub token issue --role consumer --name alice    # → asc_...，给消费者
```

三种 token 角色，对应三方：

| 角色 | 谁持有 | 怎么用 |
|---|---|---|
| `admin` | Hub 操作者（只有你） | 管理命令：`hub token issue` / `grant add` / `token revoke` / `usage` |
| `producer`（`asp_...`） | 生产者机器上的 agent | 写进 `~/.aweshare/config.toml` 的 `token` 字段，agent 靠它向 hub 注册 offering |
| `consumer`（`asc_...`） | 调用模型的一方 | 填在 SDK 环境变量（`ANTHROPIC_AUTH_TOKEN` / `OPENAI_API_KEY`）里，hub 靠它判断能调哪些别名 |

`name` 即生产者的别名命名空间（`peng/gpt-4o` 的 `peng/`）。

### 2. 生产者首跑（按顺序）

```bash
npm install -g aweshare   # ⓪ 生产者机器上装一次（Node ≥ 22）

# ① init：生成 ~/.aweshare/config.toml + secrets.json（0600）
aweshare agent init --hub https://hub.example.com --token asp_...

# ② 编辑配置（见下文），把上游 key 放进 secrets.json —— 它们不会离开这台机器

# ③ doctor：预检，按「先找第一个失败环节」的顺序
aweshare agent doctor

# ④ 授权消费者
aweshare agent grant --alias peng/qwen2.5.7b --consumer alice
#    限时试用：加 --expires-in 7d（重复授权会刷新到期时间）

# ⑤ 启动（长驻进程；停止即别名下线，消费者会收到 503）
aweshare agent start
```

### 3. 消费者首跑（按顺序）

```bash
# ① curl 一发小请求确认链路
curl https://hub.example.com/v1/chat/completions \
  -H "Authorization: Bearer asc_..." -H "content-type: application/json" \
  -d '{"model":"peng/qwen2.5.7b","messages":[{"role":"user","content":"ping"}]}'

# ② 配工具（见下）→ 跑一个最小任务
# ③ 确认用量：aweshare hub usage --alias peng/qwen2.5.7b
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

**发现可用模型**：`GET /v1/models`（OpenAI SDK `client.models.list()`）返回该密钥被授权的全部别名及在线状态。

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
maxConcurrency = 1                       # 本地模型从 1 起步，云端 API 可调高
```

密钥卫生：用专用最小权限、可撤销、带预算告警的 key；`secrets.json` 保持 0600、不进 git/截图；疑似泄露立即轮换。共享权利自查：账号条款、订阅限制、转发与商用约束。

## 消费者限制（全局默认 + 按消费者覆盖）

每个消费者默认套用全局配置（`AWESHARE_CONSUMER_RPS` / `BURST` / `CONCURRENCY`，见运维一节）。在此之上，hub 管理员可以设置**稀疏的按消费者覆盖**——只设置你关心的项，其余继续走全局默认：

```bash
aweshare hub consumer limits --name alice            # 查看当前覆盖项
aweshare hub consumer limits --name alice --tpm 60000 --max-total-tokens 5000000
aweshare hub consumer limits --name alice --rps 2    # 后续设置是合并，不是替换
aweshare hub consumer limits --name alice --clear    # 清空，回到全局默认
```

| 键 | 含义 | 生效方式 |
|---|---|---|
| `rps` / `burst` / `maxConcurrent` | 覆盖该消费者的全局限流/并发默认值 | 429 `RATE_LIMITED` |
| `tpm` | 任意滑动 60 秒窗口内的 token 上限（prompt + completion） | 429 `RATE_LIMITED`（内存窗口，与 RPS 桶一致） |
| `maxTotalTokens` | 该消费者的终身 token 预算 | 429 `QUOTA_EXCEEDED`（对 `usage_events` 求和） |

授权可带有效期：`aweshare hub grant add --alias peng/gpt-4o --consumer alice --expires-in 7d`（生产者侧用 `aweshare agent grant … --expires-in 7d`）。过期授权返回 `403 GRANT_EXPIRED`；重新授权会刷新到期时间。

诚实的限制说明：token 类上限只统计上游报告的用量——Ollama 流式响应不带 usage，按 0 计。TPM 是尽力而为（所有并发请求都在任何一个完成前通过时可能超限）；终身预算是精确的，因为它对持久化记录求和。

## 端点与错误

| 端点 | 说明 |
|---|---|
| `POST /v1/chat/completions` · `POST /v1/messages` · `POST /v1/responses` | 推理入口（Bearer 或 `x-api-key`） |
| `GET /v1/models` | 当前密钥可见的别名与状态 |
| `GET /healthz` | 存活探测 |
| `/admin/v1/*` | 令牌/授权/用量管理（admin 或生产者令牌）· 消费者限制覆盖：`GET`/`PUT`/`DELETE /admin/v1/consumers/{name}/limits`（仅 admin） |

错误语义：`401` 无效密钥 · `403` 未获授权或授权已过期（`GRANT_EXPIRED`） · `404` 别名不存在 · `400 PROTOCOL_MISMATCH` 协议/别名不匹配 · `429` 限流、TPM 超限或超生产者并发（`QUOTA_EXCEEDED` = 终身 token 预算用尽） · `502` 上游/隧道错误（上游 4xx/5xx 原样透传） · `503` 生产者离线/后端降级 · `504` 超时。所有错误带 `{error:{code,message,requestId}}`，requestId 贯穿两侧日志。

用量记录：每请求一行（别名、真实模型、状态、时长、字节数、token 数尽力提取），**内容零落库**。生产者 `aweshare agent list` 查看授权，`aweshare hub usage` 查询用量。

## 运维

| 环境变量 | 默认 | 说明 |
|---|---|---|
| `AWESHARE_HUB_DATA_DIR` | `~/.aweshare-hub` | 数据目录（SQLite/pepper/admin token，挂卷即备份） |
| `AWESHARE_HUB_PORT` / `HOST` | 8787 / 0.0.0.0 | 监听 |
| `AWESHARE_CONSUMER_RPS` / `BURST` / `CONCURRENCY` | 10 / 20 / 8 | 每消费者限流 |
| `AWESHARE_HEAD_TIMEOUT_MS` / `IDLE_TIMEOUT_MS` | 120000 / 300000 | 响应头超时 / 流空闲超时 |
| `AWESHARE_MAX_BODY_BYTES` | 32MB | 请求体上限 |
| `AWESHARE_NO_UPDATE_CHECK` | 未设置 | 设为 `1` 关闭被动更新提醒 |

健康：Agent 心跳 15s，静默 45s 判死；后端 AUTH/QUOTA 连败 2 次自动降级（别名对消费者显示 degraded，停止派发），30s 探测恢复。同一生产者令牌新连接替换旧连接（latest-wins）。

升级 npm 安装：`aweshare self-update`（安装前会确认；`--check` 只看版本不改动）。npm 上有新版本时，CLI 每天最多提醒一次。

## 已知限制（v1）

- 不做跨协议转换：一个别名只讲一种线协议（openai chat、anthropic messages 或 openai responses）。
- Ollama 流式响应不带 usage → token 数记 NULL（尽力而为）。
- 单 Hub 单实例 + SQLite，无水平扩展。
- 企业代理可能拦截 WebSocket 隧道（环境限制）。

## 开发

```bash
pnpm install
pnpm test        # 98 tests：协议包/Hub 契约（假Agent打真Hub）/Agent 单测/e2e（真实 SDK）
pnpm build       # tsc -b 全仓
pnpm check       # biome
```

构建后 link 一次，即可免掉 `node apps/.../dist/cli.js`：

```bash
npm link                 # 或 pnpm link --global——只安装唯一的 `aweshare` 命令
aweshare hub serve
aweshare agent doctor
```

发布：push 一个 `v*` tag（`docs/CHANGELOG.md` 需有对应 `## [x.y.z]` 小节），CI 通过 Trusted Publishing（OIDC，无需 token secret）自动发布 `aweshare` 到 npm，推送 Docker 镜像到 `ghcr.io/wehuman01/aweshare`，并将用户文档同步到公开仓库 wehuman01/aweshare。

结构：`packages/protocol`（线协议共享包）· `apps/hub`（HTTP+WS+SQLite+CLI）· `apps/agent`（CLI）。设计文档在 `docs/specs/`，变更记录在 `docs/CHANGELOG.md`，贡献范围见 [CONTRIBUTING.md](./CONTRIBUTING.md)。

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

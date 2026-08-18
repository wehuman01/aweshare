# aweshare 设计文档

- 日期：2026-08-15
- 状态：已与产品负责人确认
- 参考：`product/ref/fasten-share-client`（fasten 客户端，MIT；其 Hub 闭源，仅可反推契约）、fastenshare.com 官方指南六篇
- 实施计划：`.zcode/plans/plan-2026-08-15-aweshare-master.md`

## 1. 定位

aweshare 是一个开源、local-first 的 AI 能力中继服务：

- **生产者**在自己的电脑上运行轻量 Agent，配置本地 Ollama/vLLM 或已获授权的 OpenAI、Anthropic 后端。上游 API Key 只保存在生产者设备，只由本地 Agent 在请求执行时注入。
- **Hub** 部署在公网（单实例），负责令牌鉴权、按别名寻找生产者、铸造短时调用 ticket、经生产者主动建立的反向隧道转发请求、记录用量。
- **消费者**像使用普通模型厂商一样，把 Claude Code / Anthropic SDK 指向 `/v1/messages`，把 OpenAI SDK / Codex 类工具指向 `/v1/chat/completions`，只使用 Hub 签发的消费者密钥和公开模型别名。

典型场景：团队/朋友之间共享自己的 Ollama 算力或已付费的 API 额度，生产者显式授权、无任何支付环节。

### 1.1 v1 明确不做

- 跨协议转换（无 anthropic↔openai 互转，无 openai-response 协议）
- 支付、积分、提现、倍率
- 订阅账号共享
- 智能路由、负载均衡、故障转移（命名空间别名使路由成为确定性查找，天然不需要）
- Web 控制台、账号体系、注册登录
- 工具配置文件写改助手（fasten 的 tool-config，v1 用环境变量文档替代）

## 2. 总体架构

```
消费者侧（标准 SDK，零改动）                生产者侧
┌──────────────────────────┐          ┌────────────────────────────┐
│ Claude Code              │          │ aweshare-agent (Node CLI)   │
│  ANTHROPIC_BASE_URL ─────┼─► HTTPS ─┤  ~/.aweshare/config.toml   │
│ OpenAI SDK / Codex(chat) │          │  ~/.aweshare/secrets.json  │
└──────────────────────────┘          │   │ 注入上游 Key（唯一位置） │
           │ /v1/messages             │   ▼
           │ /v1/chat/completions     │  Ollama / vLLM / OpenAI / Anthropic
           │ /v1/models               │  （本地或已授权云后端）
           ▼                          │
┌─────────────────────────────┐       │
│ aweshare-hub（公网单实例）    │◄─────── WSS 反向隧道（Agent 主动外连，
│ 消费者端点：鉴权/授权/路由    │        注册 offerings / 心跳 15s）
│ 隧道服务端：分发/背压/取消    │
│ SQLite：令牌/授权/别名/用量   │
└─────────────────────────────┘
```

三个平面：

1. **控制面**：Admin REST API（令牌签发/撤销、授权管理、用量查询）+ `aweshare-hub` CLI + `aweshare-agent grant|doctor` 等管理命令。
2. **数据面**：消费者 HTTPS 端点 ↔ 反向隧道 ↔ Agent ↔ 上游后端，双向流式。
3. **隧道面**：Agent 到 Hub 的单条出站 WSS 连接，多路复用所有请求。

生产者不需要任何入站可达性：无监听端口、无公网 IP、无端口映射。Agent 是纯出站长驻进程；进程停止即别名下线（消费者收到 503 `PRODUCER_OFFLINE`）。

## 3. 令牌与授权模型

无账号体系，三类令牌，均在签发时完整显示一次、库中只存 `SHA-256(token + pepper)` 哈希（pepper 为 `hub init` 生成的文件，0600）：

| 令牌 | 前缀 | 持有者 | 用途 |
|---|---|---|---|
| 生产者令牌 | `asp_` | 生产者 | Agent 连接隧道、注册 offerings、管理自己命名空间的授权 |
| 消费者密钥 | `asc_` | 消费者 | 调用 `/v1/*` 数据面端点 |
| 管理员令牌 | `asa_` | Hub 运维者 | 调 Admin API（签发/撤销令牌等），存 Hub 本地文件 |

令牌格式：`前缀 + 32 字节随机数的 base62`（不可猜测、可被 CLI 正则识别前缀归类）。支持撤销（`revoked_at` 置位），不支持过期（v1）。

**授权（grants）**：`grants(producer_id, consumer_id, alias)` 三元组白名单。生产者在自己的机器上执行 `aweshare-agent grant alice peng/gpt-4o`，Agent 持生产者令牌调 Hub Admin API 完成——不经 Hub 管理员，也不触碰上游 Key。消费者请求某别名时，Hub 校验三条：别名存在 ∧ 其属主已授权该消费者 ∧ 该生产者隧道在线且未降级。

**命名空间**：生产者令牌签发时确定 `name`（如 `peng`），它同时是该生产者所有别名的命名空间前缀。别名 `peng/gpt-4o` 只能由 name 为 `peng` 的生产者注册，register 时强制校验。

## 4. 数据面：消费者端点与路由

### 4.1 端点

| 端点 | 协议 | 说明 |
|---|---|---|
| `POST /v1/chat/completions` | openai | OpenAI SDK / Codex（`wire_api="chat"`） |
| `POST /v1/messages` | anthropic | Claude Code / Anthropic SDK |
| `GET /v1/models` | openai | 列出该消费者密钥当前被授权且在线的别名（含 protocol、状态），供工具发现模型 |

鉴权同时接受 `Authorization: Bearer asc_…`（OpenAI 系）与 `x-api-key: asc_…`（Anthropic SDK）。Hub 会在转发前剥掉消费者的鉴权头，消费者的密钥与上游 Key 在隧道上不共存。

### 4.2 别名与路由

- 别名格式 `命名空间/名称`：命名空间 `^[a-z0-9][a-z0-9-]{1,31}$`（即生产者 name），名称 `^[a-z0-9][a-z0-9._-]{0,63}$`（不含冒号，Ollama tag 的 `:` 用 `.` 表达，如 `alice/qwen2.5.7b`）。整体形如 `peng/gpt-4o`。
- 每个别名由属主注册时绑定：`protocol`（openai | anthropic）与 `upstreamModel`（真实上游模型 ID，可与公开别名不同；必须用后端真实标识，如 Ollama 的完整 tag）。
- **路由是确定性查找**：请求体 `model` 中的别名全局唯一、属主唯一 → 直接定位唯一生产者。不存在候选集选择问题。别名属主不在线 → 503 `PRODUCER_OFFLINE`；其后端降级 → 503 `BACKEND_DEGRADED`。
- 协议检查：别名注册的 protocol 必须与所打端点一致，否则 400 `PROTOCOL_MISMATCH`。
- **请求方向改写**：Hub 解析请求 JSON body 取 `model` 完成路由后，把 `model` 改写为 `upstreamModel` 再上隧道（请求体必然是 JSON，解析成本可接受）。**响应方向纯字节透传**，SSE 不做任何解析改写（用量提取走旁路 tee，见 §7）。

### 4.3 短时调用 ticket

消费者请求通过鉴权 + 授权后，Hub 在内存铸造：

```
{ requestId, consumerId, producerId, alias, protocol, expiresAt = now + 120s, used: 单次 }
```

ticket 把一次消费请求与特定生产者隧道会话绑定：限时（防陈旧请求滞留）、单次（防重复派发）、并作为 request/response 事件关联与日志贯穿的审计单元。这是 Hub 内部机制，消费者无感知（标准 SDK 无法支持换取式票据）。过期由定时清扫回收。

## 5. 隧道线协议（packages/protocol）

Agent 出站连接 `wss://<hub>/ws/v1/producer`，HTTP Upgrade 头携带 `Authorization: Bearer asp_…`。

### 5.1 JSON 文本帧（控制面）

| 方向 | 消息 | 载荷 |
|---|---|---|
| Hub→Agent | `hello` | `{wireVersion}`（不匹配 close 4406） |
| Agent→Hub | `register` | `{offerings: [{alias, protocol, upstreamModel, backendId, maxConcurrency}]}`（幂等 upsert，未出现的别名删除；强制命名空间校验） |
| Hub→Agent | `registered` | `{accepted: [...], rejected: [{alias, reason}]}` |
| Agent→Hub | `heartbeat` | `{backendStatus: {backendId: ok\|degraded, reason?}}`，每 15s |
| Hub→Agent | `request.start` | `{requestId, protocol, method, path, headers(已消毒), query}` |
| Hub→Agent | `request.end` | `{requestId}` |
| Hub→Agent | `request.cancel` | `{requestId}` |
| Agent→Hub | `response.head` | `{requestId, status, headers}` |
| Agent→Hub | `response.end` | `{requestId}` |
| Agent→Hub | `response.error` | `{requestId, code, status, message}`（如 `BACKEND_UNREACHABLE`、上游 4xx/5xx 透传） |

所有 JSON 帧都带 `requestId`（register/hello/heartbeat 除外）。

### 5.2 二进制帧（数据面）

```
[16 字节 requestId][payload，≤ 64KiB]
```

**方向区分语义**：Hub→Agent 的二进制帧是请求体分片（`request.chunk`），Agent→Hub 是响应体分片（`response.chunk`）。无需帧类型字节——每条连接上两个方向各只有一种数据流。这是相对 fasten（20 字节头 + magic + 帧类型）的简化，成立的前提是请求/响应分片永不混向。

### 5.3 可靠性语义

- **背压**：发送方 `ws.bufferedAmount > 1MiB` 时暂停从源流读取，降下去后恢复；响应分片上限 64KiB/帧。
- **取消**：消费者断开或中止 → Hub 发 `request.cancel` → Agent abort 上游 fetch，双方释放资源。
- **心跳**：协议层 `heartbeat` 15s + WS ping/pong；超时未收即判定连接死亡。
- **重连**：Agent 指数退避 1.5s→15s 重连并重新 register。
- **latest-wins**：同一生产者令牌的新连接建立后，旧连接被 Hub 关闭。生产者任意时刻只有一个活跃隧道会话。
- **超时**：消费请求流式空闲超时 300s（504）；ticket TTL 120s。

## 6. Agent 设计

### 6.1 CLI 命令

```
aweshare-agent init      # 向导：hub 地址、贴 asp_ 令牌、配置 backends/offerings、写入密钥
aweshare-agent start     # 长驻进程：出站 WSS + 注册 + 心跳 + 转发
aweshare-agent grant <consumer> <alias>     # 授权（调 Hub Admin API）
aweshare-agent revoke / list
aweshare-agent doctor    # 上线前置预检（见 6.4）
```

### 6.2 配置与密钥

- `~/.aweshare/config.toml`：`hubUrl`、producerToken（或其 keyRef）、`backends[] {id, protocol, baseUrl, keyRef}`、`offerings[] {alias, backend, upstreamModel, maxConcurrency}`。可进 git（不含密钥）。
- `~/.aweshare/secrets.json`：上游 API Key 按 keyRef 存放，0600 权限、tmp+rename 原子写。本地 Ollama 无需 key 则不配。
- **上游 Key 的唯一消费者是 Agent 本地适配器**；register 消息、隧道报文、Hub 日志中永不允许出现密钥材料（端到端测试含断言）。

### 6.3 协议适配器

| 后端协议 | baseUrl 约定 | 注入 |
|---|---|---|
| openai 型（OpenAI/Ollama/vLLM/LM Studio 等） | 含 `/v1`，如 `http://127.0.0.1:11434/v1`（与 OpenAI SDK base_url 惯例一致） | `Authorization: Bearer <key>` |
| anthropic 型 | 不含 `/v1`，如 `https://api.anthropic.com`（SDK 自拼 `/v1/messages`） | `x-api-key: <key>` + `anthropic-version`（透传消费者带来的 version，缺省 `2023-06-01`） |

请求上隧道前 Hub 已消毒：剥消费者鉴权头与 hop-by-hop 头。Agent 收到后拼 `baseUrl + path`、注入上游凭证、以 `duplex: 'half'` 流式转发 body，响应逐块 ≤64KiB 分片回传。SSE 即字节透传。

### 6.4 doctor（上线前置，采纳自 fasten 诊断经验）

按固定顺序逐项排查，定位「第一个失败的环节」，Hub 永远最后怀疑：

1. 逐 backend 用完全相同的 baseUrl/协议/真实模型 ID/key 发最小非流式探测请求（直连重放）
2. 检测 baseUrl 与路径的 `/v1` 重复拼接（最高频错误）
3. 协议选择与后端实际请求格式匹配
4. upstreamModel 是后端真实标识（Ollama 用 `ollama list` 完整 tag）
5. key：多余空格、权限、余额
6. 本地网络（Ollama 监听范围、Docker 内 127.0.0.1 指向容器自身等）
7. 最后：与 Hub 的隧道连通性

### 6.5 健康门

生产者侧按 backend 记录连续失败，失败原因分类 `AUTH | QUOTA | HTTP | NETWORK | CANCELLED`。`AUTH`/`QUOTA` 类连续失败立即把该 backend 标记 degraded，随心跳上报；Hub 据此把相关别名对消费者呈现为 degraded（不再派发），`doctor` 或恢复探测通过后自动恢复。

### 6.6 并发

offering 级 `maxConcurrency`，**默认 1**（本地模型 VRAM/内存的现实约束），由 Agent 在 register 时声明，Hub 据此对超并发的消费请求直接回 429（`PRODUCER_MAX_CONCURRENCY`）。云端 API 用户自行调高。

## 7. 用量记录

- 每请求落一条：

```
usage_events(id, at, consumer_id, producer_id, alias, upstream_model, protocol,
             streaming, status, error_code, duration_ms, bytes_in, bytes_out,
             prompt_tokens NULL, completion_tokens NULL)
```

- token 数**尽力提取**：非流式从响应 JSON 提 `usage`；流式在 tee 旁路按 SSE 事件边界增量解析（OpenAI `stream_options.include_usage` 尾块；Anthropic `message_start` 的 input usage + `message_delta` 的 output_tokens）。解析失败记 NULL，绝不阻塞或改写响应流（Ollama 流式不带 usage，属预期内的 NULL）。
- **不持久化任何请求/响应内容**。Hub 作为中继必然能看到明文（见 §11 信任边界），但内容零落盘。
- 查询：`GET /admin/v1/usage`（生产者可查自己命名空间，消费者可查自己的）。

## 8. 错误语义

| HTTP | code | 场景 |
|---|---|---|
| 400 | `PROTOCOL_MISMATCH` | 别名协议与端点不符 / model 不是合法别名 |
| 401 | `INVALID_KEY` | 无效或已撤销的消费者密钥 |
| 403 | `NOT_GRANTED` | 别名存在但未授权该消费者 |
| 404 | `ALIAS_NOT_FOUND` | 别名不存在 |
| 429 | `RATE_LIMITED` / `PRODUCER_MAX_CONCURRENCY` | 超 per-consumer 限流（内存令牌桶，RPS+并发可配）/ 超生产者声明并发 |
| 502 | `UPSTREAM_ERROR` | 上游 4xx/5xx，`response.error` 携带上游 status 与 body 透传 |
| 503 | `PRODUCER_OFFLINE` / `BACKEND_DEGRADED` | 生产者隧道不在线 / 后端降级 |
| 504 | `STREAM_IDLE_TIMEOUT` / `TICKET_EXPIRED` | 流式空闲超 300s / ticket 过期 |

错误响应体统一 `{error: {code, message, requestId}}`，`requestId` 贯穿 Hub/Agent 日志便于排查。所有 JSON 错误帧同样携带 code。

## 9. 存储模型

SQLite（`better-sqlite3`），Hub 启动时执行 schema（`PRAGMA user_version` 管理版本）：

```
producers(id, name UNIQUE, token_hash UNIQUE, created_at, revoked_at)
consumers(id, name UNIQUE, token_hash UNIQUE, created_at, revoked_at)
grants(producer_id, consumer_id, alias, created_at, PRIMARY KEY(producer_id, consumer_id, alias))
offerings(alias PRIMARY KEY, producer_id, protocol, upstream_model, max_concurrency, updated_at)
usage_events(id, at, consumer_id, producer_id, alias, upstream_model, protocol,
             streaming, status, error_code, duration_ms, bytes_in, bytes_out,
             prompt_tokens, completion_tokens)
```

- offerings 由 Agent register 幂等 upsert（未出现的别名删除），真相源在生产者 config，Hub 只是缓存。
- 会话、ticket、限流状态、健康状态均为内存态，Hub 重启即重建（生产者重连重新注册）。

## 10. 仓库结构、部署与测试

```
aweshare/
├── package.json          # pnpm workspaces
├── packages/protocol/    # 线协议消息、二进制帧 codec、错误码、别名校验（Hub/Agent 共享）
├── apps/hub/             # Fastify HTTP + ws + better-sqlite3 + Admin CLI（bin: aweshare-hub）
├── apps/agent/           # CLI Agent（bin: aweshare-agent）
└── docs/
```

- 技术约定：Node ≥ 22、TS strict、vitest、pino 结构化日志（requestId 贯穿）、biome。
- 部署：Hub 用 Docker Compose 一键起（卷挂载数据目录：SQLite + pepper + admin token）；Agent 走 npm 分发（`npx aweshare-agent`）。
- **测试策略**——产品承诺是「消费者零改动」，所以集成测试直接用真实 `openai` 与 `@anthropic-ai/sdk` 包打 Hub，上游用进程内 mock SSE 服务器：
  - 集成：流式/非流式、AbortController 中途取消、生产者掉线→503→重连恢复、grants 矩阵、PROTOCOL_MISMATCH、并发上限 429、背压、用量落库、隧道报文无密钥泄漏断言。
  - 单元：帧 codec 往返 + fuzz、别名校验、令牌哈希、grant 判定、SSE tee 解析器、健康门状态机。

## 11. 文档义务（README 必须显式陈述）

- **信任边界**：为完成路由与计量，消费者提示词与模型响应都经过 Hub，**不是端到端加密**。Hub 不持久化内容，但运维者技术上可见明文。生产者与消费者都应只信任自己信得过的 Hub 实例（这也是开源 Hub + 自建部署的意义）。
- **合规**：能自己调用 ≠ 有权转授第三方。转授付费 API key 给他人使用可能违反上游服务商条款（OpenAI/Anthropic 的 ToS 对 API key 使用主体有限制），合规责任在生产者；自部署开源模型无此问题。
- **密钥卫生**：使用专用最小权限、可撤销、带预算告警的 key；不粘贴进截图/日志/git；疑似泄露立即轮换；`secrets.json` 保持 0600。
- **消费端工具坑**：
  - Claude Code：填的 key 是 `asc_` 消费者密钥，不是任何上游 `x-api-key`；旧 OAuth 登录态会覆盖环境变量配置，需 `/login` 切换或清理 credentials。
  - Codex：v1 不支持 Responses API，必须 `wire_api = "chat"`。
- **首跑顺序**：生产者 `doctor → grant → start`；消费者 `curl 小请求 → 确认用量记录 → 小任务 → 真实负载`。

## 12. MVP 验收标准

1. 真实 openai SDK、@anthropic-ai/sdk、curl 经 Hub 流式/非流式全通。
2. 生产者在 NAT 后（无公网、无端口映射）共享本地 Ollama 与云端 API 后端。
3. 上游 Key 全链路不出生产者设备（端到端测试断言）。
4. 每请求一条用量记录，token 尽力提取，内容零持久化。
5. §8 错误语义全表行为正确。

## 13. 风险与已知限制

- Codex v1 仅 `wire_api="chat"`（无 Responses API）。
- Ollama 流式无 `include_usage` → tokens 记 NULL（尽力而为的既定行为）。
- Hub 明文可见（§11）；未来若需要，可在消费者↔Hub 与 Agent↔Hub 之上叠加密，但 v1 不做。
- 单 Hub 单实例 + SQLite；多实例路由表同步、水平扩展超出 v1。
- WS 隧道经部分企业代理可能受限（WebSockets over corporate proxies），属环境限制，如实记录。

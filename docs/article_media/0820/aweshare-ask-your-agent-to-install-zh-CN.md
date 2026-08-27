# aweshare：我让 AI 智能体帮我共享 token

![aweshare](../../../logo/logo.png)

现在模型越来越贵了，虽然现在有 [awerouter：不怕deepseek 涨价，一句话让智能路由给你省钱](https://mp.weixin.qq.com/s/8jucVeQWQRjCIUEXxj-fHQ) ，但能不能再省点？而且，其实还有很多空间：角落里的 4090 闲着，朋友们够不到的订阅 key 买了却用不满，这可怎么办？

aweshare 用本地优先的中继终结这件事。你在自己机器上跑一个轻量 agent；朋友把标准 OpenAI / Anthropic SDK 指向 hub；请求经一条 WebSocket 隧道转回你的机器，由你的 key 在调用时注入。共享出去的从来不是 key，而是按 token 计量的能力——来自闲置 GPU，或你已付费的订阅。有闲置的出力，需要的作为消费者去使用。

它还押了第二个注：中继需要有人配置和维护，而这个人不必是你。aweshare 自带引导协议（`README.ai.md`）、skill 和 CLI，可以由 AI 智能体端到端操作。于是我对我的智能体说：

> "阅读 https://github.com/wehuman01/aweshare/blob/main/README.ai.md 并照做。我有一张 4090，Ollama 跑着 qwen2.5:7b 和 qwen2.5:14b，另有一张 GLM coding plan 的 key——都共享给两个朋友。"

它先问了我的角色（producer），把两个 Ollama 模型注册为 offering、各设 `maxConcurrencyPerUser = 1`（本地模型，单卡）；把 GLM 订阅挂成 `peng/glm-4-flash`，配上 `dailyTokens` 日额度——订阅额度是真金白银；然后铸好两个邀请码，又跑了 `producer doctor` 验证 配置 → 后端 → hub 整条链路。朋友们自己兑换邀请码：`aweshare consumer join` 只打印一次 `asc_` key，附上可直接粘贴的 SDK 环境变量。

然后它说："请在你的终端里运行 `aweshare producer start`。我不会替你启动这个长驻进程。"

这就是安装一个智能体工具的新形态：安装是一项任务，而智能体就是干任务的。于是我把任务交给了智能体。

GitHub：[github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## 安装：一份智能体照做的引导协议

大多数智能体工具给人类一份 `README.md`，给智能体另备一份 `README.ai.md`。这个拆分很诚实：人类要的是产品故事，智能体要的是操作流程。aweshare 把这点做透了——它的 `README.ai.md` 是一份引导协议（bootstrap protocol）：先确认用户角色（hub 运营者、生产者、消费者），安装 CLI，安装 skill，探测现有安装，再走对应角色的路径。凡是打印一次性令牌或启动长驻服务的步骤，都明确交回你自己的终端。

生产者路径，浓缩版：

1. `npm install -g aweshare`（Node ≥ 22），用 `aweshare --version` 验证
2. 在 VPS 上 `aweshare hub init` —— 创建数据目录并打印一次性 admin token，抄下来（Docker 也行：`ghcr.io/wehuman01/aweshare`，然后 `docker exec aweshare-hub aweshare hub init`）
3. `aweshare hub serve` —— 你的终端，不是智能体的
4. `aweshare hub invite --name <name>` 铸造一次性生产者邀请码（`asi_...`）；消费者用 `--role consumer --name <name>`。邀请码默认 7 天过期，且过期同样约束它换出的身份——过期 key 认证返回 `401 TOKEN_EXPIRED`，隧道随之关闭。`--expires-in none` 铸造永不过期的一对。
5. 在生产者机器上 `aweshare producer join --hub <url> --code asi_...`，写入 `~/.aweshare/config.toml` 和 `secrets.json`
6. 编辑 `config.toml` 注册后端（`openai`、`anthropic`、`responses` 三种协议）和 offering —— 别名 `命名空间/名称`，每条恰好一个上游模型；或用 `backends = [...]` 列表让同一个别名同时讲多种线上协议。上游 key 放进 `secrets.json` —— 它们不会离开这台机器。
7. `aweshare producer doctor` —— 配置 → 后端 → hub，修第一个 FAIL，重跑直到全绿
8. 告诉用户去运行 `aweshare producer start`

准入完全走邀请码，这就是全部的权限模型：每个被准入的消费者都可以调用 hub 上全部 offering。没有授权要接线，没有市场。护栏是限额——稀疏的按消费者覆盖（`hub limits` 的 `--rps`、`--tpm`、`--max-total-tokens`；未设置的键沿用全局默认）和按 offering 的限额（`maxConcurrencyPerUser`、`maxConcurrentUsers`、`dailyTokens`）——全部由 hub 强制执行。

### 30 秒版本

在 Claude Code、Codex、OpenCode，或 aweskill 支持的 47+ 个智能体里的任何一个，提示词都一样：

> "帮我装 aweshare。阅读 https://github.com/wehuman01/aweshare/blob/main/README.ai.md 并照做。我有一张闲置 GPU，Ollama 跑着 qwen2.5:7b 和 qwen2.5:14b，另有一张 GLM coding plan 的 key，我的 hub 在 hub.example.com。"

剩下的智能体全包：安装 npm 包和 skill、初始化 hub、铸造邀请码、写配置、注册 offering、跑 doctor。哪一步失败——Node 太旧、Ollama 没在跑、hub 连不上——它会停下来问你，而不是默默把东西弄坏。

### 智能体不会做的事

这是最重要的边界。aweshare 有两个长驻进程：hub（`aweshare hub serve`）和 producer（`aweshare producer start`）。智能体永远不会运行其中任何一个——也不会运行 `producer stop`，更不会用 Docker 部署 hub。它永远不会启动、停止或重启服务器或隧道。

README 里写明了。skill 里也写明了。安全规则毫无歧义：长驻守护进程属于用户的终端。智能体的工作是配置——`init`、`invite`、`producer join`、`producer doctor`、`hub limits`、`hub usage`、编辑 `config.toml`。连上游 key 都不进聊天：智能体写好配置骨架，让你自己填 `secrets.json`。智能体活在文本文件的世界，守护进程活在 socket 的世界，两者不相交。

这条边界不牺牲任何便利，因为改配置已经不需要重启：两个进程都会在两秒内热应用有效的修改，`aweshare producer reload` 在既有隧道上重新注册 offering，不断连。日常的中继管理——列消费者、查用量、加 offering、设限额、发邀请码——全部可以由智能体执行。只有真正的 hub 和 producer 进程要你自己在自己的终端里启动。（想要进程脱离终端时可以用 `producer start --background` —— 依然是你的决定、你的终端。）

## 日常一天

这是周二。hub 跑在一台 6 美元的 VPS 上。你的 agent 从台式机连着。两个朋友有消费者令牌。

**早上 7:42。** 新的一天开始。`aweshare producer start` 从昨天起一直在跑。你想看看昨晚中继得怎么样：

```
aweshare hub usage
```

默认视图是聚合，不是日志：一行一个 消费者 × 模型，同一个人的行聚在一起，最忙的人和最忙的模型排前面——请求数、错误数、尽力提取的 token 总量、平均耗时——表头打印着默认的 7 天窗口。昨晚：`peng/qwen2.5.7b` 847 次请求，`peng/qwen2.5.14b` 312 次，订阅端的 `peng/glm-4-flash` 也记了一整晚；7B 平均延迟 1.2 秒、14B 2.8 秒，零错误、零限流。想看逐请求日志？`--details`。只想看某个人？`--consumer bob`。你记下一笔：查查 14B 是不是超卖了。

**上午 9:15。** 朋友发消息："能试试你的模型吗？"你对智能体说：

> "邀请 alice 作为消费者。"

智能体运行 `aweshare hub invite --role consumer --name alice`，把一次性邀请码（`asi_...`）交给你转发——它 7 天后过期，让她尽快兑换。Alice 自己兑换——`aweshare consumer join` 只打印一次她的 `asc_` key，附上可直接粘贴的 SDK 环境变量；没装 aweshare 的朋友一条 curl 也能兑换。她发了个测试请求，拿到响应。你没碰任何配置文件，没重启任何东西。准入即权限：她一进来，就能调用 hub 上全部 offering。

**上午 11:30。** 你想再共享一张订阅。你对智能体说：

> "把我的 Anthropic 订阅也共享出去。key 在 secrets 里。"

智能体读取 `~/.aweshare/config.toml`，添加 `protocol = "anthropic"` 的后端，注册 `peng/claude-sonnet` 作为 offering，把 key 引用指向 `secrets.json`，再配一个 `dailyTokens` 日额度护住订阅配额。然后 `aweshare producer reload` 在既有隧道上应用新的 offering——不重启、不断连，消费者毫无感知。没有复制粘贴，没有"我先找找文档"。

**下午 1:00。** Bob 跑了个批处理任务，GPU 和订阅额度一起吃紧。你想设个限制：

```
aweshare hub limits bob --rps 2 --tpm 60000
```

智能体应用这个稀疏覆盖——每秒 2 个请求、每分钟 6 万 token。未设置的键沿用全局默认；覆盖会合并进已有的设置。你不需要记 CLI 参数，智能体记得。

**下午 3:00。** 想确认一切健康：

```
aweshare producer doctor
aweshare hub status
```

doctor 探测后台实例、配置、后端和 hub 连接——全绿，`4/4 offerings registered`。`hub status` 给出运营者总览：按别名的健康状态（一个别名讲多种协议只给一个结论、取最差）、实时占用 `IN USE 1/3`、当日剩余 token，以及最近 5 分钟一行——请求数、成功率、错误数。14B 模型已经连续跑了 6 个小时，没有一次 AUTH 或 QUOTA 失败。

**晚上 6:00。** 收工。三个后端——一张闲置 GPU 加两张订阅——四个 offering、四个消费者、两个带按消费者限额。智能体处理了每一次配置变更，hub 处理了每一个请求，producer 处理了每一次中继。你从头到尾没手动打开过 `~/.aweshare/config.toml`。

## 技能可以触达的命令栈

`aweshare` skill 刻意做得很小。它不试图成为通用智能体框架，只是 `aweshare` CLI 上面薄薄一层过程化封装，加上一个把自然语言映射到命令的意图路由。

| 你说 | 技能执行 |
|---|---|
| "这周谁用了我的模型？" | `aweshare hub usage` —— 按消费者 × 模型聚合，最忙在前 |
| "邀请 alice 作为消费者。" | `aweshare hub invite --role consumer --name alice` |
| "把我的 Anthropic 订阅也共享出去。" | 编辑 `config.toml` + `secrets.json`，注册 offering |
| "应用我的配置修改。" | `aweshare producer reload` —— 不重启、不断连 |
| "给 bob 限到每秒 2 个请求、每分钟 6 万 token。" | `aweshare hub limits bob --rps 2 --tpm 60000` |
| "hub 现在怎么样？" | `aweshare hub status` —— 别名健康、实时占用、最近 5 分钟 |
| "我的 producer 健康吗？" | `aweshare producer doctor` |
| "现在谁在 hub 上？" | `aweshare hub list producers` / `hub list consumers` —— producers 显示实时 ONLINE 状态 |
| "我能调哪些模型？" | `aweshare consumer list --hub <url> --token asc_...` |

最后一行最让人惊讶。大多数人早忘了自己几周前加入的 hub 上共享了什么。发现视图列出每个生产者、别名、协议、按别名的限额、实时占用（`IN USE n/max` —— 此刻有请求在途的不同消费者数）和当日剩余 token。Offline 的 offering 默认隐藏——离线生产者的别名本来就调不通，只是噪音——加 `--all` 才显示；degraded 的仍然列出，因为生产者还在线，只是上游短暂失败。有人捣乱的话，挂起只需一条命令且可逆：`hub revoke --id N` 把邀请码和它换出的身份一起挂起（撤销已兑换的生产者码会连带关闭其隧道），`hub restore --id N` 把两者一起救回。挂起不删除任何数据——offering 和用量记录完整保留。

## 生产者、消费者、hub：三种角色，一条隧道

架构是三个角色，中间一条隧道：

**生产者。** 你在自己的机器上运行 `aweshare producer start`。agent 向 hub 打开一条出站 WebSocket 连接。不需要公网 IP，不需要端口映射，不需要防火墙规则。它注册你的 offering、在转发时注入上游 key，并自动处理健康降级：后端连续两次 AUTH 或 QUOTA 失败即标记 degraded（该别名停止派发），每 30 秒一次的探测让它静默恢复。配置修改热应用——进程两秒内重读 `config.toml` 和 `secrets.json`，不断开隧道就重新注册 offering；只有 `hubUrl`/`token` 需要重启。同一令牌的重连会替换旧隧道（latest-wins），退避带抖动，hub 重启时不会让所有生产者同时扑上来。

**消费者。** 你的朋友把标准 SDK 指向 hub。Claude Code、Codex、OpenCode、任何 OpenAI 兼容工具——零改动全部可用。模型名是 `命名空间/别名`（如 `peng/qwen2.5.7b`），API key 是他们的消费者令牌（`asc_...`）。他们看不到你的上游 key，也不知道你的后端地址。而且一个别名可以同时讲多种线上协议——把同一个名字注册到 `openai`、`anthropic`、`responses` 多个后端上，无论朋友用哪个 SDK 调，hub 都路由到对应的线上协议。永远不做协议转换。

**hub。** 一个带 SQLite 的 Node 单进程，跑在 6 美元的 VPS 上——npm 或 Docker 镜像皆可。它认证令牌、执行限流和按别名的限额、改写模型别名、经 WebSocket 隧道中继请求。每请求一行用量，内容零落库。hub 甚至可以自己挂模型：`config.produce.toml` 里的 `[[backends]]`/`[[offerings]]` 段加上 `aweshare hub produce`，进程内直接服务 `hub/…` offering——不需要生产者机器，限额与计量完全一致。只有 hub 需要公网端点——生产者和消费者都可以待在 NAT 后面。

信任边界是明示的：消费者的提示词与模型响应以明文经过 hub。hub 不存储任何内容，但 hub 运维者技术上看得见。这也是 hub 开源、可自建的原因——跑你自己的 hub，信你自己的 hub。而上游 key 永不离开生产者的设备——它由本地 agent 注入，也只有本地 agent 能注入。

## Claude Code、Codex、OpenCode 与其他agents

同一套消费者配置在各个客户端通用。

**Claude Code** 是最常见的消费者。把 `ANTHROPIC_BASE_URL` 指向 hub，`ANTHROPIC_API_KEY` 填消费者令牌。`--model` 参数直接用别名：`claude --model peng/sonnet`。如果 Claude Code 残留旧 OAuth 登录态，它会覆盖环境变量配置——用 `/login` 切换或清理已存的凭证。

**Codex** 默认走 Responses 线协议。`responses` 协议的 offering 开箱即用；`chat` 协议的 offering 在 Codex 配置里加 `wire_api = "chat"` 即可。模型别名写进 provider 配置，Codex 把它当普通模型对待。

**OpenCode** 用同样的方式走 `openai-chat` 或 `openai-responses`。把 `OPENAI_BASE_URL` 指到 hub 的 `/v1` 端点，按别名开始调用。OpenCode 的 `@`-agent 调用可以把子任务路由到不同模型——aweshare 负责上游中继，OpenCode 负责智能体选择。

**Cursor、Gemini CLI、Windsurf** —— 任何会说 OpenAI Chat Completions、Anthropic Messages 或 OpenAI Responses 的客户端都可以。`GET /v1/models` 返回 hub 上注册的全部别名及在线状态。协议层会检测不匹配并返回清晰的 400 `PROTOCOL_MISMATCH`，而不是悄悄把响应体搅乱。

## 用量分析：谁用了什么

中继只是一半问题。另一半是知道中继用得公不公平。

aweshare 每个请求往 hub 的 SQLite 里写一行——别名、真实模型、状态、耗时、尽力提取的 token 数——**内容零落库**。`usage` 系列命令默认回答"谁用了多少"，而不是"翻日志"：

- **`hub usage`** —— 服务端聚合，一行一个 消费者 × 模型：同一个人的行聚在一起，最忙的人和最忙的模型排前面。请求数、错误数、尽力提取的 token 总量、明确的未知 token 行数、平均耗时。窗口默认 7 天并随表头打印（`--since 30m|12h|7d|all`）；`--group-by consumer` 收粗到每人一行，`--group-by alias` 收粗到每模型一行。
- **`hub usage --consumer bob`** —— 看 Bob 到底在干什么，聚合视图和 `--details`（逐请求日志，新在前，每行标明消费者）都行。他是不是凌晨 3 点在跑批处理？是不是一小时打了 200 次 14B？数据都在。
- **`producer usage`** —— 生产者机器上的同款视图，自动限定在自己模型那份。
- **`hub list consumers`** —— 名册，带状态和最近活跃。有人捣乱？`hub limits bob` 限流，`hub revoke` 挂起——可逆。

Token 计数是诚实的：只统计上游报告的用量。Ollama 流式响应不带 usage，这些行计入未知 token；OpenAI 和 Anthropic 流会报告 usage，数字如实记录。终身 token 预算（`maxTotalTokens`）是精确的，因为它对已落库的行求和——没有滑动窗口，没有尽力而为。

## 为什么这很重要

第一波共享工具假设操作者是人。共享意味着"这是我的 API key，放进你的环境变量"。授权意味着"我把你加进我的 OpenAI 账号"。多数用户忍了，因为要共享的对象只有一个人。

第二波假设操作者是智能体。共享是一项任务，准入是一项任务。上游 key 永不暴露——不暴露给消费者，不暴露给 hub，甚至不暴露给配置工具的智能体。被委托出去的东西不是 key，而是一份智能体能执行的、可读的规格。

aweshare 还有第二条让它区别于多数中继工具的设计约束：隧道是**单向出站**的。生产者的 agent 通过 WebSocket 主动外连 hub，hub 永远不回拨。这意味着生产者可以待在任何 NAT、任何防火墙、任何放行出站 HTTPS 的公司代理后面。没有端口映射，没有动态 DNS，没有静态 IP。agent 一连上，中继就通了。

这是我现在评估每一个共享工具的三连问：

1. **智能体能凭一句提示词装起来吗？**
2. **装好之后，智能体能用自然语言管理邀请和限额吗？**
3. **中继要求生产者暴露公网端点吗？**

aweshare 三项全过。第一问的答案是引导协议，第二问是 skill，第三问根本不成立：agent 打开一条出站 WebSocket，生产者的机器留在 NAT 后面，公网那一面由 hub 扛。

智能体工具的未来不是"能和智能体好好配合的工具"，而是"智能体能替你安装、配置、操作的工具"。aweshare 是第一批把这条路径当作主安装方式（而不是权宜之计）的中继工具。

## 试用

告诉你的智能体：

> "帮我装 aweshare。阅读 https://github.com/wehuman01/aweshare/blob/main/README.ai.md 并照做。"

然后在你自己的终端里启动 producer：

```bash
aweshare producer start
```

再把朋友们指向 hub：

```bash
export ANTHROPIC_BASE_URL=https://hub.example.com
export ANTHROPIC_API_KEY=asc_...
claude --model peng/qwen2.5.7b
```

没有常开的机器？项目开发者运营着一个邀请制的社区 hub：**https://aweshare.wehuman.top** —— 向 peng@wehuman.top 申请邀请码，以生产者或消费者身份加入。

接下来，问题都会变得很日常：

- "邀请 alice 作为消费者。"
- "bob 这周用了什么？"
- "把我的 Claude 订阅也共享出去。"
- "给 alice 限到每分钟 6 万 token。"
- "我的 producer 为什么掉线了？"

智能体本来就懂这些命令，只是你还没把 README 给它。

## mugpeng 的其他项目

awewarm 是 aweteam 生态的一部分：

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI 优先的技能包管理器，支持 47+ AI 编程 agent
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Claude Code、Codex、OpenCode 的 agent 配置切换器
- **[awerouter](https://github.com/mugpeng/awerouter)** — 智能路由器，用结构信号把请求分给 Flash 或 Pro 模型，减少不必要的模型开销
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — 收藏、分类、恢复 AI 编程会话，还能搭配aweswitch 实现保存配置，一键启动
- **[aweshare](https://github.com/wehuman01/aweshare)** — 通过自建 Hub 共享本地 Ollama/vLLM 或已授权的 OpenAI/Anthropic 后端，实现token 的共享经济
- **[awewarm](https://github.com/mugpeng/awewarm)** — 订阅窗口保持器，让 AI 编程套餐的窗口持续激活，无论是本地设置，还是通过远程连接的服务器


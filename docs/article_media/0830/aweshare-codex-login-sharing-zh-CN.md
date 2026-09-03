# aweshare 更新：把某gpt订阅共享出去 

![aweshare](../../logo/logo.png)

用 Codex 的人手里多半有一份 ChatGPT Plus/Pro 订阅。订阅里的 Codex 额度其实很充裕，但绝大多数时间在闲置——想借给朋友用，却发现根本没 key 可给：Codex CLI 走的是 ChatGPT 账号登录，不是 API key。aweshare 之前只能共享 key 型的后端，订阅始终够不着。

这次更新补上了这块：backend 可以声明 `login = "codex"`，直接用你本机的 `codex login` 做认证，把 ChatGPT 订阅的 Codex 能力作为一条 offering 共享出去。

GitHub：[github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## 生产者：两行配置上架订阅

```toml
[[backends]]
id = "codex-account"
protocol = "responses"
baseUrl = "https://chatgpt.com/backend-api/codex"   # 只允许官方上游
login = "codex"                                     # 用本机 codex login 代替 key；与 keyRef 互斥

[[offerings]]
alias = "gpt-5.6-codex"    # 注册后自动带上你的命名空间
backend = "codex-account"
```

不用往 `secrets.json` 里填任何东西——账号登录和 key 互斥，凭据读自 `${CODEX_HOME|~/.codex}/auth.json`，只存在于生产者进程的内存里。你在生产者机器上重新 `codex login`，运行中的 producer 会自动跟上（文件变化或收到 401 时重读），不需要重启。

几条写死的边界，防止账号凭据跑到不该去的地方：

- **上游锁死官方地址。** baseUrl 必须是 `https://chatgpt.com/backend-api/codex`，配置成别的协议或地址，catalog 加载时直接拒绝——凭据只可能发往 ChatGPT 官方后端。
- **hub 永远看不到凭据。** 请求还是由你电脑上的程序拿着登录态去敲上游的门，hub 只见到转发流量。
- **细节替你处理好了。** 生产者注入 Codex CLI 自己携带的原生请求头、强制 `store: false`（chatgpt 后端要求，而消费端工具不总是发送）、健康检查用登录安全的探测载荷，不会对账号后端打出 400/403。

也得如实说一句风险：账号登录是**账户级**凭据——解锁的是这个登录下的全部订阅，不像 key 只开一小块——共享它的封号风险和影响面，都比共享 API key 大。`aweshare producer doctor` 会把这条警示再讲一遍；干不干、担什么后果，都由生产者自己定。

## 消费者：不只是 Codex 能用

订阅上架后，目录里这条 offering 的 PROTOCOL 显示为 `openai-responses`——它说的是 Responses 线协议，端点在 `/v1/responses`。

看到 responses 先别急着划走：**能用它的不只有 Codex CLI**。OpenCode、ZCode 这类 agent 同样支持 responses 类型的接口，接法和接 OpenAI 几乎一样——把 provider 的 SDK（OpenCode 里的 `npm` 字段）换成 `@ai-sdk/openai`，URL 依然填 openai 风格的 hub 地址，模型名换成目录里的 alias 就行。

Codex CLI（`~/.codex/config.toml`）：

```toml
model = "alice/gpt-5.6-codex"
model_provider = "aweshare"

[model_providers.aweshare]
name = "aweshare"
base_url = "https://your-hub.example/v1"
wire_api = "responses"
env_key = "AWESHARE_API_KEY"
```

OpenCode（`opencode.json`）——注意只改 `npm`，`baseURL` 还是 openai 那个写法：

```json
{
  "provider": {
    "aweshare": {
      "npm": "@ai-sdk/openai",
      "options": {
        "baseURL": "https://your-hub.example/v1",
        "apiKey": "asc_..."
      },
      "models": {
        "alice/gpt-5.6-codex": {}
      }
    }
  }
}
```

ZCode 同理：provider 类型选 OpenAI Responses（同样对应 `@ai-sdk/openai` 这套 SDK），`baseURL` 一样填 hub 的 openai 风格地址。

反过来说，chat-completions 系的工具和 Claude Code 用不了这类 offering——这不是缺陷，协议本来就是这样。挑模型前看一眼 `consumer list` 的 PROTOCOL 列，就知道自己的工具接不接得上：

```text
PRODUCER  ALIAS               OBSERVED MODEL  PROTOCOL          STATUS  MAX USERS  IN USE  PER USER  DAILY TOKENS  REMAINING
alice     alice/gpt-5.6-codex gpt-5.6-codex   openai-responses  online  2          0/2     1         1000000       986412
```

护栏照旧：这个 alias 的并发人数、每人并发、每日 token 额度，跟 key 型 offering 一样由 hub 执行；用量照常记账。

## 一张速查表

| 你想做 | 怎么做 |
|---|---|
| 把 ChatGPT 订阅共享出去 | backend 写 `login = "codex"`，别填 keyRef |
| 换了账号重新登录 | 生产者机器上再跑一次 `codex login`，producer 自动跟上 |
| 确认凭据没被乱发 | baseUrl 锁死官方上游，配置错误在加载时直接被拒 |
| 用 Codex CLI 接入 | `wire_api = "responses"`，base_url 指向 hub |
| 用 OpenCode / ZCode 接入 | `npm` 换成 `@ai-sdk/openai`，baseURL 仍是 openai 风格地址 |
| 判断自己的工具能不能用 | 看 `consumer list` 的 `PROTOCOL` 列 |

一句话总结：以前能共享的是「钥匙」（API key），现在连「订阅」也能共享了——凭据不出生产者的门，消费者拿一条 alias 就能把订阅当普通模型用，用什么 agent 都行。

## 试试

### 让 AI agent 帮你装

在 Claude Code、Codex 或任何编程 agent 里说一句：

```text
阅读 https://github.com/wehuman01/aweshare/blob/main/README.ai.md 并按它安装和配置 aweshare。
```

### 或者自己动手

```bash
npm install -g aweshare   # 老用户直接升级即可

# 生产者：本机已 codex login 的话，两行配置就能上架订阅
aweshare producer config edit   # 加入 login = "codex" 的 backend 和对应 offering
aweshare producer doctor        # 检查注册状态（会重复账号共享的风险提示）

# 消费者：看看目录里有没有 responses 型的订阅 offering
aweshare consumer list --hub https://your-hub.example --token asc_...
```

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

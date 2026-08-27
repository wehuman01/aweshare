# aweshare 开发笔记：我把 Hub 藏到了 Cloudflare Tunnel 后面

![aweshare](../../logo/logo.png)

一台 VPS 跑着 aweshare Hub，一开始看起来一切正常。

请求能转发，producer 也在线，模型能用。可一想到 `3838` 可能直接露在公网，源站 IP 可能被顺手扒走，跑模型的那台电脑还要为 WebSocket 想办法，我就觉得这套东西还没真正安顿下来。

于是我做了一件很朴素的事：把 `aweshare.wehuman.top` 放到 Cloudflare Tunnel 后面。

下面就以 Hub 监听 `3838` 为例。Tunnel route 和容器配置里的端口要跟着保持一致；真正的安全边界仍然是不要把它发布到公网。

Hub 不再对公网开应用端口。`cloudflared` 从服务器主动往外连；不管是调用模型的人，还是跑 producer 的机器，看到的都只是 Cloudflare 边缘。

```
消费者 / producer agent
    → https://aweshare.wehuman.top
    → Cloudflare 边缘（TLS 在这里终止）
    → Cloudflare Tunnel（cloudflared 主动出站）
    → Docker 网络 aweshare-hub_default
    → aweshare-hub:3838
```

这张图看起来没什么惊天动地的。

但它让我终于能把几件事分开：Hub 只管路由请求；producer 继续把上游密钥留在本机；Docker 网络只负责内部通信；公网入口、TLS 和第一层防护，交给 Cloudflare。

根据这次部署留下的记录，2026-08-20 从两个网络跑 `curl https://aweshare.wehuman.top/healthz` 都拿到了 200；DNS 查到的是 Cloudflare 的边缘 IP，不是源站。

当然，这只是当天的实测，不是“现在肯定还这样”的保证。真要照着搭，Tunnel、Compose 网络、WAF 和镜像版本还是要重新检查一遍。

Hub 本身的路径也不复杂。调用方走 `/v1/messages`、`/v1/chat/completions`、`/v1/responses` 和 `/v1/models`；producer 从 `/ws/v1/producer` 主动连回来；管理操作在 `/admin/v1/*`。现在的 `/healthz` 还会带 `{ok, version, wire}`，排查时能确认自己到底打到了哪台 Hub。

真正有意思的，是搭完以后踩到的三个小坑。

## 1. `HEALTHY` 不等于“已经通了”

本文的 Tunnel route 写成 `http://aweshare-hub:3838`，用的是 Docker 的容器名 DNS。听上去顺理成章，直到你发现两个容器如果不在同一个 user-defined 网络里，`aweshare-hub` 这个名字就只是个美好的愿望。

还有个很容易让人放松警惕的绿色标记：Zero Trust 面板里的 `HEALTHY`。它只说明 `cloudflared` 成功连到了 Cloudflare，不代表 cloudflared 真能找到、真能连上 Hub。

所以最后别猜，跑这条：

```bash
curl https://aweshare.wehuman.top/healthz
```

它通了，才算从用户一路走到了 Hub。

## 2. 看到 WebSocket 502，别急着怀疑 Tunnel

我第一次拿一个没带 token 的 WebSocket 去探 `/ws/v1/producer`，外面看到的是 502。

这很像 Tunnel 配错了，对吧？其实未必。

Hub 收到没带 token 的 upgrade，会先写 401，再马上关 socket。401 还没来得及完整发出去，cloudflared 就先看到连接断了，于是外面可能显示为 502。探测体验不太优雅，但不代表带有效 token 的 producer 连不上。

最诚实的验证方式不是再造一个探针，而是直接让 producer 真接进来：

```bash
aweshare producer join --hub https://aweshare.wehuman.top --code asi_...
aweshare producer doctor
aweshare producer start
```

如果非要用 curl 测 upgrade，记得加 `--http1.1`。不然 ALPN 可能谈到 HTTP/2，`Connection: Upgrade` 被丢掉，请求最后变成普通 GET，拿到一个 404，又得白查半天。

## 3. 把门藏起来，不等于已经上了锁

Cloudflare Tunnel 解决的是入口暴露，不会替你管权限。

producer 邀请码 `asi_...` 虽然只能兑换一次，但在兑换前谁拿到谁就能用。它不是可以随手贴到群里的“激活码”，而是一张短命但真实的门票；别让它出现在群聊和日志里。

还有，Hub 的 `ports:` 真删掉、重新建过容器，`3838` 才算真正没有对外暴露。接下来调用方无需学新东西，还是熟悉的 SDK 配置：

```bash
# Claude Code / Anthropic SDK
export ANTHROPIC_BASE_URL="https://aweshare.wehuman.top"
export ANTHROPIC_AUTH_TOKEN="<consumer token>"

# Codex / OpenAI SDK
export OPENAI_BASE_URL="https://aweshare.wehuman.top/v1"
export OPENAI_API_KEY="<consumer token>"
```

Cloudflare Access 也别把整站一锅端。SDK 和 producer agent 碰上网页登录就没法干活；即使只拦 `/admin/v1/*`，远程 CLI 也得提前配好机器身份或例外规则，aweshare 的 admin token 本身过不了 Access。

剩下的交给程序自己跑。producer 每 15 秒报一次心跳，掉线后会带点随机抖动地指数重连；Hub 重启或隧道短闪，通常不用人守着救。

长请求还有一个现实限制：Cloudflare 默认 proxy read timeout 现在是 125 秒。流式响应尽快吐出第一个字节，自己的套餐和边缘配置再实测一遍，心里才有底。

Tunnel 没让 aweshare 多长出一层复杂架构。

它只是把“谁来面对公网”这件事，交给了更适合干这件事的那一层。Hub 继续转发能力，producer 继续守住密钥。该谁干的活，还是谁干。

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

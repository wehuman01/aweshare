# aweshare hub 服务器 Cloudflare 隧道保护部署笔记

- 日期：2026-08-20
- 域名：`aweshare.wehuman.top`
- 服务器上的容器：`aweshare-hub`（ghcr.io/wehuman01/aweshare:latest，数据在 `/data` 卷）、`aweshare-hub-cloudflare-tunnel-1`（cloudflared）

## 目标

hub 服务器**不开任何公网端口、不暴露源站 IP**，所有流量经 Cloudflare 边缘进入：

```
消费者 / producer agent
    → https://aweshare.wehuman.top （Cloudflare 边缘，TLS 终止）
    → Cloudflare Tunnel（cloudflared 出站连接建立的隧道）
    → cloudflared 容器
    → Docker 网络 aweshare-hub_default（容器名互查）
    → aweshare-hub:8787
```

aweshare hub 的对外路径（源码确认）：

| 路径 | 用途 |
|---|---|
| `GET /healthz` | 健康检查 |
| `POST /v1/messages`、`/v1/chat/completions`、`/v1/responses`、`GET /v1/models` | 消费者 API |
| `POST /v1/*`（同上） | Anthropic / OpenAI SDK 兼容 |
| `/ws/v1/producer` | producer agent 的 WebSocket 反向隧道 |
| `/admin/v1/*` | 管理 API（token、grant、usage、limits） |

## 部署步骤（已完成）

1. **域名 NS 托管到 Cloudflare** —— DNS 记录由 Cloudflare 接管。
2. **Zero Trust → Networks → Tunnels 创建 Tunnel**，拿到 token（dashboard 远程管理模式）。
3. **服务器上运行 cloudflared 容器**（compose 项目 `aweshare-hub-cloudflare`，命令为 `cloudflared --no-autoupdate tunnel run`，只需出站，无任何入站端口/防火墙规则）。
4. **Tunnel 配 Public Hostname**：`aweshare.wehuman.top` → `http://aweshare-hub:8787`。Cloudflare 自动生成 CNAME `<host> → <tunnel-id>.cfargotunnel.com`（橙色云代理生效）。
5. **确认两个容器在同一个 user-defined 网络**（本次实测都在 `aweshare-hub_default`，无需处理）：
   ```bash
   docker inspect aweshare-hub --format '{{json .NetworkSettings.Networks}}'
   docker inspect aweshare-hub-cloudflare-tunnel-1 --format '{{json .NetworkSettings.Networks}}'
   ```

## 验证结果（2026-08-20 实测）

```bash
curl https://aweshare.wehuman.top/healthz
# → {"ok":true}  HTTP 200（两个不同出口均确认）

dig +short aweshare.wehuman.top A
# → 172.67.136.241 / 104.21.7.159 （Cloudflare 边缘 IP，代理生效，源站 IP 不泄露）
```

producer 的 WebSocket：用真实 ws 客户端探测 `wss://aweshare.wehuman.top/ws/v1/producer`（无 token）得到 cloudflared 的 502，属预期表象（见坑 2），带 token 的真实 agent 走 101 升级不受影响。

## 踩过的坑

### 坑 1：tunnel route 用容器名，要求共享 user-defined 网络

route 写 `http://aweshare-hub:8787` 依赖容器名 DNS，而 Docker **默认 bridge 网络不做容器名解析**，只有同一个 user-defined 网络才行。若 hub 是 `docker run` 起的（默认 bridge）、cloudflared 在自己的 compose 网络里，请求会 530/1033。

修复（本次不需要，备用）：

```bash
docker network create aweshare-net
docker network connect aweshare-net aweshare-hub
docker network connect aweshare-net aweshare-hub-cloudflare-tunnel-1
```

另外注意：Zero Trust 面板里 tunnel 状态 HEALTHY 只代表 cloudflared→Cloudflare 的**出站**连接正常，**不代表它能解析/连上 hub**——必须靠 `curl https://<域名>/healthz` 验证最后一跳。

### 坑 2：未认证的 WS 升级返回 502（而非 401）

hub 源码（`apps/hub/src/tunnel.ts`）对无 token 的 upgrade 先 `socket.write('HTTP/1.1 401 ...')` 再立刻 `socket.destroy()`——401 可能还没 flush 出去 socket 就断了，cloudflared 读到中断的响应报 502。

- 影响：仅“无 token 探测”场景显示不友好；**带有效 token 的 agent 走 `handleUpgrade` → 101 正常路径，不受影响**。
- 判别方法（服务器上直连，绕过 tunnel）：
  ```bash
  curl --http1.1 -sS -o /dev/null -w '%{http_code}\n' \
    -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    http://127.0.0.1:8787/ws/v1/producer
  # 期望 401；若是空响应/重置也是同一个 race，不影响带 token 路径
  ```
- 可选源码修复：`socket.destroy()` 改为 `socket.end()`，保证 401 先发出去。

### 坑 3：用 curl 测 WebSocket 要强制 HTTP/1.1

curl 经 ALPN 可能协商到 HTTP/2，`Connection/Upgrade` 头在 H2 中非法会被丢弃，请求退化成普通 GET（hub 返回 404，容易误判）。测试要加 `--http1.1`，最好直接用 `ws` 客户端。

## 待办

1. ~~链路验证~~ ✅（2026-08-20 通过）
2. 签 producer token（服务器）：`docker exec aweshare-hub aweshare hub token issue --role producer --name <名字>`
3. producer 机器接入：`aweshare agent init --hub https://aweshare.wehuman.top --token asp_...`，配好 backends/offerings 后 `aweshare agent doctor` 全绿 → 自己终端 `aweshare agent start`（这是对 WebSocket 全链路最真实的检验）。
4. **关掉 8787 公网端口**：hub 的 compose 里删除 `ports:` 整段（cloudflared 走内部网络，不需要发布端口），`docker compose up -d` 重建，再 `curl https://aweshare.wehuman.top/healthz` 复验。
5. 消费者接入：
   ```bash
   # Anthropic SDK / Claude Code
   export ANTHROPIC_BASE_URL="https://aweshare.wehuman.top"
   export ANTHROPIC_AUTH_TOKEN="<consumer token>"
   # OpenAI SDK / Codex
   export OPENAI_BASE_URL="https://aweshare.wehuman.top/v1"
   export OPENAI_API_KEY="<consumer token>"
   ```
6. 可选加固：Cloudflare Zero Trust → Access 只对 `/admin/v1` 路径加验证（如邮箱 OTP）。**不要整域加**，会把 SDK 消费者挡在登录页外。

## 运维备忘

- **Cloudflare 免费计划约 100 秒限制**：非流式长请求可能超时返回 524；SSE 流式响应持续出字节不受影响，长生成建议走 streaming。
- producer agent 的 WebSocket 自带**心跳 + 指数退避重连**（源码确认），隧道闪断会自动恢复；hub 重启后 agent 也会自动重拨。
- 远程管理 hub：本地放一份 `admin-token` 文件，`AWESHARE_HUB_URL=https://aweshare.wehuman.top aweshare hub token list`，不必每次 ssh。
- hub 升级：`docker compose pull && docker compose up -d`（状态都在 `/data` 卷里，不丢）。

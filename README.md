<div align="center">
  <img src="./logo/logo.png" alt="aweshare" width="760">
  <h1>aweshare: Local-first AI Capability Relay</h1>
  <p><strong>An open-source, local-first AI capability relay.</strong></p>
  <p>Share local Ollama/vLLM or authorized OpenAI/Anthropic backends through a grant-based hub, consumed with standard SDKs via <code>namespace/alias</code>.</p>
  <p><strong>Upstream API keys never leave the producer's device.</strong></p>
  <p>
    <strong>English</strong> ·
    <a href="./README_cn.md">简体中文</a> ·
    <a href="https://www.npmjs.com/package/aweshare">npm</a> ·
    <a href="https://github.com/wehuman01/aweshare">GitHub</a>
  </p>
  <p>
    <a href="https://ko-fi.com/mugpeng"><img src="https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white" alt="Ko-fi"></a>
  </p>
  <p>
     <a href="https://github.com/wehuman01/aweshare-source/releases"><img src="https://img.shields.io/badge/version-0.3.5-7C3AED?style=flat-square" alt="Version"></a>
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

> Producers run a lightweight agent on their own machine and share local Ollama/vLLM or **authorized** OpenAI/Anthropic backends. Upstream API keys live only on the producer's device and are injected by the local agent at forwarding time. Consumers point a standard OpenAI/Anthropic SDK at the hub and call models by `namespace/alias` — exactly like using any other model vendor.

```
Consumer (standard SDK, zero changes)         Producer side
┌───────────────────────┐            ┌────────────────────────────┐
│ Claude Code           │            │ aweshare agent (Node CLI)   │
│  ANTHROPIC_BASE_URL ──┼──► HTTPS ──┤  ~/.aweshare/config.toml   │
│ OpenAI SDK / Codex    │            │  ~/.aweshare/secrets.json  │
└───────────────────────┘            │   │ upstream key injection  │
           │ /v1/messages            │   ▼ (the only place it happens)
           │ /v1/chat/completions    │  Ollama / vLLM / OpenAI / Anthropic
           ▼                         │
┌─────────────────────────────┐      │
│ aweshare hub (public, 1 node)│◄───── WSS reverse tunnel (agent dials out)
│ auth / grants / route / meter│      no public IP, no port forwarding needed
└─────────────────────────────┘
```

- **Grant-based trust**: consumers can only use aliases explicitly granted to them. No payments, no marketplace.
- **Namespaced aliases**: `peng/gpt-4o` is globally unique with one owner — routing is a deterministic lookup.
- v1 relays **native transparent SSE** for OpenAI↔OpenAI (chat completions and Responses), Anthropic↔Anthropic. No cross-protocol conversion, no smart routing, no web console.

## Trust boundary (read this first)

- To route and meter, **consumer prompts and model responses transit the hub in plaintext — this is not end-to-end encryption**. The hub persists no request/response content, but the hub operator can technically see it. Only use a hub instance you trust — which is why the hub is open source and self-hostable.
- Upstream API keys never leave the producer's device and are never sent to consumers. Tokens are stored **hash-only** (peppered SHA-256): the plaintext is shown exactly once at issue/redeem and can never be re-displayed. Invite codes are the deliberate exception — their plaintext is kept so the operator can re-view them with `hub list --reveal`; a DB leak exposes unredeemed codes, but no tokens.
- Token revocation is **reversible suspension** (`hub revoke --id N` / `hub restore --id N`, by invite), and an invite and the producer it minted move together: revoking a redeemed code suspends that producer (and closes its tunnel), and restoring from either handle revives both. Nothing is deleted on revoke — grants, offerings and usage history survive a suspension.

### Compliance and disclaimer

- aweshare is relay software: it cannot and does not judge whether you are allowed to share a given upstream key or subscription — that question is between you and the upstream provider. Being able to call an API yourself does not mean you may resell or re-provide it to third parties.
- Before sharing anything, read the upstream's terms (account rules, subscription and seat limits, forwarding, commercial-use clauses). Sharing a personal-subscription key — coding plans included — with third parties likely violates those terms; self-hosted open models have no such issue. **When in doubt, don't share.**
- The producer bears the consequences of sharing (key revocation, account suspension or termination by the upstream). The hub operator is responsible for operating the hub lawfully and for informing consumers of the plaintext-transit boundary above.
- The software is provided "as is" under the [proprietary license](./LICENSE) — free to use and self-host, no redistribution — without warranty of any kind. The authors and contributors are not liable for how aweshare is used or for any damage arising from sharing access through it.

## Quickstart

Published as [`aweshare`](https://www.npmjs.com/package/aweshare) on npm (requires Node ≥ 22) and as a Docker image (`ghcr.io/wehuman01/aweshare`). No clone needed.

### 1. Start the hub (operator, one VPS)

**npm** (simplest):

```bash
npm install -g aweshare
aweshare hub init        # data in ~/.aweshare-hub; prints the admin token — save it
aweshare hub serve       # listens on :8787 (put Caddy/nginx TLS in front)
```

**docker**:

```bash
docker run -d --name aweshare-hub --restart unless-stopped \
  -p 127.0.0.1:8787:8787 -v "$PWD/data:/data" ghcr.io/wehuman01/aweshare:latest
docker exec aweshare-hub aweshare hub init   # first run: prints the admin token, save it
```

Then bring people in. Producers join on their own — invite codes (`asi_…`, single use). Two modes:

```bash
# bound: lock the code to a specific name ("inviting that user")
aweshare hub invite --name peng [--expires-in 7d]      # → asi_..., send to the producer

# unbound: batch hand-out; the producer submits name + email at redeem (stored on the hub)
aweshare hub invite --count 10 [--expires-in 7d]

# the producer redeems it themselves (no token hand-off needed):
aweshare agent join --hub https://hub.example.com --code asi_... [--name NAME --email YOU@EXAMPLE.COM]
```

Consumers are few and known — their keys (`asc_…`) are issued directly via the admin API (the hub CLI is invite-only):

```bash
curl -X POST https://hub.example.com/admin/v1/tokens \
  -H "Authorization: Bearer asa_... (the admin token)" -H "content-type: application/json" \
  -d '{"role":"consumer","name":"alice"}'      # → asc_..., give to the consumer
```

Three token roles, one per party:

| Role | Who holds it | How it's used |
|---|---|---|
| `admin` | hub operator (you only) | the admin REST API (`/admin/v1/*`); CLI side: `hub invite` / `list` / `revoke` / `restore` |
| `producer` (`asp_...`) | the agent on the producer's machine | set as `token` in `~/.aweshare/config.toml`; the agent registers its offerings with it |
| `consumer` (`asc_...`) | whoever calls the models | set in SDK env vars (`ANTHROPIC_AUTH_TOKEN` / `OPENAI_API_KEY`); the hub uses it to decide which aliases they may call |

The producer's `name` becomes their alias namespace (the `peng/` in `peng/gpt-4o`).

Identity and permission are deliberately split. The operator issues identities — invite codes for producers, `asc_…` keys for consumers — while each producer alone decides who may call their own aliases (`aweshare agent grant`; the admin API can read grants for audit but cannot write them). A fresh consumer key can call nothing until a producer grants it, so the hub works the same whether you run everything yourself (private hub) or producers who don't know each other share yours (community hub).

### 2. Producer first run (in this order)

```bash
npm install -g aweshare   # ⓪ once, on the producer machine (Node ≥ 22)

# ① join with your invite code (writes ~/.aweshare/config.toml + secrets.json, 0600)
aweshare agent join --hub https://hub.example.com --code asi_...
#    or, with a producer token handed to you directly:
aweshare agent init --hub https://hub.example.com --token asp_...

# ② Edit the config (see below); put upstream keys in secrets.json — they never leave this machine

# ③ doctor: pre-flight checks, ordered to find the first failing link
aweshare agent doctor

# ④ Grant a consumer
aweshare agent grant --alias peng/qwen2.5.7b --consumer alice
#    time-limited trial: add --expires-in 7d (re-granting refreshes the expiry)

# ⑤ Start (long-running; when it stops, aliases go offline and consumers get 503)
aweshare agent start
```

### 3. Consumer first run (in this order)

```bash
# ① one small curl to prove the path
curl https://hub.example.com/v1/chat/completions \
  -H "Authorization: Bearer asc_..." -H "content-type: application/json" \
  -d '{"model":"peng/qwen2.5.7b","messages":[{"role":"user","content":"ping"}]}'

# ② configure your tool (below) → run one minimal task
# ③ check usage: GET /admin/v1/usage with your consumer key (you only see your own rows)
# ④ only then move to real workloads
```

## Consumer tool configuration

**OpenAI SDK / any OpenAI-compatible tool**

```ts
const client = new OpenAI({ baseURL: 'https://hub.example.com/v1', apiKey: 'asc_...' })
await client.chat.completions.create({ model: 'peng/gpt-4o', messages: [...] })
```

**Claude Code** (the key is the `asc_` consumer key — **not** any upstream x-api-key)

```bash
export ANTHROPIC_BASE_URL=https://hub.example.com
export ANTHROPIC_API_KEY=asc_...
claude --model peng/sonnet
```

If Claude Code has a stale OAuth login it overrides env config — switch with `/login` or clean stored credentials.

**Codex** (the default Responses wire protocol works — the alias must be backed by a `responses`-protocol offering; `wire_api = "chat"` against an `openai`-protocol offering also works)

```toml
[model_providers.aweshare]
base_url = "https://hub.example.com/v1"
```

**Discovering models**: `GET /v1/models` (OpenAI SDK `client.models.list()`) returns every alias granted to the key, with online status.

## Producer config reference (~/.aweshare/config.toml)

```toml
hubUrl = "https://hub.example.com"
token = "asp_..."

[[backends]]
id = "ollama"
protocol = "openai"                      # openai-style baseUrl includes /v1 (SDK convention)
baseUrl = "http://127.0.0.1:11434/v1"

[[backends]]
id = "anthropic-main"
protocol = "anthropic"                   # anthropic-style baseUrl excludes /v1 (agent adds it)
baseUrl = "https://api.anthropic.com"
keyRef = "anthropic-key"                 # key lives in secrets.json under this name

[[backends]]
id = "glm-responses"
protocol = "responses"                   # responses-style baseUrl includes the version path
baseUrl = "https://open.bigmodel.cn/api/v1"
keyRef = "glm-key"                       # e.g. a GLM coding-plan key (Codex-ready)

[[offerings]]
alias = "peng/qwen2.5.7b"                # namespace must be your producer name
backend = "ollama"
upstreamModel = "qwen2.5:7b"             # the real backend id (full tag from `ollama list`)
maxConcurrency = 1                       # start at 1 for local models; raise for cloud APIs
```

Key hygiene: use dedicated, least-privilege, revocable keys with budget alerts; keep `secrets.json` at 0600 and out of git/screenshots; rotate on suspected leaks. Before sharing, check the upstream's terms: account rules, subscription limits, forwarding and commercial-use constraints.

## Consumer limits (hub-wide defaults + per-consumer overrides)

Every consumer gets the hub-wide defaults (`AWESHARE_CONSUMER_RPS` / `BURST` / `CONCURRENCY`, see Operations). On top of that, the hub admin can set **sparse per-consumer overrides** — only the keys you set take effect, everything else keeps the defaults:

```bash
# PUT /admin/v1/consumers/{name}/limits — sparse JSON; unset keys keep the defaults,
# later PUTs merge into what is stored
curl -X PUT https://hub.example.com/admin/v1/consumers/alice/limits \
  -H "Authorization: Bearer asa_... (the admin token)" -H "content-type: application/json" \
  -d '{"tpm":60000,"maxTotalTokens":5000000}'

# DELETE the same path clears all overrides back to the hub-wide defaults
```

| Key | Meaning | Enforcement |
|---|---|---|
| `rps` / `burst` / `maxConcurrent` | override the hub-wide rate/inflight defaults for this consumer | 429 `RATE_LIMITED` |
| `tpm` | max tokens (prompt + completion) in any sliding 60s window | 429 `RATE_LIMITED` (in-memory window, like the RPS bucket) |
| `maxTotalTokens` | lifetime token budget for this consumer | 429 `QUOTA_EXCEEDED` (sums `usage_events`) |

Grants can also carry an expiry: `aweshare agent grant --alias peng/gpt-4o --consumer alice --expires-in 7d`. Grant writes are producer-owned — the admin API keeps read-only audit access but rejects admin-token writes with `403 NOT_GRANTED`. An expired grant returns `403 GRANT_EXPIRED`; re-granting refreshes the expiry.

Honest limits: token-based caps count what upstreams report — Ollama streams report no usage, so they contribute 0. Both TPM and the lifetime budget are observed-usage thresholds, not hard reservations: one request can cross the threshold, and concurrent requests that start before earlier usage is recorded can overshoot it further. Once recorded usage has reached the threshold, new requests are rejected.

## Endpoints and errors

| Endpoint | Purpose |
|---|---|
| `POST /v1/chat/completions` · `POST /v1/messages` · `POST /v1/responses` | inference (Bearer or `x-api-key`) |
| `GET /v1/models` | aliases visible to this key, with status |
| `GET /healthz` | liveness |
| `/admin/v1/*` | token/limit/usage management (admin or producer token) · grants: writes producer-only, admin reads for audit · consumer limit overrides: `GET`/`PUT`/`DELETE /admin/v1/consumers/{name}/limits` (admin only) |

Error semantics: `401` invalid key · `401 TOKEN_REVOKED` suspended token (ask the operator to restore it) · `403` not granted or `GRANT_EXPIRED` · `403 HUB_FULL` producer capacity reached · `404` unknown alias · `400 PROTOCOL_MISMATCH` protocol/alias mismatch · `429` rate limit, TPM or producer concurrency cap (`QUOTA_EXCEEDED` = lifetime token budget hit) · `502` upstream/tunnel failure (upstream 4xx/5xx passes through verbatim) · `503` producer offline / backend degraded · `504` timeout. Errors carry `{error:{code,message,requestId}}`; the requestId spans both sides' logs.

Usage metering: one row per request (alias, real model, status, duration, byte counts, best-effort token counts), **zero content stored**. Producers list grants with `aweshare agent list`; usage is queried via `GET /admin/v1/usage` (admin sees everything, producers and consumers their own slice).

## Command reference

Both sides at a glance — details in the sections above.

**Hub (operator)** — needs the admin token from `aweshare hub init`; for a hub on another server, run these on the server or set `AWESHARE_HUB_URL`:

| Command | Purpose |
|---|---|
| `aweshare hub init` | create data dir + admin token (printed once) |
| `aweshare hub serve [--host H] [--port N]` | run the hub |
| `aweshare hub invite [--name NAME] [--count N] [--expires-in 7d]` | mint one-time invite codes (`asi_…`, printed once; re-view with `list --reveal`); with `--name` bound to that producer, without it the producer submits name + email at redeem |
| `aweshare hub list [--reveal] [--token]` | list invites (status: pending/used/suspended/revoked/expired); `--reveal` shows the codes, `--token` shows the producer token each minted, with last seen |
| `aweshare hub revoke --id N` · `aweshare hub restore --id N` | kill an invite / undo — a redeemed code suspends the producer it minted, restore revives both |

The CLI is invite-only: token issuance, consumer limits and usage left it when it narrowed — they live on the admin REST API (`/admin/v1/*`, see Endpoints and errors). Grants are producer-owned and were never the operator's CLI: manage them with `aweshare agent grant`/`revoke`/`list` on the producer machine (the admin API keeps read-only audit access).

`list` prints an aligned table by default; append `--json` for the raw API response.

**Agent (producer)** — runs on the producer's machine (the one with the backends); consumers run no aweshare commands — they point a standard SDK at the hub (see Consumer tool configuration):

| Command | Purpose |
|---|---|
| `aweshare agent init [--hub URL] [--token asp_…]` | write config templates into `~/.aweshare` |
| `aweshare agent join --hub URL --code asi_… [--name NAME --email YOU@EXAMPLE.COM]` | redeem an invite code into a producer token and write it into the config (`--name`/`--email` for unbound codes) |
| `aweshare agent config path` · `config show` · `config edit` | locate / inspect (secrets redacted) / edit the config |
| `aweshare agent doctor` | pre-flight checks — fix the first FAIL, re-run |
| `aweshare agent grant --alias ns/model --consumer NAME [--expires-in 7d]` | grant a consumer access |
| `aweshare agent revoke --alias ns/model --consumer NAME` | revoke access |
| `aweshare agent list` | list grants for your namespace |
| `aweshare agent start` | connect and relay (long-running; run it in your own terminal) |

CLI maintenance: `aweshare self-update [--check]` updates the npm-installed CLI (`--check` only compares versions).

## Operations

| Env var | Default | Purpose |
|---|---|---|
| `AWESHARE_HUB_DATA_DIR` | `~/.aweshare-hub` | data dir (SQLite/pepper/admin token; volume-mount = backup) |
| `AWESHARE_HUB_PORT` / `HOST` | 8787 / 0.0.0.0 | listen address |
| `AWESHARE_CONSUMER_RPS` / `BURST` / `CONCURRENCY` | 10 / 20 / 8 | per-consumer limits |
| `AWESHARE_HEAD_TIMEOUT_MS` / `IDLE_TIMEOUT_MS` | 120000 / 300000 | response-head timeout / stream idle timeout |
| `AWESHARE_MAX_BODY_BYTES` | 32MB | request body cap |
| `AWESHARE_INVITE_REDEEM_PER_MIN` | 10 | rate limit for the unauthenticated redeem endpoint |
| `AWESHARE_MAX_PRODUCERS` | 10 | max active producers — token issuance (admin API), invite redeem and restore refuse with `403 HUB_FULL` when full |
| `AWESHARE_NO_UPDATE_CHECK` | unset | set to `1` to disable the passive update reminder |

Health: agent heartbeats every 15s, silent 45s = dead; backends with 2 consecutive AUTH/QUOTA failures auto-degrade (alias shows `degraded`, dispatch stops), 30s probes recover. A new connection with the same producer token replaces the old one (latest-wins).

Updating a npm install: `aweshare self-update` (asks before installing; `--check` only shows versions). The CLI also reminds you at most once a day when a newer npm release exists.

## Known limitations (v1)

- No cross-protocol conversion: an alias speaks exactly one wire (openai chat, anthropic messages, or openai responses).
- Ollama streams carry no usage → token counts recorded as NULL (best effort by design).
- Single hub instance + SQLite; no horizontal scaling.
- Corporate proxies may block the WebSocket tunnel (environmental limit).

## Development

```bash
pnpm install
pnpm test        # 98 tests: protocol / hub contract (fake agent vs real hub) / agent unit / e2e (real SDKs)
pnpm build       # tsc -b, whole monorepo
pnpm check       # biome
```

To run the CLIs from a source checkout without `node apps/.../dist/cli.js`, link them once after building:

```bash
npm link                 # or: pnpm link --global — exposes the single `aweshare` bin
aweshare hub serve
aweshare agent doctor
```

Releasing: push a `v*` tag with a matching `## [x.y.z]` section in `docs/CHANGELOG.md`; CI publishes the `aweshare` package to npm via Trusted Publishing (OIDC, no token secret), pushes the Docker image to `ghcr.io/wehuman01/aweshare`, and mirrors user-facing docs to the public repo (`wehuman01/aweshare`).

Layout: `packages/protocol` (shared wire protocol) · `apps/hub` (HTTP+WS+SQLite+CLI) · `apps/agent` (CLI). Design docs live in `docs/specs/`; the changelog in `docs/CHANGELOG.md`; contribution scope in [CONTRIBUTING.md](./CONTRIBUTING.md).

## Support

If aweshare saves you a subscription or a GPU box, consider supporting it:

- ⭐ Star the repo — it helps others find it.
- ☕ [Ko-fi](https://ko-fi.com/mugpeng) — buy me a coffee.
- 💬 WeChat — scan the QR code below.

<p align="center">
  <img src="assets/images/wechat-pay.jpg" alt="WeChat Pay" width="240">
</p>

> aweshare is free to use and self-host. Sponsors keep it maintained — thank you.

Licensed under the aweshare Proprietary License — free to use and self-host,
no redistribution. See [LICENSE](./LICENSE).

---
name: aweshare
description: "Use when helping users configure or operate aweshare — producer agent setup (backends, offerings, secrets), hub admin (invites, limits, usage), and consumer SDK wiring. 中文触发词：aweshare、共享模型、配置agent、hub管理、consumer接入。"
---

# aweshare

This skill covers **configuring** the aweshare producer and hub so consumers can call shared models.

## Do Not Launch

**Never launch the long-running services from this agent** — not `aweshare hub serve`, not `aweshare producer start` (foreground it would block the session; even with `--background`, starting/stopping the shared service is the user's call). The same applies to starting the hub as a container (`docker run` / `docker compose up` of `ghcr.io/wehuman01/aweshare`) — deploying a service is the user's call. If the user wants to run them, give them the commands (see Hub Deployment) or tell them to run them in their own terminal (or as a service/systemd/daemon); a detached producer is inspected with `aweshare producer doctor --status` and stopped with `aweshare producer stop`.

You may run these read-only commands:
- `aweshare producer config path`
- `aweshare producer config show` (secrets redacted)
- `aweshare producer doctor`
- `aweshare hub list invites [--reveal] [--token]` — the invite ledger: lifecycle pending/used/suspended/revoked/expired; `--reveal` re-shows stored codes, `--token` shows the token each invite minted
- `aweshare hub status` — live state: capacity, producer/consumer rosters (status, ONLINE, last seen) and the offering table (same columns as `consumer list`, worst status first, live occupancy and today's remaining daily tokens)
- `aweshare hub list usage [--consumer NAME] [--alias ns/model] [--limit N] [--json]` — recent requests, newest first
- `aweshare self-update --check` (current vs npm latest; plain `self-update` needs a TTY — see Self-Update)

You may also run these commands (they modify files/state but are non-interactive):
- `aweshare producer init [--hub URL] [--token asp_...]` — write config template + empty secrets (no-op if they exist)
- `aweshare producer config edit` — open config in `$VISUAL`/`$EDITOR`/`vi`
- `aweshare hub init`
- `aweshare hub invite [--role producer|consumer] [--name NAME] [--count N] [--expires-in D]` — mint one-time invite codes (`asi_…`, printed once, expire after 7 d by default; re-view with `hub list invites --reveal`); consumers need `--role consumer --name NAME`
- `aweshare hub limits NAME [--rps N] [--burst N] [--max-concurrent N] [--tpm N] [--max-total-tokens N] [--clear]` — show (bare), merge or clear one consumer's limit overrides
- `aweshare hub revoke --id N`, `aweshare hub restore --id N` — kill / revive an invite; a redeemed one carries its identity (producer or consumer) with it
- `aweshare producer join --hub URL --code asi_… [--name NAME --email YOU@EXAMPLE.COM]` — redeem an invite code into a producer token and write it into the config
- `aweshare producer reload` — re-read config.toml + secrets.json and re-register the offerings on the open tunnel (no disconnect; a broken config keeps the previous values — check `producer doctor --status` for the log). Since v0.4.2 both processes stat-poll their config every 2s and apply valid edits automatically — `reload`/SIGHUP just skips that delay; only `hubUrl`/`token` changes need a restart

The operator owns admission and access: one-time invite codes for both roles (the only admission path; every identity carries its invite handle from mint to suspension). A redeemed consumer key may call **every** offering on the hub — there are no per-alias grants. Guardrails are all hub-side and CLI-managed: per-consumer `limits`, per-offering caps (`maxConcurrentUsers`/`dailyTokens` from the producer's config), and `revoke`/`restore` suspension. The hub CLI covers admission (`invite`), reads (`status` for live state, `list invites` for the ledger, `list usage` for the meter), tuning (`limits`) and suspension (`revoke`/`restore`) — thin wrappers over the admin REST API (`/admin/v1/*`), so curl works too.

## Suspension semantics (hub)

Revocation is **reversible suspension**, never deletion, and the invite is the operator's handle: `hub revoke --id N` suspends (a pending code stops pairing; a redeemed one suspends the identity it minted — a producer's tunnel closes at once, a consumer's key gets `401 TOKEN_REVOKED`); `hub restore --id N` brings both back. An invite and its minted identity move together; restoring a redeemed producer needs a free slot (`403 HUB_FULL` when `AWESHARE_MAX_PRODUCERS`, default 10, active producers are reached — the cap also gates invite redeem; consumers have no cap).

## Intent Router

| User intent | Domain | Approach |
|---|---|---|
| "Set up sharing on my machine" | Producer setup | `aweshare producer init`, edit config.toml, fill secrets.json |
| "Share my Ollama / vLLM model" | Add backend + offering | Edit config.toml |
| "Share an OpenAI/Anthropic key" | Add backend + offering | Edit config.toml; warn about upstream ToS (see Trust) |
| "Where is the config?" | Config Path | `aweshare producer config path` |
| "Show my config" | Config Show | `aweshare producer config show` |
| "Something doesn't work" | Diagnose | `aweshare producer doctor` — fix the first FAIL |
| "Suspend / bring back a user or token" | Hub admin | `aweshare hub revoke --id N` / `restore --id N` (by invite, reversible — see Suspension semantics) |
| "Who can use what?" | Browse | Every admitted consumer can call every offering; see who is admitted in the `aweshare hub status` rosters and what is shared via the consumer catalog (`aweshare consumer list`) |
| "Set up a hub" | Hub setup | npm or Docker — see Hub Deployment; `init` prints the admin token once; user runs `serve`/container themselves |
| "Issue a consumer token (asc_)" | Hub admin | `aweshare hub invite --role consumer --name NAME` (bound, single); the consumer redeems the code themselves with `aweshare consumer join` and keeps the printed `asc_` token — see Admission via Invite Codes |
| "Rate-limit or cap a consumer" | Hub admin | `aweshare hub limits NAME --rps 5 --max-concurrent 2 --tpm 60000 --max-total-tokens 5000000` (merges; bare call views; `--clear` resets to hub-wide defaults; unset keys keep the `AWESHARE_CONSUMER_*` defaults) |
| "How much was used?" | Metering | `aweshare hub list usage [--consumer NAME] [--alias ns/model] [--limit N]` (admin sees everything; the API `GET /admin/v1/usage` also takes producer/consumer keys, each sees its own slice) |
| "Invite producers without hand-delivering tokens" | Invite codes | `aweshare hub invite --name NAME` (bound) or `--count N` (unbound); producer redeems via `aweshare producer join` — see Admission via Invite Codes |
| "Point Claude Code / an SDK at the hub" | Consumer | Explain env vars (see Consumer Setup) |
| "Update aweshare itself", "upgrade the CLI/hub" | Self-Update | `aweshare self-update --check` first, then see Self-Update (npm vs Docker differ) |

## Config Location

Producer: `~/.aweshare/` — `config.toml` + `secrets.json` (override with `AWESHARE_AGENT_DIR`).
Hub: `~/.aweshare-hub/` (override with `AWESHARE_HUB_DATA_DIR`).

Always read the config before modifying it. Run `aweshare producer config show` first — secrets are redacted in its output, so read `config.toml` directly only when you need the structure, never print `secrets.json` values.

## Hub Deployment (npm or Docker)

Both paths are first-class. Docker is the better default on a VPS (restart policy survives reboots, no Node on the host, data isolated in a volume); npm is fine for local or quick setups. In both cases the user runs the server themselves (see Do Not Launch).

**npm:**

```bash
npm install -g aweshare        # Node ≥ 22
aweshare hub init              # data in ~/.aweshare-hub; prints the admin token ONCE — save it
aweshare hub serve             # user runs this in their own terminal / systemd
```

**Docker** (image is hub-only; the producer CLI always runs on producer machines):

```bash
docker pull ghcr.io/wehuman01/aweshare:latest
docker run -d --name aweshare-hub --restart unless-stopped \
  -p 127.0.0.1:8787:8787 -v "$PWD/data:/data" ghcr.io/wehuman01/aweshare:latest
docker exec aweshare-hub aweshare hub init   # first run: prints the admin token ONCE — save it
docker ps | grep aweshare-hub                # verify container is running
```

The repo also ships a `docker-compose.yml` (port, volume, limit-tuning env vars). The image sets `AWESHARE_HUB_DATA_DIR=/data`, so everything persistent lives in the mounted volume.

**TLS:** consumers dial `https://<hub-host>`, so on a public VPS keep 8787 off the public interface (docker: publish `-p 127.0.0.1:8787:8787`; npm: `--host 127.0.0.1` plus a firewall) and terminate TLS with Caddy/nginx in front. Never expose plaintext :8787 to the internet — consumer tokens and all traffic would cross it unencrypted.

### Administering a remote hub

Hub CLI admin commands (`invite`, `list`, `limits`, `usage`, `revoke`, `restore`) read the admin token file `<AWESHARE_HUB_DATA_DIR>/admin-token` and call the admin API at `AWESHARE_HUB_URL` (default `http://127.0.0.1:8787`). When the hub runs on a server:

- run the commands on the server (`ssh` + CLI, or `docker exec aweshare-hub aweshare hub invite ...`), or
- run them locally with `AWESHARE_HUB_URL=https://<hub-host>` and the admin-token file placed in a local `AWESHARE_HUB_DATA_DIR`.

Running them from the user's laptop without both will fail ("no admin token at ..." or connection refused) — check this before treating it as a hub malfunction.

### Hub configuration (config.toml + env vars)

The hub reads `<dataDir>/config.toml` (Docker: `/data/config.toml`); `hub init` writes the template with every key commented out — uncomment to override. Keys mirror the env vars in camelCase (`consumerRps`, `headTimeoutMs`, …). Precedence: `serve` flags (`--host`/`--port`) > env vars > config.toml > defaults. A broken file (invalid TOML, unknown key, non-positive value) fails fast at startup naming the key; `AWESHARE_HUB_DATA_DIR` itself stays env-only.

| Env var | Default | Purpose |
|---|---|---|
| `AWESHARE_HUB_DATA_DIR` | `~/.aweshare-hub` (image: `/data`) | SQLite, pepper, admin token, config.toml — volume-mount it |
| `AWESHARE_HUB_HOST` · `AWESHARE_HUB_PORT` | `0.0.0.0` · `8787` | listen address for `serve` |
| `AWESHARE_CONSUMER_RPS` · `AWESHARE_CONSUMER_BURST` · `AWESHARE_CONSUMER_CONCURRENCY` | `10` · `20` · `8` | hub-wide per-consumer defaults |
| `AWESHARE_HEAD_TIMEOUT_MS` · `AWESHARE_IDLE_TIMEOUT_MS` | `120000` · `300000` | response-head timeout / stream idle timeout |
| `AWESHARE_MAX_BODY_BYTES` | `32MB` | request body cap |
| `AWESHARE_INVITE_REDEEM_PER_MIN` | `10` | rate limit for the unauthenticated invite-redeem endpoint |
| `AWESHARE_MAX_PRODUCERS` | `10` | max active producers — issue/redeem/restore refuse with `403 HUB_FULL` when full |

## Admission via Invite Codes

Both roles self-service through one-time invite codes (the CLI's admission path):

```bash
# producer, bound: locked to one producer name
aweshare hub invite --name peng [--expires-in 7d]      # → asi_..., send to the producer
# producer, unbound: batch hand-out; producer submits name + email at redeem
aweshare hub invite --count 10 [--expires-in 7d]
# consumer: always bound to one name, single (no --count) — limits, usage and
#           suspension reference consumers by name
aweshare hub invite --role consumer --name alice [--expires-in 7d]

# producer side — redeems the code, writes the token into their config:
aweshare producer join --hub https://<hub-host> --code asi_... [--name NAME --email YOU@EXAMPLE.COM]

# consumer side — prints the asc_ token once with ready-to-paste SDK env vars
# (save it; the operator can re-view it with `hub list invites --token`); no aweshare? curl works too:
aweshare consumer join --hub https://<hub-host> --code asi_...
# curl -s -X POST https://<hub-host>/invites/v1/redeem -H 'content-type: application/json' -d '{"code":"asi_..."}'
```

Codes are single-use, optionally expiring, and revocable at any stage (`hub list invites` shows pending/used/suspended/revoked/expired; `hub revoke --id N`, undo with `hub restore --id N`). Revoking a **redeemed** code suspends the identity it minted (a producer's token dies and tunnel closes; a consumer's key is suspended) — one code, one identity; restore revives both. Both `join` commands assert their role, so handing a code to the wrong one fails with `409 INVITE_ROLE_MISMATCH` without burning the code. `hub list invites --reveal` re-shows stored codes; `hub list invites --token` re-shows each minted token with when it was last seen. Redeem respects the active-producer cap (`AWESHARE_MAX_PRODUCERS`, default 10; `403 HUB_FULL` when full; consumers uncapped). After a successful join, continue with the normal first-time producer setup (edit backends/offerings, doctor, start).

## Producer Config Structure (config.toml)

```toml
hubUrl = "http://127.0.0.1:8787"        # hub to dial out to (WSS reverse tunnel)
token = "asp_..."                        # producer token from the hub operator

[[backends]]
id = "ollama"                            # local name referenced by offerings
protocol = "openai"                      # openai | anthropic | responses
baseUrl = "http://127.0.0.1:11434/v1"    # openai-style includes /v1
# keyRef = "openai-key"                  # optional; value lives in secrets.json

[[backends]]
id = "glm"
protocol = "responses"                   # responses-style baseUrl includes the version path
baseUrl = "https://open.bigmodel.cn/api/v1"
keyRef = "glm-key"

[[offerings]]
alias = "YOUR_NAME/qwen2.5.7b"           # namespace/name, lowercase, globally unique
backend = "ollama"                       # must match a backends.id
upstreamModel = "qwen2.5:7b"             # exact id the backend knows (incl. tag)
maxConcurrencyPerUser = 1                # concurrent requests PER CONSUMER (1..64)
# maxConcurrentUsers = 3                 # distinct concurrent CONSUMERS (hub default 3)
# dailyTokens = 1000000                  # shared tokens per UTC day (default 1M; 0 = unlimited)
```

secrets.json maps `keyRef` names to upstream API keys:

```json
{ "openai-key": "sk-..." }
```

**Rules:**
- The namespace in every alias must match the producer name the token was issued for.
- One offering = exactly one upstream model: the hub rewrites the request's model to `upstreamModel`, so consumers can never pick another. More models = more `[[offerings]]`.
- Per-offering caps ride the register message and are enforced by the hub — `maxConcurrencyPerUser` (default 1, concurrent requests **per consumer**; alias-wide bound is `maxConcurrentUsers × maxConcurrencyPerUser`) → 429 `PRODUCER_MAX_CONCURRENCY`; `maxConcurrentUsers` (default 3) → 429 `PRODUCER_MAX_USERS`; `dailyTokens` (default 1M, 0 = unlimited) → 429 `QUOTA_EXCEEDED` (UTC-midnight reset). They apply by default to every alias, including old agents that don't send them. The old `maxConcurrency` key (alias-wide cap, pre-v0.4.3) fails validation with a rename hint.
- Upstream keys live only in secrets.json on the producer's machine — never in config.toml, never in chat output.
- `anthropic`-protocol baseUrl excludes `/v1` (the agent appends it); `openai`-protocol baseUrl includes `/v1`; `responses`-protocol baseUrl includes the version path (e.g. `https://open.bigmodel.cn/api/v1`).
- An alias speaks exactly one wire protocol — there is no cross-protocol conversion.
- `upstreamModel` must match the backend exactly (e.g. `ollama list` tag).

## Workflows

### First-time producer setup

1. `aweshare producer init [--hub URL] [--token asp_...]` — writes templates (kept if they exist)
2. Edit `config.toml`: set hubUrl/token, define backends and offerings
3. Put upstream keys in `secrets.json` (chmod 600 already applied)
4. `aweshare producer doctor` — must be all green
5. Tell the user to run `aweshare producer start` in their own terminal — or `aweshare producer start --background` to detach it (logs to `~/.aweshare/producer.log`), then check `producer doctor --status` / stop with `producer stop`

### Add a backend / offering

1. Read config.toml (via `aweshare producer config show` or the file)
2. Append a `[[backends]]` block (unique `id`, valid `protocol`, correct baseUrl convention)
3. If the backend needs a key: add `keyRef = "name"` and the matching entry in secrets.json
4. Append an `[[offerings]]` block mapping `namespace/alias` to the backend + upstreamModel
5. Verify with `aweshare producer doctor`
6. If the producer is running: `aweshare producer reload` applies the new catalog without a restart

### Verify configuration

```bash
aweshare producer config show    # config with token + secrets redacted
aweshare producer doctor         # instance, config, backends, hub, recent log — fix the first FAIL
aweshare producer doctor --status  # background instance state + recent log only, no network probes
```

### Consumer Setup

Redeeming an invite: `aweshare consumer join --hub https://<hub-host> --code asi_...` prints the `asc_` token once with these exact exports — tell the consumer to save it, it will not be shown again. Discovery: `aweshare consumer list --hub https://<hub-host> --token asc_...` shows every producer, alias, protocol, status and the per-offering caps with remaining daily tokens (`GET /v1/catalog` under the hood). After that, consumers point a standard SDK at the hub — no special client:

```bash
# Anthropic SDK / Claude Code
export ANTHROPIC_BASE_URL="https://<hub-host>"
export ANTHROPIC_AUTH_TOKEN="<consumer token from hub operator>"
# model: namespace/alias, e.g. peng/gpt-4o

# OpenAI SDK / Codex
export OPENAI_BASE_URL="https://<hub-host>/v1"
export OPENAI_API_KEY="<consumer token>"
```

Remind consumers: traffic transits the hub in plaintext — only use a hub they trust.

### Self-Update

Use when the task is about updating the aweshare CLI or a deployed hub, or when the installed CLI behaves differently from the repo/README.

```bash
# npm installs (producer machines, npm-run hub)
aweshare self-update --check     # current vs npm latest — read-only, safe to run here
aweshare self-update             # y/n confirm — needs a real terminal (agent shells have no TTY)
npm install -g aweshare          # non-interactive equivalent; verify with aweshare -v

# Docker-deployed hub (state persists in the /data volume)
docker compose pull && docker compose up -d      # with the repo's docker-compose.yml
docker pull ghcr.io/wehuman01/aweshare:latest    # or plain docker: stop/rm + re-run the Hub Deployment command
```

Rules of thumb:
- Update the hub first (it is the public entry point), then producer agents. Agents redial automatically after a hub restart (reverse tunnel, latest-wins); consumers see 503 only during the brief restart window.
- Config changes hot-reload — no restart: both processes stat-poll their config files every 2s and apply valid edits within a couple of seconds; `aweshare producer reload` (SIGHUP to either process) forces it immediately, skipping only the polling delay. A broken file keeps the previous values; host/port and connection identity (`hubUrl`/`token`) still need a restart. Restart is also needed for CLI updates on that machine (background instances: `producer stop`, then `start --background` again).
- The CLI prints a passive update reminder at most once per 24h; disable with `AWESHARE_NO_UPDATE_CHECK=1`.

If the installed `aweshare` doesn't match what the user expects from the repository:

1. `which aweshare` — confirm which binary is active
2. `aweshare self-update --check` — installed vs npm latest ("unknown target" means the install predates 0.2.4, when self-update landed)
3. Update via `npm install -g aweshare` (or have the user run `aweshare self-update` in their own terminal), then `aweshare -v`
4. If the mismatch persists, inspect the global package (`npm ls -g aweshare`) to confirm which code is actually running.

## Trust and Compliance

Before sharing a backend, warn the user: relaying a personal-subscription API key (coding plans included) to third parties likely violates the upstream's terms. Self-hosted open models (Ollama/vLLM) have no such issue. When in doubt, don't share. The producer bears the consequences (key revocation, account suspension).

## Core Rules

1. **Do not run `producer start` or `hub serve` inside the agent.** `hub serve` and foreground `producer start` are long-running blocking processes; even detached (`--background`) the service is the user's call. Tell the user to run them in their own terminal.
2. Always read the config before editing. Never overwrite existing backends/offerings without checking.
3. Never print or copy upstream API keys from secrets.json. Use `aweshare producer config show` (redacted) when showing config to the user.
4. Offering aliases must be `namespace/name` (lowercase) with the namespace matching the producer token's name; names are globally unique on the hub.
5. Use `aweshare producer doctor` after any config change; fix the first FAIL, then re-run.
6. `aweshare producer init` is a no-op if the files already exist — it will not clobber.
7. Hub admin commands need the admin token from `aweshare hub init` output; it is printed only once. They read `<AWESHARE_HUB_DATA_DIR>/admin-token` and dial `AWESHARE_HUB_URL` (default `http://127.0.0.1:8787`) — for a remote hub see Hub Deployment.

---
name: aweshare
description: "Use when helping users configure or operate aweshare — producer agent setup (backends, offerings, secrets), hub admin (tokens, grants, limits, usage), and consumer SDK wiring. 中文触发词：aweshare、共享模型、配置agent、grant授权、hub管理、consumer接入。"
---

# aweshare

This skill covers **configuring** the aweshare agent and hub, and applying grants so consumers can call shared models.

## Do Not Launch

**Never run `aweshare agent start` or `aweshare hub serve` inside this agent.** Both are long-running foreground processes that would block the session. The same applies to starting the hub as a container (`docker run` / `docker compose up` of `ghcr.io/wehuman01/aweshare`) — deploying a service is the user's call. If the user wants to run them, give them the commands (see Hub Deployment) or tell them to run it in their own terminal (or as a service/systemd/daemon).

You may run these read-only commands:
- `aweshare agent config path`
- `aweshare agent config show` (secrets redacted)
- `aweshare agent doctor`
- `aweshare agent list`
- `aweshare hub token list` (suspension state + last seen; tokens are hash-only at rest — no --reveal exists, save tokens at issue)
- `aweshare hub invite list` (`--reveal` re-shows stored invite codes; statuses: pending/used/suspended/revoked/expired)
- `aweshare hub grant list`
- `aweshare hub usage [--alias ALIAS]`
- `aweshare self-update --check` (current vs npm latest; plain `self-update` needs a TTY — see Self-Update)

You may also run these commands (they modify files/state but are non-interactive):
- `aweshare agent config init` — write config template + empty secrets (no-op if they exist)
- `aweshare agent config edit` — open config in `$VISUAL`/`$EDITOR`/`vi`
- `aweshare agent grant --alias ALIAS --consumer NAME [--expires-in 7d|12h|30m|90s]`
- `aweshare agent revoke --alias ALIAS --consumer NAME`
- `aweshare hub init`, `aweshare hub token issue`, `aweshare hub token revoke`, `aweshare hub token restore --role R --id N`
- `aweshare hub invite create [--name NAME] [--count N] [--expires-in 7d]`, `aweshare hub invite revoke --id N`, `aweshare hub invite restore --id N` — one-time producer invite codes (`asi_…`, printed once; re-view with `invite list --reveal`)
- `aweshare agent join --hub URL --code asi_… [--name NAME --email YOU@EXAMPLE.COM]` — redeem an invite code into a producer token and write it into the config
- `aweshare hub grant add|remove`, `aweshare hub consumer limits` (flags: `--rps` `--burst` `--concurrency` `--tpm` `--max-total-tokens` `--clear`)

## Suspension semantics (hub)

Token revocation is **reversible suspension**, never deletion: `hub token revoke --role R --id N` sets the suspension flag (closes a producer's tunnel at once); `hub token restore --role R --id N` clears it — the same token works again, and grants/offerings/usage survived. Suspended tokens get `401 TOKEN_REVOKED` (not a bare invalid key). An invite and the producer it minted move together: revoking a redeemed code suspends that producer, and restoring from either handle (`invite restore` or `token restore`) revives both; restoring a producer needs a free slot (`403 HUB_FULL` when `AWESHARE_MAX_PRODUCERS`, default 10, active producers are reached — the cap also gates `token issue --role producer` and invite redeem).

## Intent Router

| User intent | Domain | Approach |
|---|---|---|
| "Set up sharing on my machine" | Agent setup | `aweshare agent init`, edit config.toml, fill secrets.json |
| "Share my Ollama / vLLM model" | Add backend + offering | Edit config.toml |
| "Share an OpenAI/Anthropic key" | Add backend + offering | Edit config.toml; warn about upstream ToS (see Trust) |
| "Where is the config?" | Config Path | `aweshare agent config path` |
| "Show my config" | Config Show | `aweshare agent config show` |
| "Something doesn't work" | Diagnose | `aweshare agent doctor` — fix the first FAIL |
| "Let NAME use my model" | Grant | `aweshare agent grant --alias ns/model --consumer NAME` |
| "Stop NAME from using my model" | Revoke (grant) | `aweshare agent revoke --alias ns/model --consumer NAME` |
| "Suspend / bring back a user or token" | Hub admin | `aweshare hub token revoke` / `token restore` (reversible; a redeemed invite suspends its producer too — see Suspension semantics) |
| "Who can use what?" | Browse | `aweshare agent list` |
| "Set up a hub" | Hub setup | npm or Docker — see Hub Deployment; `init` prints the admin token once; user runs `serve`/container themselves |
| "Issue a producer/consumer token" | Hub admin | `aweshare hub token issue --role R --name NAME` |
| "Rate-limit or cap a consumer" | Hub admin | `aweshare hub consumer limits --name NAME --rps N --tpm N --max-total-tokens N ...` |
| "How much was used?" | Metering | `aweshare hub usage` |
| "Invite producers without hand-delivering tokens" | Invite codes | `aweshare hub invite create --name NAME` (bound) or `--count N` (unbound); producer redeems via `aweshare agent join` — see Producer Admission |
| "Point Claude Code / an SDK at the hub" | Consumer | Explain env vars (see Consumer Setup) |
| "Update aweshare itself", "upgrade the CLI/hub" | Self-Update | `aweshare self-update --check` first, then see Self-Update (npm vs Docker differ) |

## Config Location

Agent: `~/.aweshare/` — `config.toml` + `secrets.json` (override with `AWESHARE_AGENT_DIR`).
Hub: `~/.aweshare-hub/` (override with `AWESHARE_HUB_DATA_DIR`).

Always read the config before modifying it. Run `aweshare agent config show` first — secrets are redacted in its output, so read `config.toml` directly only when you need the structure, never print `secrets.json` values.

## Hub Deployment (npm or Docker)

Both paths are first-class. Docker is the better default on a VPS (restart policy survives reboots, no Node on the host, data isolated in a volume); npm is fine for local or quick setups. In both cases the user runs the server themselves (see Do Not Launch).

**npm:**

```bash
npm install -g aweshare        # Node ≥ 22
aweshare hub init              # data in ~/.aweshare-hub; prints the admin token ONCE — save it
aweshare hub serve             # user runs this in their own terminal / systemd
```

**Docker** (image is hub-only; the agent always runs on producer machines):

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

Hub admin commands (`token issue/list/revoke`, `grant add/remove/list`, `consumer limits`, `usage`) read the admin token file `<AWESHARE_HUB_DATA_DIR>/admin-token` and call the admin API at `AWESHARE_HUB_URL` (default `http://127.0.0.1:8787`). When the hub runs on a server:

- run the commands on the server (`ssh` + CLI, or `docker exec aweshare-hub aweshare hub token issue ...`), or
- run them locally with `AWESHARE_HUB_URL=https://<hub-host>` and the admin-token file placed in a local `AWESHARE_HUB_DATA_DIR`.

Running them from the user's laptop without both will fail ("no admin token at ..." or connection refused) — check this before treating it as a hub malfunction.

### Hub env vars

| Env var | Default | Purpose |
|---|---|---|
| `AWESHARE_HUB_DATA_DIR` | `~/.aweshare-hub` (image: `/data`) | SQLite, pepper, admin token — volume-mount it |
| `AWESHARE_HUB_HOST` · `AWESHARE_HUB_PORT` | `0.0.0.0` · `8787` | listen address for `serve` |
| `AWESHARE_CONSUMER_RPS` · `AWESHARE_CONSUMER_BURST` · `AWESHARE_CONSUMER_CONCURRENCY` | `10` · `20` · `8` | hub-wide per-consumer defaults |
| `AWESHARE_HEAD_TIMEOUT_MS` · `AWESHARE_IDLE_TIMEOUT_MS` | `120000` · `300000` | response-head timeout / stream idle timeout |
| `AWESHARE_MAX_BODY_BYTES` | `32MB` | request body cap |
| `AWESHARE_INVITE_REDEEM_PER_MIN` | `10` | rate limit for the unauthenticated invite-redeem endpoint |
| `AWESHARE_MAX_PRODUCERS` | `10` | max active producers — issue/redeem/restore refuse with `403 HUB_FULL` when full |

## Producer Admission via Invite Codes

Besides the admin issuing a producer token (`hub token issue --role producer`) and handing over the secret, producers can self-service:

```bash
# bound: locked to one producer name
aweshare hub invite create --name peng [--expires-in 7d]      # → asi_..., send to the producer
# unbound: batch hand-out; producer submits name + email at redeem
aweshare hub invite create --count 10 [--expires-in 7d]

# producer side — redeems the code, writes the token into their config:
aweshare agent join --hub https://<hub-host> --code asi_... [--name NAME --email YOU@EXAMPLE.COM]
```

Codes are single-use, optionally expiring, and revocable at any stage (`hub invite list` shows pending/used/suspended/revoked/expired; `hub invite revoke --id N`, undo with `hub invite restore --id N`). Revoking a **redeemed** code suspends the producer it minted (its token dies, tunnel closes) — one code, one producer; restoring from either side revives both. `hub invite list --reveal` re-shows stored codes (pre-v4 rows have no plaintext — revoke and re-create those). Redeem and issue respect the active-producer cap (`AWESHARE_MAX_PRODUCERS`, default 10; `403 HUB_FULL` when full). After a successful join, continue with the normal first-time producer setup (edit backends/offerings, doctor, grant).

## Agent Config Structure (config.toml)

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
maxConcurrency = 1                       # 1..64
```

secrets.json maps `keyRef` names to upstream API keys:

```json
{ "openai-key": "sk-..." }
```

**Rules:**
- The namespace in every alias must match the producer name the token was issued for.
- Upstream keys live only in secrets.json on the producer's machine — never in config.toml, never in chat output.
- `anthropic`-protocol baseUrl excludes `/v1` (the agent appends it); `openai`-protocol baseUrl includes `/v1`; `responses`-protocol baseUrl includes the version path (e.g. `https://open.bigmodel.cn/api/v1`).
- An alias speaks exactly one wire protocol — there is no cross-protocol conversion.
- `upstreamModel` must match the backend exactly (e.g. `ollama list` tag).

## Workflows

### First-time producer setup

1. `aweshare agent init [--hub URL] [--token asp_...]` — writes templates (kept if they exist)
2. Edit `config.toml`: set hubUrl/token, define backends and offerings
3. Put upstream keys in `secrets.json` (chmod 600 already applied)
4. `aweshare agent doctor` — must be all green
5. `aweshare agent grant --alias ns/model --consumer NAME`
6. Tell the user to run `aweshare agent start` in their own terminal

### Add a backend / offering

1. Read config.toml (via `aweshare agent config show` or the file)
2. Append a `[[backends]]` block (unique `id`, valid `protocol`, correct baseUrl convention)
3. If the backend needs a key: add `keyRef = "name"` and the matching entry in secrets.json
4. Append an `[[offerings]]` block mapping `namespace/alias` to the backend + upstreamModel
5. Verify with `aweshare agent doctor`

### Grant / revoke access

```bash
aweshare agent grant --alias peng/gpt-4o --consumer alice --expires-in 7d
aweshare agent revoke --alias peng/gpt-4o --consumer alice
aweshare agent list
```

Hub-side equivalents (`aweshare hub grant add|remove|list`) do the same thing via the admin API.

### Verify configuration

```bash
aweshare agent config show    # config with token + secrets redacted
aweshare agent doctor         # config validity, backend reachability, hub connectivity
```

### Consumer Setup

Consumers point a standard SDK at the hub — no special client:

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
- A running `aweshare agent start` does not hot-reload — restart it after updating the CLI on that machine.
- The CLI prints a passive update reminder at most once per 24h; disable with `AWESHARE_NO_UPDATE_CHECK=1`.

If the installed `aweshare` doesn't match what the user expects from the repository:

1. `which aweshare` — confirm which binary is active
2. `aweshare self-update --check` — installed vs npm latest ("unknown target" means the install predates 0.2.4, when self-update landed)
3. Update via `npm install -g aweshare` (or have the user run `aweshare self-update` in their own terminal), then `aweshare -v`
4. If the mismatch persists, inspect the global package (`npm ls -g aweshare`) to confirm which code is actually running.

## Trust and Compliance

Before sharing a backend, warn the user: relaying a personal-subscription API key (coding plans included) to third parties likely violates the upstream's terms. Self-hosted open models (Ollama/vLLM) have no such issue. When in doubt, don't share. The producer bears the consequences (key revocation, account suspension).

## Core Rules

1. **Do not run `agent start` or `hub serve` inside the agent.** They are foreground long-running processes. Tell the user to run them in their own terminal.
2. Always read the config before editing. Never overwrite existing backends/offerings without checking.
3. Never print or copy upstream API keys from secrets.json. Use `aweshare agent config show` (redacted) when showing config to the user.
4. Offering aliases must be `namespace/name` (lowercase) with the namespace matching the producer token's name; names are globally unique on the hub.
5. Use `aweshare agent doctor` after any config change; fix the first FAIL, then re-run.
6. `aweshare agent config init` (like `agent init`) is a no-op if files already exist — it will not clobber.
7. Hub admin commands need the admin token from `aweshare hub init` output; it is printed only once. They read `<AWESHARE_HUB_DATA_DIR>/admin-token` and dial `AWESHARE_HUB_URL` (default `http://127.0.0.1:8787`) — for a remote hub see Hub Deployment.

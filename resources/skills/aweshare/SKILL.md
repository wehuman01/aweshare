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
- `aweshare hub token list`
- `aweshare hub grant list`
- `aweshare hub usage [--alias ALIAS]`

You may also run these commands (they modify files/state but are non-interactive):
- `aweshare agent config init` — write config template + empty secrets (no-op if they exist)
- `aweshare agent config edit` — open config in `$VISUAL`/`$EDITOR`/`vi`
- `aweshare agent grant --alias ALIAS --consumer NAME [--expires-in 7d|12h|30m|90s]`
- `aweshare agent revoke --alias ALIAS --consumer NAME`
- `aweshare hub init`, `aweshare hub token issue`, `aweshare hub token revoke`
- `aweshare hub grant add|remove`, `aweshare hub consumer limits`

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
| "Stop NAME from using my model" | Revoke | `aweshare agent revoke --alias ns/model --consumer NAME` |
| "Who can use what?" | Browse | `aweshare agent list` |
| "Set up a hub" | Hub setup | npm or Docker — see Hub Deployment; `init` prints the admin token once; user runs `serve`/container themselves |
| "Issue a producer/consumer token" | Hub admin | `aweshare hub token issue --role R --name NAME` |
| "Rate-limit a consumer" | Hub admin | `aweshare hub consumer limits --name NAME --rps N ...` |
| "How much was used?" | Metering | `aweshare hub usage` |
| "Point Claude Code / an SDK at the hub" | Consumer | Explain env vars (see Consumer Setup) |

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
docker run -d --name aweshare-hub --restart unless-stopped \
  -p 127.0.0.1:8787:8787 -v "$PWD/data:/data" ghcr.io/wehuman01/aweshare:latest
docker exec aweshare-hub aweshare hub init   # first run: prints the admin token ONCE — save it
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

## Agent Config Structure (config.toml)

```toml
hubUrl = "http://127.0.0.1:8787"        # hub to dial out to (WSS reverse tunnel)
token = "asp_..."                        # producer token from the hub operator

[[backends]]
id = "ollama"                            # local name referenced by offerings
protocol = "openai"                      # openai | anthropic
baseUrl = "http://127.0.0.1:11434/v1"    # openai-style includes /v1; anthropic-style excludes it
# keyRef = "openai-key"                  # optional; value lives in secrets.json

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
- `anthropic`-protocol baseUrl excludes `/v1` (the agent appends it); `openai`-protocol baseUrl includes `/v1`.
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

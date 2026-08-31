# aweshare Bootstrap Protocol

This document is for AI coding agents. Help the user install and configure `aweshare`, a local-first AI capability relay: producers share local Ollama/vLLM or authorized OpenAI/Anthropic backends through a self-hosted hub; consumers point standard OpenAI/Anthropic SDKs at the hub and call models by `namespace/alias`.

## Long-Running Services and Secrets

Unlike ordinary CLIs, aweshare's two core processes are **long-running services**:

- Never launch them from this agent — not `aweshare hub serve`, not `aweshare producer start` (foreground blocks the session; even `--background` starts a shared service, which is the user's call). The same applies to deploying the hub as a container (`docker run` / `docker compose up` of `ghcr.io/wehuman01/aweshare`). Give the user the commands and let them run them in their own terminal.
- Upstream API keys live only in `~/.aweshare/secrets.json` (0600) on the producer's machine. Never print them, never echo them into logs or chat. `aweshare producer config show` redacts them.
- Some tokens are printed exactly once (the hub admin token from `hub init`, an `asc_` consumer token from `consumer join`, invite codes from `hub admin invite mint`). Prefer having the user run those commands so the secret lands in their terminal; if you must run one, tell the user to save the value immediately.
- Before helping share an OpenAI/Anthropic backend, state the compliance boundary: relaying a personal-subscription key (coding plans included) to third parties likely violates the upstream's terms; self-hosted open models have no such issue. When in doubt, don't share.

## Language Behavior

- Reply in the user's language when possible.
- If the user asks in Chinese, continue in Chinese.
- If the user asks in English, continue in English.

## Step 0: Identify the user's role

aweshare has three roles with different setups. Ask which one applies (more than one is possible):

- **Hub operator** — runs the public hub on an always-on server; mints invite codes.
- **Producer** — shares models from their own machine through a hub.
- **Consumer** — calls shared models with a standard SDK from any machine.

Then follow Steps 1–2 (identical for everyone) and the matching path in Step 4.

## Step 1: Install aweshare CLI

### Prerequisites

- Node >= 22 (`node --version`)

If Node.js is missing, tell the user to install it from https://nodejs.org/.

### Steps

```bash
npm install -g aweshare
aweshare -v
```

Expected output: a version number (e.g. `0.4.8`).

---

## Step 2: Install the aweshare skill

Install the skill so the agent can operate aweshare in this and future sessions. Choose one of the following options.

### Option A: Via aweskill (recommended if aweskill is available)

Use this option if the user already has aweskill installed, or is willing to install it. This gives full skill management — install, update, projection, backup.

#### Prerequisites

- Node.js >= 20 (`node --version`) — required by aweskill
- npm available (`npm --version`)

#### Steps

##### A1. Install aweskill (if not already installed)

```bash
npm install -g aweskill
```

##### A2. Initialize the aweskill central store (if not already done)

```bash
aweskill store init
```

##### A3. Install the aweshare skill from GitHub

```bash
aweskill install wehuman01/aweshare
```

##### A4. Identify the current agent

```bash
aweskill agent supported
```

Look for lines marked with `✓`. Common agent ids: `claude-code`, `cursor`, `codex`, `gemini-cli`, `windsurf`, `opencode`, `qwen-code`.

If you cannot determine the agent id, ask the user.

##### A5. Project the aweshare skill to this agent

```bash
aweskill agent add skill aweshare --global --agent <agent-id>
```

##### A6. Verify

```bash
aweskill agent list --global --agent <agent-id>
```

Expected: `aweshare` shows as `linked`.

---

### Option B: Direct copy (no aweskill needed)

Use this option if the user does not have aweskill. This copies the SKILL.md file directly into the agent's skill directory.

#### Prerequisites

- `curl` or `wget` available

#### Steps

##### B1. Identify the current agent's skill directory

Determine which agent is running and its global skill directory:

| Agent | Skill directory |
|---|---|
| Claude Code | `~/.claude/skills/aweshare/` |
| Codex | `~/.codex/skills/aweshare/` |
| Cursor | `.cursor/skills/aweshare/` (project-level) |
| Gemini CLI | `~/.gemini/skills/aweshare/` |
| Windsurf | `~/.windsurf/skills/aweshare/` |
| OpenCode | `~/.opencode/skills/aweshare/` |
| Qwen Code | `~/.qwen/skills/aweshare/` |

If the agent is not in this list, ask the user where to place the skill file.

##### B2. Download and place SKILL.md

```bash
mkdir -p <skill-directory>
curl -fsSL https://raw.githubusercontent.com/wehuman01/aweshare/main/resources/skills/aweshare/SKILL.md -o <skill-directory>/SKILL.md
```

Replace `<skill-directory>` with the path from step B1.

---

## Step 3: Detect the current setup (read-only, safe to run)

```bash
aweshare producer config path       # where config.toml / secrets.json live
aweshare producer config show       # config with token + secrets redacted
aweshare producer doctor --status   # background producer state + recent log, instant, no network
```

Report the findings to the user:

- No config at `~/.aweshare/config.toml` — fresh machine, continue with Step 4.
- Config present — a producer is (or was) set up here; `doctor --status` tells whether a background instance is running.
- Full `aweshare producer doctor` (without `--status`) adds network probes of the configured backends and the hub plus the recent log. Diagnostic traffic only — run it freely after setup, fix the first FAIL, re-run until green.

---

## Step 4: Role-specific setup

Interactive or service-starting commands stay in the user's terminal. Everything else you can do.

### Producer — shares models from this machine

1. Join the hub (either works):
   - The user redeems their invite code — you may run it, it is non-interactive and writes `~/.aweshare/config.toml` + empty `secrets.json`:
     ```bash
     aweshare producer join --hub https://hub.example.com --code asi_...
     ```
   - Or the operator handed over a token directly:
     ```bash
     aweshare producer init --hub https://hub.example.com --token asp_...
     ```
2. Edit `config.toml` yourself: set `hubUrl`/`token`, define `[[backends]]` (protocol + baseUrl convention: `openai` baseUrl includes `/v1`; `anthropic` excludes `/v1`; `responses` includes the version path) and `[[offerings]]` (alias namespace = producer name, one upstream model each).
3. Upstream keys go into `secrets.json` under the backend's `keyRef` name. **Do not ask the user to paste keys into chat** — ask them to edit `secrets.json` themselves, then continue.
4. Verify:
   ```bash
   aweshare producer doctor      # instance, config, backend probes, hub — fix the first FAIL
   ```
5. Tell the user (do not run):
   > Run `aweshare producer start` in your terminal — or `aweshare producer start --background` to detach it (logs to `~/.aweshare/producer.log`). Stopping later: `aweshare producer stop`.

After config edits on a running producer, `aweshare producer reload` applies the new catalog without a restart (both processes also stat-poll their config every 2s and hot-apply valid edits; `hubUrl`/`token` still need a restart).

### Consumer — calls shared models

1. Have the user redeem their invite in their own terminal — it prints the `asc_` token exactly once:
   ```bash
   aweshare consumer join --hub https://hub.example.com --code asi_...
   ```
   (No aweshare installed? One curl works: `POST https://hub.example.com/invites/v1/redeem` with `{"code":"asi_..."}`.)
2. Configure the tool with the printed env vars:
   ```bash
   # Claude Code / Anthropic SDK — the key is the asc_ consumer key, NOT any upstream x-api-key
   export ANTHROPIC_BASE_URL=https://hub.example.com
   export ANTHROPIC_AUTH_TOKEN=asc_...
   claude --model peng/sonnet

   # OpenAI SDK / Codex
   export OPENAI_BASE_URL=https://hub.example.com/v1
   export OPENAI_API_KEY=asc_...
   ```
3. Discovery (read-only, safe to run once you have the token):
   ```bash
   aweshare consumer list --hub https://hub.example.com --token asc_...
   ```
   Every producer, alias, protocol, status, caps, live occupancy and remaining daily tokens.
4. Verify offerings end-to-end (real model calls, consume quota — scope with `--alias`; the hub budgets probe-shaped requests at 15/day per consumer):
   ```bash
   aweshare consumer list --hub https://hub.example.com --token asc_... --ping
   ```
   The table gains LAST SEEN (the hub's own freshness evidence) plus the consumer's RESULT/TIME/DETAIL per row.
4. A first smoke-test request (`curl ... /v1/chat/completions` with `"ping"`) is a real model call — only run it when the user asks.

Remind the consumer: prompts and responses transit the hub in plaintext — only use a hub they trust. If Claude Code ignores env config, a stale OAuth login is overriding it — switch with `/login`.

### Hub operator — runs the hub on a server

1. Choose npm or Docker (Docker is the better default on a VPS). Both `hub serve` and container deployment run in the **user's** terminal:
   ```bash
   # npm
   npm install -g aweshare
   aweshare hub init        # data in ~/.aweshare-hub; prints the admin token ONCE — save it
   aweshare hub serve       # listens on :8787; put Caddy/nginx TLS in front

   # docker
   docker run -d --name aweshare-hub --restart unless-stopped \
     -p 127.0.0.1:8787:8787 -v "$PWD/data:/data" ghcr.io/wehuman01/aweshare:latest
   docker exec aweshare-hub aweshare hub init
   ```
2. After `hub init` (wherever it ran), mint invites — you may run these:
   ```bash
   aweshare hub admin invite mint --name peng                       # bound producer code → asi_...
   aweshare hub admin invite mint --count 10                        # unbound batch, name+email at redeem
   aweshare hub admin invite mint --role consumer --name alice      # bound consumer code → asi_...
   ```
   Consumers redeem codes themselves (`aweshare consumer join`); producers via `aweshare producer join`.
3. Administering a remote hub: run admin commands on the server (`ssh` + CLI, or `docker exec aweshare-hub aweshare hub ...`), or locally with `AWESHARE_HUB_URL=https://<hub-host>` plus the admin-token file in a local data dir — otherwise they fail with "no admin token" / connection refused.
4. Guardrails you can tune on request: per-consumer `aweshare hub limits NAME [--rps N] [--tpm N] [--max-total-tokens N] ...`, suspension `aweshare hub admin invite revoke N` / `restore N` (reversible, invite-keyed).
5. Security notes for the operator: keep :8787 off the public internet behind TLS; a redeemed consumer key can call **every** offering on the hub; tokens/codes stored plaintext-recoverable (`hub list invites --reveal` / `--token`) means a data-dir leak exposes identities — guard it.

---

## Step 5: Verify and tune (safe to run)

After setup:

```bash
aweshare producer doctor            # full diagnosis, ordered to find the first failing link
aweshare producer list              # registered offerings, live status, caps, occupancy, config drift
aweshare hub status                  # live dashboard: capacity, 5m health, admission pressure
aweshare hub list offerings          # the catalog table (worst status first)
aweshare hub list usage                  # who used how much, aggregated per consumer × model
aweshare self-update --check        # installed vs npm latest
```

On the user's request you may also:

```bash
aweshare hub limits alice --tpm 60000 --max-total-tokens 5000000   # cap a consumer
aweshare hub list usage --details --since 24h                           # per-request log
aweshare producer reload                                           # apply config edits without restart
```

## Useful commands

Read-only commands (safe to run in agent):

```bash
aweshare -v                          # installed version
aweshare producer config path        # config/secrets locations
aweshare producer config show        # config, secrets redacted
aweshare producer doctor [--status]  # diagnosis (with --status: instant, no network)
aweshare producer list [--json]      # this producer's offerings + drift
aweshare producer list usage [...]   # who used this producer's models
aweshare producer status             # one-glance summary: process, config counts, health rollup
aweshare consumer list --hub URL --token asc_...   # hub catalog view
aweshare consumer list --hub URL --token asc_... [--ping] [--alias a,b]  # discovery; --ping adds real-call proof
aweshare hub status                          # capacity + 5m health + admission pressure
aweshare hub list invites [--reveal|--token]        # invite ledger / codes / minted tokens
aweshare hub limits NAME             # bare call views current overrides
aweshare hub list usage [--details] [--group-by consumer|alias] [--since 7d]
aweshare self-update --check         # versions only
```

Local changes (run on user request):

```bash
aweshare producer init [--hub URL] [--token asp_...]   # write templates; no-op if they exist
aweshare producer join --hub URL --code asi_...        # redeem a producer invite into the config
aweshare producer config edit                          # open config.toml in $EDITOR
aweshare producer reload                               # re-read config + re-register offerings
aweshare hub init                                      # create data dir + admin token (printed once!)
aweshare hub admin invite mint [--role producer|consumer] ...   # mint one-time codes (printed once)
aweshare hub limits NAME [--rps N] [--burst N] [--max-concurrent N] [--tpm N] [--max-total-tokens N] [--clear]
aweshare hub admin invite revoke N / restore N    # reversible suspension, by invite handle
aweshare hub admin offering revoke ALIAS / restore ALIAS   # per-alias scalpel
```

User-only commands (long-running, TTY-confirming, or one-time-secret-printing):

```bash
aweshare producer start [--background] / stop          # the relay service
aweshare hub serve                                     # the hub
aweshare consumer join --hub URL --code asi_...        # prints the asc_ token once
aweshare self-update                                   # y/n confirm; non-interactive: npm install -g aweshare
docker run / docker compose up                         # hub deployment
```

## Safety Rules

- Never start or stop the long-running services (`hub serve`, `producer start`/`stop`, hub containers) inside the agent — deployment is the user's call. Inspect a detached producer with `producer doctor --status`.
- Never read or print `secrets.json` values; use `producer config show` (redacted) when showing config. Never ask the user to paste an upstream API key into chat — point them at the file instead.
- Commands that print a secret exactly once (`hub init`, `consumer join`, `hub admin invite mint`) are best run by the user; if you run one, flag the value as save-now.
- State the trust boundary before anyone joins a hub: consumer traffic transits the hub in plaintext; a redeemed consumer key can call every offering. State the compliance boundary before anyone shares a key: personal-subscription keys forwarded to third parties likely violate upstream terms — the producer bears the consequences.
- Read state through the CLI (`config show`, `list`, `doctor`); do not hand-edit SQLite or pidfiles. Config TOML edits are fine — they hot-reload.
- Offering aliases must be `namespace/name`, lowercase, namespace matching the producer token's name. One offering = one upstream model; the old `maxConcurrency` key fails validation with a rename hint (use `maxConcurrencyPerUser`).
- If any command fails, report the exact command and error message (codes like `403 HUB_FULL`, `409 INVITE_ROLE_MISMATCH`, `401 TOKEN_REVOKED` carry meaning — pass them through). Do not silently retry.

## Final Step

After setup, tell the user to invoke skills (`/` in Claude Code, `$` in Codex, or the equivalent in other agents) and check if `aweshare` appears in the list. If it does, the skill is ready to use immediately. If not, the user should restart the agent.

> aweshare is installed and configured. Invoke skills (type `/` or `$` depending on your agent) and look for `aweshare` — if it appears, you're good to go. If not, restart the agent. Then you can ask me things like:
>
> - "Share my local Ollama qwen2.5:7b as peng/qwen2.5.7b."
> - "Why is my producer offline?" (I'll run `producer doctor` and fix the first FAIL.)
> - "Cap alice at 60k tokens per minute."
> - "Who used my models this week?"

If the user is speaking Chinese, use this version instead:

> aweshare 已安装并配置完成。请调用 skills（输入 `/` 或 `$`，取决于你的 agent），看看列表中是否出现了 `aweshare`。如果出现了，说明已就绪可以直接使用。如果没有，请重启 agent 后再试。然后你可以继续问我，例如：
>
> - “把我本地的 Ollama qwen2.5:7b 以 peng/qwen2.5.7b 共享出去。”
> - “我的 producer 为什么掉线了？”（我会跑 `producer doctor` 并修复第一个 FAIL。）
> - “给 alice 限流到每分钟 6 万 token。”
> - “这周谁用了我的模型？”

---

## Next Steps

### Community hub — no server of your own

The project's developer runs an invite-based community hub at https://aweshare.wehuman.top. If the user wants to share or consume without operating a hub, guide them through the tutorial: https://github.com/wehuman01/aweshare/blob/main/docs/community-hub/README.md — requesting an invite at peng@wehuman.top, joining as producer or consumer, and the first connection. State the trust rule before they join: their traffic transits that hub in plaintext.

### awewarm — keep shared subscription windows warm

If the user shares a coding-plan-backed endpoint through aweshare, pair it with [awewarm](https://github.com/wehuman01/awewarm): it schedules one minimal request per window so the underlying subscription quota never cools down mid-day. Its agent doc lives at https://github.com/wehuman01/awewarm/blob/main/README.ai.md.

### aweswitch — agent profile switching

Consumers who juggle several providers can use [aweswitch](https://github.com/Webioinfo01/aweswitch) to switch Claude Code / Codex / OpenCode profiles; pointing one of those profiles at an aweshare hub is just another provider entry.

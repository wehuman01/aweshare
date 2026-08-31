# aweshare: I Let My Agent Share My Tokens

![aweshare](../../logo/logo.png)

Being the only person in the group with model access is its own tax: a 4090 sitting idle in the corner, subscription keys your friends can't reach, and every request landing back on you as copy-paste relay work. You are the API — and that scales to exactly one person.

aweshare ends this with a local-first relay. You run a lightweight agent on your machine; your friends point their standard OpenAI or Anthropic SDK at a hub; requests travel through a single WebSocket tunnel back to your machine, where your keys inject themselves at call time. What gets shared is never the key — it's capability, metered in tokens, from an idle GPU or a subscription you already pay for.

And aweshare makes a second bet: a relay needs configuring and maintaining, and that someone doesn't have to be you. It ships a bootstrap protocol (`README.ai.md`), a skill, and a CLI built to be operated end-to-end by an AI agent. So I gave mine one prompt:

> "Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it. I have a 4090 with Ollama running qwen2.5:7b and qwen2.5:14b, plus a GLM coding-plan key — share all of it with two friends."

It asked my role first (producer), registered both Ollama models with `maxConcurrencyPerUser = 1` each (local models, single GPU), hung the GLM key off as `peng/glm-4-flash` behind a `dailyTokens` cap — subscription quota is real money — minted two invites, and ran `producer doctor` to verify config → backend → hub. My friends redeemed their codes themselves: `aweshare consumer join` prints the `asc_` key exactly once, with SDK env vars ready to paste.

Then it said: "Run `aweshare producer start` in your terminal. I will not start the long-running process for you."

That is the new shape of installing an agent tool. The install is a task. The agent does tasks. So I gave the task to the agent.

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## The Install: A Bootstrap Protocol the Agent Follows

Most agent tools ship a `README.md` for humans and a separate `README.ai.md` for agents. The split is honest: humans want a marketing story, agents want a procedure. aweshare leans into this — its `README.ai.md` is a bootstrap protocol: identify the user's role (hub operator, producer, consumer), install the CLI, install the skill, detect any existing setup, then walk the role-specific path. Steps that print one-time tokens or start long-running services are explicitly handed back to your terminal.

The producer path, condensed:

1. `npm install -g aweshare` (Node ≥ 22) and verify with `aweshare --version`
2. `aweshare hub init` on the VPS — creates the data dir and prints the admin token once, save it (Docker works too: `ghcr.io/wehuman01/aweshare`, then `docker exec aweshare-hub aweshare hub init`)
3. `aweshare hub serve` — your terminal, not the agent's
4. `aweshare hub invite --name <name>` mints one-time producer codes (`asi_...`); `--role consumer --name <name>` for consumers. Codes expire after 7 days by default, and the expiry bounds the minted identity too — an expired key fails auth with `401 TOKEN_EXPIRED` and its tunnel closes. `--expires-in none` mints a pair that never expires.
5. `aweshare producer join --hub <url> --code asi_...` on the producer machine writes `~/.aweshare/config.toml` and `secrets.json`
6. Edit `config.toml` to register backends (`openai`, `anthropic`, `responses` protocols) and offerings — alias `namespace/name`, one upstream model each, or a `backends = [...]` list to speak several wire protocols on one alias. Upstream keys go in `secrets.json` — they never leave this machine.
7. `aweshare producer doctor` — config → backend → hub, fix the first FAIL, re-run until green
8. Tell the user to run `aweshare producer start`

Admission is invite-only, and that is the whole permission model: every admitted consumer may call every offering. No grants to wire, no marketplace. The guardrails are limits — sparse per-consumer `hub limits` overrides (`--rps`, `--tpm`, `--max-total-tokens`; unset keys keep the hub defaults) and per-offering caps (`maxConcurrencyPerUser`, `maxConcurrentUsers`, `dailyTokens`) — all enforced by the hub.

### The 30-Second Version

In Claude Code, Codex, OpenCode, or any of the 47+ agents supported by aweskill, the prompt is the same:

> "Set up aweshare for me. Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it. I have an idle GPU with Ollama running qwen2.5:7b and qwen2.5:14b, plus a GLM coding-plan key. My hub is at hub.example.com."

The agent does the rest. It installs the npm package and the skill, initializes the hub, mints the invites, writes the config, registers the offerings, and runs the doctor. If something fails — Node too old, Ollama not running, hub unreachable — it stops and asks, instead of silently breaking things.

### What the Agent Will Not Do

This is the most important boundary. aweshare has two long-running processes: the hub (`aweshare hub serve`) and the producer (`aweshare producer start`). The agent will never run either of them — nor `producer stop`, nor the Docker deployment of the hub. It will never start, stop, or restart the server or the tunnel.

The README says so explicitly. The skill says so explicitly. The safety rule is unambiguous: long-running daemons are the user's terminal. The agent's job is configuration — `init`, `invite`, `producer join`, `producer doctor`, `hub limits`, `hub usage`, editing `config.toml`. Even the upstream keys stay out of the chat: the agent writes the config skeleton and asks you to fill `secrets.json` yourself. The agent lives in the text file world. The daemons live in the socket world. They do not cross.

The boundary costs you no convenience, because config changes no longer need a restart: both processes hot-apply valid edits within two seconds, and `aweshare producer reload` re-registers offerings on the open tunnel without a disconnect. The day-to-day relay management — list consumers, check usage, add offerings, set limits, mint invites — is all agent-runnable. Only the actual hub and producer processes are yours to start in your own terminal. (`producer start --background` exists when you want the process detached — still your call, your terminal.)

## A Day in Practice

It is Tuesday. The hub is running on a $6 VPS. Your agent is connected from your desktop. Two friends have consumer tokens.

**7:42 AM.** You start the day. `aweshare producer start` is already running from yesterday. You want to see how the relay went overnight:

```
aweshare hub usage
```

The default view is an aggregate, not a log: one row per consumer × model, a person's rows together, busiest person and busiest model first — requests, errors, best-effort token totals, mean duration — with the 7-day window printed in the header. Overnight: 847 requests to `peng/qwen2.5.7b`, 312 to `peng/qwen2.5.14b`, and a steady night of `peng/glm-4-flash` on the subscription side — average latency 1.2s for the 7B model and 2.8s for the 14B. No errors, no rate-limit hits. Want the per-request log instead? `--details`. Just one person? `--consumer bob`. You make a note to check if the 14B model is oversubscribed.

**9:15 AM.** A friend messages you: "Can I try your models?" You tell the agent:

> "Invite alice as a consumer."

The agent runs `aweshare hub invite --role consumer --name alice` and hands you the one-time code (`asi_...`) to forward — it expires in 7 days, so she should redeem soon. Alice redeems it herself — `aweshare consumer join` prints her `asc_` key once, with the SDK env vars ready to paste; a friend without aweshare installed can redeem with one curl. She runs a test request and gets a response. You did not touch a config file. You did not restart anything. Admission is the permission: once she is in, she can call every offering on the hub.

**11:30 AM.** You want to share another subscription. You tell the agent:

> "Share my Anthropic subscription too. The key is in my secrets."

The agent reads `~/.aweshare/config.toml`, adds the Anthropic backend entry with `protocol = "anthropic"`, registers `peng/claude-sonnet` as an offering, points the key reference at `secrets.json`, and sets a `dailyTokens` cap to protect the quota. Then `aweshare producer reload` applies the new offering on the open tunnel — no restart, no disconnect, consumers never see a blip. No copy-paste. No "let me find the docs."

**1:00 PM.** Bob is running a batch job that's eating your GPU and your subscription quota alike. You want to set a limit:

```
aweshare hub limits bob --rps 2 --tpm 60000
```

The agent applies the sparse override — 2 requests per second, 60k tokens per minute. Unset keys keep the hub defaults; the override merges into whatever was already set. You did not need to remember the CLI flags. The agent knew them.

**3:00 PM.** You want to check if everything is healthy:

```
aweshare producer doctor
aweshare hub status
```

Doctor probes the background instance, the config, the backends, and the hub connection — all green, `4/4 offerings registered`. `hub status` gives the operator's overview: per-alias health (one alias speaking several protocols gets one verdict, the worst), live occupancy `IN USE 1/3`, today's remaining daily tokens, and a last-5-minutes line — requests, success rate, errors. The 14B model has been running for 6 hours without a single AUTH or QUOTA failure.

**6:00 PM.** You are done. Three backends — one idle GPU and two subscriptions — four offerings, four consumers, two with per-consumer limits. The agent handled every config change. The hub handled every request. The producer handled every relay. You never opened `~/.aweshare/config.toml` by hand.

## The Stack: What the Skill Can Reach

The `aweshare` skill is intentionally small. It does not try to be a general agent framework. It is a thin procedural layer over the `aweshare` CLI, with an intent router that maps natural language to commands.

| You say | The skill runs |
|---|---|
| "Who used my models this week?" | `aweshare hub usage` — per consumer × model, busiest first |
| "Invite alice as a consumer." | `aweshare hub invite --role consumer --name alice` |
| "Share my Anthropic subscription too." | edits `config.toml` + `secrets.json`, registers the offering |
| "Apply my config edits." | `aweshare producer reload` — no restart, no disconnect |
| "Cap bob at 2 RPS and 60k tokens a minute." | `aweshare hub limits bob --rps 2 --tpm 60000` |
| "How is the hub doing?" | `aweshare hub status` — alias health, live occupancy, last 5 minutes |
| "Is my producer healthy?" | `aweshare producer doctor` |
| "Who's on the hub right now?" | `aweshare hub list producers` / `hub list consumers` — producers show live ONLINE state |
| "What models can I call?" | `aweshare consumer list --hub <url> --token asc_...` |

The last row is the one that gets the most surprise. Most people forget what is shared on a hub they joined weeks ago. The discovery view lists every producer, alias, protocol, per-offering caps, live occupancy (`IN USE n/max` — distinct consumers with a request in flight right now), and today's remaining daily tokens. Offline offerings are hidden by default — an offline producer's aliases can't be called, so they were noise — with `--all` to include them; degraded ones stay listed, because the producer is up and the upstream is briefly failing. And if someone misbehaves, suspension is one command and reversible: `hub revoke --id N` suspends the invite and the identity it minted together (revoking a redeemed producer code closes its tunnel too), `hub restore --id N` brings both back. Nothing is deleted on revoke; offerings and usage history survive.

## Producer, Consumer, Hub: Three Roles, One Tunnel

The architecture is three roles with a single tunnel between them:

**Producer.** You run `aweshare producer start` on your machine. The agent opens a single outbound WebSocket connection to the hub. No public IP, no port forwarding, no firewall rules. It registers your offerings, injects your upstream keys at forwarding time, and handles health degradation automatically: two consecutive AUTH or QUOTA failures mark the backend degraded (the alias stops dispatching), a probe every 30 seconds recovers it silently. Config edits hot-apply — the process re-reads `config.toml` and `secrets.json` within two seconds and re-registers offerings without dropping the tunnel; only `hubUrl`/`token` need a restart. A reconnect with the same token replaces the old tunnel (latest-wins), with jittered backoff so a hub restart doesn't stampede every producer at once.

**Consumer.** Your friends point their standard SDK at the hub. Claude Code, Codex, OpenCode, any OpenAI-compatible tool — they all work with zero changes. The model name is `namespace/alias` (e.g., `peng/qwen2.5.7b`). The API key is their consumer token (`asc_...`). They never see your upstream keys. They never know your backend URLs. And one alias can speak several wire protocols at once — register the same name against `openai`, `anthropic`, and `responses` backends, and whichever SDK they point at it, the hub routes to the matching wire. No conversion, ever.

**Hub.** A single Node process with SQLite, running on a $6 VPS — npm or the Docker image. It authenticates tokens, enforces rate limits and per-offering caps, rewrites model aliases, and relays requests through the WebSocket tunnel. One row of usage per request. Zero content stored. The hub can even host models itself: `[[backends]]`/`[[offerings]]` sections in `config.produce.toml` plus `aweshare hub produce` serve `hub/…` offerings in-process — no producer machine, same caps and metering. The hub is the only piece that needs a public endpoint — the producer and consumers can all sit behind NAT.

The trust boundary is explicit: consumer prompts and model responses pass through the hub in plaintext. The hub stores no content, but the hub operator can technically see it. This is why the hub is open source and self-hostable. Run your own hub. Trust your own hub. The upstream keys, meanwhile, never leave the producer's device — they are injected by the local agent and only the local agent.

## Compliance and Disclaimer

Some things belong in a terms section, not just a one-line note in an article:

- aweshare is relay software: it cannot and does not judge whether you are allowed to share a given upstream key or subscription — that question is between you and the upstream provider. Being able to call an API yourself does not mean you may re-provide it to third parties.
- The two kinds of backends sit in very different positions: **self-hosted open models** (Ollama / vLLM on your own GPU) share your own hardware and open weights — no upstream account involved, clean; **third-party API accounts and personal subscription keys** (coding plans included) — read the upstream's terms first (account rules, subscription and seat limits, forwarding, commercial-use clauses); re-providing to third parties likely violates them. When in doubt, don't share.
- The consequences of sharing (key revocation, account suspension or termination by the upstream) fall on the producer; the hub operator is responsible for operating the hub lawfully and for informing every consumer of the "traffic transits the hub in plaintext" boundary.
- The software is provided "as is" under the [proprietary license](https://github.com/wehuman01/aweshare/blob/main/LICENSE) (free to use and self-host, no redistribution), without warranty of any kind; the authors and contributors are not liable for how aweshare is used or for any damage arising from sharing access through it.

## Claude Code, Codex, OpenCode, and the Long Tail

The same consumer setup works across clients.

**Claude Code** is the most common consumer. Point `ANTHROPIC_BASE_URL` at the hub and set `ANTHROPIC_API_KEY` to the consumer token. The `--model` flag takes the alias: `claude --model peng/sonnet`. If Claude Code has a stale OAuth login, it overrides the env config — switch with `/login` or clean stored credentials.

**Codex** uses the Responses wire protocol. The alias must be backed by a `responses`-protocol offering — `wire_api = "chat"` was removed in 2026-02 and no longer works. The model alias goes in the provider config, and Codex treats it like any other model.

**OpenCode** uses `openai-chat` or `openai-responses` the same way. Set `OPENAI_BASE_URL` to the hub's `/v1` endpoint and start calling models by alias. The `@`-agent calling in OpenCode lets you route sub-tasks to different models — aweshare handles the upstream relay, OpenCode handles the agent selection.

**Cursor, Gemini CLI, Windsurf** — any client that speaks OpenAI Chat Completions, Anthropic Messages, or OpenAI Responses works. `GET /v1/models` returns every alias registered on the hub, with online status. The protocol layer detects mismatches and returns a clear 400 `PROTOCOL_MISMATCH` instead of silently garbling the body.

## Usage Analytics: Who Used What

Relay is half the problem. The other half is knowing whether the relay is being used fairly.

aweshare writes one row per request to the hub's SQLite database — alias, real model, status, duration, best-effort token counts — with **zero content stored**. The `usage` commands answer "who used how much" by default, not "scroll the log":

- **`hub usage`** — server-side aggregate, one row per consumer × model: a person's rows stay together, busiest person and busiest model first. Requests, errors, best-effort token totals, an explicit unknown-token count, mean duration. The window defaults to 7 days and prints with the header (`--since 30m|12h|7d|all`); `--group-by consumer` rolls up to per-person totals, `--group-by alias` to per-model.
- **`hub usage --consumer bob`** — see exactly what Bob is doing, in either the aggregate or `--details` (the per-request log, newest first, each row naming its consumer). Is he running a batch job at 3 AM? Is he hitting the 14B model 200 times an hour? The data is there.
- **`producer usage`** — the same views on the producer's machine, scoped to its own models.
- **`hub list consumers`** — the roster, with status and last seen. Misbehaving? `hub limits bob` throttles him; `hub revoke` suspends him, reversibly.

Token counting is honest: it counts what upstreams report. Ollama streams report no usage, so those rows count as unknown tokens. OpenAI and Anthropic streams report usage, and those numbers are recorded. The lifetime token budget (`maxTotalTokens`) is exact because it sums persisted rows — no sliding window, no best-effort.

## Why It Matters

The first wave of sharing tools assumed a human operator. Share meant "here's my API key, put it in your env." Grant meant "I'll add you to my OpenAI account." Most users tolerated it because they only had one person to share with.

The second wave assumes an agent operator. Share is a task. Admission is a task. The upstream keys are never exposed — not to the consumer, not to the hub, not even to the agent that configures the tool. The artifact that gets delegated is not the key — it is a readable spec the agent can execute.

aweshare has a second design constraint that makes it different from most relay tools: the tunnel is **single-direction outbound**. The producer's agent dials out to the hub over WebSocket. The hub never dials in. This means the producer can sit behind any NAT, any firewall, any corporate proxy that allows outbound HTTPS. No port forwarding. No dynamic DNS. No static IP. The agent connects, and the relay is live.

This is the test I now apply to every sharing tool I evaluate:

1. **Can an agent install it from a single prompt?**
2. **Can an agent manage invites and limits from natural language after install?**
3. **Does the relay require the producer to expose a public endpoint?**

aweshare passes all three. The first prompt is the bootstrap protocol. The second is the skill. The third is a non-issue: the agent opens a single outbound WebSocket. The producer's machine stays behind NAT. The hub handles the public side.

The future of agent tooling is not "tools that work well with agents." It is "tools that the agent itself can install, configure, and operate on your behalf." aweshare is one of the first relay tools to ship with that as the primary install path, not a workaround.

## Try It

Tell your agent:

> "Set up aweshare for me. Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it."

Then start the producer in your own terminal:

```bash
aweshare producer start
```

And point your friends at the hub:

```bash
export ANTHROPIC_BASE_URL=https://hub.example.com
export ANTHROPIC_API_KEY=asc_...
claude --model peng/qwen2.5.7b
```

No always-on machine of your own? The project's developer runs an invite-based community hub at **https://aweshare.wehuman.top** — request a code at peng@wehuman.top and join as a producer or a consumer.

From there, the questions become ordinary:

- "Invite alice as a consumer."
- "What did bob use this week?"
- "Share my Claude subscription too."
- "Cap alice at 60k tokens per minute."
- "Why is my producer offline?"

The agent already knows the commands. You just had not given it the README yet.

## More from mugpeng

aweshare is part of the aweteam ecosystem:

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager for 47+ AI coding agents
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Agent profile switcher for Claude Code, Codex, and OpenCode; launches sessions with the right provider config
- **[awerouter](https://github.com/mugpeng/awerouter)** — A smart LLM router that automatically directs agent requests to fast, low-cost Flash models or more capable Pro providers using structural signals
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — AI coding session manager with profile-aware restoration
- **[aweshare](https://github.com/wehuman01/aweshare)** — An open-source, local-first AI capability relay: share token-denominated model capability — local models on an idle GPU, or your own subscriptions — without ever exposing the keys
- **[awewarm](https://github.com/wehuman01/awewarm)** — Subscription window warmer that keeps AI coding-plan windows predictably open; pairs well with a shared coding-plan endpoint

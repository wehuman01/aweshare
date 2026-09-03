# aweshare update: Sharing You Can See — Usage, Models, Honesty, and End-to-End Ping, One Command Away

![aweshare](../../logo/logo.png)

Once sharing is live, the questions change. Before launch, everyone asks "is this safe to share?"; a week in, the group chat asks different things:

- "Is that model in use right now? How much of my daily quota is left?"
- "Who's using my shared models, and how much?"
- "What's available on the hub at this moment?"
- "That alias claims to be qwen — is qwen what actually answers?"
- "The hub says it's online — does it actually work for me, and how slow is it?"

Until now these were either unanswerable or meant digging through server logs. This update turns each of them into a one-command affair — a dashboard for the whole sharing arrangement, plus an end-to-end ping so you stop trusting "online" at face value and prove it yourself.

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## Consumers: Pick a Model on Facts, Not Luck

Consumers used to face a list of model names and guess: is it up? is it busy? any quota left today? One command now answers all of it:

```bash
aweshare consumer list --hub https://your-hub.example --token asc_...
```

The output looks roughly like this (sample data with fictional names):

```text
PRODUCER  ALIAS                 OBSERVED MODEL     PROTOCOL                STATUS  MAX USERS  IN USE  PER USER  DAILY TOKENS  REMAINING
alice     alice/step-3.7-flash  -                  anthropic, openai-chat  online  2          0/2     1         1000000000    1000000000
bob       bob/glm-5.3           -/glm-5.3          anthropic, openai-chat  online  3          0/3     1         10000000      5592928
bob       bob/minimax-m3        minimax-m2.7 ✗     openai-chat             online  3          0/3     2         1000000       999751
carol     carol/kimi-k2.7-code  -                  anthropic, openai-chat  online  2          0/2     1         1000000       900881
carol     carol/gpt-5.6-luna    gpt-5.6-luna       openai-responses        online  2          1/2     1         30000000      26459988
hub       hub/deepseek-v4-pro   -/deepseek-v4-pro  anthropic, openai-chat  online  2          0/2     1         1000000       981936
hub       hub/seed-evolving     -                  anthropic, openai-chat  online  5          0/5     1         50000000      50000000
```

Every column maps to a question you actually ask:

- **STATUS** — online, degraded, or gone. Offline models are hidden by default (you can't call them anyway); pass `--all` for the full picture.
- **IN USE `n/max`** — how many distinct consumers have a request in flight on that channel right now. `2/3` means one seat free; `3/3` turns new callers away. Pick a less crowded one.
- **REMAINING** — how many of the model's daily tokens are still available. When it's spent, don't bother trying — come back tomorrow.
- **PROTOCOL** — `openai-chat` or `openai-responses`. This column defuses a frequent trap: chat-completions-style tools and Codex-style responses tools dial different endpoint families. One glance tells you whether your tool can use the model, instead of finding out from an error.

By the way: the `bob/minimax-m3` row in the sample has an OBSERVED MODEL marked `✗` — the declared name and what the upstream actually served don't match. The "Honesty" section below covers that.

## Producers: You Have a Shelf on the Hub

Producers used to be blind: configure, connect the tunnel — and whether your models actually registered was something you learned from consumer feedback. Now:

```bash
aweshare producer list
```

The output looks roughly like this (for a producer named bob):

```text
instance: background running (pid 48213, up 2h)

ALIAS           OBSERVED MODEL  PROTOCOL                STATUS  MAX USERS  IN USE  PER USER  DAILY TOKENS  REMAINING
bob/glm-5.3     -/glm-5.3       anthropic, openai-chat  online  3          0/3     1         10000000      5592928
bob/minimax-m3  minimax-m2.7 ✗  openai-chat             online  3          0/3     2         1000000       999751

2 of 2 config offering(s) registered
```

It shows what the hub actually carries under your name, the live status and occupancy of each alias, and any drift against your local `config.toml`. An alias the hub rejected (a name clash, say) is named with its reason instead of hiding in `producer.log`.

To find out who's been using your models:

```bash
aweshare producer usage
```

The output looks roughly like this:

```text
CONSUMER  ALIAS           REQUESTS  ERRORS  RATE    PROMPT  COMPL  UNK  AVG TOOK  LAST USED
dave      bob/glm-5.3     42        0       100.0%  18320   9402   0    1240ms    2026-08-29 14:32Z
erin      bob/glm-5.3     15        0       100.0%  6042    3100   0    1100ms    2026-08-28 21:47Z
dave      bob/minimax-m3  7         1       85.7%   3211    1400   0    980ms     2026-08-29 12:05Z
```

The default view is a summary: one row per consumer, busiest first, with requests, error rate and token totals. `--details` gives the per-request log. No more asking the operator to check the books on your behalf.

There's also a discovery entry point: `producer list --all` browses the whole hub's catalog as a producer — the same view consumers get.

## Hub Operators: The Meter and the Roster in One Place

An operator's daily questions are the same ones: how's overall capacity? who's over-using? which model got hammered hardest today?

```bash
aweshare hub status
```

The output looks roughly like this:

```text
hub status
  producer slots: 3/10 active (0 suspended)
  consumers: 5 active (0 suspended)
  offerings: 7 online, 0 offline, 0 degraded, 0 blocked (7 alias(es))
  last 5m: 23 requests, 100.0% ok, 0 error(s)
  consumer defaults: rps 5, burst 10, max concurrent 2
  timeouts: head 120000ms, idle 300000ms

aliases (worst status first):
PRODUCER  ALIAS                 OBSERVED MODEL     PROTOCOL                STATUS  MAX USERS  IN USE  PER USER  DAILY TOKENS  REMAINING
alice     alice/step-3.7-flash  -                  anthropic, openai-chat  online  2          0/2     1         1000000000    1000000000
bob       bob/glm-5.3           -/glm-5.3          anthropic, openai-chat  online  3          0/3     1         10000000      5592928
bob       bob/minimax-m3        minimax-m2.7 ✗     openai-chat             online  3          0/3     2         1000000       999751
carol     carol/kimi-k2.7-code  -                  anthropic, openai-chat  online  2          0/2     1         1000000       900881
carol     carol/gpt-5.6-luna    gpt-5.6-luna       openai-responses        online  2          1/2     1         30000000      26459988
hub       hub/deepseek-v4-pro   -/deepseek-v4-pro  anthropic, openai-chat  online  2          0/2     1         1000000       981936
hub       hub/seed-evolving     -                  anthropic, openai-chat  online  5          0/5     1         50000000      50000000
```

It defaults to a compact summary: per deduplicated alias — protocols, live occupancy (`IN USE n/max`), today's remaining tokens — plus requests and ok-rate over the last 5 minutes. The producer and consumer rosters appear as counts; `--all` expands the full lists (who's online, when last seen). One glance at a terminal and the hub's whole picture is there.

For the books:

```bash
aweshare hub usage
```

The output looks roughly like this:

```text
PRODUCER  CONSUMER  ALIAS                 REQUESTS  ERRORS  RATE    PROMPT  COMPL  UNK  AVG TOOK  LAST USED
bob       dave      bob/glm-5.3           42        0       100.0%  18320   9402   0    1240ms    2026-08-29 14:32Z
carol     erin      carol/gpt-5.6-luna    31        0       100.0%  24150   11088  0    2010ms    2026-08-29 14:10Z
carol     frank     carol/kimi-k2.7-code  19        1       94.7%   9800    5230   0    870ms     2026-08-29 10:22Z
bob       erin      bob/glm-5.3           15        0       100.0%  6042    3100   0    1100ms    2026-08-28 21:47Z
hub       dave      hub/deepseek-v4-pro   12        0       100.0%  4100    2600   0    1530ms    2026-08-28 18:03Z
```

It defaults to a 7-day window aggregated by producer × consumer, busiest first; `--group-by alias` flips to per-model totals, `--details` shows every request. Who to throttle, which alias to raise a cap on — let the data speak.

## Honesty: Does the Name Match? The Hub Keeps Score Now

This is the capability we cared about most in this update. The catalog says "wang/qwen" — but what model does the upstream actually send back? The hub used to neither know nor ask.

It now records the model each upstream **self-reports** (`observed_model`) on every response, compares it against the producer's declared model per alias, and adds an **OBSERVED MODEL** column to `hub status`, `producer list` and `consumer list`: a match shows the name itself; a mismatch shows what was actually observed; insufficient evidence (an upstream that never self-reports) renders `?`. No lecture — just the fact on the table.

When a name doesn't hold up, the operator has a scalpel:

```bash
aweshare hub offering block ns/model    # block exactly this alias; everything else keeps serving
aweshare hub offering restore ns/model  # bring it back
```

A blocked alias answers new requests with a clear 503 while the producer's other models are untouched. Or let the hub handle it automatically: set one env var and repeated mismatches auto-block the offering (report-only by default).

## End-to-End Ping: Don't Trust, Verify

The hub tells you a model is "online" — but online doesn't mean it works for you. This update gives consumers a way to prove it for real: **end-to-end ping**.

Add `--ping` to `consumer list`:

```bash
aweshare consumer list --hub https://your-hub.example --token asc_... --ping [--alias a,b]
```

Each online offering gets one minimal real request (SDK-compatible `/v1` endpoint, `max_tokens:1`), and the output gains three columns: **RESULT** (OK / FAIL), **TIME** (round-trip in ms), and **DETAIL** (hub or upstream error verbatim on failure). If the declared name doesn't match what the upstream actually served, the `OBSERVED MODEL` column shows `✗` — the hub's record and your own test, side by side.

> Real model calls consume the producer's quota. Use `--alias` to scope the run.

### --ping-table: Tabular Results

Streaming line-by-line is the default for `--ping`. Want to wait for everything to finish and see a clean summary? Add `--ping-table`:

```bash
aweshare consumer list --hub https://your-hub.example --token asc_... --ping --ping-table
```

When the run completes, you get a **FAIL table** first (with HTTP status or `network`) and an **OK table** below (served model, latency), each titled with its count; a progress line on stderr shows the wait (suppressed when piped so stdout stays pure tables).

### Daily Budget

`--ping` isn't unlimited. The hub charges per **complete run**: one full `consumer list --ping` cycle costs one budget unit regardless of how many alias rows it probes. Default is 10 runs per consumer per day; when spent you'll get 429 `PROBE_BUDGET_EXCEEDED` — real requests are never affected. Operators can override per-consumer with `hub limits NAME --probe-budget N`.

## Cheat Sheet

| You want to know | Run |
|---|---|
| What's available right now? How much quota is left? | `aweshare consumer list` |
| Will my tool work with this model? | Read the `PROTOCOL` column (`openai-chat` / `openai-responses`) |
| What of mine is on the hub? Does it match my config? | `aweshare producer list` |
| Who's using my models? | `aweshare producer usage` |
| The hub at a glance: occupancy, quotas, 5-minute health | `aweshare hub status` |
| Busiest consumer? Busiest model? | `aweshare hub usage` |
| Is the declared model what actually answers? | Read the `OBSERVED MODEL` column |
| End-to-end proof — don't trust, verify | `aweshare consumer list --ping [--alias a,b]` |
| Wait for all pings, then see a summary table | `aweshare consumer list --ping --ping-table` |
| Name doesn't hold up — block just this alias | `aweshare hub offering block <alias>` |
| Adjust a single consumer's daily ping budget | `aweshare hub limits NAME --probe-budget N` |

One-line summary: sharing graduates from "trust that everyone plays fair" to "everyone can see the facts themselves" — consumers see quota and protocol, producers see their shelf and their users, operators see the ledger, and the hub sees every model's real name.

## Try It

### Let the agent install it

In Claude Code, Codex, or any coding agent, say:

```text
Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare.
```

### Or do it yourself

```bash
npm install -g aweshare   # existing users: just upgrade

# Consumer: see what's available
aweshare consumer list --hub https://your-hub.example --token asc_...

# Producer: check your shelf and your books
aweshare producer list && aweshare producer usage

# Operator: the hub at a glance
aweshare hub status
```

Sharing no longer runs on good faith. Who used how much, what's left, and whether the model behind the name is really that model — one command, all visible.

## Apply Now

10 consumer spots, first come first served; producers uncapped, welcome anytime.

Email [peng@wehuman.top](mailto:peng@wehuman.top) — who you are, whether you want to share or consume, and what backend you'll bring. Bugs in aweshare itself go to [GitHub issues](https://github.com/wehuman01/aweshare/issues).

## aweshare Series

- [aweshare: Stepping into the Token Sharing Era](https://mp.weixin.qq.com/s/zFRIuxdLj6F5vPj9P7rXAQ)
- [aweshare: I Let My Agent Share My Tokens](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0820/aweshare-ask-your-agent-to-install.md) / [aweshare：我把 agent 变成了共享节点](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0820/aweshare-ask-your-agent-to-install-zh-CN.md)
- [aweshare Dev Note: I Hid My Hub Behind a Cloudflare Tunnel](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0822/aweshare-hub-cloudflare-tunnel-en.md) / [aweshare 开发笔记：我把 Hub 藏到了 Cloudflare Tunnel 后面](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0822/aweshare-hub-cloudflare-tunnel.md)
- [aweshare Community Hub Opens for Beta: 10 Consumer Spots, Unlimited Producers](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0827/aweshare-community-hub-beta-10-spots.md) / [aweshare 社区 Hub 开放 Beta：10 个消费者名额，生产者不设限](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0827/aweshare-community-hub-beta-10-spots-zh-CN.md)
- [aweshare's Three Roles: Who Provides Compute, Who Uses It, Who Keeps the Gate](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0828/aweshare-three-roles.md) / [aweshare 设计哲学1：谁出算力，谁来用，谁来守门](https://github.com/wehuman01/aweshare/blob/main/docs/article_media/0828/aweshare-three-roles-zh-CN.md)
- **This article: Sharing You Can See — Usage, Models, Honesty, and End-to-End Ping** (you are reading the English version)

## aweshare 系列文章

- [aweshare：迈入共享token 时代](https://mp.weixin.qq.com/s/zFRIuxdLj6F5vPj9P7rXAQ)

## Awesome Ecosystem

aweshare is part of a growing family of "awesome" tools — CLI-first, local-first, and operable by AI agents.

### CLI Tools

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager supporting 47+ AI coding agents.
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Agent profile switcher for Claude Code, Codex, and OpenCode.
- **[awerouter](https://github.com/mugpeng/awerouter)** — Smart router that splits requests between Flash and Pro models using structural signals, cutting unnecessary model spend.
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — Bookmark, categorize, and restore AI coding sessions; pairs with aweswitch to save profiles and launch with one command.
- **[aweshare](https://github.com/wehuman01/aweshare)** — Share local Ollama/vLLM backends, domestic coding plans, or authorized OpenAI/Anthropic subscriptions through a self-hosted hub — a sharing economy for tokens.
- **[awewarm](https://github.com/wehuman01/awewarm)** — Subscription window warmer that keeps AI coding-plan windows active, for local setups and through a remote hub server.
- **[awescholar](https://github.com/Webioinfo01/awescholar)** — AI-agent-operable scientific literature discovery and curation.

### Desktop Apps

- **[awedot](https://awedot.wehuman.top/)** — A floating orb at your screen edge keeps track of the current AI session: bookmark it in one click, resume anytime, and pair with aweswitch to pin the agent's config (e.g., relaunch with the GLM model).

### Project Collections

- **[Awesome AI Meets Biology](https://github.com/Webioinfo01/Awesome-AI-Meets-Biology)** — A curated survey of AI applications in biology, bioinformatics, and biomedical research. Powered by awescholar.
- **[Awesome AI Virtual Tumor](https://github.com/Webioinfo01/Awesome-AI-Virtual-Tumor)** — A curated collection of state-of-the-art AI systems for virtual tumor modeling and simulation: static models, dynamic models, agents, benchmarks, and reviews.

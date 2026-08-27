# Community Hub — share and use AI capacity without running a server

<strong>English</strong> · <a href="./README_cn.md">简体中文</a>

`https://aweshare.wehuman.top` is a community [aweshare](https://github.com/wehuman01/aweshare) hub run by the project's developer. aweshare lets people share AI model access with each other: **producers** connect their own backends (a local Ollama, an API account) to the hub, and **consumers** call those models through one standard URL with an ordinary OpenAI- or Anthropic-speaking SDK — as if it were just another API provider.

Admission is invite-based for both roles — see [Contact](#contact) for how to get a code.

## Read this first — the trust rules

**If you produce:** your upstream API keys never leave your machine. They live in `~/.aweshare/secrets.json` (chmod 600) on your box; the hub only ever sees relayed traffic, never a key. But relaying a personal-subscription API key to third parties may violate that upstream's terms of service — self-hosted open models (Ollama/vLLM) have no such issue. When in doubt, don't share that backend. The producer bears the consequences (key revocation, account suspension).

**If you consume:** everything you send passes through the hub in transit — the operator can see prompts and responses passing through, and meters them for usage caps (the hub stores your token only as a hash). Treat shared offerings as "in plain sight of the operator", not as a private channel.

**For everyone:** the operator can suspend any identity by revoking its invite. A server run by someone you don't trust is not a place for sensitive traffic — in that case run your own hub: [`aweshare hub serve`](../../README.md#operations) on any box you control.

## Compliance and disclaimer

aweshare is relay software: it cannot and does not judge whether you are allowed to share a given upstream key or subscription — that question is between you and the upstream provider. Being able to call an API yourself does not mean you may re-provide it to third parties. The two kinds of backends sit in very different compliance positions:

| Backend type | Compliance position |
|---|---|
| Self-hosted open models (Ollama / vLLM on your own GPU) | Clean — you share your own hardware and open weights; no upstream account is involved |
| Third-party API accounts / personal subscription keys (coding plans included) | Read the upstream's terms first (account rules, subscription and seat limits, forwarding, commercial-use clauses); re-providing to third parties likely violates them. **When in doubt, don't share.** |

The rest matches the main [README](https://github.com/wehuman01/aweshare/blob/main/README.md#compliance-and-disclaimer):

- The consequences of sharing (key revocation, account suspension or termination by the upstream) fall on the producer; the hub operator is responsible for operating the hub lawfully and for informing consumers of the plaintext-transit boundary above.
- The software is provided "as is" under the [proprietary license](https://github.com/wehuman01/aweshare/blob/main/LICENSE) (free to use and self-host, no redistribution), without warranty of any kind. The authors and contributors are not liable for how aweshare is used or for any damage arising from sharing access through it.

## What's shared right now

Ask the hub, not this page — it changes:

```bash
npm install -g aweshare            # Node ≥ 22
aweshare consumer list --hub https://aweshare.wehuman.top --token asc_...   # after you have a token
```

## Producer quick start

### 1. Install

Node ≥ 22:

```bash
npm install -g aweshare
```

### 2. Redeem your producer invite

```bash
aweshare producer join --hub https://aweshare.wehuman.top --code asi_...
```

This probes the hub first (the code only burns once the probe passes), writes `~/.aweshare/config.toml` + an empty `secrets.json` (both chmod 600), and prints your producer name — that name is your **namespace**: every offering you publish will be `<yourname>/<model>`.

### 3. Point the config at your backend

Edit `~/.aweshare/config.toml`: define one `[[backends]]` per upstream and one `[[offerings]]` per model you want to share. The protocol decides how the agent dials the upstream (see [the consumer endpoint table](#2-point-your-sdk-at-the-hub)):

```toml
hubUrl  = "https://aweshare.wehuman.top"
token   = "asp_..."                # already filled in by join

[[backends]]
id = "stepfun"
protocol = "openai"                # baseUrl includes /v1 for openai-style
baseUrl = "https://api.stepfun.com/v1"
keyRef = "stepfun-key"

[[offerings]]
alias = "peng1/step-flash"         # namespace must match your producer name
backend = "stepfun"
upstreamModel = "step-3.7-flash"
maxConcurrencyPerUser = 2          # concurrent requests per consumer
```

Put the actual key in `secrets.json` — it never leaves this machine:

```json
{ "stepfun-key": "sk-..." }
```

### 4. Pre-flight, then start

```bash
aweshare producer doctor           # fix the first FAIL, re-run until green
aweshare producer start --background   # detached; logs → ~/.aweshare/producer.log
aweshare producer doctor --status      # pid, uptime, recent log — instant
```

Stop with `aweshare producer stop`. When the producer stops or crashes, its aliases go offline immediately and consumers get 503 — `doctor` tells you which link failed.

## Consumer quick start

### 1. Redeem your consumer invite

Redeeming runs through the aweshare CLI — install it first (Node ≥ 22):

```bash
npm install -g aweshare
aweshare consumer join --hub https://aweshare.wehuman.top --code asi_...
```

No Node on the machine and don't want to install any? One curl redeems too:

```bash
curl -s -X POST https://aweshare.wehuman.top/invites/v1/redeem \
  -H 'content-type: application/json' -d '{"code":"asi_..."}'
```

Either way your `asc_` token is printed **once** — save it; the hub stores only a hash.

### 2. Point your SDK at the hub

The base URL is always `https://aweshare.wehuman.top`; the path depends on the offering's protocol (check `consumer list` / `/v1/catalog`):

| Offering protocol | You call | SDK setup |
| --- | --- | --- |
| `openai` | `POST /v1/chat/completions` | `OPENAI_BASE_URL=https://aweshare.wehuman.top/v1`<br>`OPENAI_API_KEY=asc_...` |
| `anthropic` | `POST /v1/messages` | `ANTHROPIC_BASE_URL=https://aweshare.wehuman.top`<br>`ANTHROPIC_AUTH_TOKEN=asc_...` |
| `responses` | `POST /v1/responses` | OpenAI-style base URL, Responses API |

Calling the wrong endpoint fails loudly with a pointer to the right one — nothing is silently translated.

### 3. One curl to prove the path

```bash
curl https://aweshare.wehuman.top/v1/chat/completions \
  -H "Authorization: Bearer asc_..." -H "content-type: application/json" \
  -d '{"model":"peng1/step-flash","messages":[{"role":"user","content":"ping"}]}'
```

Then point any tool that accepts a custom OpenAI/Anthropic base URL at the hub and pick aliases as model names.

### Recommended: manage provider switching with aweswitch

Day-to-day, the hub will likely be one of several API providers you use. [aweswitch](https://github.com/Webioinfo01/aweswitch) keeps each agent × provider combination as a named profile and launches it without touching global config (`pip3 install aweswitch`, Python ≥ 3.9). An aweshare-backed profile is just another entry:

```json
{
  "profiles": {
    "api": {
      "claude": {
        "cc-aweshare": {
          "env": {
            "ANTHROPIC_BASE_URL": "https://aweshare.wehuman.top",
            "ANTHROPIC_AUTH_TOKEN": "${AWESHARE_ASC_TOKEN}",
            "ANTHROPIC_MODEL": "peng1/step-flash"
          }
        }
      }
    }
  }
}
```

Launch it with `aweswitch cc-aweshare`; Codex / OpenCode profiles and official-account logins are covered in the [aweswitch README](https://github.com/Webioinfo01/aweswitch).

## Caps and fair use

Per-offering guardrails are set by the producer (`maxConcurrencyPerUser` — concurrent requests per consumer, `maxConcurrentUsers` — distinct concurrent consumers, daily token budget and remaining — visible in `consumer list`). The hub also applies global admission limits (consumers are capped, currently 10; producers are uncapped) and rate limiting. Hit a cap and the 429 error names it.

## FAQ

**I lost my consumer token.** It cannot be recovered from the hub (only a hash is stored) — ask the operator to mint a fresh invite.

**A model answers 503.** Its producer is offline. Nothing you can do but wait — check STATUS in `consumer list`.

**My Claude Code only speaks Anthropic and the alias is `openai`.** Correct — the hub does not translate protocols. Use an endpoint matching the alias's protocol column, or a local translation proxy if your tool has no such setting.

**Something I shared was abused.** Revoke what you published: remove the offering from your config and run `aweshare producer reload` — it hot-applies without a restart and the alias leaves the hub's catalog at once. For anything more serious contact the operator, who can suspend identities.

**What if the service goes away?** It is run personally by the developer with no uptime guarantees. Producers lose nothing but their connection (config and keys stay local); consumers need a new hub.

**Stop using it.** Producers: `aweshare producer stop`. Consumers: delete the env vars. Ask the operator to revoke your invite so your slot frees up.

## Contact

- **Invite codes (either role)**: email **peng@wehuman.top** — mention who you are and whether you want to share or use.
- **aweshare bugs**: [GitHub issues](https://github.com/wehuman01/aweshare/issues).

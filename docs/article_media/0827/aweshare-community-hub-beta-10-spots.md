# aweshare Community Hub Opens for Beta: 10 Consumer Spots, Unlimited Producers

![aweshare](../../logo/logo.png)

aweshare works by putting your idle AI capacity behind a standard facade: you run a lightweight producer on your own machine, where the upstream keys stay in `secrets.json` and never leave; friends point ordinary OpenAI / Anthropic SDKs at a hub, whose requests travel back to your machine over an outbound WebSocket — keys are injected only at call time. The whole stack is self-hostable — `aweshare hub serve` is one command away. Its only real threshold is that relay server: it needs a public IP, TLS, and someone watching the process. That's the one link the community hub replaces: **that machine already exists.**

Starting today, the community hub at `https://aweshare.wehuman.top` is taking its first batch of testers: **10 consumer spots, first come first served — and no cap on producers, welcome anytime.**

To be clear about what this does and doesn't replace: the hub takes over the "relay" link only. Keys and models still leave from your machine — for others to use your models, your machine must stay online with the producer running. That's aweshare by design: keys don't travel.

## How to Apply

Just send an email:

- **To**: [peng@wehuman.top](mailto:peng@wehuman.top)
- **Include**: who you are; which role you want (producer / consumer); what you plan to share — Ollama / vLLM on an idle GPU, or an OpenAI Chat / OpenAI Responses / Anthropic-compatible API account (base URL + API key counts) — or which kinds of models you'd like to call.

I'll reply with a one-time invite code (`asi_...`). Consumer spots go fast — later emails automatically join the waitlist for the next round; producer spots are uncapped.

## Once You Have an Invite

Never used aweshare? Ask your agent to install it:

> "Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare."

Doing it yourself, there are two paths. **Producer** (share your capacity):

```bash
npm install -g aweshare                                        # Node ≥ 22
aweshare producer join --hub https://aweshare.wehuman.top --code asi_...
# Edit ~/.aweshare/config.toml to register backends / offerings; put keys in secrets.json — they never leave this machine
aweshare producer doctor                 # fix the first FAIL, rerun until green
aweshare producer start --background     # your terminal, not your agent's
```

**Consumer** (use models others share):

```bash
npm install -g aweshare
aweshare consumer join --hub https://aweshare.wehuman.top --code asi_...
# The asc_ token prints once — save it; no Node? A single curl redeems too.
export OPENAI_BASE_URL=https://aweshare.wehuman.top/v1
export OPENAI_API_KEY=asc_...
```

From there, Claude Code, Codex, OpenCode, anything that speaks OpenAI Chat / Anthropic Messages / Responses points straight at the hub — just use the alias (e.g. `peng/qwen2.5.7b`) as the model name. For juggling multiple providers day to day, [aweswitch](https://github.com/Webioinfo01/aweswitch) manages profiles nicely.

## What Testers Get

- **No server to run.** Public entry, TLS, relaying, usage accounting — the hub handles all of it; you just run the producer locally.
- **Keys stay home.** Upstream keys live only in your machine's `secrets.json` (mode 600), injected by the local agent at forward time — the hub never sees them.
- **Leave anytime.** Your config and key originals live on your machine throughout; nothing is locked in. Done? `aweshare producer stop`, ask me to revoke the invite code, and the spot goes to the waitlist.

## What I'll Try to Protect (and What You Should Weigh)

The hub relays traffic but never touches your keys — that's an architectural guarantee, not a verbal promise. The honest caveats are elsewhere:

- **For producers:** relaying a personal subscription-based API key to third parties may violate that upstream provider's terms of service. Self-hosted open models (Ollama / vLLM) have no such problem; if unsure, don't share that backend. Consequences fall on the publisher.
- **For consumers:** everything you send passes through the hub in plaintext — the operator (me) can see prompts and responses flowing through, and uses them for usage accounting; your token is stored on the hub as a hash only. Treat shared models as "operated in my line of sight," not as a private channel.
- **For everyone:** if you don't trust a server I operate, don't use it — run [`aweshare hub serve`](https://github.com/wehuman01/aweshare) on any machine you control. The code is open source, every line.

## What Backends Are Welcome

| What you want to share | Welcome on the hub? |
|---|---|
| Local open models (Ollama / vLLM on an idle GPU) | **Most welcome** — clean, no terms-of-service worries |
| API accounts (OpenAI Chat / OpenAI Responses / Anthropic-compatible) | Yes — keys stay on your machine |
| Personal subscription keys | Technically yes, but ToS risk is yours — skip it if unsure |

One alias speaks one protocol, and the hub does no translation: callers pick the endpoint matching the alias's protocol, and a wrong endpoint gets a clear error pointing the way — never silently garbled output.

## Compliance and Disclaimer

Some things belong in a terms section, not just a one-line FAQ note:

- aweshare is relay software: it cannot and does not judge whether you are allowed to share a given upstream key or subscription — that question is between you and the upstream provider. Being able to call an API yourself does not mean you may re-provide it to third parties.
- The two kinds of backends therefore sit in very different positions: **self-hosted open models** (Ollama / vLLM on your own GPU) share your own hardware and open weights — no upstream account involved, clean; **third-party API accounts and personal subscription keys** (coding plans included) — read the upstream's terms first (account rules, subscription and seat limits, forwarding, commercial-use clauses); re-providing to third parties likely violates them. When in doubt, don't share.
- The consequences of sharing (key revocation, account suspension or termination by the upstream) fall on the producer; the hub operator (me) is responsible for operating the hub lawfully and for informing every consumer of the "traffic transits the hub in plaintext" boundary.
- The software is provided "as is" under the [proprietary license](https://github.com/wehuman01/aweshare/blob/main/LICENSE) (free to use and self-host, no redistribution), without warranty of any kind; the authors and contributors are not liable for how aweshare is used or for any damage arising from sharing access through it.

## You Might Be Wondering

**Why 10?** The hub's global admission cap currently applies to consumers — 10 of them; producers are uncapped. If you want to consume, come early; if you want to produce, come anytime.

**Is there an availability guarantee?** No — the hub is run by me personally. If it ever shuts down, producers lose only the connection itself (config and keys were always local); consumers find another hub or self-host one. If that day comes, I'll announce it.

**Calls return 503.** The producer behind that alias is offline; all you can do is wait — check STATUS in `consumer list`. And a note for producers: around-the-clock availability needs an always-on machine. A laptop that powers off at night won't serve through the night.

**Lost token.** A consumer's `asc_` token can't be recovered (the hub stores hashes only) — say the word and I'll issue a fresh invite.

**Someone's abusing what I share.** Remove the offering from your config and run `aweshare producer reload` — it delists instantly, no restart, catalog updates right away. For anything worse, contact me; revoking an identity is one command.

**Rate limited.** Per-model guardrails (`maxConcurrencyPerUser`, `maxConcurrentUsers`, daily token budget) are set by each publisher and visible in `consumer list`; the hub adds its own rate limits. When you hit them, the 429 explains why.

## Build It Together

This hub isn't meant to stay just a relay server. I'm inviting users with ideas to co-create something more useful:

- **Share your idle compute.** The GPU in the corner, the subscription you can't max out — hook it up and it becomes an offering on the hub. Producer spots are uncapped; idle capacity is always welcome.
- **Sustainability is being explored.** Down the road: ad revenue, or rewarding producers with credits the way compute-sharing communities (like 科研通) do — the compute you contribute earns points, and points may become redeemable down the line. All still ideas — come help define them.
- **Bring your ideas.** Which models are missing, how to set caps fairly, what a credit should be worth — email [peng@wehuman.top](mailto:peng@wehuman.top) or open a [GitHub issue](https://github.com/wehuman01/aweshare/issues).

## Apply Now

10 consumer spots, first come first served; producers uncapped, welcome anytime.

Email [peng@wehuman.top](mailto:peng@wehuman.top) — who you are, whether you want to share or consume, and what backend you'll bring. Bugs in aweshare itself go to [GitHub issues](https://github.com/wehuman01/aweshare/issues).

## More from mugpeng

aweshare is part of the aweteam ecosystem:

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager supporting 47+ AI coding agents
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — agent config switcher for Claude Code, Codex, and OpenCode
- **[awerouter](https://github.com/mugpeng/awerouter)** — smart router that uses structural signals to route requests to Flash or Pro models, reducing unnecessary model costs
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — save, organize, and restore AI coding sessions; pair it with aweswitch to save configurations and launch with one click
- **[aweshare](https://github.com/wehuman01/aweshare)** — share local Ollama/vLLM or authorized OpenAI/Anthropic backends through a self-hosted Hub, enabling a shared token economy
- **[awewarm](https://github.com/mugpeng/awewarm)** — subscription-window keeper that keeps AI coding-plan windows active, whether configured locally or through a remotely connected server

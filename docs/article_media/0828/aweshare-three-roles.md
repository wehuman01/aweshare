# aweshare's Three Roles: Who Provides Compute, Who Uses It, Who Keeps the Gate

![aweshare](../../logo/logo.png)

A familiar friend group: one has an idle GPU, one can't max out a subscription, and several have neither. The most direct way to share is to hand over an API key — and everyone hesitates. A key handed out is the whole keyring given away: overspend, leak, ban — the consequences all land on the owner.

aweshare splits the problem into three roles: those who provide compute, those who use it, and those who keep the gate. This article covers no installation and no commands — only what each role does, where its boundaries sit, and the design philosophy underneath.

## The Producer: the one with capacity

You have a graphics card sitting idle, or a subscription you can't exhaust — in aweshare, you are a producer. Your job is a single thing: list the models you want to share. A small program runs on your computer, dials out to the relay, and registers your models in its catalog — "wang/qwen-big", say. Friends then call them by that name.

Three boundaries define the experience of this role:

- **Your keys never leave home.** Your API keys and subscription credentials stay on your machine from start to finish. When someone makes a call, the request is relayed back to your computer, and the program there uses your key to knock on the upstream's door. Nobody ever sees the key — not even the relay.
- **Your computer never opens for business.** The connection is one you dial out, like a phone call, not a shop you open. No public IP, no port forwarding, no firewall changes — the laptop at home and the desktop inside a corporate network can both be producers.
- **You set the guardrails.** How many people at once, how much per day, how much in total — you write these down when you list the model. Shut the computer down or delist the model, and sharing stops instantly; come back anytime by listing it again.

In one sentence: a producer shares **capability**, not **keys**. Others can use your models but cannot touch your account.

## The Consumer: the one who needs capacity

You lack a good GPU, or don't want another subscription for a model you only occasionally use — in aweshare, you are a consumer.

The experience of this role is deliberately boring: you receive a token (a string of characters) and an address, paste them into the tools you already use — Claude Code, Codex, or any client that accepts a custom endpoint — and type the catalog name in the model field. Done. No new software, no new protocol to learn. A shared model works exactly like any other API provider's.

What you can't see matters as much as what you can: you see nobody's keys, never the provider's real address, never anyone else's traffic. What you do see is the catalog — who shares what, whether it's online, how much quota remains.

## The Hub Operator: the one who keeps the gate

The relay (the hub) needs someone to run it. That person does simple things:

- **Mint invites.** Entry is by invitation — one code per person, void after one use. No code, no entry.
- **Read the meter.** Who used how much, and when — the ledger is clear, so fairness can be checked against facts.
- **Step on the brake.** Someone abusing it? Throttle or suspend them — both reversible, instantly enforceable, and nothing gets deleted.

And one boundary that must be stated honestly: **everything passing through the relay is, technically, visible to the operator.** That is not a hidden flaw; it is an architectural fact written down in plain words. The response is just as direct — the relay's code is fully open source, and anyone can run their own: if you don't trust someone else's gate, keep your own. The project's author runs a community hub himself (`https://aweshare.wehuman.top`); readers who don't trust it are welcome to start their own.

## The Design Philosophy

Behind the three roles run a few principles that run through all of aweshare.

**Share capability, never keys.** This is the core one. A key handed out is handed out entirely and cannot be recalled; aweshare replaces it with capability that is per-call, metered, and revocable at any moment. A producer's maximum loss is "the quota others used", not "the whole account".

**Connections only dial out.** The producer's computer only makes outbound calls; the relay never calls back. This design means sharing no longer requires "a server exposed to the public internet" — home broadband and office networks can both supply compute, which most sharing schemes cannot manage.

**Admission is permission; guardrails are management.** The permission model is one sentence: if you're in, you can use everything in the catalog. No permission trees, no role-configuration screens. Fairness comes from limits, not approvals — every cap for every model and every person is written at the door, and exceeding one gets you a clear rejection with the reason spelled out.

**An honest boundary beats a pretty promise.** The relay can see the traffic — aweshare doesn't pretend it's an encrypted channel; it states the boundary, opens the code, and hands you the right to self-host. A protocol mismatch returns a clear error instead of a silently garbled answer. Suspension is reversible. Everything that should be said is said in the open.

**Keep the ledger, never the content.** One line per request: who, which model, how many tokens, how long. The content itself is stored nowhere. The ledger is enough to settle fairness; the content is not yours to keep.

## How the Three Roles Meet

The most common scene is a group of friends: one contributes a GPU running open models, one lists an under-used subscription, the rest each take a token and consume. The gate can be kept by any one of them — or by the community hub. Installation and day-to-day management are designed to be delegated to an AI agent: you talk, it works; only starting the long-running programs must be done by your own hand, in your own terminal.

Across the whole arrangement, nobody passes keys around the group chat, nobody but the gatekeeper needs to buy a server, and everyone's exit cost is near zero: the producer stops the program, the consumer deletes two lines of config. That's all.

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## Try It

### Let the agent install it

In Claude Code, Codex, or any coding agent, say:

```text
Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare.
```

### Or do it yourself

```bash
npm install -g aweshare

# To share (producer): aweshare producer init
# To consume: aweshare consumer join --hub <URL> --code asi_...
# To keep the gate (operator): aweshare hub init && aweshare hub invite
```

## Apply Now

10 consumer spots, first come first served; producers uncapped, welcome anytime.

Email [peng@wehuman.top](mailto:peng@wehuman.top) — who you are, whether you want to share or consume, and what backend you'll bring. Bugs in aweshare itself go to [GitHub issues](https://github.com/wehuman01/aweshare/issues).

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

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

Want to try it? Email [peng@wehuman.top](mailto:peng@wehuman.top) — say who you are and which role you want. Problems with aweshare itself go to [GitHub issues](https://github.com/wehuman01/aweshare/issues).

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## More from mugpeng

aweshare is part of the aweteam ecosystem:

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager supporting 47+ AI coding agents
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — agent config switcher for Claude Code, Codex, and OpenCode
- **[awerouter](https://github.com/mugpeng/awerouter)** — smart router that uses structural signals to route requests to Flash or Pro models, reducing unnecessary model costs
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — save, organize, and restore AI coding sessions; pair it with aweswitch to save configurations and launch with one click
- **[aweshare](https://github.com/wehuman01/aweshare)** — share local Ollama/vLLM or authorized OpenAI/Anthropic backends through a self-hosted Hub, enabling a shared token economy
- **[awewarm](https://github.com/mugpeng/awewarm)** — subscription-window keeper that keeps AI coding-plan windows active, whether configured locally or through a remotely connected server

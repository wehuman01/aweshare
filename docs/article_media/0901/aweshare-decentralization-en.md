# aweshare Design Philosophy 2: Decentralization — the Hub Is a Platform, Not the World

![aweshare](../../logo/logo.png)

The previous post covered aweshare's three roles: producers who supply compute, consumers who use it, and the operator who keeps the gate. It left one question open: does the hub at the gate just replace "the central platform" — swap OpenAI for somebody else?

The answer is in the design: the hub is a platform, but not a center. It is light enough to be replaced at any time — and it is meant to be. This post covers no installation and no commands, only three things: why the hub is light, why there is more than one platform, and how these platforms might one day be connected.

## The Hub Is Light: It Holds No Secrets

First, what the hub does hold: a catalog (who shares what), a ledger (who used how much), a roster of identities (who may enter). Now what it does not hold:

- **Upstream keys and subscription credentials never touch the hub.** Requests are dialed back to the producer's machine, which knocks on the upstream's door with its own key; the hub sees only forwarded traffic. Breach the hub and you leak a ledger of "who used what" — not a single credential that can call a model.
- **Request and response content is stored nowhere.** The ledger records who, which model, how many tokens, how long. Not the conversations.
- **Deployment is always one step away.** One small server runs an identical hub; nothing outside the hub is bound to it.

These three facts fix the hub's status: a **replaceable coordination point**, not an indispensable center. Shut down any single hub and the producer's keys are still on the producer's machine, the consumer's tools still work, and everyone can start again by pointing at a different address.

## More Than One Platform: wehuman's Hub Is Just One

`https://aweshare.wehuman.top` is a community platform run by the project's author — it is not "the aweshare network" itself, just one of the platforms built with aweshare.

This is worth spelling out: **aweshare is a framework; a hub is an instance.** Deployment needs one small server, so:

- a group of friends can run one, for people they actually know;
- a team can run one, sharing a few subscriptions and an idle GPU internally;
- a community, a university lab, an open-source project — each can run its own, setting its own bar for entry and its own rules.

Every platform decides for itself whom to invite, what to cap, when to suspend — **trust is local**. You don't need to trust wehuman, or any "sharing-economy platform" at all; you only need to trust whoever handed you the invite code. It's the same line of thinking as self-hosted mail servers or Mastodon instances: the protocol is open, instances are many, and nobody monopolizes.

The producer's experience confirms how light this is: no public IP, no port forwarding — a laptop at home dials out and can join any hub. Moving from one platform to another means changing one line in the config: the address.

## Exit Freedom: Switching Platforms Is Changing an Address

Whether decentralization is real shows not in the manifesto but in the exit cost. In aweshare:

- **A producer** switching hubs: change the hub address and token in the config, `join` again. The catalog follows the person; the key never left their machine in the first place.
- **A consumer** switching hubs: take a new token, change two lines of environment variables. The tools stay Claude Code, Codex, OpenCode — nothing to relearn.
- **An operator** closing a platform: delete the container. The ledger goes with the hub, but nobody's credentials live in it.

No "one global account", no platform-exclusive balance, no lock-in. When a platform is run badly, users vote with their feet — the most practical constraint on an operator, and more effective than any terms of service.

## The Road Ahead: Connecting the Platforms

With one platform, the "sharing economy" spans that platform's friend circle. Once platforms coexist, a natural question follows: can these islands be bridged?

This is a direction we are seriously considering (note: still on paper, nothing shipped). Roughly three shapes come to mind:

- **Federated catalogs.** Consumers on platform A could see the catalog platform B chooses to expose — like a federated timeline: every platform still keeps its own gate, but visibility is no longer bounded by one wall.
- **Hub-to-hub peering.** One hub joins another hub as a *producer*, listing its own catalog as an offering there. Chained together, small platforms can offer capability outward without each one facing the public internet directly.
- **Portable reputation.** Whether the track record you build on one platform — usage history, a history of playing fair — can travel with you, so you don't queue from scratch on every new platform.

Honestly, interconnection is much harder than independence: how to compute cross-platform trust, how to split the books, how to contain abuse — all real problems. Decentralization first guarantees that "anyone can open a gate"; interconnection aims to "build roads between gates". The roads get built, but the rules behind each gate remain the gatekeeper's own.

## The Design Philosophy

**A platform is only a real platform if it can be replaced.** To judge whether a system is decentralized, ask one question: if you shut it down, what happens to its users? In aweshare, the answer is "change the address, keep going".

**Trust stays local.** What you should trust is the person who gave you the code, not a distant company. The smaller the platform, the more concrete the trust.

**Deployable anytime, so instances multiply.** "Run your own" isn't a slogan — one small server, an afternoon of work.

**Exit first, then interconnect.** Gates can open freely because exit costs nearly nothing; when the roads get built, they must not raise the exit cost back up.

## Try It

### Let the agent install it

In Claude Code, Codex, or any coding agent, say:

```text
Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare.
```

### Or open your own gate

```bash
npm install -g aweshare

# Operator: one small server, your own platform
aweshare hub init && aweshare hub serve

# Producer: dial out and join any hub (including your own)
aweshare producer init && aweshare producer start
```

Want a ready-made one? The community platform is at [aweshare.wehuman.top](https://aweshare.wehuman.top). Want to run your own? The docs are on [GitHub](https://github.com/wehuman01/aweshare).

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

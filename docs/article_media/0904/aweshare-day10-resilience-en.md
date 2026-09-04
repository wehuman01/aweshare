# Global Outage Took Down Codex, Grok, and More. On aweshare, Nothing Happened.

![aweshare](../../logo/logo.png)

Yesterday (Sep 3), Grok, Codex, and several other platforms went down in a wave of outages, and timelines filled with downtime screenshots. A friend messaged: did your sharing hub go down too?

The answer is boring: no. Nothing to report. Requests kept flowing, the ledger kept recording. The only trace is a few rows of numbers — the error rate on two model families ran a bit hotter than usual.

That is exactly why this post is worth writing. The previous post laid out the decentralization philosophy; this one is its field report. The aweshare community hub has been running for 10 days and happened to catch a large-scale upstream outage head-on. Open the ledger and see how "nothing happened" happened.

## The 10-Day Ledger First

One command:

```bash
aweshare hub usage
```

Spanning Aug 25 to Sep 4, the totals:

- **10 vendors, 20 distinct models**, listed as **32 channels (aliases)** — the same model can be listed independently by different producers; the vendors span glm, gpt, deepseek, step, minimax, kimi, mimo, agnes, sensenova, and seed;
- **3,664 requests, 93.4% overall success**, across 93 producer × consumer × model streams;
- **~353 million tokens** (350.7M prompt, 1.9M completion).

Which model worked hardest? The ledger ranks them cleanly (top 8 by requests):

| Model | Requests | Success | Tokens | Producers |
|---|---|---|---|---|
| glm-5.3 | 1,036 | 96.3% | 122M | 2 |
| glm-5.3-flash | 820 | 97.1% | 121M | 1 |
| gpt-5.6-luna | 570 | 87.5% | 43.8M | 2 |
| gpt-5.6-terra | 297 | 86.2% | 29.6M | 2 |
| step-3.7-flash | 171 | 87.1% | 2.6M | 4 |
| minimax-m3 | 157 | 99.4% | 8.9M | 2 |
| deepseek-v4-pro | 123 | 98.4% | 7.8M | 1 |
| mimo-v2.5-pro | 90 | 98.9% | 4.2M | 1 |

The champion is glm-5.3: 1,036 requests and 122M tokens; the runner-up glm-5.3-flash: 820 requests and 121M. Together the pair carried 69% of all traffic — heavy users voted with their feet and picked the workhorses. Third and fourth are gpt-5.6-luna and gpt-5.6-terra — the two streams dragged down by yesterday's affected upstream. Behind them, step, minimax, deepseek, and mimo each have their steady customers: one model having a bad day only dents a small corner.

## What Yesterday Looked Like: an Outage, as Bookkeeping

Honesty first: it was not zero damage. gpt-5.6-luna and gpt-5.6-terra — the two families routed through the affected upstream — finished the 10 days with error rates of 12.5% and 13.8%, clearly above the glm family's ~3%, and the ledger holds several 30-second timeouts. That is what an upstream outage looks like inside a sharing network: **a few rows and one column of error rate, not an afternoon of dead tooling.**

The key next sentence: **nobody's work stopped.** Because:

- gpt-5.6-luna and gpt-5.6-terra each have **2 independent producers** (peng1 and jiyu2 — different machines, separate upstream channels). From yesterday's daytime through this morning, both producers' gpt-5.6 streams kept logging requests, last used at 10:32 and 10:38 today. One channel shook; the other carried.
- The other 18 models untouched by the affected upstream — glm, deepseek, kimi, minimax, step, mimo, sensenova, seed, agnes — served as usual. Over the past two days, 44 of the 93 streams were active.
- The consumer's entire response was: switch to another alias, or simply another model, and keep going.

On a monolithic platform, an upstream outage means your work stops. Here it gets translated into one column of the ledger. **The failure wasn't eliminated — it was diluted.**

## Why There Was No Story: Redundancy Grew Itself

The interesting part: nobody planned "redundancy". Of the 20 models, 9 naturally have more than one source — step-3.7-flash has 4 producers, step-router-v1 has 3, and glm-5.3, kimi-k2.7-code, minimax-m3, and the two gpt-5.6s each have 2.

The reason is plain: the logic of a sharing economy is "everyone lists what they already have". When a model proves useful and popular, a second person naturally puts it on their own shelf. **Popular things get duplicated, and duplication is backup.** That is cheaper than any "high-availability architecture" — because it isn't architecture at all; it's a byproduct of distribution.

Layer on the two properties from the decentralization design (detailed in the previous post):

- **There is no center to take down.** Upstream keys live on the producers' own machines; the hub is only a coordination point. Knock out any single piece and the rest keeps turning.
- **Exit costs almost nothing.** Switching channels is a two-line environment-variable change for a consumer — voting with your feet can happen at any moment.

One counterexample, in the spirit of honesty: one of the 5 producers (hsh2) finished the 10 days at only 70% success. It dragged no one down — the damage stayed on its own shelf, and consumer traffic simply routed around it. **A weak node degrades itself, not the network.**

## One Sentence

**Availability is not bought from one vendor; it is grown from many sources.** The reliability of a single point has a ceiling — even the biggest vendors go down, as yesterday just proved. The diversity of sources has no ceiling — every added producer, every newly listed model, raises the whole network's availability one notch.

To judge whether a network can take a punch, don't read its SLA promises; read its ledger: **on the days things broke, did the requests keep flowing?**

## Try It

### Let the agent install it

In Claude Code, Codex, or any coding agent, say:

```text
Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare.
```

### Or run your own hub

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
- [aweshare 社区：消费者 10 个名额，螃蟹先到的吃](https://mp.weixin.qq.com/s/iOU72DB-SESe4IktIIdvbQ)

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

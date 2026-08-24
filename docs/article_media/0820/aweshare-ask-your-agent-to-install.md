# aweshare: I Let My Agent Share My GPU

> Historical article, written against the v0.3.x CLI. Since then: per-alias grants were removed in v0.4.0 (any admitted consumer may call every offering), and `aweshare agent …` became `aweshare producer …` — the workflow below is kept as published.

![aweshare](../../logo/logo.png)

Here is the uncomfortable math of being the one person in the group with a GPU: you have a 4090 sitting in the corner running Ollama, you have API keys for models your friends can't reach, and every conversation ends with "can you run this prompt for me?" You become a human relay. Copy, paste, wait, paste back. It is the least interesting kind of work, and it scales to exactly one person.

aweshare's answer is a local-first relay. You run a lightweight agent on your machine. Your friends point their standard OpenAI or Anthropic SDK at a hub. The hub forwards requests through a single WebSocket tunnel back to your agent, which injects your upstream keys and sends the request to the actual backend. The keys never leave your machine. The friends never touch your terminal. You stop being a copy-paste relay and become a capability provider.

aweshare was born out of this exact frustration. And it makes a second bet on top of the first: a relay is only useful if someone configures and maintains it — backends to register, offerings to define, consumers to grant, limits to set. That someone does not have to be you. aweshare is built as a tool for the AI age: operable end-to-end by an AI agent. It ships with a README the agent reads, a skill the agent uses, and a CLI the agent runs. The learning cost of the tool moves from you to the agent. You say what you want; the agent figures out how.

Then I let my agent set the whole thing up.

I told it: "Read https://github.com/wehuman01/aweshare/blob/main/README.md and follow the setup. I have a 4090 with Ollama running qwen2.5:7b and qwen2.5:14b. I want to share them with two friends." Then I went to get a coffee.

When I came back, the hub was running on my VPS, the agent was connected, two producer tokens were issued, two consumer tokens were generated, and the grants were in place. The agent had read the config template, registered both Ollama models as offerings, set `maxConcurrency` to 1 for each (local models, single GPU), and wired the grants to the right consumers. It even ran `aweshare agent doctor` to verify the path from config to backend to hub was healthy.

Then it said: "Run `aweshare agent start` in your terminal. I will not start the long-running process for you."

That is the new shape of installing an agent tool. The install is a task. The agent does tasks. So I gave the task to the agent.

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## The Install: A README the Agent Reads

Most agent tools ship a `README.md` for humans and a separate `README.ai.md` for agents. The split is honest: humans want a marketing story, agents want a procedure. aweshare leans into this.

The README is a contract written for the agent, not the user:

1. `npm install -g aweshare` and verify with `aweshare --version`
2. `aweshare hub init` to create the hub data directory and print the admin token
3. `aweshare hub token issue --role producer --name <name>` and `--role consumer --name <name>` to issue tokens
4. `aweshare agent init --hub <url> --token <asp_...>` to create `~/.aweshare/config.toml` and `secrets.json`
5. Edit `config.toml` to register backends and offerings, put upstream keys in `secrets.json`
6. `aweshare agent doctor` to verify the full path: config → backend → hub
7. `aweshare agent grant --alias <namespace/alias> --consumer <name>` to grant access
8. Tell the user to run `aweshare agent start`

### The 30-Second Version

In Claude Code, Codex, OpenCode, or any of the 47+ agents supported by aweskill, the prompt is the same:

> "Set up aweshare for me. I have a GPU with Ollama running qwen2.5:7b and qwen2.5:14b. My hub is at hub.example.com."

The agent does the rest. It installs the npm package, initializes the hub, issues tokens, writes the config, registers the offerings, sets up grants, and runs the doctor. If something fails — Node too old, Ollama not running, hub unreachable — it stops and asks, instead of silently breaking things.

### What the Agent Will Not Do

This is the most important boundary. aweshare has two long-running processes: the hub (`aweshare hub serve`) and the agent (`aweshare agent start`). The agent will never run either of them. It will never start, stop, or restart the server or the tunnel.

The README says so explicitly. The skill says so explicitly. The safety rule is unambiguous: long-running daemons are the user's terminal. The agent's job is configuration — `init`, `token issue`, `agent init`, `agent doctor`, `agent grant`, `hub usage`, editing `config.toml` and `secrets.json`. The agent lives in the text file world. The daemons live in the socket world. They do not cross.

This means the day-to-day relay management — list grants, check usage, add offerings, set consumer limits, issue tokens — is all agent-runnable. Only the actual hub and agent processes are yours to start in your own terminal.

## A Day in Practice

It is Tuesday. The hub is running on a $6 VPS. Your agent is connected from your desktop. Two friends have consumer tokens.

**7:42 AM.** You start the day. `aweshare agent start` is already running from yesterday. You want to see how the relay went overnight:

```
aweshare hub usage
```

The agent reads the SQLite usage log and reports: 847 requests to `peng/qwen2.5.7b`, 312 to `peng/qwen2.5.14b`. Average latency is 1.2s for the 7B model, 2.8s for the 14B. No errors, no rate limit hits. Your GPU sat at 78% utilization. You make a note to check if the 14B model is oversubscribed.

**9:15 AM.** A friend messages you: "Can I try your new model?" You tell the agent:

> "Grant alice access to peng/qwen2.5.14b."

The agent runs `aweshare agent grant --alias peng/qwen2.5.14b --consumer alice` and reports back. Alice gets a notification. She runs a test curl and gets a response. You did not touch a config file. You did not restart anything. The grant went live the moment the command completed.

**11:30 AM.** You want to add a new backend. You tell the agent:

> "Add GLM as a backend. I have GLM_API_KEY in my secrets."

The agent reads `~/.aweshare/config.toml`, adds the GLM backend entry with `protocol = "responses"`, registers `peng/glm-4-flash` as an offering, and updates `secrets.json` with the key reference. Then it asks: "Do you want to grant any consumers access to `peng/glm-4-flash`?" You say yes for alice, and it runs the grant. No copy-paste. No "let me find the docs."

**1:00 PM.** Bob is running a batch job that's saturating the GPU. You want to set a limit:

```
aweshare hub consumer limits --name bob --rps 2 --maxConcurrent 1
```

The agent applies the override. Bob's requests now get throttled to 2 per second with a single concurrent slot. You did not need to remember the CLI flags. The agent knew them.

**3:00 PM.** You want to check if everything is healthy:

```
aweshare agent doctor
```

The agent probes the config, the backends, and the hub connection. All three links are green. The health gate shows no degraded backends. The 14B model has been running for 6 hours without a single AUTH or QUOTA failure.

**6:00 PM.** You are done. Three backends, five offerings, four consumers, two with per-consumer limits. The agent handled every config change. The hub handled every request. The agent handled every relay. You never opened `~/.aweshare/config.toml` by hand.

## The Stack: What the Skill Can Reach

The `aweshare` skill is intentionally small. It does not try to be a general agent framework. It is a thin procedural layer over the `aweshare` CLI, with an intent router that maps natural language to commands.

| You say | The skill runs |
|---|---|
| "Show me usage for peng/qwen2.5.7b." | `aweshare hub usage --alias peng/qwen2.5.7b` |
| "Grant alice access to peng/qwen2.5.14b." | `aweshare agent grant --alias peng/qwen2.5.14b --consumer alice` |
| "Add a GLM backend for responses." | edits `config.toml`, `secrets.json`, registers offering |
| "Set bob's rate limit to 2 RPS." | `aweshare hub consumer limits --name bob --rps 2` |
| "Is everything healthy?" | `aweshare agent doctor` |
| "Issue a consumer token for charlie." | `aweshare hub token issue --role consumer --name charlie` |
| "List all my grants." | `aweshare agent list` |

The last row is the one that gets the most surprise. Most producers forget who they granted access to — especially after a week of casual "sure, try it" conversations. The agent will list every grant, show who has access to what, and flag any expired grants. You can revoke with a single command and the consumer loses access immediately.

## Producer, Consumer, Hub: Three Roles, One Tunnel

The architecture is three roles with a single tunnel between them:

**Producer.** You run `aweshare agent start` on your machine. The agent opens a single outbound WebSocket connection to the hub. No public IP, no port forwarding, no firewall rules. The agent registers your offerings, injects your upstream keys at forwarding time, and handles health degradation automatically. Two consecutive AUTH or QUOTA failures from a backend, and that backend is marked degraded. The agent probes every 30 seconds and recovers silently.

**Consumer.** Your friends point their standard SDK at the hub. Claude Code, Codex, OpenCode, any OpenAI-compatible tool — they all work with zero changes. The model name is `namespace/alias` (e.g., `peng/qwen2.5.7b`). The API key is their consumer token (`asc_...`). They never see your upstream keys. They never know your backend URLs. They just call the model.

**Hub.** A single Node process with SQLite, running on a $6 VPS. It authenticates tokens, validates grants, enforces rate limits, rewrites model aliases, and relays requests through the WebSocket tunnel. One row of usage per request. Zero content stored. The hub is the only piece that needs a public endpoint — the producer and consumers can all sit behind NAT.

The trust boundary is explicit: consumer prompts and model responses pass through the hub in plaintext. The hub stores no content, but the hub operator can technically see it. This is why the hub is open source and self-hostable. Run your own hub. Trust your own hub. The upstream keys, meanwhile, never leave the producer's device — they are injected by the local agent and only the local agent.

## Claude Code, Codex, OpenCode, and the Long Tail

The same consumer setup works across clients.

**Claude Code** is the most common consumer. Point `ANTHROPIC_BASE_URL` at the hub and set `ANTHROPIC_API_KEY` to the consumer token. The `--model` flag takes the alias: `claude --model peng/sonnet`. If Claude Code has a stale OAuth login, it overrides the env config — switch with `/login` or clean stored credentials.

**Codex** uses the Responses wire protocol by default. A `responses`-protocol offering works out of the box. A `chat`-protocol offering works with `wire_api = "chat"` in the Codex config. The model alias goes in the provider config, and Codex treats it like any other model.

**OpenCode** uses `openai-chat` or `openai-responses` the same way. Set `OPENAI_BASE_URL` to the hub's `/v1` endpoint and start calling models by alias. The `@`-agent calling in OpenCode lets you route sub-tasks to different models — aweshare handles the upstream relay, OpenCode handles the agent selection.

**Cursor, Gemini CLI, Windsurf** — any client that speaks OpenAI Chat Completions, Anthropic Messages, or OpenAI Responses works. `GET /v1/models` returns every alias granted to the consumer's key, with online status. The protocol layer detects mismatches and returns a clear 400 `PROTOCOL_MISMATCH` instead of silently garbling the body.

## Usage Analytics: Who Used What

Relay is half the problem. The other half is knowing whether the relay is being used fairly.

aweshare writes one row per request to the hub's SQLite database. The `usage` command lets you inspect it:

- **`hub usage`** — per-alias breakdowns: request count, success rate, average latency, token counts (best-effort). Filter by consumer, alias, or time range.
- **`hub usage --consumer bob`** — see exactly what Bob is doing. Is he running a batch job at 3 AM? Is he hitting the 14B model 200 times an hour? The data is there.
- **`agent list`** — from the producer side, see every grant you've issued. Who has access to what. Revoke with `agent revoke`.

Token counting is honest: it counts what upstreams report. Ollama streams report no usage, so those rows show NULL token counts. OpenAI and Anthropic streams report usage, and those numbers are recorded. The lifetime token budget (`maxTotalTokens`) is exact because it sums persisted rows — no sliding window, no best-effort.

## Why It Matters

The first wave of sharing tools assumed a human operator. Share meant "here's my API key, put it in your env." Grant meant "I'll add you to my OpenAI account." Most users tolerated it because they only had one person to share with.

The second wave assumes an agent operator. Share is a task. Grant is a task. The upstream keys are never exposed — not to the consumer, not to the hub, not even to the agent that configures the tool. The artifact that gets delegated is not the key — it is a readable spec the agent can execute.

aweshare has a second design constraint that makes it different from most relay tools: the tunnel is **single-direction outbound**. The producer's agent dials out to the hub over WebSocket. The hub never dials in. This means the producer can sit behind any NAT, any firewall, any corporate proxy that allows outbound HTTPS. No port forwarding. No dynamic DNS. No static IP. The agent connects, and the relay is live.

This is the test I now apply to every sharing tool I evaluate:

1. **Can an agent install it from a single prompt?**
2. **Can an agent manage grants and limits from natural language after install?**
3. **Does the relay require the producer to expose a public endpoint?**

aweshare passes all three. The first prompt is the README. The second is the skill. The third is a non-issue: the agent opens a single outbound WebSocket. The producer's machine stays behind NAT. The hub handles the public side.

The future of agent tooling is not "tools that work well with agents." It is "tools that the agent itself can install, configure, and operate on your behalf." aweshare is one of the first relay tools to ship with that as the primary install path, not a workaround.

## Try It

Tell your agent:

> "Set up aweshare for me. Read https://github.com/wehuman01/aweshare/blob/main/README.md and follow the setup."

Then start the agent in your own terminal:

```bash
aweshare agent start
```

And point your friends at the hub:

```bash
export ANTHROPIC_BASE_URL=https://hub.example.com
export ANTHROPIC_API_KEY=asc_...
claude --model peng/qwen2.5.7b
```

From there, the questions become ordinary:

- "Grant alice access to peng/qwen2.5.14b."
- "What did bob use this week?"
- "Add a GLM backend for responses."
- "Set bob's rate limit to 2 RPS."

The agent already knows the commands. You just had not given it the README yet.

## More from mugpeng

aweshare is part of the aweteam ecosystem:

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager for 47+ AI coding agents
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Agent profile switcher for Claude Code, Codex, and OpenCode; launches sessions with the right provider config
- **[awerouter](https://github.com/mugpeng/awerouter)** — A smart LLM router that automatically directs agent requests to fast, low-cost Flash models or more capable Pro providers using structural signals
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — AI coding session manager with profile-aware restoration
- **[aweshare](https://github.com/wehuman01/aweshare)** — An open-source, local-first AI capability relay: share your GPU and API keys without exposing the keys
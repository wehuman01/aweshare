# Contributing to aweshare

aweshare is intentionally narrow: an open-source, local-first relay where producers hold their own upstream keys and consumers use standard SDKs. The project should stay that. Prefer changes that make the relay clearer, safer, or easier to operate.

## Scope fence

The v1 design (`docs/specs/2026-08-15-aweshare-design.md`) deliberately excludes the following. Pull requests adding them will be declined — if you believe the fence is wrong, open an issue and argue it there first:

- payments, credits, withdrawals, rate multipliers
- cross-protocol conversion (anthropic↔openai↔responses) — each registration speaks exactly one wire protocol (an alias may register one offering per protocol); relaying within a protocol family (chat completions, messages, responses) is fine
- smart routing, load balancing, failover across producers (namespaced aliases make routing a deterministic lookup — there is nothing to be smart about)
- web console, accounts, signup/login
- tool-config rewriting assistants (consumers configure via env vars; see README)
- telemetry of any kind, including phone-home update checks — local-first is a trust promise, not a slogan

In scope: tunnel reliability (backpressure, cancellation, reconnect), compatibility with real OpenAI/Anthropic SDKs and tools (Claude Code, Codex with the Responses or chat wire), metering accuracy, doctor diagnostics, packaging, and docs.

## Engineering Taste

Every change is reviewed against these seven principles:

- **Simple**: make the smallest change that solves the real problem.
- **Clear**: optimize for the next reader, not for cleverness.
- **Decoupled**: keep boundaries clean, but do not add abstractions without a real need.
- **Honest**: make complexity, state, side effects, assumptions, and failure modes visible; do not hide complexity or create extra complexity.
- **Focused**: preserve boundaries between modules, and keep top-level convenience commands minimal.
- **Durable**: choose behavior that is easy to maintain, test, and extend.
- **First principles**: identify the real problem, hard constraints, and known facts before reaching for patterns, abstractions, or prior solutions.

In practice: plain exported functions over classes (custom `Error` subclasses are the exception), dependency injection over global state, error messages that tell the user what to do next, and one test file per source module.

## Development setup

```bash
pnpm install
pnpm test        # vitest, whole suite
pnpm build       # tsc -b, whole monorepo
pnpm check       # biome (format + lint)
```

Node ≥ 22, pnpm ≥ 11. The layout:

```
packages/protocol       shared wire protocol: binary frame codec, control messages,
                        alias rules, error codes (used by hub, agent and consumer)
packages/producer-core  shared producer runtime: catalog validation, upstream
                        adapters, health gate, request execution (used by the
                        agent and the hub's own models — README "Hub-hosted models")
apps/hub                node:http + ws + better-sqlite3; consumer endpoints, tunnel
                        server, admin API, aweshare hub CLI
apps/agent              aweshare producer CLI: config/secrets, tunnel client with
                        reconnect, doctor
apps/consumer           aweshare consumer CLI: invite redeem (join) that prints
                        the asc_ token once with ready-to-paste SDK env vars
```

## Testing expectations

- Contract tests (`apps/hub/test/tunnel.test.ts`) drive the real hub with a fake agent speaking the actual wire protocol — extend these when you touch the tunnel or dispatch semantics.
- E2E tests (`apps/hub/test/e2e.test.ts`) use the **real** `openai` and `@anthropic-ai/sdk` packages against mock upstreams. "Consumers need zero changes" is the product promise; if your change breaks these tests, it breaks the product.
- Behavior changes come with tests. Pure refactors keep the suite green without edits.

## Commits and branches

`main` is the only long-lived branch. Conventional-commit style subjects (Chinese or English both fine). The changelog lives at `docs/CHANGELOG.md` — add an entry under `Unreleased` for user-visible changes.

## Security notes for contributors

- Never add logging, caching, or persistence of request/response content — the "hub sees plaintext but stores nothing" boundary is documented in the README and must hold.
- Upstream API keys are handled only by the process that dials the upstream: the producer agent (`~/.aweshare/secrets.json`) for shared models, and the hub itself (`<dataDir>/secrets.json`) for hub-hosted models (`config.produce.toml`, mounted automatically by `aweshare hub serve` — the operator shares their own keys from the same process). Keys are injected at dispatch time and never cross the tunnel in either direction. Any change that moves key material across that boundary needs a design discussion first.

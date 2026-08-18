# Changelog

All notable changes to aweshare are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [semver](https://semver.org/).

## [Unreleased]

## [0.2.2] - 2026-08-18

### Changed

- Docker image renamed to `ghcr.io/wehuman01/aweshare` and repository moved to `wehuman01/aweshare-source`; `release.yml`, `docker-compose.yml`, `package.json` repository URLs, and README install snippets updated. English README releasing section updated to reflect npm Trusted Publishing (OIDC).

## [0.2.1] - 2026-08-18

### Changed

- Single-package distribution: the `aweshare` npm tarball now bundles the wire-protocol module (`packages/protocol/dist`) instead of depending on a separately published `aweshare-protocol` package. `release.yml` publishes one package and no longer requires protocol/CLI version lockstep. `aweshare-protocol` on npm is deprecated in favor of the bundled copy.

## [0.2.0] - 2026-08-17

### Added

- Published for general use: [`aweshare`](https://www.npmjs.com/package/aweshare) on npm (`npm install -g aweshare`) and Docker image `ghcr.io/wehuman01/aweshare` (amd64 + arm64). Consumers and producers no longer need to clone the repo; hub operators can `docker run` the published image directly.
- Grant expiry: `aweshare agent grant --expires-in 7d|12h|30m|90s` (and `aweshare hub grant add --expires-in …`, or `expiresAt` ISO timestamp on `PUT /admin/v1/grants`). Expired grants return `403 GRANT_EXPIRED`; re-granting refreshes the expiry. `grant list` shows `expires_at`.
- Per-consumer limit overrides (sparse, admin-managed): `aweshare hub consumer limits --name NAME [--rps N] [--burst N] [--concurrency N] [--tpm N] [--max-total-tokens N] | --clear`, backed by `GET`/`PUT`/`DELETE /admin/v1/consumers/{name}/limits`. Only set keys override; unset keys keep the hub-wide env defaults. Later `PUT`s merge into the stored overrides.
- TPM: per-consumer tokens-per-minute sliding window (in-memory, like the RPS bucket), enforced as `429 RATE_LIMITED` and recorded from each request's extracted usage.
- Lifetime token budget: `maxTotalTokens` sums `usage_events` per consumer and rejects with `429 QUOTA_EXCEEDED` once reached.
- DB schema v2 (`grants.expires_at`, `consumers.config`) with automatic v1 → v2 migration; fresh installs create v2 directly.

### Changed

- `release.yml` publishes to npm (`aweshare-protocol` first, then the umbrella CLI — requires the `NPM_TOKEN` repo secret) and pushes the multi-arch image to GHCR, in addition to the GitHub Release with changelog notes.

## [0.1.0] - 2026-08-16

### Added

- Initial implementation of the design in `docs/specs/2026-08-15-aweshare-design.md`.
- `packages/protocol` — shared wire protocol: `[16-byte requestId + payload ≤64KiB]` binary frames (direction determines request/response chunks), JSON control messages (`register`/`heartbeat`/`request.*`/`response.*`), namespaced-alias rules, stable error codes.
- `apps/hub` — hub server on bare `node:http` + `ws` + SQLite: producer tunnel endpoint `/ws/v1/producer` (upgrade auth, latest-wins, heartbeat sweep), consumer endpoints `/v1/chat/completions`, `/v1/messages`, `/v1/models` (Bearer / `x-api-key`), grant-based authorization, deterministic alias routing with model rewrite to `upstreamModel`, transparent SSE byte relay with tee-based best-effort token extraction, per-consumer rate limiting and per-offering concurrency caps, 120s head ticket / 300s stream-idle timeouts, cancellation propagation, admin REST API and `aweshare-hub` CLI (`init`/`serve`/`token`/`grant`/`usage`).
- `apps/agent` — producer CLI: `~/.aweshare/config.toml` + `secrets.json` (0600, atomic writes) split so keys never leave the machine, openai/anthropic upstream adapters (baseUrl per SDK convention, credential injection as the only key touchpoint), outbound WSS with 1.5s→15s reconnect backoff, health gate (2 consecutive AUTH/QUOTA failures degrade a backend, 30s probes recover), `doctor` pre-flight ordered to find the first failing link, `grant`/`revoke`/`list` against the hub admin API.
- Usage metering: one `usage_events` row per request (alias, real model, status, latency, byte counts, best-effort prompt/completion tokens); zero request/response content stored.
- Tests: 64 across 11 files — protocol unit, hub contract (fake agent over the real wire), agent unit, and e2e using the real `openai` and `@anthropic-ai/sdk` packages against mock upstreams (streaming, abort propagation, upstream 5xx passthrough, grant matrix).
- Deployment: two-stage Dockerfile (hub only) + docker-compose with `/data` volume.
- Docs: bilingual README (EN + 中文), CONTRIBUTING with the v1 scope fence, this changelog.
- Third wire protocol: OpenAI **Responses** (`responses`) end to end — hub endpoint `POST /v1/responses`, agent adapter (openai-style baseUrl with the version path, Bearer auth), usage extraction (non-stream `usage.input_tokens/output_tokens`, stream `response.completed`), doctor probes. Codex now works with its default Responses wire against `responses`-protocol offerings; `wire_api="chat"` against `openai`-protocol offerings keeps working. No cross-protocol conversion: one alias still speaks exactly one wire.
- Umbrella CLI `aweshare` as the single installed command: `aweshare hub …` and `aweshare agent …` route to the hub/agent CLIs (the long `aweshare-hub` / `aweshare-agent` bin names were retired before ever shipping; expose with `npm link` after a build).
- CI (`.github/workflows/ci.yml`: biome + build + tests across ubuntu/macos/windows) and tag-driven release workflow (`release.yml`: tests, release notes extracted from this changelog).
- README (EN + 中文): the trust-boundary section now carries an explicit "Compliance and disclaimer" subsection — relay software cannot judge sharing rights, producers bear the consequences, MIT "as is" no-warranty statement.

### Fixed

- Agent no longer leaks completed jobs: each tunneled request is removed from the connection's job map when it settles (previously every request body stayed in memory until reconnect).
- Agent relays bodyless GET/HEAD requests without triggering a fetch `TypeError` on an empty body.
- Hub router returns 404 instead of 500 for paths with undecodable percent-encoding (e.g. `%zz`).
- Hub `GET /admin/v1/usage` validates `limit` (integer 1..1000): NaN returned 500, negatives bypassed the row cap in SQLite.
- Hub register now enforces the alias charset (`isValidAlias`), not just the namespace prefix — uppercase/invalid aliases are rejected instead of stored ungranted.
- `aweshare-agent doctor` output no longer contains a stray full-width colon in English messages.
- Umbrella CLI guards command lookup against prototype keys (`aweshare __proto__` errors cleanly).
- CONTRIBUTING gained the Engineering Taste section; test counts updated.
- Docker build was broken in three independent ways: `pnpm-lock.yaml` was never copied (`ERR_PNPM_NO_LOCKFILE`), `pnpm --filter … prune` is not a valid pnpm invocation, and the runtime image omitted `packages/protocol` (the hub resolves it through a workspace symlink) — `docker compose up` could never complete. Dockerfile rewritten against a verified install → filtered build → runtime layout sequence, with a new `.dockerignore`.
- Oversized request bodies now produce a clean `413 BODY_TOO_LARGE` JSON response; previously the socket was destroyed first and consumers saw a connection reset (`UND_ERR_SOCKET`).
- All three CLIs (`aweshare`, `aweshare-hub`, `aweshare-agent`) accept `-v`/`--version` (zen requirement) and `--help`/`-h` now exit 0 instead of "unknown command" with exit 1.
- Hub numeric env vars (`AWESHARE_HUB_PORT` etc.) and `aweshare-hub serve --port` fail fast with an actionable message instead of an uncaught `RangeError` from `listen()`.
- Hub strips `cookie` from tunneled requests and `set-cookie` from responses — consumer credentials for the hub domain never reach producer upstreams.
- Agent config reports `backends`/`offerings` type problems as `ConfigError` entries instead of a raw `TypeError` when they are not TOML arrays.
- CLI fetch failures surface the underlying cause (`ECONNREFUSED` etc.) instead of a bare "fetch failed".

### Known limitations

Codex requires `wire_api="chat"` (no Responses API); Ollama streams carry no usage (token counts NULL); single hub instance + SQLite; corporate proxies may block WebSocket tunnels.

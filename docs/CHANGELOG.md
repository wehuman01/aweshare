# Changelog

All notable changes to aweshare are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [semver](https://semver.org/).

## [Unreleased]

## [0.4.3] - 2026-08-24

### Changed

- **`aweshare hub invite` now defaults `--expires-in` to 7d** — an unexpiring one-time secret was the silent default before; codes now live 7 days unless the operator spells another duration (`90s/30m/12h/7d`). The admin REST API is unchanged: omitting `expiresAt` there still mints a code with no expiry, for operators who deliberately want one.

- **`aweshare consumer list` now shows both per-offering concurrency caps** — the `USERS` column is renamed `MAX USERS` (still `maxConcurrentUsers`, the distinct-consumer cap) and a new `PER USER` column shows `maxConcurrencyPerUser` (concurrent requests per consumer; `-` on pre-v0.5 hubs that don't report it). `--json` already included both fields.

- **`maxConcurrency` is now `maxConcurrencyPerUser`** (breaking, wire v2) — the per-offering concurrency cap is now per **consumer** instead of per alias: a user hitting their own cap gets 429 `PRODUCER_MAX_CONCURRENCY` while other consumers proceed unaffected; the alias-wide bound becomes `maxConcurrentUsers × maxConcurrencyPerUser`. Renamed everywhere: config key, register message, DB column (`offerings.max_concurrency` → `max_concurrency_per_user`, schema v10), catalog field. A config still using the old `maxConcurrency` key fails validation with a rename hint. WIRE_VERSION bumped to 2 — mixed old/new hub+agent pairs refuse to pair with a clear mismatch error instead of silently applying default caps.

## [0.4.2] - 2026-08-24

### Added

- **Hot config reload for hub and producer** — editing `config.toml` no longer needs a restart: both processes stat-poll their config files every 2s (polling, not inotify, so edits on Docker bind mounts and network volumes are seen too) and apply valid changes within a couple of seconds; `aweshare producer reload` (or SIGHUP to either process) forces it immediately and only skips the polling delay. The producer re-reads `config.toml` + `secrets.json` and re-registers its offerings on the open tunnel — no disconnect; the hub live-applies its tunables (`consumerRps`, timeouts, `maxProducers`, …). A broken file keeps the previous values and logs the error; host/port still need a restart.

### Changed

- **`GET /v1/catalog` now reports `usedDailyTokens`** — consumers can see how many tokens each offering has consumed today and infer the remaining budget (`dailyTokens - usedDailyTokens`, or ∞ when unlimited). `aweshare consumer list` renders this as a `REMAINING` column. `--json` includes `usedDailyTokens` on every offering row.

### Fixed

- `producer start --background` now records the log file position and polls for up to 2s: an instantly dying child prints its last log lines instead of silently succeeding, and healthy starts return as soon as the first line lands.

## [0.4.1] - 2026-08-24

### Added

- **`producer start --background` / `stop`, and a doctor that sees the running instance** — the producer can now run detached: `start --background` spawns a background instance (logs append to `~/.aweshare/producer.log`, pid recorded in `producer.pid`, both 0600), waits briefly and surfaces the log tail if it dies instantly. `stop` ends it (SIGTERM, SIGKILL after a 10s grace) and cleans up the pidfile. **`doctor` is now the single diagnostic, pre-flight and runtime**: it leads with an `instance` check (running with pid + uptime; a pidfile naming a dead process FAILS as a crashed daemon) and appends the recent producer.log (pino JSON rendered readably); `doctor --status` shows just that instance state and log tail, skipping every network probe for an instant answer. A second `start` refuses while a background instance is alive (two instances would kick each other off the hub's latest-wins tunnel). Foreground `start` is unchanged. Connection lifecycle events (`registered`, tunnel close/reconnect) are now logged at info/warn so detached logs are actually useful.
- **Community hub guide** — step-by-step producer/consumer quickstarts (trust rules, endpoints, FAQ) now live under `docs/community-hub/` (English + 中文), and both READMEs' Operations sections point at the developer-run invite-based hub at **https://aweshare.wehuman.top** (request a code at peng@wehuman.top) for anyone without an always-on box to share from.

### Changed

- **`hub list --token` shows real tokens again** — reversing schema v5's hash-only rule, tokens join invite codes as the deliberate on-disk plaintext: redeem now keeps the plaintext (`token_plain` columns, schema v9, auto-migrated) next to the auth hash, so a user who loses their token gets the same identity handed back instead of re-pairing. Authentication is untouched (peppered SHA-256); the exposure widens accordingly — a data-dir reader can now act as an existing identity, so guard it. Identities minted before this release have no stored plaintext and keep showing `#id name` in the TOKEN column; hand them a fresh invite. `--json` follows `--token` the way it follows `--reveal`.

## [0.4.0] - 2026-08-24

### Removed

- **Breaking: per-alias grants.** The producer-side grant business is gone — admission (the operator's one-time invite codes) plus the existing guardrails (per-consumer `hub limits`, per-offering `maxConcurrentUsers`/`dailyTokens` caps, `hub revoke` suspension) fully replace it. A redeemed consumer key may call **every** offering on the hub; if the operator lets someone in, they can use what is shared. Removed: `aweshare producer grant`/`revoke`/`list`, `PUT`/`DELETE`/`GET /admin/v1/grants`, the `NOT_GRANTED`/`GRANT_EXPIRED` error codes, the catalog's `granted` flag (schema v8 drops the `grants` table on upgrade), and the grants-only GRANTED column in `aweshare consumer list`. `GET /v1/models` now lists every registered alias. Producers lose nothing else: their connection is the tunnel, and `GET /admin/v1/usage` still answers producer tokens (own slice). **Before upgrading a shared hub, decide whether every admitted consumer may use every offering** — on a private hub this is usually already true.
- **Breaking: direct admin-API token issuance.** `POST /admin/v1/tokens`, `DELETE /admin/v1/tokens/{producers|consumers}/{id}` and its `/restore` are gone — admission and suspension are invite-only (`hub invite` + the public redeem endpoint; `hub revoke --id N` / `hub restore --id N`). The mint route duplicated what any admin-token holder could already do in two calls (create an invite, redeem it) while bypassing the lifecycle handle: identities it minted had no invite row, so `hub revoke` — the CLI's only suspension tool — could not touch them. Every identity now provably carries an invite handle from mint to suspension. `GET /admin/v1/tokens` stays (the `hub list producers`/`hub list consumers` rosters read it). Hubs holding identities minted by the old route should re-admit them via invites before upgrading — those identities lose their suspension handle otherwise.

## [0.3.10] - 2026-08-24

### Added

- **Per-offering usage caps** — `maxConcurrentUsers` (distinct consumers with a request in flight; hub default 3, 429 `PRODUCER_MAX_USERS`) and `dailyTokens` (tokens shared across all consumers per alias per UTC day; hub default 1,000,000, `0` = unlimited, 429 `QUOTA_EXCEEDED` with UTC-midnight reset) are optional keys on every `[[offerings]]`. They ride the register message to the hub (schema v7), which enforces them at dispatch. `maxConcurrency` caps in-flight requests; `maxConcurrentUsers` caps in-flight people — one consumer firing parallel requests still counts as one user. **Behavior change:** the defaults apply to every alias once the hub upgrades, including offerings whose agent predates these fields — raise them or set `dailyTokens = 0` in the producer's config.toml to relax. Daily caps count recorded usage (Ollama streams report none), so they are observed-usage thresholds like the existing token budgets.
- **`GET /v1/catalog`** (consumer key) — every offering on the hub: producer, alias, protocol, status, the caller's grant flag and the per-offering caps. A discovery view for consumers deciding what to ask for; `/v1/models` keeps its OpenAI shape.
- **`aweshare consumer list --hub URL --token asc_... [--json]`** — renders the catalog as an aligned table (PRODUCER/ALIAS/PROTOCOL/STATUS/GRANTED/USERS/DAILY TOKENS).

### Fixed

- Schema v7 migration also creates `offerings`/`usage_events` for databases upgraded all the way from v1 — those tables previously only existed if the database was created fresh, leaving upgraded v1 databases without them.

## [0.3.9] - 2026-08-24

### Changed

- **`aweshare agent` is now `aweshare producer`** — the command group now carries the role it serves, matching the `hub`/`producer`/`consumer` triple and the `asp_`/`asc_` token prefixes. Every subcommand keeps its name and behavior (`init`, `join`, `config`, `doctor`, `start`, `grant`, `revoke`, `list`). **Breaking:** the old `agent` target is gone without an alias — scripts must switch to `aweshare producer ...`. Internal names are untouched: the config dir stays `~/.aweshare`, the env var stays `AWESHARE_AGENT_DIR`, and the directory/package stay `apps/agent`/`@aweshare/agent`.
- Retired hub subcommands (`hub token`, `hub grant`, `hub consumer`) no longer get pointer errors — they fail as unknown commands like anything else unrecognized.
- `INVITE_ROLE_MISMATCH` now points at the right command for both directions (`use 'aweshare <role> join' with this code`), and the `hub invite --role consumer` handout leads with `aweshare consumer join` (curl stays as the no-install fallback).

### Added

- **Hub `config.toml`** — the hub now reads `<dataDir>/config.toml` (`~/.aweshare-hub/`; Docker `/data/`), so tuning no longer requires env vars. `hub init` writes the template with every key commented out (uncomment to override); keys mirror the env vars in camelCase (`consumerRps`, `headTimeoutMs`, …). Precedence: `serve` flags > env vars > config.toml > defaults — existing env-only deployments behave identically. A broken file (invalid TOML, unknown key, non-positive value) fails fast at startup with the key named; `AWESHARE_HUB_DATA_DIR` stays env-only (it locates the file).
- **`aweshare consumer join --hub URL --code asi_... [--allow-http]`** — consumers redeem their invite with the CLI instead of curl: probes the hub first (the code only burns after the probe passes), asserts the consumer role (a producer code rejects with 409 without being burned), then prints the `asc_` token once with ready-to-paste `OPENAI_*` / `ANTHROPIC_*` exports. Consumers keep no local files — the token lives in their SDK environment.
- Token outputs now tell you to save them: `consumer join` prints a "will not be shown again" warning under the token (the hub stores only a hash), and the `producer join` failure path that hands over the `asp_` token says the same. `hub init` (admin token) and `hub invite` (codes) already did.

## [0.3.8] - 2026-08-23

### Added

- **`aweshare hub limits NAME`** — per-consumer limit overrides are back on the CLI as a thin wrapper over the unchanged `GET`/`PUT`/`DELETE /admin/v1/consumers/{name}/limits`: bare `aweshare hub limits alice` shows the current overrides (or that none are set), value flags merge (`--rps 5 --max-concurrent 2 --tpm 60000 --max-total-tokens 5000000`, kebab-case mapping to the API keys; unset keys keep the hub-wide `AWESHARE_CONSUMER_*` defaults), and `--clear` drops everything back to defaults. Positive-number checks run client-side; integer/precision rules stay server-side so its error lists every problem in one shot. `--json` prints the raw API response, matching `list`.
- **`aweshare hub usage`** — the metered request log, newest first, as an aligned table (TIME/CONSUMER/ALIAS/MODEL/STATUS/TOOK/TOKENS; NULL token counts such as Ollama streams render as `-`, error rows carry their code). `--consumer NAME`, `--alias ns/model` and `--limit N` (1..1000, default 100) narrow it; usage rows carry consumer ids, which the CLI maps to names via the roster — one extra call, no API change. `--json` prints the raw rows. `hub usage` left the retired-command list; the `hub consumer` pointer now routes to `hub invite --role consumer` / `hub limits NAME`.

## [0.3.7] - 2026-08-23

### Added

- **Consumer invites** — admission is now invite-only for both roles: `aweshare hub invite --role consumer --name alice` mints a code that redeems into an `asc_` consumer token. Consumers redeem it themselves with one curl against the existing public `POST /invites/v1/redeem` (rate-limited as before) and keep the returned token for their SDK env vars — no aweshare install on their side. Consumer invites are bound-only (the name is the handle grants reference) and single (no `--count`); names clash across roles, matching admin-API issuance. The redeem answer now carries `role`, and `aweshare agent join` asserts `expectRole: 'producer'` so mixing up codes fails with `409 INVITE_ROLE_MISMATCH` **without burning the code** (pre-expectRole hubs are covered too: an `asc_` token back is reported honestly). Revocation keeps its lockstep: revoking a redeemed consumer invite suspends the consumer it minted, restore revives it, and suspending via the admin token handle (`DELETE /admin/v1/tokens/consumers/:id`) now flags the invite as well (previously consumer tokens had no invite pairing). Schema v6 adds `invites.role` + `invites.consumer_id` (existing rows default to producer). Direct admin-API issuance remains available.
- **`hub list producers` / `hub list consumers`** — read-only rosters from the existing `GET /admin/v1/tokens`: name, email (producers), suspension status and last seen — the audit view that left the CLI in 0.3.5, modeled on awewarm-hub's `list users`. `hub list` (invites) gains a ROLE column and shows consumer-side minted tokens in `--token`; `hub list` bare still means invites. The removed-command pointer for `hub token` now points here.

### Fixed

- The hub Docker image (`ghcr.io/wehuman01/aweshare`) crashed on startup: `apps/hub/dist` reads the monorepo root `package.json` for its version, and the image's run stage never copied it — `ENOENT: /app/package.json`, an instant crash loop that surfaced as 502 behind fronting tunnels. The file now ships in the image.

## [0.3.6] - 2026-08-23

### Added

- `GET /healthz` now identifies the hub: `{ok, version, wire}` (was `{ok}` alone). `aweshare agent join` preflights it before burning the one-time invite, so each failure gets its own fix: unreachable hub, "answered but not an aweshare hub" (wrong URL / non-JSON), WAF-blocked 403 (Cloudflare bot protection), or a wire-version skew that previously only surfaced at `start`. `agent doctor` reports the hub version in its hub line, and `join` prints the hub version it paired with.
- `aweshare agent join --allow-http`: escape hatch for pairing with a plain-HTTP hub outside the LAN. Without it, join refuses — the producer token would cross the network unencrypted — and points at https (e.g. a Cloudflare tunnel) or a LAN address instead. Loopback/private/link-local IPs and `localhost`/`*.local` names stay allowed silently.

### Changed

- Every agent→hub HTTP call (`join`, `doctor`, `grant`, `revoke`, `list`) and the producer WebSocket now identify themselves as `aweshare-agent/<version>` (the WebSocket previously sent a bare `ws/8.x` UA; Node fetch sends none — anonymous UAs sit on Cloudflare Bot Fight Mode's blocklist) and carry a 10s timeout — an unreachable hub used to hang `join` and the grant commands forever. The hub CLI's localhost admin calls gained the same 10s timeout.
- Agent CLI internals: each command is now one function (`runInit`/`runJoin`/…), and all hub access goes through `apps/agent/src/hub.ts` — one User-Agent, one timeout policy, one error shape — with unit tests. No command surface changes.

## [0.3.5] - 2026-08-23

### Changed

- **Breaking (API):** grant writes are producer-owned — `PUT`/`DELETE /admin/v1/grants` now accept only the producer token of the alias namespace; admin-token writes get `403 NOT_GRANTED` (reads stay: admin sees all for audit, producers their own slice). Identity and permission are now split by design: the operator issues identities (invites, consumer keys) and governs (suspend/restore, limits, usage); each producer alone decides who may call their aliases — one rule for private hubs (operator == producer) and community hubs (mutually unaffiliated producers). `aweshare hub grant` points at `aweshare agent grant`.
- **Breaking (CLI):** `aweshare agent config init` removed — `aweshare agent init` is the same behavior plus `--hub`/`--token` pre-fill; the old spelling prints a pointer. Flag-only agent commands (`init`/`join`/`doctor`/`start`/`grant`/`revoke`/`list`) now reject stray positional arguments instead of silently ignoring them, matching the hub CLI.
- **Breaking (CLI):** the hub CLI narrowed to the invite workflow, modeled on awewarm-hub — `invite create` became `invite` (flags unchanged: `--name`, `--count`, `--expires-in`), `invite list` became `list` (plus a new `--token` showing the producer token each invite minted, with last seen), and `invite revoke`/`invite restore` became flat `revoke --id N` / `restore --id N`. The `token`, `grant`, `consumer` and `usage` command groups left the CLI — the admin REST API (`/admin/v1/*`) still serves token/limit/usage management, and grants are producer-owned (`aweshare agent grant`/`revoke`/`list`). Producers are admitted via invites only; consumer keys (`asc_…`) are issued directly through the admin API.
- Hub and agent `--help` narrowed to one-line command descriptions (matching awewarm-hub / peng-code-zen layout); every command now answers `-h` with its own flags, and the umbrella `aweshare -h` lists the new surfaces.
- Server-side error hints now point at the new commands (`aweshare hub revoke --id N` / `aweshare hub restore`).

### Added

- `hub list --token`: TOKEN (`#id name`) and SEEN columns join the invite table — the operator sees who redeemed which code and whether that producer is alive. The API (`GET /admin/v1/invites`) now returns `producer_name` and `producer_last_seen_at` on each row.

## [0.3.4] - 2026-08-23

### Added

- Reversible suspension: `hub token restore --role R --id N` (API: `POST /admin/v1/tokens/{producers|consumers}/{id}/restore`) undoes `token revoke` — the same token works again, and nothing was deleted in between (grants, offerings, usage history survive a suspension). Suspended tokens now fail with a distinct `401 TOKEN_REVOKED` (message points at restore) instead of a bare invalid-key 401.
- Invite/tenant lockstep: revoking a redeemed invite (`hub invite revoke --id N`) suspends the producer it minted and closes its tunnel; `hub invite restore --id N` (API: `POST /admin/v1/invites/{id}/restore`) brings it back. Revoking a producer token flags its invite, and restoring from either handle clears both sides — the code and the token are two handles for the same suspension.
- Producer capacity cap: `AWESHARE_MAX_PRODUCERS` (default 10) — `hub token issue --role producer`, invite redeem and producer restore refuse with `403 HUB_FULL` when all slots are active. Suspended producers free their slot.
- Liveness tracking: `last_seen_at` on producers (tunnel connect + heartbeat) and consumers (authenticated requests), throttled to one write per 10 minutes; shown as a `LAST SEEN` column in `hub token list`.
- `hub invite list` now derives a lifecycle status per row: `pending` / `used` / `suspended` (its producer is suspended) / `revoked` / `expired`. Expired codes are lazily deleted when someone tries to redeem them.

### Changed

- **Breaking (security, schema v5):** tokens are stored hash-only again — the `token_plain` columns are dropped (auto-migrated) and `hub token list --reveal` / `?reveal=true` on `/admin/v1/tokens` is removed. Tokens are shown exactly once at issue/redeem and can never be re-displayed. Invite codes keep their plaintext (`hub invite list --reveal` still works). **Back up `hub.db` before upgrading — the v5 migration is not reversible and the database cannot roll back to an older version afterwards.** Deployments with more than 10 active producers should raise `AWESHARE_MAX_PRODUCERS` before upgrading.
- Revocation semantics are now documented and implemented as reversible suspension everywhere: revoking never deletes rows, and the CLI help for `token revoke` / `invite revoke` says so.
- README token-limit wording now describes TPM and lifetime limits as observed-usage thresholds, including their single-request and concurrent overshoot behavior.

### Fixed

- `hub token issue` with an already-taken name now returns `409 NAME_TAKEN` instead of an unhandled SQLite constraint error (500).
- Revoking a producer token now closes its existing tunnel immediately instead of waiting for a disconnect.
- Slow consumer responses now apply backpressure to the producer tunnel, bounding hub-side response buffering without changing the wire protocol.
- `GET /v1/models` no longer lists offerings whose grant has expired.
- Hub and agent version output now reads the root package version, removing release-time version drift.
- Biome configuration and formatting are aligned with the locked toolchain so the CI check passes again.

## [0.3.3] - 2026-08-22

### Added

- `hub token list --reveal` and `hub invite list --reveal` (API: `?reveal=true` on the two admin list endpoints) re-display the stored plaintext of tokens / invite codes. Secrets issued from this version on are stored in the database alongside their hash (new `token_plain` / `code_plain` columns, schema v4, auto-migrated); pre-v4 rows show `-` since hashes are not reversible. Trade-off made explicit in the README trust section: a DB leak now exposes every secret issued since this version. Producer tokens minted at invite redeem are stored the same way.

### Changed

- README / README_cn / `resources/skills/aweshare/SKILL.md`: command reference and trust-boundary wording updated for `--reveal`; invite code descriptions now note re-viewability via `hub invite list --reveal`.

## [0.3.1] - 2026-08-21

### Changed

- `apps/hub/package.json` version synced to match the root package version.
- Docker hub wrapper now handles `-h/--help/help`, `-v/--version` and empty args by delegating to the hub CLI directly.
- Self-update reminder hardened: numeric version comparison (`versionGte`), 6-hour backoff after failed npm lookup, legacy caches written by older aweshare versions are treated as stale.
- `.github/FUNDING.yml` normalized to the current `ko_fi` key format.

## [0.3.0] - 2026-08-21

### Added

- Invite codes (`asi_…`) for producer self-service admission, in two modes. Bound: `aweshare hub invite create --name NAME [--count N] [--expires-in 7d]` locks the code to that producer name. Unbound: omit `--name` to batch hand-out codes; the producer submits `--name` + `--email` at redeem and both are stored on the producer row (visible in `hub token list`; email is self-reported contact info, not verification). Producers run `aweshare agent join --hub URL --code asi_… [--name NAME --email YOU@EXAMPLE.COM]` to redeem a producer token and write it into their config — no admin round-trip for the secret itself. Codes are single-use, optionally expiring, revocable until redeemed (`hub invite list` / `hub invite revoke`); a name clash at redeem rolls back and leaves the code usable. `hub token issue` also accepts `--email` for producers. DB schema v3 (auto-migrated); the unauthenticated redeem endpoint is rate-limited (`AWESHARE_INVITE_REDEEM_PER_MIN`, default 10/min).

### Changed

- Docker hub wrapper now routes `aweshare hub <command>` directly and rejects bare invocations with a clearer error message.
- README / README_cn: added invite flow docs and command reference tables.
- CLI help output restructured to a standard `Usage` / `Options` / `Commands` layout; adds `-v/--version`.
- `resources/skills/aweshare/SKILL.md` adds a Self-Update section and Docker deployment hints (`docker pull`, `docker ps`).
- `scripts/sync-public.mjs` excludes `docs/specs` from public sync.

## [0.3.2] - 2026-08-21

### Added

- Shared table module (`apps/hub/src/table.ts`, `apps/agent/src/table.ts`) with aligned-column rendering, timestamp formatting, and byte-size humanization.
- Hub `token list`, `invite list`, `grant list`, and `usage` now render aligned tables by default (`--json` keeps the raw API response).
- Agent `list` now renders grants as an aligned table (`--json` keeps the raw API response).
- `docker/aweshare-wrapper.sh`: container-local `aweshare` command that forwards to the hub CLI and rejects `agent` with a clear error.
- `resources/skills/aweshare/SKILL.md` expanded with Producer Admission via Invite Codes, Operations env vars, and `responses` protocol config examples.

### Changed

- Hub and agent CLI help restructured into categorized sections (Setup/Onboarding, Tokens, Invites, Grants, Limits & usage, Run, Config).
- Agent protocol validation error now names all three supported protocols: `openai`, `anthropic`, `responses`.
- Umbrella CLI (`bin/aweshare.mjs`) command descriptions updated to reflect `invite`, `join`, and `config` additions.
- README / README_cn: note that list/usage commands print tables by default; `--json` returns the raw API response.
- `apps/hub/test/table.test.ts` and `apps/agent/test/table.test.ts` added with full coverage for `formatTable`, `fmtTime`, `renderTokens`, `renderInvites`, `renderGrants`, and `renderUsage`.

## [0.2.8] - 2026-08-20

### Changed

- Docker image now ships an `aweshare` wrapper on PATH: `docker exec aweshare-hub aweshare hub token list` works like the npm install, replacing `docker exec aweshare-hub node apps/hub/dist/cli.js ...`; `agent` subcommands fail with a readable error (the agent runs on producer machines).
- README / README_cn: docker quickstart uses the new `aweshare hub init` exec form; added a three-token-roles table (admin / producer / consumer); README_cn aligned with README (Support section, section order).

## [0.2.7] - 2026-08-20

### Changed

- License switched from MIT to the aweshare Proprietary License: free to use and self-host, no redistribution or re-provisioning. Applies to releases from this point on; previously published MIT versions remain MIT for those who already obtained them.
- README / README_cn: added Support section (Ko-fi, WeChat Pay QR), reorganized Known limitations placement, and updated the license badge to proprietary.
- `scripts/sync-public.mjs` now mirrors all non-source files to the public docs repo (previously a hardcoded allowlist); the sync workflow no longer commits and pushes inline.

### Added

- `.github/FUNDING.yml` (Ko-fi sponsor link)
- `assets/images/wechat-pay.jpg`
- `resources/README.md` explaining the `resources/` directory shipped with the public docs repo.
- `resources/skills/aweshare/SKILL.md` expanded with Hub Deployment (npm and Docker), TLS guidance, and remote hub administration notes.

## [0.2.6] - 2026-08-19

### Added

- `aweshare agent config` subcommands: `path`, `show` (secrets redacted), `edit` (`$VISUAL`/`$EDITOR`/`vi`), and `init` (no-op if files exist).
- `redactConfig` helper to safely print config without producer token or upstream secrets.
- `resources/skills/aweshare/SKILL.md` skill for agent/hub configuration and grant workflows.

## [0.2.5] - 2026-08-18

### Fixed

- Docs-sync CI no longer fails when the `sync-public` and `sync-public-docs` workflows push the public repo concurrently; the sync step now rebases on `main` before pushing.

## [0.2.4] - 2026-08-18

### Added

- `aweshare self-update [--check]`: update the npm-installed CLI in place (version check, y/n confirm, `npm install -g aweshare`). A passive update reminder runs at most once per 24h after other commands (cache in `~/.cache/aweshare/`); disable with `AWESHARE_NO_UPDATE_CHECK=1`.

## [0.2.3] - 2026-08-18

### Added

- `scripts/sync-public.mjs` and `.github/workflows/sync-public.yml` to mirror user-facing files (README, LICENSE, docker-compose.yml, docs, logo) to the public repo `wehuman01/aweshare` on every main merge.
- `sync-public-docs` job in `.github/workflows/release.yml` so the public repo is also refreshed on every release.

### Changed

- Restyled both READMEs with aweskill-style header, badges, and concise description.
- Fixed Chinese README release section to reflect npm Trusted Publishing (OIDC, no token secret) and the public-repo sync.

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

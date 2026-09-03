# Changelog

All notable changes to aweshare are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [semver](https://semver.org/).

## [0.6.3] - 2026-08-31

### Added

- **LAST SEEN — the hub's freshness evidence in every offering table** (`consumer list`, `hub list offerings`/`hub status`, `producer list`): how long ago real traffic or a recovery probe last proved the offering actually served (`-` = never). Producer heartbeats now report every backend, not just degraded ones — healthy entries carry `lastOkAt` — and the catalog's new `hubCheckAt` is the newer of that stamp and the traffic-derived `observedAt`. Old hubs and old agents degrade to `'-'` on either side.
- **Per-consumer probe budget** — probe-shaped requests (a single-turn `'ping'` with a minimal token cap: what `consumer list --ping` and hand-rolled smoke-test curls send) are counted per consumer per day, shared across aliases, and answered with 429 `PROBE_BUDGET_EXCEEDED` naming the budget once spent; real requests are never counted. Default 15, tunable hub-wide via `consumerProbeBudget` (config.toml / `AWESHARE_CONSUMER_PROBE_BUDGET`, 0 = unlimited) or per consumer via `hub limits NAME --probe-budget N`; executed probes are flagged in the usage rows (`usage_events.probe`, schema v16).

### Changed

- **`consumer ping` folded into `consumer list --ping`** — one entry point instead of two commands sharing the same flags. The plain view stays free (and now carries LAST SEEN); `--ping` appends the consumer's own proof: one minimal real request per offering through the same `/v1` endpoints an SDK hits, with RESULT/TIME/DETAIL inserted before OBSERVED MODEL so the hub's claim and your own test sit side by side. Lines stream per alias as pings settle; offline/blocked rows show SKIP unpinged; `--alias` scopes both view and pings; `--json` attaches each row's result; exit code is 1 only when a pinged row fails (the plain list always exits 0). The standalone `consumer ping` subcommand from earlier in this unreleased cycle never shipped and is replaced.
- **Ping diagnostics fixed** — a timed-out ping now reports the 60s it actually waited (the message previously hardcoded the control path's 10s); error bodies without a message fall back to the raw `HTTP <status>` instead of a usually-empty statusText; the RESULT column fits `FAIL (network)` so streamed rows stay column-aligned.

## [0.6.4] - 2026-09-01

### Added

- **`consumer list --ping --ping-table`** — the run's verdict as two tables rendered once it completes instead of one streamed line per ping: a FAIL table first (PRODUCER/ALIAS/PROTOCOL/STATUS/TIME/DETAIL — STATUS carries the HTTP code, or `network` when no answer came) and an OK table below (served model, TIME), each titled with its count; offline/blocked SKIP rows stay out of both, their count still on the header line. Streaming remains the default; `--ping-table` implies `--ping`, keeps the wait visible with one rewritten progress line on stderr (silent when piped, so redirected stdout stays pure tables), and refuses only `--json`.

### Changed

- **Probe budget semantics: per-run instead of per-request** — a complete `consumer list --ping` cycle now counts as one budget unit regardless of how many offering rows it probes (was: one unit per probed row). The consumer CLI labels every request in a cycle with the same `x-aweshare-probe-run` UUID header; the hub tracks run admissions in a new `probe_runs` table (schema v17) with `admitProbeRun()`, an atomic check-and-record that prevents double-counting across concurrent requests. The default budget is 10 runs/day per consumer (was 15), tunable via `consumerProbeBudget` / `--probe-budget`; individual probe requests remain flagged in usage rows (`usage_events.probe`), while run admissions live in the new table. Hand-rolled smoke tests without a valid run header are treated as their own one-request run — they cannot suppress accounting by reusing a fixed header.

## [0.6.5] - 2026-09-01

### Changed

- **`--ping-table` now implies `--ping`** — `consumer list --ping-table` no longer requires the separate `--ping` flag; the table mode automatically enables pinging and shows progress on stderr while it runs (silent when piped, so redirected stdout stays pure tables). The two flags can still be combined for clarity.
- **`--ping-table` refuses `--json`** — the table output is a text view; passing `--json` with `--ping-table` now fails loudly instead of silently ignoring the table flag.

## [0.6.6] - 2026-09-03

### Added

- **Per-backend egress proxy (`proxyUrl`)** — a backend whose upstream needs a ladder (a Codex account login, or an `api.openai.com` key behind the same proxy) can now declare it in config: `proxyUrl = "http://127.0.0.1:7890"` inside its `[[backends]]` block. It covers that backend's http and https traffic only, hot-reloads with the config, and survives background/systemd starts where shell environment variables silently vanish. Precedence: `proxyUrl` over `HTTPS_PROXY`/`HTTP_PROXY`/`ALL_PROXY`; the env vars alone still apply to codex-login backends only (a machine-wide proxy setting can never capture a local Ollama). `NO_PROXY` is always honored; SOCKS or malformed URLs fail config load naming the backend. `producer doctor` gains a TCP reachability check for a configured proxy (the most common egress failure is the proxy itself being down) and names the active egress on the codex login check; proxy URLs are redacted in `producer config show` alongside tokens and never logged.

### Fixed

- **`producer config show` now redacts `proxyUrl` lines even when they are indented or carry a trailing comment** — a common TOML layout like `  proxyUrl = "http://user:pass@proxy:7890" # local proxy` used to leak the credentials in plain text. The redactor now preserves leading whitespace and trailing comments while replacing only the quoted value.
- **`parseCatalog` no longer echoes the full `proxyUrl` in validation errors** — malformed or SOCKS proxy URLs now report the backend id and the requirement without printing the original URL, so config mistakes do not leak proxy credentials into logs or CI output.
- **Hot-reloading `proxyUrl` now closes the previous proxy dispatcher** — repeated config reloads no longer leave pooled `EnvHttpProxyAgent` instances and sockets behind; the new route closes the old dispatcher before caching the replacement.

### Documentation

- Updated README and CHANGELOG guidance around `proxyUrl`, egress precedence, doctor output, and redaction behavior.

## [Unreleased]

### Added

- **Per-backend egress proxy (`proxyUrl`)** — a backend whose upstream needs a ladder (a Codex account login, or an `api.openai.com` key behind the same proxy) can now declare it in config: `proxyUrl = "http://127.0.0.1:7890"` inside its `[[backends]]` block. It covers that backend's http and https traffic only, hot-reloads with the config, and survives background/systemd starts where shell environment variables silently vanish. Precedence: `proxyUrl` over `HTTPS_PROXY`/`HTTP_PROXY`/`ALL_PROXY`; the env vars alone still apply to codex-login backends only (a machine-wide proxy setting can never capture a local Ollama). `NO_PROXY` is always honored; SOCKS or malformed URLs fail config load naming the backend. `producer doctor` gains a TCP reachability check for a configured proxy (the most common egress failure is the proxy itself being down) and names the active egress on the codex login check; proxy URLs are redacted in `producer config show` alongside tokens and never logged.

## [0.6.2] - 2026-08-31

### Added

- **Handshake timeout on the agent tunnel** — a 20s `handshakeTimeout` is now passed to the WebSocket constructor. A network that swallows the TCP/TLS/upgrade exchange (sleep-wake, Wi-Fi switch, dead peer) no longer leaves the socket in `CONNECTING` forever: the timeout errors the dial and the reconnect loop retries instead of parking for the life of the process.
- **Pong-based liveness detection** — the hub auto-pongs our pings, so an `OPEN` socket whose pong has been silent past 45s is assumed dead and terminated. The reconnect loop then dials a fresh tunnel instead of waiting minutes for TCP retransmit to give up. Pings go out at `pongTimeoutMs / 3`, so the deadline is only judged against pings we actually sent.
- **Tests for both regressions** — a TCP black hole that accepts but never speaks HTTP/101, and a hub whose control frames flow but whose pongs go silent, are now covered by integration tests using real WebSocket servers.

### Changed

- **`applyConfig` cuts non-OPEN sockets before redialing** — previously, reloading the config while the socket was still connecting, closing, or half-open silently did nothing and a stuck connection stayed stuck until a process restart. The socket is now terminated so the reconnect loop dials a fresh tunnel with the new config.
- **`stop()` gives the peer a 2s graceful-close window** — in-flight requests can finish cleanly instead of being aborted by a hard terminate. A timer (`unref`'d so it never holds the event loop open) cuts the socket after the grace period when the peer ignores the close frame.

## [0.6.1] - 2026-08-31

### Added

- **Bilingual landing page on `GET /` for browsers** — the hub root used to answer every visitor with a bare JSON 404; to someone holding an invite code that reads as "site broken". A request whose `Accept` includes `text/html` now gets a static landing page (no JavaScript, no external requests) explaining what the hub is and how to connect: ask for an invite, `aweshare consumer join`, point the SDK at the visited host. Every other client keeps the exact JSON 404 it always got. The page exists in two fully monolingual versions, English and Chinese, switched by the `EN / 中文` toggle (`?lang=zh|en`); the first visit follows the browser's primary `Accept-Language` tag. The operator's invite-request address is configurable — `contactEmail` in the hub's `config.toml` or `AWESHARE_HUB_CONTACT_EMAIL` — shown as a mailto link when set, generic "contact the hub operator" wording when not; it hot-reloads like the other tunables. The join commands on the page interpolate the request's `Host` header (both it and the email are HTML-escaped — reflected input never becomes markup), so visitors always see the address that brought them there.

### Changed

- **Usage summaries now default to most-recently-used first, with `--sort` to choose the order** — `aweshare hub list usage` and `aweshare producer list usage` (summary view) used to sort "busiest first": a person's token total, then each model's tokens. The default is now time — the group touched most recently sits on top, matching the `--details` log's newest-first reading direction. `--sort KEY` picks the order explicitly: `time` (default), `consumer`, `producer` or `model` (that column alphabetical, newest first within it — meaningless combos like `--sort consumer --group-by alias` fail loudly), or `tokens` / `requests` (busiest first; `tokens` keeps a person's rows together and reproduces the old default order). The header line now names the active sort. `GET /admin/v1/usage/summary` takes the same `sort` parameter (400 `INVALID_SORT` on a bad value); summary rows gained two additive fields, `tokens` (prompt + completion total) and `last_id` (the group's latest event id, the order tiebreak). `--sort` is rejected on `--details` — a request log is a timeline. On the producer CLI `--sort producer` is rejected too (every row is already the caller's own).

### Fixed

- **The person grouping behind the busiest-first summary order was fragile** — the "busiest person first" window function read bare `u.prompt_tokens`/`u.completion_tokens` columns, which in an aggregate query sample one arbitrary event per group; which event got sampled depended on the query plan, so the person ranking could silently flip (the same bare-column trap an earlier 0.5.x fix spelled out for the row-level sums). The window now runs over the grouped rows' own `tokens` totals, making the person grouping deterministic — and reachable as `--sort tokens`.

### Added

- **`aweshare consumer ping`** — end-to-end ping of the offerings a consumer can actually call: one minimal real model request per online offering row, through the same `/v1` endpoints an SDK would hit, reporting HTTP status, round-trip latency and the self-reported model per alias/protocol. A green row proves the whole chain (consumer auth, hub dispatch, tunnel, producer, upstream); a FAIL passes the hub/upstream error through verbatim (quota, auth, upstream down). Stream-only responses upstreams (e.g. chatgpt's Codex backend, "Stream must be set to true") are retried once in the shape they accept and flagged instead of misreported as broken. `--alias` scopes the run (comma-separated, bare or `producer/name` form); offline rows are skipped; requests run sequentially so the hub's per-consumer rate limits are never tripped by the diagnostic itself. Exit code 1 when any row fails, so it scripts cleanly alongside `producer doctor`.

## [0.6.0] - 2026-08-30

### Added

- **Master switch for the hub-local catalog** — `config.produce.toml` now accepts a top-level `enabled = true|false` (default `true`). `false` unloads every `hub/…` model within the 2s hot-reload window while the catalog definitions stay intact — flipping it back restores the whole catalog in one edit. This gives the produce identity the counterpart of what `admin invite revoke` already gives remote producers: one reversible, whole-identity off switch. The switch is read before anything else, so it wins even over a broken `secrets.json`; a non-boolean value (e.g. `enabled = "false"`) fails the reload loudly and keeps the previous state rather than silently serving or unloading. `hub produce init` scaffolds the key commented out.

### Fixed

- **Editing `config.produce.toml` (or a producer re-register) no longer reverts a same-day quota refresh** — day-scoped refresh grants (`producer refresh` / `hub produce refresh`) used to ride on the offerings rows, which every catalog hot-reload prunes and rebuilds; a config edit whose mid-write state read as a valid-but-partial catalog deleted the rows and, with them, the grant — the day's usage came back and every REMAINING column snapped to its pre-refresh value. Grants now live in their own alias-keyed `quota_grants` table (schema v15; existing markers migrate on first open): they survive prune, re-add and protocol swaps, and still lapse at Beijing midnight by computation. `--clear` drops the grant row; the refresh API's reply is unchanged.

### Changed

- **Hub CLI surface: one gate for writes, five tables for reads, one dashboard (breaking)** — the hub subcommands now follow one law: `list <noun>` reads a table, `status` is the live dashboard, `admin` is the operator's write gate, and unknown flags fail loudly everywhere.
  - **`admin` group (new)** — every state-changing verb lives under `aweshare hub admin`: `invite mint` (was bare `hub invite`), `invite revoke N` / `restore N` (was `hub invite revoke/restore`, identity-level suspension — the sledgehammer), and `offering revoke ALIAS` / `restore ALIAS` (was `hub offering block/restore`, the per-alias scalpel; the API path and the 503 `OFFERING_BLOCKED` code are unchanged). Bare `admin`, `admin invite` and `admin offering` print help — nothing mutates by accident. The old command names fail loudly with a pointer to the new forms.
  - **`list` grew to five tables** — `hub list [invites|producers|consumers|offerings|usage]`, default still `invites`. `producers`/`consumers` are the rosters and `offerings` the alias table (same columns as `consumer list`, worst status first) — all three moved out of `status`, which no longer takes `--all` or prints tables.
  - **`status` is a slim dashboard** — capacity (producer slots, consumers, offering counts), last-5m health, admission-rejection pressure and the effective consumer defaults; no tables, no flags.
  - **`serve` is the only runner** — bare `hub produce` no longer starts a server (it failed loudly with a pointer to `serve`); a `config.produce.toml` in the data dir mounts automatically either way, and `produce init` / `produce refresh` keep their exact semantics.
  - **Unknown flags are rejected on every hub command** (and on `consumer`, matching `producer`, which already had this) — a typo'd flag now fails with the command's `-h` pointer instead of being silently ignored. Subcommand help resolves depth-first, so `hub admin invite mint -h` shows the invite help.

## [0.5.9] - 2026-08-29

### Added

- **`refresh --all` on both CLIs** — `aweshare producer refresh --all` bare-refreshes every one of the producer's registered offerings, `aweshare hub produce refresh --all` every hub-hosted `hub/…` model, in one command instead of one per alias. The selection dedupes by alias (an alias serving several protocol rows is refreshed once) and skips unlimited offerings (`dailyTokens = 0`), reporting them instead — the endpoint would answer `NO_DAILY_CAP`. One failure does not stop the rest; the run exits nonzero and `--json` prints one entry per alias (`skipped`/`error` markers included). `--all` is bare-only: per-offering `--add`/`--clear` stay single-alias.

### Fixed

- **Refresh output times now render in the display zone** — the `resets …` and bonus `until …` timestamps the refresh commands print were raw UTC ISO (the refresh feature landed one commit after the timezone-aware display change and missed it). They now render like every other CLI time (default `Asia/Shanghai`, `AWESHARE_TIMEZONE` overrides); `--json` keeps the raw UTC ISO. Also corrected the Chinese README's stale claim that `dailyTokens` rolls at UTC midnight — it has always rolled at Beijing midnight, as the English README already said.
- **Documentation sync** — both READMEs' env tables and the packaged skill still listed the pre-0.5.8 `IDLE_TIMEOUT_MS` default (300000; the default has been 120000 since v0.5.8), and the Chinese README's command tables were missing the `refresh` rows the English README has (both now include `--all`).

## [0.5.8] - 2026-08-29

### Added

- **Owner-side daily-quota refresh** — an exhausted `dailyTokens` budget can be reopened mid-day by the offering's owner, effective at once with no restart or re-register: `aweshare producer refresh ns/model` (producer's own offerings, works even while the agent is stopped) and `aweshare hub produce refresh name` (hub-hosted `hub/…` models; `hub/` prefix optional), both over `POST /admin/v1/offerings/refresh`. A bare call re-anchors today's window at that moment (usage before it stops counting), `--add N` raises today's cap by N tokens until Beijing midnight, `--clear` drops both markers. Authority follows ownership — the hub operator can restrict a producer's model (`offering block`) but can never expand its budget, and vice versa; markers survive re-registers and lapse at Beijing midnight by computation (no sweep). The catalog's `dailyTokens`/`usedDailyTokens` now report the effective budget (declaration + unexpired bonus), so every REMAINING column reflects a refresh immediately; unlimited offerings (`dailyTokens = 0`) answer `NO_DAILY_CAP` instead of pretending to refresh. Fixed stale README wording that claimed a UTC-midnight reset; the budget has always rolled at Beijing midnight.
- **Admission-rejection visibility** — every admission 429 (rate limit, per-user/alias concurrency caps, token budgets) is now counted per code × alias × consumer, exposed at `GET /admin/v1/rejections` and as an "admission rejections" section in `hub status` (top cells, since hub start). 429s never reached the usage rows, so throttling pressure was previously invisible to the operator tuning those caps.
- **`Retry-After` on admission 429s** — token-bucket rejections carry the exact refill wait; concurrency-cap rejections carry a jittered 1–5s hint (the true wait depends on other requests, and jitter keeps retrying clients from re-herding in lockstep). Budget-exhausted rejections carry no hint: retrying before the daily reset or a limit raise is pointless.

### Changed

- **CLI surface consolidation: `hub invite` is now the whole invite lifecycle; the producer's read views live under `list`** — `hub revoke --id N` / `hub restore --id N` (breaking) became `hub invite revoke N` / `hub invite restore N`, same shape as `offering block|restore ALIAS`: the invite is the handle from mint to suspension, so both verbs live on it (the old commands fail loudly with a pointer). `aweshare producer usage` (breaking) became `aweshare producer list usage`, mirroring the hub's `list usage` — on both CLIs `list` is now the records view (hub: `invites|usage`, producer: `offerings|usage`) and `status` the live snapshot. `producer status` keeps its one-glance summary but no longer repeats `list offerings`'s full table (config counts, health rollup including `blocked`, drift); hub-side `status` was already standalone, so the two CLIs now share one syntax: `list` = records, `status` = snapshot. Each subcommand rejects the other's flags instead of silently ignoring them. Hub error messages (`TOKEN_REVOKED`, `HUB_FULL`, `INVITE_REVOKED`, the tunnel's 401) point at the new forms.
- **CLI display times now render in Beijing time (UTC+8)** — every human-readable timestamp the CLIs print (hub/producer table cells, `since …` window dates, `producer doctor` log lines) defaults to `Asia/Shanghai`, matching the daily-token budget, which already resets at Beijing midnight. `AWESHARE_TIMEZONE` overrides with any IANA zone. The wire, SQLite rows and `--json` output stay UTC ISO; the trailing `Z` is gone from table cells because they are no longer UTC.
- **`idleTimeoutMs` default 300s → 120s** — a silent stream held an admission slot hostage for up to five minutes; live coding-agent traffic emits chunks far more often than that. Existing deployments that relied on the old default should set `AWESHARE_IDLE_TIMEOUT_MS=300000` (or the config-file key) explicitly.
- **Unreachable per-user caps are now flagged** — registering an offering whose `maxConcurrencyPerUser` exceeds the hub's consumer-side default `maxConcurrent` logs a warning: consumers on the defaults can never reach the promised cap (their own limit binds first). Applies to tunnel registrations and the hub-local catalog alike.

## [0.5.7] - 2026-08-29

### Added

- **Model honesty audit and per-alias blocking** — the hub records the model each upstream actually self-reports (`observed_model`) alongside the producer's declared `upstream_model`, classifies every response as exact, compatible, mismatch, or insufficient evidence per alias/protocol/declaration, and shows `OBSERVED MODEL` in `hub status`, `producer list` and `consumer list` (insufficient evidence renders as `?`). Operators can block or restore a specific alias with the new admin endpoints and `offering block`/`restore` CLI subcommands.
- **Optional auto-block on model mismatch** — `ModelWatch` warns on consecutive mismatches and, when `AWESHARE_AUTO_BLOCK_MODEL_MISMATCH=true`, auto-blocks the offering after repeated mismatches on successful responses (manual blocks take precedence; admin restores reset the strike window). Report-only by default.

### Changed

- **`hub status` defaults to a compact summary** — the live capacity and offering-health summary is shown by default; the full producer/consumer rosters require `--all`. The 5-minute health line now reads from the aggregated usage summary endpoint so it stays accurate.
- **Stricter doctor model probes** — `producer doctor` probes each distinct configured model instead of a single request, and the model-consistency audit only counts successful responses toward auto-block strikes.

### Added

- **Adaptive backend recovery probes** — degraded backends now use a health ladder keyed to time spent degraded, with bounded probe caps that escalate as an outage continues instead of repeatedly probing at one fixed cadence.
- **HTTP(S) proxy support for Codex account login** — account-login backends honor the standard proxy environment variables for the fixed ChatGPT upstream, while keeping proxy URLs out of logs and rejecting unsupported SOCKS proxies.

### Changed

- **More realistic hub-local health checks** — hub-hosted offerings probe with a real model request, so health status reflects the configured upstream path instead of relying on a synthetic request that some backends reject.

### Fixed

- **Codex Responses compatibility** — account-login forwarding removes `max_output_tokens` when present, avoiding a request rejection from the ChatGPT Codex backend.

## [0.5.5] - 2026-08-28

### Added

- **Codex account-login sharing: `login = "codex"`** — a backend can authenticate with the producer machine's own `codex login` instead of a key, sharing a chatgpt subscription through the fixed official upstream `https://chatgpt.com/backend-api/codex` (responses wire; any other protocol or baseUrl is rejected at catalog load, and `producer doctor` skips its `/v1` suffix check for that URL, so account credentials can only ever reach the official upstream). The login is read from `${CODEX_HOME|~/.codex}/auth.json`, lives in producer memory only, and is re-read whenever the file changes or a request comes back 401 — a fresh `codex login` on the producer machine is picked up without a restart; no `secrets.json` entry exists for it. The producer injects the headers the Codex CLI itself sends, forces `store: false` on every request (the chatgpt backend requires it; consumer tools don't always send it), and sends login-safe probe payloads so health checks don't 400/403 against the account backend. The hub never sees the credential.

- **`protocolLabel` in the consumer catalog API and CLI tables** — `openai` and `responses` offerings now carry a display label (`openai-chat` vs `openai-responses`) in the hub's consumer-facing JSON and render with it in `consumer list`, `producer list` and `hub status`, so a consumer can tell which of their tools will work: chat-completions clients vs Codex-CLI-style responses clients. Both wire protocols dial the hub with the same OpenAI SDK env vars; the label names the endpoint family they answer on.

### Changed

- **Hub CLI: `hub list` is gone** (breaking) — the read views it carried moved to where they belong: `hub status` is now the full live state — capacity, producer and consumer rosters, offering health — with roster columns matching `consumer list` / `producer list`, and the invite ledger lives on `hub invite --list` (`--reveal`/`--token` apply there; mint output now points at the new recovery command). Suspend/restore/limits keep their `--id` workflow, with ids now found via `hub invite --list`.

- **The hub strips edge/CDN headers before relaying upstream** — `cf-*`, `x-forwarded-*`, `cdn-loop`, `true-client-ip`, `x-real-ip` and similar ingress headers are dropped, so upstreams see the request as coming from the producer instead of learning the hub's ingress path.

### Fixed

- **Usage metering missed bare-SSE upstreams** — the chatgpt codex backend streams `text/event-stream` payloads without the SSE content-type; the extractor assumed one JSON body and token counts came back empty. When the content-type is missing, the first bytes are now sniffed (`event:`/`data:` prefixes vs a JSON body) before deciding how to parse.

## [0.5.1] - 2026-08-26

### Added

- **Identity expiry: `--expires-in` bounds the minted identity, not just the code** — redeem copies the invite's expiry onto the identity it mints (schema v12; identities minted before the upgrade keep NULL and never expire). An expired key fails auth with 401 `TOKEN_EXPIRED`, an expired producer's tunnel is rejected at WS upgrade and closed on its next heartbeat, and `hub list` shows the redeemed invite as `expired`. `hub invite --expires-in none` mints a code and identity that never expire. Suspension still outranks expiry in the list, and `restore` never revives an expired identity — extend by minting a new invite. This changes the meaning of the CLI default: a plain `hub invite` now yields a 7-day trial end to end.

- **`aweshare hub status` capacity view** — offerings are counted per deduplicated alias (one alias, several protocols → one verdict, the worst status) instead of per registration row, and a per-alias table lists protocols, live occupancy (`IN USE n/max`) and today's remaining daily tokens, worst status first. A `last 5m` line (requests, ok-rate, errors) aggregates the existing usage summary — hub-admission 429s are never metered, so it reflects relayed outcomes only. Occupancy columns show `-` against older hubs.

- **Layered rate limiting on the invite-redeem entry** — every attempt now consumes a small per-origin-IP bucket (`AWESHARE_INVITE_REDEEM_PER_IP_MIN`, default 5, from `CF-Connecting-IP` behind a tunnel/proxy, hot-reloadable) so one hostile visitor can no longer monopolize admission for everyone; the existing `AWESHARE_INVITE_REDEEM_PER_MIN` becomes the global insurance budget, spent only by valid-format codes (distributed JSON garbage burns its own per-IP buckets and never the shared budget). The limiter's key map also sweeps abandoned origins past a sane bound.

- **Unexpected hub errors no longer leak internals** — a request body that parses to `null`/an array/a scalar is a stable 400 `INVALID_JSON` instead of a 500 carrying `Cannot read properties of null …`, and any non-HttpError failure answers a generic `500 INTERNAL "internal error (details in the hub logs)"` with the real error kept to the structured server log.

- **CLIs name Cloudflare edge blocks for what they are** — a 403 answered with an HTML page (a WAF rule in front of the hub, e.g. on `/admin` paths) now reports "blocked by a proxy/WAF in front of the hub" instead of a bare `403 Forbidden`, on both producer and consumer clients.

- **Reconnect jitter** — the producer tunnel's exponential backoff now spreads each delay ±25%, so many agents reconnecting after a hub restart don't stampede it in lockstep.

## [0.5.0] - 2026-08-25

### Added

- **`aweshare producer list --all`** — a producer can now see the whole hub's catalog, not just its own slice: the admin offerings route accepts `?all=true` for producer tokens and the listing renders an extra `PRODUCER` column when the flag is on — the same discovery view `consumer list` gives, minus what only consumers care about. Older hubs ignore the flag.

- **Producer online state: `ONLINE` column in hub listings** — `aweshare hub list producers` (and the admin tokens API behind it) now reports each producer's tunnel liveness, so a stale roster entry is distinguishable from a live one. The built-in `hub` producer counts as online whenever it carries offerings.

### Changed

- **`aweshare consumer list` hides offline offerings by default** — an offline producer's aliases can't be called, so they were noise when picking a model; they are now hidden unless `--all` is passed (degraded offerings stay listed — the producer is up, the upstream is briefly failing). When every offering is offline the table is replaced by a one-line hint suggesting `--all`; `--json` follows the same filtering.

### Fixed

- **A crash mid schema upgrade no longer bricks the hub** — SQLite migrations now run inside a single transaction: a power loss or kill during an upgrade rolls back to the previous `user_version` and the ladder re-runs cleanly on the next open, instead of leaving half-applied schema blocks (duplicate column, leftover temp table) that fail every later startup.
- **The detached producer daemon survives crashing requests** — a bug inside a request job now logs an error and settles the job instead of raising an unhandled rejection that killed the whole background producer; the backpressure wait loop also exits once the tunnel socket is dead instead of sleeping forever, and the pidfile liveness check anchors on the trailing `start` argument so a recycled pid can never SIGKILL an unrelated `aweshare` command.
- **Hub and producer fail loudly where they used to fail quietly** — hub bind errors surface at `listen` (a taken port no longer looks like a silent no-op start), `--host` values are validated from env and config, `--since` windows get range checks, `config edit` reports an unlaunchable `$EDITOR` as a clean message, and `producer config show` redacts single-quoted `token = '…'` lines just like the double-quoted form (`producer init --hub/--token` now escape TOML special characters instead of writing a broken config).
- **`hub usage summary` rows sorted arbitrarily when token counts were missing** — the "busiest first" `ORDER BY` used bare column names inside an arithmetic expression, which SQLite resolves to the raw `usage_events` columns instead of the aggregated sums; combined with the one-`MAX()` bare-column rule and tied timestamps, the sort key could come from a NULL-token row and silently flip the row order. The `ORDER BY` now spells out the SUM aggregates.
- **Stricter upstream and wire validation** — backend `baseUrl`s are validated at catalog load (malformed URLs fail into the request as an error instead of crashing the producer), connect-phase upstream timeouts are classified `BACKEND_TIMEOUT`, and the protocol rejects oversized binary chunk frames on the receiving side. `self-update` pins its npm install to the version it verified.

## [0.4.9] - 2026-08-25

### Added

- **AI-agent setup guide (`README.ai.md`)** — a bootstrap protocol for AI coding agents (Claude Code, Codex, …): the agent installs the CLI, asks whether you are a hub operator, producer or consumer, and does everything safe to automate — editing configs, minting invites, running `producer doctor`. Steps that print one-time tokens (`hub init`, `consumer join`) or start long-running services (`hub serve`, `producer start`, Docker) stay in your terminal. Both READMEs now carry a "Let an AI agent set it up" section pointing agents at the doc.

### Changed

- **Hub-hosted models moved to `config.produce.toml`** (breaking for `hub produce` operators) — the hub's runtime config and its local model catalog are now separate files: `[[backends]]`/`[[offerings]]` sections (producer format, alias namespace `hub/…`) live in a new `config.produce.toml` in the data dir, and `config.toml` is exclusively hub runtime settings — it now rejects `backends`/`offerings` as unknown keys, so an operator with catalog sections in the old file must move them or the hub fails startup validation naming the key. `hub produce init` creates the produce config template and an empty `secrets.json` (never replacing either); hot-reload and the 2s stat-poll watch the new file; `secrets.json` is unchanged.

- **Docker image publishes linux/amd64 only** — the release workflow drops the QEMU-emulated arm64 half of the multi-arch image (the slowest part of every release); arm64 hosts can still run the amd64 image under emulation.

- Community-hub docs: consumer invites can be redeemed with one `curl` against `/invites/v1/redeem` (no Node needed on that machine), and day-to-day provider switching via [aweswitch](https://github.com/Webioinfo01/aweswitch) profiles is now recommended (EN + 中文).

## [0.4.8] - 2026-08-25

### Added

- **`aweshare hub produce init`** — bootstraps hub-hosted models in one command: it creates the editable `config.toml` template (every catalog entry commented out, so the file is valid to start before editing) and an empty owner-only `secrets.json`, never replacing either existing file, and along the way initializes the data dir, pepper, admin token and DB schema. It reports which files were created vs kept and prints the one-time admin token, ending with the next steps (`add [[backends]] / [[offerings]], fill secrets.json, then run: aweshare hub produce`). Previously operators assembled these files by hand before the first `produce` run.

### Changed

- **`aweshare hub usage` / `aweshare producer usage` now answer "who used how much" by default** — the aggregated summary replaces the per-request log as the default view, one row per consumer × model (`--group-by consumer-alias`, the default) so a person's rows stay together, busiest person and busiest model first; `--group-by consumer` rolls up to per-person totals, `--group-by alias` to per-model totals. The window defaults to 7 days (previously `--since` was required on summaries) and is printed with the table header; `--since all` covers everything. The old per-request view moves behind `--details` — its `--limit` flag follows it there — while `--consumer`/`--alias` filters work in both views. The bare `summary` positional is gone: passing it fails with a hint pointing at `--details`.

## [0.4.7] - 2026-08-25

### Added

- **Usage visibility for producers and hub operators: `aweshare producer usage [summary]` and `hub usage summary`** — producers could not see who consumes their models, and the hub's usage view was a flat newest-first log that cannot answer "who used the most". The producer-side command shows the request log scoped to its own models (rows name the consumer) plus a server-side aggregate per consumer or per alias; `aweshare hub usage summary --since 7d` aggregates consumption per producer × consumer (default) or per alias — requests, errors, rate, best-effort token totals, unknown-token count, mean duration, busiest first (`--since` is required: aggregates need an explicit window). New `GET /admin/v1/usage/summary` carries the same role slices as the detail log (admin everything, producer/consumer their own); usage rows now join consumer/producer names, the detail view gains `--producer` and per-consumer filtering for producer keys, and token counts the upstream never reported render as UNK rows instead of zero.

### Fixed

- **`aweshare hub status` crashed with `input.offerings.filter is not a function`** — broken since the command was introduced: the CLI parsed `GET /admin/v1/offerings` as a bare array, but the endpoint wraps its rows (`{object: "offerings", offerings: [...]}`). The CLI now unwraps; covered by a new e2e test that runs the real CLI dist against a live hub.

## [0.4.6] - 2026-08-25

### Fixed

- **Docker image crashed at startup (`ERR_MODULE_NOT_FOUND: Cannot find package 'aweshare-protocol'`)** — the v0.4.5 image omitted `packages/producer-core/node_modules`, so the bare `aweshare-protocol` import in `producer-core/dist/catalog.js` (loaded at startup by the new hub-local producer) could not resolve from its own path; the container crash-looped. The image now ships the pnpm symlink dir. npm installs were unaffected — the published tarball inlines that import to a relative path.
- **`docker-compose.yml` published `8787:8787` on all interfaces** — plaintext hub on a public VPS. Now binds `127.0.0.1:8787:8787`, matching the README's TLS-fronting guidance; change it back only on trusted networks.

### Changed

- **Release gate: images are smoke-tested before push** — `release.yml` now builds the image, boots it, and requires `GET /healthz` to answer before anything reaches ghcr (this exact bug would have been caught at the gate). Both build steps also share a persistent GHA layer cache, so routine releases with an unchanged lockfile skip most of the (QEMU-heavy) rebuild.

## [0.4.5] - 2026-08-25

### Added

- **Live channel occupancy: `IN USE` column in `aweshare consumer list` and `producer list`** — both listings now show, per alias, how many distinct consumers have a request in flight right now, against the cap (`n/max`, e.g. `2/3`; an alias at `max/max` turns a new consumer away with 429 `PRODUCER_MAX_USERS`, so pick one below its cap when a channel is busy). `GET /v1/catalog` and `GET /admin/v1/offerings` report the same snapshot as `activeUsers` plus `activeRequests` (total in-flight requests, diagnosis signal); `--json` carries both. The number is a snapshot at list time, not a reservation — it can change between listing and calling. Older hubs don't report the fields; the column shows `-` (like `PER USER` on pre-v0.4.3 hubs). No wire-protocol change.

- **Hub-hosted models: `aweshare hub produce`** — the hub can now attach models itself, no producer machine needed. `[[backends]]` and `[[offerings]]` sections in the hub's own `config.toml` (same format as a producer's config; alias namespace `hub/…`, bare names auto-prefixed) register under the built-in producer `hub`, with upstream keys in `secrets.json` next to the config. Consumer requests to `hub/*` offerings are served by the hub process directly — in-process upstream fetch, no tunnel and no self-dial; the response streams straight back over the consumer's HTTP connection. Everything guardrail-side applies unchanged: per-offering caps, daily tokens, consumer limits, usage metering (`producer_id = 0`), catalog status with AUTH/QUOTA auto-degrade and 30s recovery probes. The built-in producer is not an identity (empty token hash), carries no invite, and never counts against `AWESHARE_MAX_PRODUCERS`; the name `hub` is reserved for it, and it appears in `hub list producers` — status `built-in` — only while it carries offerings. `produce` is an explicit entry point over the same runner as `serve` (the catalog is config-driven either way); catalog and key edits hot-reload via the existing 2s stat-poll, and a broken catalog fails startup or keeps the previous values on reload. Internally the producer runtime (upstream fetch/stream, adapter conventions, health gate, catalog validation) moved into a shared `aweshare-producer-core` package used by both the agent and the hub — agent behavior is unchanged.

## [0.4.4] - 2026-08-25

### Added

- **`aweshare producer list [--json]` and `GET /admin/v1/offerings`** — producers can finally see what the hub actually carries under their name: alias, protocol, live status, per-offering caps and today's token use, plus the local background instance state and drift against `config.toml` (a configured alias the hub rejected — e.g. alias taken — is named instead of dying in producer.log). The endpoint follows the `/admin/v1/usage` slice semantics: admin sees every producer's registrations, a producer key only its own. `producer doctor`'s hub check now also reports `N/M offering(s) registered` and the missing aliases.
- **Multi-protocol offerings** — one alias can now speak several wire protocols at once: registrations are keyed by `(alias, protocol)` (schema v11 migrates the offerings table), consumers route to the row matching the protocol they called with, and bare aliases are auto-prefixed with the producer namespace on register. A new `backends = [...]` list on an offering expands into one registration per backend (backends sharing a protocol are rejected); agent and consumer tables merge multi-protocol aliases into a single row (protocols joined with `, `, differing values with `/`).

## [0.4.3] - 2026-08-24

### Changed

- **`aweshare hub invite` now defaults `--expires-in` to 7d** — an unexpiring one-time secret was the silent default before; codes now live 7 days unless the operator spells another duration (`90s/30m/12h/7d`). The admin REST API is unchanged: omitting `expiresAt` there still mints a code with no expiry, for operators who deliberately want one.

- **`aweshare consumer list` now shows both per-offering concurrency caps** — the `USERS` column is renamed `MAX USERS` (still `maxConcurrentUsers`, the distinct-consumer cap) and a new `PER USER` column shows `maxConcurrencyPerUser` (concurrent requests per consumer; `-` on pre-v0.4.3 hubs that don't report it). `--json` already included both fields.

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

# aweshare update: Share Your ChatGPT Subscription — `login = "codex"`

![aweshare](../../logo/logo.png)

Most Codex users hold a ChatGPT Plus/Pro subscription, and the Codex quota inside it is generous — and idle most of the time. Lending it to a friend used to be a non-starter, because there is no key to hand over: the Codex CLI authenticates with your ChatGPT account login, not an API key. aweshare could only share key-based backends, so subscriptions stayed out of reach.

This update closes that gap: a backend can declare `login = "codex"` and authenticate with your machine's own `codex login`, turning your ChatGPT subscription's Codex capability into a shareable offering.

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

## Producers: List Your Subscription in Two Lines

```toml
[[backends]]
id = "codex-account"
protocol = "responses"
baseUrl = "https://chatgpt.com/backend-api/codex"   # official upstream only
login = "codex"                                     # account auth instead of a key; exclusive with keyRef

[[offerings]]
alias = "gpt-5.6-codex"    # namespaced automatically on register
backend = "codex-account"
```

Nothing goes into `secrets.json` — account login and key are mutually exclusive. The credential is read from `${CODEX_HOME|~/.codex}/auth.json` and lives only in the producer process's memory. Run `codex login` again on the producer machine and the running producer picks it up automatically (the file is re-read on change or on a 401) — no restart.

A few boundaries are hard-coded so the account credential cannot end up somewhere it shouldn't:

- **The upstream is pinned to the official endpoint.** `baseUrl` must be `https://chatgpt.com/backend-api/codex`; any other protocol or URL is rejected at catalog load — the credential can only ever reach ChatGPT's official backend.
- **The hub never sees the credential.** Requests are still dialed by the program on your machine; the hub only ever sees forwarded traffic.
- **The fiddly bits are handled.** The producer injects the native headers the Codex CLI itself sends, forces `store: false` (the chatgpt backend requires it; consumer tools don't always send it), and uses login-safe probe payloads so health checks don't throw 400/403 at the account backend.

One honest caveat: an account login is an **account-wide** credential — it unlocks every subscription under that login, not one scoped key — so sharing it carries a higher risk of account suspension than sharing an API key. `aweshare producer doctor` repeats this warning; the decision and its consequences sit with the producer.

## Consumers: Not Just Codex

Once listed, the offering shows `openai-responses` in the PROTOCOL column — it speaks the Responses wire protocol, answered on `/v1/responses`.

Don't scroll past "responses" just yet: **the Codex CLI is not the only client that can use it.** Agents like OpenCode and ZCode also support responses-type endpoints, and wiring them up is nearly identical to wiring OpenAI — swap the provider's SDK (the `npm` field in OpenCode) to `@ai-sdk/openai`, keep the URL in the OpenAI style, and put the catalog alias in the model field.

Codex CLI (`~/.codex/config.toml`):

```toml
model = "alice/gpt-5.6-codex"
model_provider = "aweshare"

[model_providers.aweshare]
name = "aweshare"
base_url = "https://your-hub.example/v1"
wire_api = "responses"
env_key = "AWESHARE_API_KEY"
```

OpenCode (`opencode.json`) — note only `npm` changes; `baseURL` stays the OpenAI-style URL:

```json
{
  "provider": {
    "aweshare": {
      "npm": "@ai-sdk/openai",
      "options": {
        "baseURL": "https://your-hub.example/v1",
        "apiKey": "asc_..."
      },
      "models": {
        "alice/gpt-5.6-codex": {}
      }
    }
  }
}
```

ZCode works the same way: pick the OpenAI Responses provider type (backed by the same `@ai-sdk/openai` SDK) and point `baseURL` at the hub's OpenAI-style address.

The other side of the coin: chat-completions tools and Claude Code cannot use this kind of offering — that's protocol fact, not a limitation to be fixed. A glance at the PROTOCOL column in `consumer list` tells you whether your tool will connect:

```text
PRODUCER  ALIAS               OBSERVED MODEL  PROTOCOL          STATUS  MAX USERS  IN USE  PER USER  DAILY TOKENS  REMAINING
alice     alice/gpt-5.6-codex gpt-5.6-codex   openai-responses  online  2          0/2     1         1000000       986412
```

The guardrails apply as usual: concurrent users, per-user concurrency and the daily token budget for this alias are enforced by the hub exactly as they are for key-based offerings, and usage is metered the same way.

## Cheat Sheet

| You want to | Do |
|---|---|
| Share your ChatGPT subscription | Write `login = "codex"` on the backend, no keyRef |
| Re-login with a different account | Run `codex login` again on the producer machine; the producer picks it up |
| Be sure the credential goes nowhere else | baseUrl is pinned to the official upstream; misconfiguration is rejected at load |
| Connect from the Codex CLI | `wire_api = "responses"`, base_url pointed at the hub |
| Connect from OpenCode / ZCode | Swap `npm` to `@ai-sdk/openai`, baseURL stays the OpenAI-style URL |
| Tell if your tool will work | Read the `PROTOCOL` column in `consumer list` |

One-line summary: what could be shared used to be "keys" (API keys) — now subscriptions can be shared too. The credential never leaves the producer's machine, and consumers call the subscription like any ordinary model, from whatever agent they prefer.

## Try It

### Let the agent install it

In Claude Code, Codex, or any coding agent, say:

```text
Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare.
```

### Or do it yourself

```bash
npm install -g aweshare   # existing users: just upgrade

# Producer: with `codex login` already done, two lines of config list the subscription
aweshare producer config edit   # add the login = "codex" backend and its offering
aweshare producer doctor        # check registration (repeats the account-sharing warning)

# Consumer: look for a responses-type subscription offering in the catalog
aweshare consumer list --hub https://your-hub.example --token asc_...
```

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
- **[awewarm](https://github.com/wehuman01/awewarm)** — subscription-window keeper that keeps AI coding-plan windows active, whether configured locally or through a remotely connected server

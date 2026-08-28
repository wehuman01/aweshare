# aweshare Dev Note: I Hid My Hub Behind a Cloudflare Tunnel

![aweshare](../../logo/logo.png)

An aweshare Hub on a VPS can look perfectly fine at first.

Requests relay. Producers are online. Models answer.

But if port `8787` is sitting on the public internet, the origin IP is easy to discover, and the machine providing models still has to worry about inbound WebSocket connectivity, the setup has not really settled into place.

So I did the obvious thing: I put `aweshare.wehuman.top` behind Cloudflare Tunnel.

The Hub below listens on `8787` — the project's documented default, so the number itself is no secret. Keep the port consistent in the Tunnel route and container configuration; the actual security boundary is whether the port is reachable from the internet, not whether the number is known.

The Hub no longer publishes an application port to the internet. `cloudflared` dials out from the server; consumers and producer machines see only the Cloudflare edge.

```
Consumer / producer agent
    → https://aweshare.wehuman.top
    → Cloudflare edge (TLS terminates here)
    → Cloudflare Tunnel (outbound connection from cloudflared)
    → Docker network aweshare-hub_default
    → aweshare-hub:8787
```

Nothing dramatic in that diagram.

But it lets each layer do one job. The Hub routes requests. The producer keeps upstream keys on its own machine. Docker networking stays internal. Cloudflare owns the public entry point, TLS, and the first line of protection.

GitHub: [github.com/wehuman01/aweshare](https://github.com/wehuman01/aweshare)

According to the deployment record, on 2026-08-20 I ran `curl https://aweshare.wehuman.top/healthz` from two networks and got 200 both times. DNS returned Cloudflare edge IPs, not the origin.

That is a record of what worked that day, not a promise that it is still true today. If you build this yourself, check the Tunnel, Compose network, WAF policy, and image version again.

The Hub itself stays simple. Consumers use `/v1/messages`, `/v1/chat/completions`, `/v1/responses`, and `/v1/models`. Producers dial back through `/ws/v1/producer`. Management lives under `/admin/v1/*`. `/healthz` now includes `{ok, version, wire}`, which is handy when you need to know exactly which Hub you reached.

The interesting part came after deployment: three small traps.

## 1. `HEALTHY` does not mean the request gets through

The tunnel route in this setup is `http://aweshare-hub:8787`, which relies on Docker's container-name DNS. That is fine—until the two containers are not on the same user-defined network. At that point, `aweshare-hub` is just a hopeful string.

There is another reassuring green signal: `HEALTHY` in the Zero Trust dashboard. It says that `cloudflared` can reach Cloudflare. It does not say that cloudflared can resolve and reach the Hub.

So do not guess. Run this:

```bash
curl https://aweshare.wehuman.top/healthz
```

Only then has the request actually made it from the user to the Hub.

## 2. A WebSocket 502 is not always a Tunnel failure

The first time I probed `/ws/v1/producer` with a WebSocket that had no token, I got a 502.

That looks like a bad tunnel route, right? Not necessarily.

For an upgrade without a token, the Hub writes a 401 and closes the socket immediately. The 401 may not finish flushing before cloudflared sees the close, and cloudflared can surface that as a 502. The probe is ugly; the valid-token producer path is not necessarily broken.

The most honest end-to-end test is not another synthetic probe. It is connecting a real producer:

```bash
aweshare producer join --hub https://aweshare.wehuman.top --code asi_...
aweshare producer doctor
aweshare producer start
```

If you do test an upgrade with curl, add `--http1.1`. Otherwise ALPN can select HTTP/2, `Connection: Upgrade` disappears, the request becomes an ordinary GET, and you are left debugging a 404 that never mattered.

## 3. Hiding the door is not the same as locking it

Cloudflare Tunnel solves the exposed-entry-point problem. It does not decide who gets in.

An `asi_...` producer invite can be redeemed only once, but until then it is a bearer credential: whoever gets it first can use it. It is not a harmless activation code to drop into a group chat or a log.

And port `8787` is not truly private until nothing publishes it on a public interface. The compose default is already loopback-only (`127.0.0.1:8787:8787`); with a Tunnel, you can drop the `ports:` mapping entirely and recreate the container — cloudflared reaches the Hub over the Docker network. After that, consumers still use the SDK settings they already know:

```bash
# Claude Code / Anthropic SDK
export ANTHROPIC_BASE_URL="https://aweshare.wehuman.top"
export ANTHROPIC_AUTH_TOKEN="<consumer token>"

# Codex / OpenAI SDK
export OPENAI_BASE_URL="https://aweshare.wehuman.top/v1"
export OPENAI_API_KEY="<consumer token>"
```

Do not put Cloudflare Access over the entire hostname either. SDK clients and producer agents cannot complete an interactive browser login. Even if Access covers only `/admin/v1/*`, remote CLI administration needs a machine identity or a carefully scoped exception; an aweshare admin token does not automatically pass Access.

The rest is infrastructure doing its job quietly. Producers send a heartbeat every 15 seconds and reconnect with jittered exponential backoff. A Hub restart or a brief Tunnel interruption normally does not need human rescue.

One practical limit remains: Cloudflare's default proxy read timeout is currently 125 seconds. Start streaming early, then test the behavior against your own plan and edge settings.

| You say | you run |
|---|---|
| "Did it actually get through?" | `curl https://aweshare.wehuman.top/healthz` |
| "Onboard this machine as a producer." | `aweshare producer join --hub https://aweshare.wehuman.top --code asi_...` |
| "Is my producer wiring healthy?" | `aweshare producer doctor` |
| "Keep the relay running." | `aweshare producer start` |
| "Point Claude Code / Codex at the hub." | the `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL` exports above |

One-line summary: the Tunnel did not add another complicated layer to aweshare — it simply handed the public-entry problem to the layer built for it, so the Hub keeps routing, the producer keeps the keys, and each part keeps doing its own work.

## Try It

### Let the agent install it

If you're in Claude Code, Codex, or any other coding agent, tell it:

```text
Read https://github.com/wehuman01/aweshare/blob/main/README.ai.md and follow it to install and configure aweshare.
```

### Or hide your own hub behind a tunnel

Everything above compresses into four moves:

```bash
# 1) On the VPS, run the Hub without publishing a port (no `ports:` in Compose)
docker compose up -d                          # image: ghcr.io/wehuman01/aweshare
docker exec aweshare-hub aweshare hub init    # prints the one-time admin token

# 2) In Zero Trust, route your hostname to http://aweshare-hub:8787,
#    with cloudflared attached to the same Compose network as the Hub

# 3) Mint invites; producers onboard over the hostname, not a raw IP
aweshare hub invite --role consumer --name alice

# 4) Verify from outside; DNS should show Cloudflare edge IPs
curl https://your-hub.example.com/healthz
```

Then remember the three traps: green is not through, a 502 is not always the Tunnel, and hiding the door is not locking it.

## More from mugpeng

aweshare is part of the aweteam ecosystem:

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager supporting 47+ AI coding agents
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — agent config switcher for Claude Code, Codex, and OpenCode
- **[awerouter](https://github.com/mugpeng/awerouter)** — smart router that uses structural signals to route requests to Flash or Pro models, reducing unnecessary model costs
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — save, organize, and restore AI coding sessions; pair it with aweswitch to save configurations and launch with one click
- **[aweshare](https://github.com/wehuman01/aweshare)** — share local Ollama/vLLM or authorized OpenAI/Anthropic backends through a self-hosted Hub, enabling a shared token economy
- **[awewarm](https://github.com/wehuman01/awewarm)** — subscription-window keeper that keeps AI coding-plan windows active, whether configured locally or through a remotely connected server

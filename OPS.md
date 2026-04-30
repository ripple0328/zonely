# Zonely Ops

`../mini-infra` is the golden path for production operations. Keep this repo focused on app code and delegate deployment/service control through the local `Justfile`.

Daily commands:

```sh
just status
just health
just logs
just tail
```

Change commands:

```sh
just deploy
just migrate
just restart
just rollback
just install
```

Runtime env file on Mini:

```sh
~/.config/zonely/env.runtime
```

Expected production values include `DATABASE_URL=postgresql://zonely:...@127.0.0.1:5432/zonely_prod`, `SECRET_KEY_BASE`, `PHX_HOST=zonely.qingbo.us`, `PORT=4020`, and optionally `PRONUNCIATION_API_KEY` for production pronunciation API access.

The local `Justfile` intentionally sends `PORT=4020` to `../mini-infra` by
default and ignores any ambient development `PORT`. Override the production
operation port with `ZONELY_PROD_PORT` only when intentionally changing the
service port.

Optional observability values:

```sh
SCOUT_MONITOR=true
SCOUT_NAME=zonely-prod
SCOUT_KEY=<agent-key>
SCOUT_CORE_AGENT_TRIPLE=aarch64-apple-darwin
POSTHOG_ENABLED=true
POSTHOG_API_KEY=<project-api-key>
POSTHOG_HOST=https://us.i.posthog.com
```

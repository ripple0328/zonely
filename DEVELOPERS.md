# Zonely Developer Guide

Zonely is a Phoenix/LiveView app for distributed team coordination. Keep product work anchored to [the mission](docs/mission.md): time zones, work-hour overlap, location context, holidays, and team availability.

Pronunciation support is deliberately decoupled from implementation: Zonely profile buttons call the production pronunciation API and do not implement providers, local audio cache, or a standalone pronunciation app.

## Local Setup

```sh
mise trust
mise install
mix deps.get
mix assets.setup
mix db.up
mix ecto.setup
just dev
```

Open [zonely.localhost](http://zonely.localhost:1355).

`just dev` is the golden path for the local web server. It starts Phoenix through
Portless:

```sh
PORTLESS_STATE_DIR=/tmp/personal-portless-http PORTLESS_HTTPS=0 PORTLESS_PORT=1355 APP_DISPLAY_NAME=Zonely portless zonely ./scripts/dev_with_tidewave_banner.sh
```

Portless assigns Phoenix a free local port through `PORT` and exposes the app at
the stable browser URL `http://zonely.localhost:1355`. The no-TLS Portless
state is shared with sibling Phoenix apps at `/tmp/personal-portless-http`, so
multiple app routes can coexist behind one local HTTP proxy. The Phoenix dev
endpoint still defaults to `http://localhost:4000` when started directly with
`mix phx.server`. The Phoenix local HTTP port is intentionally unregistered
because Portless owns the browser-facing URL.

`just dev` also opens Tidewave.app when needed and prints the working Tidewave
URLs. Tidewave Web uses Phoenix's assigned app URL as `origin`: the same
`.localhost` host plus the current random `PORT`. The Portless URL is for normal
browser access; the direct app URL is what Tidewave Web uses to connect. The raw
`/tidewave/mcp` endpoint is for MCP clients only and uses JSON-RPC over POST.

Keep Postgres, Redis, MailHog SMTP, and other non-HTTP local services on
registered Docker Compose ports. Zonely's local Postgres host port is `5434`;
`POSTGRES_PORT` is committed in `.mise.toml` and defaults to `5434` in Phoenix
dev/test config.

## Configuration

Local tool versions and local-only secrets are managed by mise.

Committed:

```sh
.mise.toml
```

Local-only and gitignored:

```sh
.mise.local.toml
```

Start from the checked-in example:

```sh
cp .mise.local.toml.example .mise.local.toml
```

Required local development secrets go in `.mise.local.toml`:

```sh
MAPTILER_API_KEY=...
```

Optional:

```sh
PRONUNCIATION_API_KEY=...
```

`PRONUNCIATION_API_KEY` is used only against the production SayMyName API at `https://saymyname.qingbo.us`.
It authenticates pronunciation playback plus reusable name-card/name-list share creation:

- `GET /api/v1/pronounce`
- `POST /api/v1/name-card-shares`
- `GET /api/v1/name-card-shares/:token`
- `POST /api/v1/name-list-shares`
- `GET /api/v1/name-list-shares/:token`

Zonely owns teams, users, permissions, timezone/location context, and profile UI. SayMyName owns pronunciation providers, audio caching, pronunciation generation, and immutable share snapshot storage.

Do not use `.envrc` or `.env` for new local secrets.

## Tests And Checks

```sh
mix test
mix precommit
```

`mix precommit` is the handoff gate. Browser automation was removed with the stale route specs; add a new end-to-end harness only when the product surface needs it again.

## Stitch MCP

This repo includes a project-scoped MCP server in `.mcp.json`.
It authenticates with Google Application Default Credentials through `dev/stitch-mcp`.
The current quota project is `gen-lang-client-0280380712`, exported as `STITCH_QUOTA_PROJECT` in `.mcp.json`.

```sh
npx -y @modelcontextprotocol/inspector --cli --config .mcp.json --server stitch --method tools/list
npx -y @modelcontextprotocol/inspector --cli --config .mcp.json --server stitch --method tools/call --tool-name list_projects
```

Use [design.md](design.md) as the prompt source when generating Zonely screens in Stitch. The Stitch MCP points at the official remote endpoint through `mcp-remote`; do not add local npm asset setup for this Phoenix app.

## Core Modules

- `Zonely.Accounts` manages teammate profiles.
- `Zonely.WorkingHours` calculates availability and overlap signals.
- `Zonely.Holidays` provides holiday context.
- `Zonely.Audio` converts profile pronunciation clicks into playback events.
- `Zonely.PronunciationClient` is the production API boundary for pronunciation.
- `ZonelyWeb.HomeLive` renders the fullscreen map workspace, team orbit, and selected teammate sheet.

## Deployment

Use the local `Justfile`, which delegates to `../mini-infra/platform/Justfile`:

```sh
just status
just health
just deploy
```

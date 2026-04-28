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
mix phx.server
```

Open [localhost:4000](http://localhost:4000).

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

`PRONUNCIATION_API_KEY` is used only against the production pronunciation API at `https://saymyname.qingbo.us`.

Do not use `.envrc` or `.env` for new local secrets.

## Tests And Checks

```sh
mix test
mix precommit
```

`mix precommit` is the handoff gate. Browser automation was removed with the stale route specs; add a new end-to-end harness only when the product surface needs it again.

## Core Modules

- `Zonely.Accounts` manages teammate profiles.
- `Zonely.WorkingHours` calculates availability and overlap signals.
- `Zonely.Holidays` provides holiday context.
- `Zonely.Audio` converts profile pronunciation clicks into playback events.
- `Zonely.PronunciationClient` is the production API boundary for pronunciation.
- `ZonelyWeb.HomeLive` renders the map-first home page and directory page.

## Deployment

Use the local `Justfile`, which delegates to `../mini-infra/platform/Justfile`:

```sh
just status
just health
just deploy
```

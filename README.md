# Zonely

Zonely helps distributed teams understand where teammates are, when work hours overlap, and which local context matters before reaching out.

The canonical mission, product boundaries, and roadmap live in [docs/mission.md](docs/mission.md). The Stitch-ready product design direction lives in [design.md](design.md). The current stack recommendation lives in [docs/tech-stack-review.md](docs/tech-stack-review.md). In short: Zonely is a team coordination app, not a pronunciation product. Pronunciation is profile context only and always calls the production pronunciation API at `https://saymyname.qingbo.us`.

Live: [zonely.qingbo.us](https://zonely.qingbo.us)

## Current Surface

- Fullscreen team map with local work-hour, daylight, timezone, and location context
- Map-native team orbit for scanning teammates without leaving the geographic surface
- Reachability preview rail for simulating the next 24 hours, with one Reset to now action that restores live map, marker, orbit, context-strip, and selected-sheet state
- Selected teammate decision sheet with effective local time, work window, timezone offset, daylight, reachability guidance, and next transition context
- Optional profile pronunciation playback through the production pronunciation API

## Architecture

| Layer | Technology |
|---|---|
| Web | Phoenix 1.8, LiveView, Tailwind CSS |
| Data | PostgreSQL, Ecto |
| HTTP client | Req |
| Deployment | Mac Mini launchd flow via `../mini-infra` |

Pronunciation boundary:

- `Zonely.Audio` builds playback events for profile buttons.
- `Zonely.PronunciationClient` calls only `https://saymyname.qingbo.us/api/v1/pronounce`.
- `Zonely.NameProfileContract` converts Zonely users into the SayMyName portable profile contract using canonical `lang`/`text` variants.
- `Zonely.SayMyNameShareClient` creates reusable production name-card and name-list shares through `https://saymyname.qingbo.us/api/v1/name-card-shares` and `https://saymyname.qingbo.us/api/v1/name-list-shares`.
- `PRONUNCIATION_API_KEY` is required for authenticated production SayMyName API access.

Zonely does not own pronunciation providers, pronunciation caches, or SayMyName snapshot storage. It only renders team/profile context and sends portable share payloads to production SayMyName.

## Development

See [DEVELOPERS.md](DEVELOPERS.md) for the local workflow.

```sh
mise trust
mise install
cp .mise.local.toml.example .mise.local.toml
mix deps.get
mix db.up
mix ecto.setup
just dev
```

The golden-path dev server runs through Portless so the browser URL stays stable:
`https://zonely.localhost`. Phoenix still supports direct startup with
`mix phx.server`, defaulting to `http://localhost:4000` unless `PORT` is set.
Local Postgres runs on host port `5434`, registered in `../mini-infra` to avoid
colliding with sibling apps.

Run checks before handing off changes:

```sh
MIX_ENV=test mix test
mix precommit
```

## Operations

Production operations are delegated to `../mini-infra/platform/Justfile`. See [OPS.md](OPS.md) for the production defaults and runtime env path.

```sh
just status
just health
just deploy
just logs
just tail
just restart
just rollback
just migrate
```

Production runtime env lives at:

```sh
~/.config/zonely/env.runtime
```

# Zonely Mission: Foundational Availability Primitives

You are working in `/Users/qingbo/Projects/Personal/zonely`, a Phoenix 1.8 /
LiveView app. Use Factory/Droid mission mode to do careful, incremental,
well-tested foundation work. This is an overnight mission, so optimize for
small composable capabilities that can be reviewed and built on tomorrow, not a
large end-to-end scheduling system.

## Canonical Product Mission

Read these first, in this order:

- `AGENTS.md`
- `docs/mission.md`
- `docs/foundational-capabilities.md`
- `docs/shared-profile-contract.md`
- `README.md`
- `DEVELOPERS.md`

Zonely's durable foundation is a composable availability and reachability
engine. The fullscreen map is the current primary UI projection, but this
mission should build low-level primitives that can later power APIs, map
markers, preview rails, selected teammate sheets, Slack/calendar integrations,
and import/export flows.

Do not turn this mission into a dashboard, meeting scheduler, calendar product,
or visual redesign.

## Mission Goal

Implement the first bottom-up foundational slice from
`docs/foundational-capabilities.md`: **small independently useful availability
primitives that compose into future reachability APIs**.

The priority order is:

1. Public holiday primitive and read-only JSON API.
2. Local-time primitive and read-only JSON API.
3. Availability evidence normalization.
4. Work-window evaluation as a pure module, only if the first three are solid.

Each primitive should be useful on its own. For example, public holiday lookup
must not depend on people, teams, LiveView state, reachability, or map code.
High-level reachability may later depend on public holidays, but not the other
way around.

## Scope

### In Scope

- Add focused modules for low-level capabilities, such as:
  - `Zonely.Calendar.PublicHolidays`
  - `Zonely.LocalTime`
  - `Zonely.Availability.Evidence`
  - `Zonely.Schedules` only if time remains
- Add read-only JSON API endpoints for the first primitives:
  - `GET /api/v1/countries/:country/holidays?year=2026`
  - `GET /api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30T16:00:00Z`
- Return structured JSON with versions, normalized inputs, evidence-ready
  fields, and explicit missing-data behavior.
- Reuse existing persisted holiday data through `Zonely.Holidays`; do not
  silently fetch external APIs from public read endpoints.
- Use `Req` only if you need HTTP in an internal sync/helper path. The read-only
  API endpoints should not depend on outbound network calls.
- Add focused tests for pure modules and JSON endpoints.
- Update docs if the implemented API shape differs from the current
  `docs/foundational-capabilities.md` candidate shape.

### Out Of Scope

- Full team reachability API.
- Meeting scheduling, booking, calendar UI, or automatic meeting proposals.
- Slack/calendar/presence integrations.
- Personal leave persistence or database schema unless absolutely required.
- Regional holiday persistence unless the current schema already supports it.
  The current `holidays` table has `country`, `date`, and `name`; prefer
  country-level V1 with explicit `region_supported: false`.
- Map, LiveView, CSS, selected panel, or preview rail changes.
- Pronunciation or SayMyName feature expansion.
- New dependencies unless a small dependency is clearly justified and covered
  by docs/tests. Prefer existing Elixir/Phoenix APIs and current dependencies.

## Existing Code Context

Useful starting points:

- `lib/zonely/holidays.ex` has DB-backed holiday listing and a Nager.Date fetch
  helper.
- `lib/zonely/holidays/holiday.ex` is the holiday schema.
- `priv/repo/migrations/20250816000002_create_holidays.exs` defines the current
  holiday table.
- `priv/repo/seeds.exs` seeds sample country-level holidays.
- `lib/zonely/reachability.ex` currently mixes core decisions with display
  labels and copy; do not expand that coupling in this mission.
- `lib/zonely/working_hours.ex` has existing work-hour helpers, including some
  simplified overlap/meeting-time stubs. Do not build on those stubs for a
  public scheduling API without first replacing them with deterministic
  primitives.
- `lib/zonely_web/router.ex` currently has browser and health routes only. Add
  a small `:api` pipeline if you expose JSON endpoints.

The existing `test/zonely/holidays_test.exs` is skipped. Do not simply add more
skipped tests. Prefer new focused tests that pass, using `Zonely.DataCase` or
pure module tests as appropriate.

## Recommended API Shapes

### Public Holidays

Endpoint:

```http
GET /api/v1/countries/JP/holidays?year=2026
```

Response:

```json
{
  "version": "zonely.holidays.v1",
  "country": "JP",
  "year": 2026,
  "region": null,
  "region_supported": false,
  "source": "zonely_holidays_table",
  "data_status": "available",
  "holidays": [
    {
      "date": "2026-05-04",
      "name": "Greenery Day",
      "scope": "national",
      "impact": "blocks_scheduling",
      "evidence_type": "public_holiday"
    }
  ]
}
```

If no rows exist, return `200` with an empty list and `data_status:
"no_local_data"` rather than inventing holidays or fetching silently.

Candidate module API:

```elixir
Zonely.Calendar.PublicHolidays.list(country, year)
Zonely.Calendar.PublicHolidays.evidence(country, date)
Zonely.Calendar.PublicHolidays.to_api(country, year)
```

Expected behavior:

- Normalize country to uppercase.
- Validate country as a two-letter ISO code, using existing app helpers when
  practical.
- Validate year as an integer in a reasonable range.
- Sort by date.
- Return date strings in ISO 8601 for JSON.
- Return evidence maps that can later compose into availability decisions.

### Local Time

Endpoint:

```http
GET /api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30T16:00:00Z
```

Response:

```json
{
  "version": "zonely.local_time.v1",
  "timezone": "Asia/Tokyo",
  "effective_at": "2026-04-30T16:00:00Z",
  "local_date": "2026-05-01",
  "local_time": "01:00:00",
  "utc_offset": "UTC+09:00",
  "evidence": {
    "type": "local_time",
    "impact": "informational",
    "confidence": "high",
    "source": "iana_timezone_database"
  }
}
```

Candidate module API:

```elixir
Zonely.LocalTime.evaluate(timezone, effective_at)
```

Expected behavior:

- Require IANA timezone names; do not accept fixed offsets as equivalent to
  timezone identity.
- Parse `at` as an ISO 8601 UTC DateTime. If `at` is absent, using current UTC
  is acceptable for the HTTP endpoint, but pure module tests should pass an
  explicit timestamp.
- Return clear `400` errors for invalid timezone or timestamp input.
- Keep formatting deterministic.

### Evidence Normalization

Candidate module API:

```elixir
Zonely.Availability.Evidence.new(attrs)
Zonely.Availability.Evidence.normalize(signal)
Zonely.Availability.Evidence.merge(list)
```

Keep this small. It can be a struct or a documented map shape, but it should
standardize these fields:

- `type`
- `impact`
- `source`
- `confidence`
- `label`
- `starts_at` / `ends_at` or `observed_on` when relevant
- `metadata`

Do not overbuild a rules engine. The goal is to make public holidays, local
time, work windows, leave, preferences, and future presence signals speak one
common evidence vocabulary.

### Work Window Evaluation

Only do this after the public holiday, local-time, and evidence pieces pass.

Candidate module API:

```elixir
Zonely.Schedules.evaluate(schedule, effective_at, timezone)
```

Expected output should be evidence-first:

- `:inside_work_window`
- `:near_work_boundary`
- `:outside_work_window`
- `:non_working_day`

Keep it pure and deterministic. Avoid touching the existing map UI. If this
requires a large refactor of `Zonely.WorkingHours`, stop and document the
recommended next step instead.

## Implementation Guidance

- Start by writing or updating tests for the smallest primitive you are about
  to implement.
- Keep modules narrow and named around domain capabilities, not UI features.
- Prefer returning `{:ok, data}` / `{:error, reason}` from module functions that
  parse or validate user input.
- Avoid exceptions for control flow.
- Do not use `String.to_atom/1` on request params or external input.
- Use pattern matching and guards where it keeps code clear.
- Use Phoenix controller JSON responses for HTTP APIs; do not create LiveViews
  for this mission.
- Keep API response versions explicit, such as `zonely.holidays.v1`.
- Keep error responses stable enough for clients and tests:

```json
{
  "error": {
    "code": "invalid_timezone",
    "message": "timezone must be an IANA timezone name"
  }
}
```

## Validation Requirements

Run targeted checks as you build, then finish with:

```sh
mise exec -- mix precommit
```

Minimum test coverage expected:

- Public holiday module:
  - country normalization
  - year filtering
  - empty local data behavior
  - evidence map shape
- Public holiday endpoint:
  - valid request returns versioned JSON
  - invalid country/year returns `400`
- Local-time module:
  - known timezone conversion, including date rollover
  - UTC offset formatting
  - invalid timezone handling
- Local-time endpoint:
  - valid request returns versioned JSON
  - invalid timestamp/timezone returns `400`
- Evidence normalization:
  - known signal shapes normalize consistently
  - unknown or invalid signals return a controlled error or ignored result,
    not a crash

If local Postgres is not running, use the repo docs to start it rather than
skipping DB-backed tests:

```sh
mix db.up
mix ecto.setup
```

Use `mise` for environment loading when appropriate.

## Stop Conditions

Stop and report instead of broadening scope if:

- You need a schema migration for regional holidays, personal leave, or
  preferences.
- You need auth or write endpoints for holiday syncing.
- You are tempted to implement full meeting suggestions or final team
  reachability.
- The API route shape gets blocked by Phoenix routing details for timezone
  paths; use the query-param `GET /api/v1/local-time?timezone=...` shape.
- You find existing tests are skipped or brittle. Add new passing focused tests
  and document the old test issue instead of increasing skip coverage.

## Delivery Report

Final report should include:

- Short summary of primitives implemented.
- API endpoints and example responses.
- Files changed.
- Test commands and results.
- Any intentionally deferred work, especially region support, personal leave
  persistence, preferences, or full reachability composition.

Do not push. Do not revert unrelated edits. If the repo is dirty when you
start, inspect the diff and preserve unrelated user or agent changes.

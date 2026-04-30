# Foundational Capabilities

Zonely's durable foundation is not the map UI. The foundation is a set of
composable capabilities for answering distributed-team coordination questions:
who can be reached, who can be scheduled, when a better window opens, and what
local context explains that answer.

The map, preview rail, selected teammate sheet, API responses, future Slack or
calendar surfaces, and import/export flows should all compose these same
capabilities instead of inventing separate availability logic.

## Core Principles

- Keep core modules UI-independent. They should return structured facts,
  decisions, reason codes, evidence, scores, and timestamps; CSS classes,
  LiveView labels, and prose copy belong in projection/explanation modules.
- Pass an explicit `effective_at` timestamp into foundational calculations.
  Avoid hidden clock calls inside core reachability, overlap, and scheduling
  functions so live mode, preview mode, tests, and APIs stay deterministic.
- Model availability as composable evidence, not as one larger `work_hours`
  field. Public holidays, personal leave, calendar busy blocks, preferences,
  daylight, and timezone context should be separate signals with explicit
  impacts.
- Keep precedence explicit. A personal leave block should outrank a normal work
  window; a public holiday should usually block scheduling but may still allow
  async reachability guidance; personal preferences should rank otherwise valid
  windows rather than overwrite facts.
- Accept both persisted Zonely records and imported shared-profile payloads.
  Foundational APIs should work for database-backed teams, previews, imports,
  exports, tests, and future integrations.
- Preserve the shared profile vocabulary from
  `docs/shared-profile-contract.md`: `person`, `profile`, `name_variant`,
  `team`, `membership`, `location`, and `availability`.
- Treat integrations as evidence providers. Calendar, presence, Slack, HR/PTO,
  or holiday services should refine reachability and scheduling decisions
  without becoming separate product surfaces.
- Build bottom-up through independently useful primitives. A country public
  holiday lookup, a timezone local-time conversion, or a work-window evaluator
  should be useful on its own and later compose into higher-level reachability
  and scheduling APIs.

## Incremental Capability Ladder

The foundation should be built piece by piece. Each lower layer should expose a
small, testable, publicly useful capability before higher layers depend on it.

1. Reference data primitives: countries, regions, timezones, public holidays,
   local weekend norms, and daylight/local-time facts.
2. Personal data primitives: work windows, working days, leave blocks, travel,
   focus blocks, calendar busy blocks, and meeting preferences.
3. Evidence primitives: normalize each fact into a consistent evidence record
   with `type`, `impact`, `source`, `confidence`, and effective dates.
4. Person evaluation: reduce evidence for one person at one `effective_at`
   timestamp into reachability and schedulability decisions.
5. Group evaluation: combine person decisions at one timestamp for a team or
   selected group.
6. Window search: scan a bounded range and rank candidate overlap windows.
7. Timeline evaluation: produce snapshots for preview rails, APIs, and future
   integrations.
8. UI/API projections: map markers, GeoJSON, LiveView assigns, JSON responses,
   accessible copy, and share/export payloads.

The dependency direction should stay one-way: high-level reachability may depend
on public holidays, but the public holiday API must not depend on reachability,
profiles, LiveView state, or map code.

## Capability Map

### Profiles And Teams

Own the canonical contact and group vocabulary.

- Normalize `person`, `profile`, `name_variant`, `team`, and `membership`.
- Import/export the shared profile shape.
- Keep a clear projection to JSContact and vCard.
- Preserve unknown shared fields where practical.

### Locations

Own geographic facts and projections.

- Validate and normalize country, region, place label, latitude, longitude, and
  IANA timezone.
- Resolve country and regional labels used by availability explanations.
- Project people or teams to GeoJSON for map surfaces.

### Schedules

Own normal working expectations.

- Represent working days, local work windows, and optional team-level defaults.
- Support personal work-hour preferences such as preferred meeting windows,
  avoid-before/avoid-after times, focus blocks, and async-first preference.
- Keep schedule rules timezone-aware and local-date aware.

### Calendar Exceptions

Own exceptions to the normal schedule.

- Regional public holidays by country and region.
- Company holidays, shutdown weeks, and team no-meeting days.
- Personal leave, sick days, travel, out-of-office, and explicit calendar busy
  blocks.
- Each exception should carry an impact such as `blocks_scheduling`,
  `discourages_reachability`, `busy`, or `informational`.

### Context Signals

Compute local context for one person at one timestamp.

Useful signals include:

- Local date and local time.
- UTC offset and timezone.
- Work-window state.
- Daylight state.
- Regional holiday state.
- Company/team exception state.
- Personal leave or busy state.
- Personal preference match.
- Next meaningful transition.
- Confidence and freshness of the data behind each signal.

### Reachability

Answer whether it is reasonable to reach someone at an effective time.

Reachability should reduce context signals into a structured decision:

- `state`: `reachable`, `ask_carefully`, or `wait`.
- `score`: numeric ordering for comparisons and sorting.
- `confidence`: `high`, `medium`, or `low`.
- `reason_codes`: stable machine-readable explanation keys.
- `evidence`: the signals that caused the decision.
- `next_better_time`: the next useful transition when applicable.

### Overlap And Window Search

Answer when a selected group has a respectful shared window.

This capability should search a bounded range and return candidate windows, not
become a meeting scheduler or booking workflow. A candidate window should
include participants, start/end timestamps, local-time projections, fairness or
burden notes, blockers, and reason codes.

### Timeline Evaluation

Evaluate reachability over a bounded horizon.

The preview rail, future API consumers, and scheduling suggestions should share
the same timeline capability. The input is a group, a range, a step size, and a
policy; the output is a list of deterministic snapshots.

### Explanations

Turn reason codes and evidence into human-facing text.

This layer may produce short UI labels, detailed sentences, accessible text, or
API-friendly explanations. It should not decide reachability.

### Projections And APIs

Expose the same foundation through different shapes.

- Shared profile JSON for Zonely and SayMyName.
- vCard or JSContact export/import.
- GeoJSON for maps.
- JSON APIs for reachability, overlap, and timeline evaluation.
- LiveView assigns and hook payloads.

## Atomic API Candidates

Prefer small APIs that are valuable before the full scheduling engine exists.
These can be internal module APIs first and HTTP APIs later.

### Country And Regional Public Holidays

Public holidays are a good early primitive because they are broadly useful and
have low dependency on people, teams, maps, or UI state.

```http
GET /api/v1/countries/JP/holidays?year=2026&region=optional-region
```

```json
{
  "version": "zonely.holidays.v1",
  "country": "JP",
  "region": null,
  "region_supported": false,
  "year": 2026,
  "data_status": "available",
  "holidays": [
    {
      "date": "2026-05-04",
      "name": "Greenery Day",
      "observed": true,
      "scope": "national",
      "impact": "blocks_scheduling",
      "source": "public_holiday_calendar",
      "evidence_type": "public_holiday"
    }
  ]
}
```

Candidate module API:

```elixir
Zonely.Calendar.PublicHolidays.list(country, year)
Zonely.Calendar.PublicHolidays.evidence(country, date)
```

### Timezone And Local Time

Local-time conversion is another independent primitive. It should accept an
IANA timezone and explicit timestamp, then return local date, local time, UTC
offset, and transition context.

```http
GET /api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30T16:00:00Z
```

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
    "source": "iana_timezone_database",
    "confidence": "high",
    "label": "Local time in Asia/Tokyo",
    "observed_on": "2026-05-01",
    "metadata": {
      "timezone": "Asia/Tokyo",
      "effective_at": "2026-04-30T16:00:00Z",
      "local_date": "2026-05-01",
      "local_time": "01:00:00",
      "utc_offset": "UTC+09:00"
    }
  }
}
```

Candidate module API:

```elixir
Zonely.LocalTime.evaluate(timezone, effective_at)
```

### Work Window Evaluation

This evaluates a schedule without knowing anything about a team or map.

```elixir
Zonely.Schedules.evaluate(schedule, effective_at, timezone)
```

It should return evidence such as `:inside_work_window`,
`:near_work_boundary`, `:outside_work_window`, or
`:non_working_day`.

### Calendar Exceptions

This normalizes personal leave, team shutdowns, company holidays, and busy
blocks into the same evidence shape used by public holidays.

```elixir
Zonely.Calendar.Exceptions.evidence(person_or_team, effective_at, sources)
```

### Preference Evaluation

This ranks valid windows without turning preferences into hard facts.

```elixir
Zonely.Preferences.evaluate(preferences, effective_at, timezone)
```

Examples include preferred meeting hours, avoid-before/avoid-after settings,
focus blocks, async-first preference, and fairness rotation.

### Evidence Normalization

Every upstream signal should be convertable into a common shape.

```elixir
Zonely.Availability.Evidence.normalize(signal)
Zonely.Availability.Evidence.merge(evidence)
```

This is the bridge that lets public holidays, leave plans, work windows,
preferences, daylight, and presence compose predictably.

## Availability Evidence

Availability decisions should be built from evidence records. A future shape
could look like this:

```elixir
%{
  type: :public_holiday,
  scope: :regional,
  impact: :blocks_scheduling,
  label: "Golden Week",
  source: :holiday_calendar,
  confidence: :high,
  observed_on: ~D[2026-05-04]
}
```

Common evidence types:

- `:local_time`
- `:work_window`
- `:weekend_or_non_working_day`
- `:public_holiday`
- `:company_holiday`
- `:team_no_meeting_window`
- `:personal_leave`
- `:calendar_busy`
- `:travel`
- `:preferred_meeting_window`
- `:focus_block`
- `:daylight`
- `:presence`
- `:data_missing`
- `:data_stale`

## Precedence Model

The reducer should apply signals in a predictable order.

1. Explicit personal leave, sick leave, or out-of-office blocks scheduling and
   usually pushes reachability to `wait`.
2. Calendar busy blocks scheduling for the busy interval, but may still allow
   urgent or async reachability depending on policy.
3. Public holidays, company holidays, shutdowns, and local non-working days
   usually block scheduling and discourage reachability.
4. Normal work windows and working days define the default reachable baseline.
5. Personal preferences rank otherwise valid windows up or down.
6. Daylight, local night, edge-of-day, and timezone burden explain the human
   cost of a window.
7. Missing or stale data lowers confidence instead of inventing defaults.

## API Shape

Foundational APIs should be independently composable and should not require the
current LiveView surface.

Example person evaluation:

```json
{
  "version": "zonely.availability.v1",
  "effective_at": "2026-04-30T16:00:00Z",
  "person_id": "p_123",
  "decision": {
    "reachability": "wait",
    "schedulability": "not_schedulable",
    "score": 0.12,
    "confidence": "high",
    "reason_codes": ["public_holiday", "outside_preferred_hours", "local_night"],
    "next_better_time": "2026-05-01T00:00:00Z"
  },
  "evidence": [
    {
      "type": "public_holiday",
      "impact": "blocks_scheduling",
      "label": "Golden Week"
    },
    {
      "type": "local_time",
      "value": "01:00",
      "timezone": "Asia/Tokyo"
    }
  ]
}
```

Example capability entrypoints:

```elixir
Zonely.Availability.evaluate_person(person, effective_at, sources, policy)
Zonely.Availability.evaluate_group(people, effective_at, sources, policy)
Zonely.Overlap.find_windows(people, time_range, sources, policy)
Zonely.Timeline.evaluate(people, time_range, step, sources, policy)
Zonely.Explanations.explain(decision, audience)
```

## Implementation Direction

- Keep `Zonely.Reachability` focused on pure decision data.
- Move display labels, CSS class names, and prose sentences toward explanation
  or projection modules over time.
- Replace simplified overlap and meeting-time helpers with a real overlap
  capability before adding meeting suggestions.
- Add public holiday, company exception, personal leave, and preference support
  as evidence providers instead of special-casing each one directly in UI code.
- Keep tests centered on deterministic inputs and stable reason codes, then
  separately test UI projections.

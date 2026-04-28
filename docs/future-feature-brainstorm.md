# Future Feature Brainstorm

This brainstorm is grounded in `docs/mission.md` and `design.md`. Zonely should keep answering one map-first coordination question: who can I reasonably reach, and what local context should I know before I do?

## Priority 1: Strengthen Reachability Decisions

These ideas deepen the current map workspace without changing product shape.

- **Small-group teammate comparison:** compare two or three selected teammates at the same live or previewed time, capped at three and operated through visible touch/keyboard controls.
- **Regional exception signals:** show holidays or local exceptions as quiet context on markers, orbit rows, and decision sheets once data is dependable.
- **Next respectful action copy:** refine deterministic guidance for "message now," "ask carefully," and "wait until" across work-hour boundaries and date rollover.
- **Map-native timezone context:** add compact timezone hover/click details that explain local time and offset without leaving the map.

## Priority 2: Improve Map Scanning

These features help users understand the team spatially while preserving the fullscreen map as the primary surface.

- **Timezone clustering:** group dense marker areas by timezone or region at low zoom, then reveal individual teammates as the user zooms.
- **Meaningful time-rail moments:** snap the preview rail to now, next overlap, workday start, workday end, sunrise, and sunset when those moments are relevant.
- **Quiet team filters:** let users temporarily focus by region, availability state, or role through compact map controls, not a list-first dashboard.
- **Personal map memory:** remember a user's last map position, zoom, and rail preference per browser session without changing shared team data.

## Priority 3: Operational Team Context

These ideas can add utility after the reachability model is trusted.

- **Handoff windows:** show where the next handoff window opens between regions, expressed as map and rail context rather than a calendar event.
- **Country context snippets:** surface concise country or locale notes that affect reachability, such as public holidays or local weekend norms.
- **Directory as secondary scan:** keep `/directory` for denser searching and grouping, with compact rows that link back to map context.
- **Narrow presence integrations:** if added later, Slack or calendar signals should only refine availability decisions and must not become a scheduler or inbox.

## Explicit Non-Goals

- No dashboard home, metric-card grid, productivity analytics, or generic status board.
- No meeting scheduler, booking flow, calendar replacement, or automatic meeting proposal engine.
- No pronunciation-product expansion; pronunciation remains a small profile aid backed by the production API.
- No Directory-first replacement for the home map and no team-card list below the map.
- No broad Slack/calendar integration scope until core reachability, holiday, and overlap signals are reliable.
- No visual-system reset, neon/purple AI styling, decorative blobs, or marketing hero surface.

## Sequencing Notes

1. Ship small-group comparison first because it directly extends the current selected-teammate and preview-rail model.
2. Add regional/holiday context only when the data can be deterministic, testable, and explained in teammate-local terms.
3. Improve map scanning before adding external integrations so future signals have a stable cartographic home.
4. Treat integrations as supporting evidence for reachability, never as a new scheduler or communications product.

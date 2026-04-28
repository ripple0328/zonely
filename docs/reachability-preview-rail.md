# Reachability Preview Rail Design Note

This note is the implementation gate for the reachability preview rail. It is intentionally limited to product, interaction, and validation decisions; product code changes should happen after this note exists.

## Current Surface Read

- `ZonelyWeb.HomeLive` owns the `/` map workspace, current reachability summary, team orbit, static `#map-time-rail`, selected teammate panel, and map payload JSON.
- `assets/js/hooks/team_map.js` owns MapLibre and marker DOM inside `#map-container[phx-update="ignore"]`, so marker status changes need an explicit hook event rather than relying on replaced `data-users`.
- `Zonely.Reachability` already accepts an optional `DateTime` in core helpers; preview work should thread one effective timestamp through every surface.
- `assets/css/app.css` already defines the map-first instrument glass language, availability marker rings, mobile bottom-sheet positioning, and compact bottom rail.
- Existing tests cover HomeLive map rendering, teammate selection, pronunciation/share boundaries, and deterministic reachability labels.

## User Journey

1. A teammate lands on `/` and sees the live map first: markers, Now strip, team orbit, and compact rail all describe current reachability.
2. They scan markers or orbit rows to understand who is reachable, near a boundary, or off-hours without leaving the map.
3. They move the preview rail to a future moment within the next day to answer "what changes if I wait?"
4. The rail, Now/Preview strip, marker rings, orbit rows, and selected teammate sheet all switch to the same simulated effective time.
5. If the simulated time is not useful, one Reset to now action returns every surface to live semantics.
6. If a teammate is selected, the decision sheet explains the local time, work window, daylight, offset, reachability state, and next meaningful transition for the effective time.

## Interaction States

### Live State

- `preview_at` is absent; the effective time is live now.
- The strip is labeled as Now, not simulated.
- `#map-time-rail-status` communicates the current time window and live reachability.
- `#map-time-rail-reset` is absent from the accessibility tree.
- Marker rings, orbit status dots, local-time text, and selected-sheet copy are all live-derived.

### Preview State

- `preview_at` is present and normalized on the server to UTC.
- The strip and rail explicitly use preview/simulated language in text or accessible descriptions, never color alone.
- The rail stays bounded to approximately now through +24 hours; malformed or out-of-range inputs are rejected or clamped without crashing.
- Reset to now appears once and clears the preview.
- Marker updates are pushed to the TeamMap hook as structured state: teammate ID, status, selected state, and effective timestamp.

### Selected Teammate State

- Selection remains a map-native decision sheet, not a centered modal or pronunciation workflow.
- Desktop keeps the compact panel near map context and avoids hiding the selected marker when feasible.
- The sheet prioritizes reachability decision content over profile metadata: name, role, place, local time, work window, timezone offset, daylight, next transition, and human guidance.
- Pronunciation remains a small secondary profile aid near identity.
- Preview/reset preserves the selected teammate unless the user closes or selects another teammate.

### Mobile State

- The rail remains touch-sized and bottom anchored without horizontal page overflow.
- The selected teammate panel behaves as a bottom sheet with map context visible above it.
- Targets for rail, reset, close, and primary marker/orbit interactions are at least 44px.
- Pointer/touch interaction on the rail must not accidentally pan the map or create page scroll traps.

## Map-First Visual Hierarchy

- The map remains the primary object in every state; the rail is a compact instrument overlay, not a dashboard.
- Navigation, Now/Preview strip, orbit, rail, and selected sheet stay as floating islands with one job each.
- Marker availability is encoded through ring/status color using existing Available Green, Edge Ochre, and Quiet Slate roles.
- Live Meridian is reserved for active/selected/focus states and reset/primary affordances.
- Motion should be restrained and limited to transform/opacity; no new heavy animation dependency is needed.
- Avoid metric-card rows, marketing hero copy, team-card lists below the map, nested cards, purple/neon gradients, or decorative blobs.

## Accessibility Decisions

- Required stable topology: `#map-time-rail`, `#map-time-rail-control`, `#map-time-rail-status`, `#map-time-rail-ticks`, and `#map-time-rail-reset` only when previewing.
- The rail control should expose an accessible name, current value, finite min/max range, and keyboard adjustment with standard keys.
- Preview mode must be communicated in visible copy and accessible text, not by color or ring position alone.
- Tick/end labels should describe the bounded time range and be associated with the control through visible labels or ARIA description.
- Reset must be a real button with a clear accessible name and must restore live semantics across all surfaces.
- Selected sheet close controls need stable labels, and mobile layout must avoid horizontal overflow.

## Non-Goals

- No product code is implemented in this design-note feature.
- No database schema changes.
- No new dependencies, frontend framework, scheduler, calendar, Slack, or holiday API integration.
- No Directory route work except future regression fixes directly caused by the rail mission.
- No pronunciation provider, cache, share, or standalone pronunciation expansion.
- No replacement of MapLibre, the visual system, or the map-first home layout.

## Validation Checklist

- File review confirms this note exists at `docs/reachability-preview-rail.md` before implementation code changes.
- Live mode renders map-first with Now strip, markers, orbit, and rail visible without dashboard/card-grid regressions.
- Preview interaction sets server-owned `preview_at`, applies bounded timestamp parsing, and labels simulated state clearly.
- Reset appears only while previewing and restores rail, strip, markers, orbit, and selected sheet to live-now context.
- Reachability, local times, daylight, next transitions, marker state, orbit rows, strip copy, and sheet copy share one effective timestamp.
- TeamMap marker rings update through explicit structured hook payloads despite `phx-update="ignore"` and without map reinitialization.
- Rail keyboard, pointer, and touch interactions are usable and do not disrupt the map.
- Desktop and mobile screenshots show preserved map visibility, compact instrument overlays, and no horizontal overflow.
- Targeted domain/LiveView/hook tests plus `mix precommit` pass for later implementation features.

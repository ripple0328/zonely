# Zonely Mission: Reachability Preview Rail and Decision Sheet

You are working in `/Users/qingbo/Projects/Personal/zonely`, a Phoenix 1.8 / LiveView app. Use Factory/Droid mission mode to do high-quality, design-first work. This is not a speed run. Spend real time on the user journey, interaction quality, visual fit, accessibility, and validation before broadening the feature.

## Canonical Product Mission

Read these first and keep every decision grounded in them:

- `AGENTS.md`
- `docs/mission.md`
- `design.md`
- `README.md`
- `DEVELOPERS.md`

Zonely answers one practical question: "who can I reasonably reach right now?" The product should feel like a calm, precise, map-first geographic instrument for distributed teams. Do not turn it into a SaaS dashboard, generic directory, meeting scheduler, pronunciation product, or marketing landing page.

## Recommended Feature

Implement the next sensible V1 feature: **Reachability Preview Rail + Selected Teammate Decision Sheet**.

The existing home map already has a map, teammate markers, reachability states, a team orbit, selected profile panel, daylight/timezone overlays, and a bottom `map-time-rail`, but the rail is mostly static. Make the rail meaningful and use it to answer the next user question after "who can I reach now?":

- If someone is reachable, how long is that likely to remain true?
- If someone is not reachable, when is the next reasonable time?
- If I preview a future moment, which teammates become reachable, near boundary, or off hours?

This must be designed as one coherent map interaction, not as a pile of cards or controls.

## UX Principles

Design first, then implement. The final UI should preserve the map as the primary object.

Required feel:

- Cartographic, calm, precise, alive.
- Instrument glass overlays, not dashboard cards.
- Asymmetric floating controls over the map.
- Responsive, with mobile bottom-sheet behavior where appropriate.
- Tactile but restrained motion using transform/opacity.
- No hero/marketing copy, no metric-card rows, no nested cards, no decorative blobs/orbs, no purple/neon/AI gradient aesthetic.
- Use the existing Zonely palette from `design.md`: Polar Canvas, Instrument White, Charcoal Ink, Slate Signal, Live Meridian, Solar Amber only for daylight.

Primary journey to optimize:

1. User lands on the map and sees live "Now" reachability.
2. User notices a teammate is not reachable or near a boundary.
3. User drags/clicks the time rail to preview later today / next meaningful moment.
4. Marker rings, orbit rows, Now/Preview strip, and selected teammate sheet update together.
5. The UI clearly indicates when the user is previewing instead of viewing live now.
6. User can reset to Now in one obvious action.

## Scope

Implement a polished V1, not a full calendar or scheduler.

In scope:

- Replace the static `map-time-rail` labels/track with a functional preview control.
- Support a bounded preview window, preferably now through the next 24 hours or the current local day plus clear next-transition affordances.
- Add a server-side `preview_at` assign in `HomeLive` or equivalent, with reachability recomputed for that DateTime.
- Update marker JSON and map hook behavior so marker status rings update when preview time changes.
- Update team orbit rows so their status/local-time text reflects preview time.
- Update the selected teammate panel/card into a decision sheet: name/role/location, local time at selected time, work window, timezone offset, reachability label, human decision sentence, and next transition text.
- Keep pronunciation actions small and secondary. Do not expand pronunciation capabilities.
- Add a clear preview/live state label and a Reset to now control that appears only when previewing.
- Add useful next-transition calculations in domain code: e.g. "Workday ends in 1h 40m", "Starts at 09:00 local", or "Back tomorrow at 09:00 local".
- Use existing holiday data only if it can be integrated cleanly and locally. Do not fetch new holiday APIs. If holiday integration risks scope creep, document it as a follow-up.
- Maintain keyboard and touch accessibility: stable IDs, 44px touch targets, clear labels, focus states.

Out of scope:

- Full meeting-time scheduler.
- Calendar/Slack integrations.
- Directory route unless needed for regression fixes.
- iOS surface.
- Pronunciation provider/cache/share expansion.
- New visual system or brand reset.
- New frontend framework.
- Heavy animation libraries.
- Database schema changes unless absolutely required; prefer derived state from existing user fields.

## Technical Constraints

Follow Phoenix 1.8 and repo guidance in `AGENTS.md`:

- Use existing `<.icon>` and `<.input>` components when applicable.
- Use HEEx correctly; no raw `<script>` tags in templates.
- For JS interop, use `phx-hook` with unique DOM IDs, and `phx-update="ignore"` when JS owns DOM.
- Use `push_event/3` correctly when pushing events from server to hook.
- Consult package docs with `mix usage_rules.search_docs` / `mix usage_rules.docs` when uncertain.
- Use `Req` for HTTP if any HTTP is needed, but this feature should not need new HTTP.
- Avoid new dependencies unless there is a strong reason.

Likely code areas:

- `lib/zonely_web/live/home_live.ex`
- `lib/zonely/reachability.ex`
- `lib/zonely/working_hours.ex` or a new focused domain module if it keeps boundaries cleaner
- `lib/zonely_web/components/core_components.ex` for the profile/decision sheet if that is where the current profile card lives
- `assets/js/hooks/team_map.js`
- `assets/css/app.css`
- focused tests under `test/zonely/**` and `test/zonely_web/**`

Respect existing patterns. Keep units small and testable. Do not create tangled JS/LiveView loops.

## Design Process Requirement

Before editing code, inspect the existing UI structure and CSS. Write down the intended interaction model in a short repo-local design note, e.g. `docs/reachability-preview-rail.md`, covering:

- user journey
- interaction states: live now, previewing, selected teammate, mobile
- visual hierarchy
- accessibility decisions
- explicit non-goals
- validation checklist

Then implement against that design. Keep the note concise and useful, not bureaucratic.

## Quality Bar

This mission should be judged more on product quality than feature count.

Implementation quality expectations:

- No hardcoded fake rail labels like `06:12` / `18:47` unless they are computed from real state.
- No UI text overlap at desktop or mobile widths.
- No markers/panels fighting each other visually.
- No decorative extra cards below the map.
- No confusing live/preview ambiguity.
- No uncontrolled event spam while dragging. Debounce/throttle server updates if needed, and keep the interaction feeling responsive.
- Domain calculations should be deterministic and covered by tests, especially around timezone conversion and work-hour boundaries.

## Validation

Run and fix all relevant checks before finishing:

- Targeted domain tests for reachability/transition calculations.
- Targeted LiveView/component tests for key selectors and preview/selected states.
- `mix precommit` at the end, as required by `AGENTS.md`.

Also do browser-visible verification if local services can run:

- Start the app through the repo's golden path if practical (`just dev` or documented command).
- Check desktop around 1440x900 and mobile around 390x844.
- Capture screenshots or otherwise record clear visual evidence in the final report.
- Verify the time rail interaction, selected teammate sheet, reset-to-now control, and marker/orbit status updates.

If browser automation or the dev server cannot run, report exactly why and what validation still passed.

## Git / Delivery

- Work in the Zonely repo only.
- Do not push.
- Do not revert unrelated edits.
- The repo may be ahead of origin; preserve that.
- This prompt file was intentionally added by Codex so the mission is auditable. Keep it unless the user later asks to remove it.
- If you commit, make at most one focused local commit after `mix precommit` passes. If you leave changes uncommitted, report that clearly.
- Final report should include changed files, validation commands/results, screenshots or visual-verification notes, and any follow-up risks.

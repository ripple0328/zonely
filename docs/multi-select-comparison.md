# Multi-Select Comparison Design Note

This note is the implementation gate for the teammate multi-select follow-up. It is grounded in `docs/mission.md` and `design.md`: Zonely answers whether teammates are reasonably reachable through a map-first geographic surface, not a dashboard, scheduler, directory, or pronunciation product.

## V1 Product Intent

Multi-select should help a teammate compare a small group at the same live or previewed moment. The useful V1 question is: "Can these two or three people be reached respectfully now, or at the previewed time?"

- Cap V1 comparison at three selected teammates.
- One selected teammate keeps the existing decision sheet unchanged.
- Two or three selected teammates open a compact comparison panel over the map.
- The preview rail remains the time source: comparison uses `preview_at || live_now`.
- The map, markers, orbit rows, Now/Preview strip, and comparison panel must agree on the same effective timestamp.

## User Journey

1. The user lands on the map and scans teammates through markers or the orbit.
2. They select one teammate and see the existing single decision sheet.
3. From visible controls, they add a second teammate to compare without holding a modifier key.
4. They may add one more teammate; a fourth add is blocked with calm feedback such as "Compare up to three teammates."
5. They preview a later time with the rail; every selected teammate row updates local time, reachability, daylight, and work-window context.
6. Reset to now clears preview state but preserves the selected group.
7. The user can remove one teammate, focus a single teammate, or clear the group.

## Interaction Model

### Selection

- Primary selection remains click/tap/Enter on a marker or orbit row.
- Add-to-compare is an explicit button in map-native surfaces, for example "Add to compare" on orbit rows and selected-sheet actions.
- Modifier-click can be an enhancement, but it must never be required because touch and keyboard users need the full flow.
- Selected IDs are canonical as `selected_user_ids`; one ID renders single-select, two or three IDs render group comparison.

### Touch and Keyboard

- All add, remove, focus-one, and clear controls are real buttons with stable labels and at least 44px touch targets.
- Keyboard users can Tab to teammate actions, press Enter/Space to add or remove, and clear the group without shortcut chords.
- The comparison cap feedback should be visible and announced through accessible text, not color alone.
- Mobile uses the same visible controls; no long-press or multi-finger gesture is required.

### Preview and Reset

- Preview rail changes update group rows, selected marker state, orbit rows, and strip copy from the same effective timestamp.
- Reset to now keeps `selected_user_ids` intact while recomputing live local time, reachability, daylight, and next transition.
- Marker selected styling persists for every selected teammate across preview and reset without MapLibre reinitialization.

## Comparison Panel Content

The panel should stay compact and map-native:

- Header: "Comparing 2 teammates" or "Comparing 3 teammates" plus the live/preview effective time.
- Summary: one short deterministic sentence, for example "Lisbon and London overlap now; Tokyo starts later."
- Rows: name, city/country, local time, reachability state, work window, daylight label, and next transition.
- Controls: remove teammate, clear group, and focus one teammate to return to the single decision sheet.
- Pronunciation should be absent from V1 group rows, or remain a tiny secondary identity aid only if already available without new scope.

## Visual Hierarchy

- The map stays visually primary; comparison is a floating instrument panel on desktop and a bottom sheet on mobile.
- Avoid metric cards, chart tiles, equal card grids, team-card lists, dashboard summaries, or a scheduler layout.
- Use existing instrument glass, Hairline Frost borders, Live Meridian selected accents, and availability ring colors from `design.md`.
- Desktop panel should remain narrow enough to preserve marker context. Mobile bottom sheet should stay constrained with map visible above and no horizontal overflow.

## Non-Goals

- No meeting scheduler, calendar workflow, Slack integration, or booking proposal.
- No Directory route expansion or list-first scanning replacement for the home map.
- No pronunciation provider/cache/share expansion and no standalone pronunciation workflow.
- No analytics dashboard, productivity score, metric-card row, or generic status board.
- No database schema change unless a later implementation worker proves derived state is impossible.
- No new frontend framework, heavy animation dependency, or visual-system replacement.

## Validation Checklist

- Selecting one teammate still renders the existing decision sheet fields and secondary pronunciation controls.
- Selecting two or three teammates renders compact comparison mode; a fourth selection is capped with clear feedback.
- Users can enter, adjust, and exit comparison mode with touch and keyboard controls without modifier keys.
- Preview rail updates all selected teammate rows, selected markers, orbit rows, and Now/Preview strip from one effective timestamp.
- Reset to now preserves the selected group and restores live reachability context.
- Desktop and mobile layouts remain map-first with no dashboard/card-grid regressions or horizontal overflow.

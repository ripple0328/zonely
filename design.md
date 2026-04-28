# Zonely Design System for Stitch

This file is the design source of truth for rebuilding or extending Zonely screens in Google Stitch. Zonely should feel like a live geographic instrument for distributed teams, not a directory with a map attached.

## 1. Product Experience

Zonely helps a teammate answer one question quickly: "Is this a good moment, and what local context should I know before reaching out?"

The primary surface is a global map. The map owns the first impression, the main interaction model, and the emotional quality of the app. Team members appear where they are, daylight moves across the world, timezone regions respond to hover and selection, and the interface changes based on the viewer's local time, the selected teammate, and the team's overlap window.

The home page must not become a status dashboard. Do not place a team-name card list, availability list, or generic metric grid below the map. If a user needs a scannable people list, send them to a separate Directory surface.

## 2. Visual Theme and Atmosphere

Atmosphere: cartographic, calm, precise, and alive. It should feel closer to a mission room with daylight moving across the planet than a SaaS admin page.

Design settings for Stitch:

- Design variance: 8 of 10. Use asymmetric composition, anchored overlays, and off-center control clusters.
- Motion intensity: 6 of 10. Use fluid map-aware motion, animated daylight, pulsing live markers, and soft panel transitions.
- Visual density: 4 of 10. Keep the home map open and spatial. Reserve dense information for contextual panels and the Directory page.

Chosen visual archetype: Soft Structuralism with cartographic depth. Use a restrained light canvas by default, deep ink typography, one green-blue accent, and translucent overlays that look like instrument glass rather than decorative glassmorphism.

## 3. Color Palette and Roles

Use one consistent palette. Do not mix warm beige surfaces with cool slate surfaces. Do not use purple, neon blue, or generic AI gradients.

- **Polar Canvas** (#F7F8F6) - primary page background outside the map.
- **Map Mist** (#EEF2EF) - loading and low-detail map fallback.
- **Instrument White** (#FFFFFF) - panels, popovers, and sheet interiors.
- **Charcoal Ink** (#161A1D) - primary text. Never use pure black.
- **Slate Signal** (#5F6B73) - secondary text, helper labels, metadata.
- **Hairline Frost** (rgba(22, 26, 29, 0.10)) - borders, dividers, map panel outlines.
- **Live Meridian** (#1F8A70) - the single accent color for active states, selected teammates, focus rings, and primary action.
- **Solar Amber** (#D99A2B) - contextual sunlight color only. It is not a second brand accent and must be used sparingly for daylight labels and sunrise/sunset cues.
- **Night Veil** (rgba(15, 23, 42, 0.46)) - map night overlay.
- **Available Green** (#2E8F5B) - working-now status marker.
- **Edge Ochre** (#B9822E) - near-work-hours marker.
- **Quiet Slate** (#8B97A1) - off-hours marker.

Map styling should prioritize land, water, timezones, sunlight, and teammate locations. Avoid saturated basemap colors that compete with people markers.

## 4. Typography

Use a premium sans-serif pair. Inter, Roboto, Arial, Helvetica, and generic system-only typography are banned for Stitch outputs.

- **Display:** Satoshi or Geist, 600 weight, tight but readable tracking. Use controlled scale, not oversized hero shouting.
- **Body:** Satoshi or Geist, 400 to 500 weight, relaxed line height, max 65 characters.
- **Mono:** JetBrains Mono or Geist Mono for timestamps, offsets, coordinates, and compact timezone metadata.

Type scale:

- Map title: clamp(1.75rem, 3vw, 3rem), line-height 1.02.
- Section heading: 1.25rem to 1.75rem.
- Panel title: 1rem to 1.125rem.
- Body: 1rem.
- Metadata: 0.8125rem to 0.875rem, mono when numeric.

The home screen should not use marketing hero copy. The map is the hero.

## 5. Core Screens

### Home Map

The first viewport is a full-bleed map workspace with a compact floating navigation island and map-aware context overlays. The map should remain visible behind every primary control.

Required home elements:

- Full-viewport geographic map using natural cartographic colors.
- Daylight and night terminator layer that updates over time.
- Timezone hover and click states with compact local-time popovers.
- Team member markers positioned by latitude and longitude.
- Marker state encoded by availability through ring color, not large status cards.
- A floating "Now" context strip that summarizes the viewer's current local time, team overlap, and next meaningful transition.
- A selected-teammate sheet that opens from the marker location on desktop and from the bottom on mobile.
- One route to Directory for people-list scanning.

Forbidden on the home map:

- No team member card list below the map.
- No three-column metric row above or below the map.
- No marketing hero section before the map.
- No generic "working now / edge / off" dashboard tiles on the home surface.
- No centered headline taking visual priority over the geographic view.

### Teammate Selection

Selecting a marker should create a contextual moment, not open a generic profile card.

The selected state should show:

- Name, role, location, local time, and work-hour window.
- Current context sentence, for example: "Local afternoon in Lisbon. Workday ends in 1h 40m."
- Daylight state: sunrise, daylight, dusk, or night.
- Overlap relationship to the viewer: available now, near boundary, or wait until a named local time.
- Pronunciation action as a small respectful profile aid. It must call the production pronunciation API and must not look like a standalone pronunciation feature.

Panel style:

- Desktop: compact floating instrument panel anchored near the selected marker, with enough offset to avoid hiding the marker.
- Mobile: bottom sheet with a strong drag handle, 92vw max width, and clear close affordance.
- The panel must never cover the entire map unless the user enters a focused profile view.

### Time Travel and Overlap

Zonely should make temporal context visible. Add a map scrubber only when it directly answers availability.

Interaction model:

- A horizontal time rail floats near the bottom of the map.
- The rail shows now, sunrise/sunset boundaries, and work-hour overlap windows.
- Scrubbing changes marker states, timezone labels, and sunlight position.
- The rail should snap to meaningful moments: now, next overlap, start of workday, end of workday.
- Use a "Reset to now" control only when the user has moved away from real time.

### Directory

The Directory is a separate route for scanning, search, and administrative clarity. It can contain denser information, but it should still preserve the geographic point of view.

Directory rules:

- Use search, filters, and grouping by timezone or country.
- Prefer rows or compact profile strips over large equal cards.
- Show local time, availability, and location as the primary scan fields.
- Pronunciation controls stay small and secondary.
- Avoid generic stat cards. If summary data is needed, use a slim segmented header or inline counters.

## 6. Layout Principles

- Map-first always. The geographic canvas is the primary object.
- Floating controls should be islands with clear jobs: navigation, now context, selected teammate, time scrubber, map tools.
- Use asymmetric placement: navigation top-left, context top-right or lower-left, time rail bottom-center, map tools bottom-right.
- Do not put cards inside cards.
- Do not use page sections as floating decorative cards.
- Use cards only for repeated directory items, selected teammate sheets, popovers, and focused tools.
- Prefer CSS Grid for fixed layout zones. Do not use percentage math hacks.
- Desktop max readable panel width: 420px.
- Bottom sheet mobile max height: 72dvh.
- Touch target minimum: 44px.
- Use `min-h-[100dvh]` for full viewport layouts. Do not use `h-screen`.

Responsive behavior:

- Below 768px, all panels become single-column and bottom anchored.
- The map remains the first visible element.
- Time rail can collapse into a compact scrubber with labeled ticks.
- Directory filters become a horizontal segmented control with no horizontal page overflow.

## 7. Component Styling

### Navigation Island

Use a detached rounded island, not a full-width navbar. It should feel like a map control.

- Shape: rounded full pill or 14px rounded compact cluster.
- Fill: Instrument White at 88 percent opacity.
- Border: Hairline Frost.
- Shadow: soft cartographic shadow, rgba(22, 26, 29, 0.10), broad and low.
- Active route: Live Meridian text and a subtle inset surface, no blue pill.

### Map Markers

Markers should read at three zoom levels: world, region, and city.

- Default: circular avatar or initials inside a white instrument bezel.
- Availability ring: Available Green, Edge Ochre, or Quiet Slate.
- Selected marker: Live Meridian ring, slight scale up, and a soft pulse using opacity and transform only.
- Cluster marker: small stacked avatars or count puck, never a generic colored bubble.
- Hover: lift by translateY(-2px), no layout shift.

### Context Panels

Panels are instrument glass, not heavy cards.

- Outer shell: rgba(255, 255, 255, 0.74), subtle blur only when fixed or over the map.
- Inner surface: Instrument White.
- Radius: 16px for compact panels, 20px for selected teammate sheet.
- Border: Hairline Frost.
- Shadow: 0 22px 70px rgba(22, 26, 29, 0.14).
- Use dividers and whitespace instead of nested boxes.

### Buttons

- Primary: Live Meridian fill, white text, no glow.
- Secondary: transparent or white fill, Hairline Frost border.
- Icon buttons: square or circular 44px targets with visible hover and focus states.
- Active press: translateY(1px) or scale(0.98).
- Never use custom cursors.

### Forms and Filters

- Labels sit above inputs.
- Helper text is below labels or below fields, never inside placeholder-only fields.
- Errors are inline and specific.
- Search in Directory should use a compact command-field style, not a large hero search bar.

### Loading and Empty States

- Map loading: skeleton basemap with latitude/longitude hairlines and soft shimmer.
- Marker loading: small shimmer pucks where markers will appear.
- Empty team state on home: keep the map visible and show a single focused setup panel.
- Do not use circular spinners as the primary loading pattern.

## 8. Motion and Interaction

Motion must reveal changing context. It should not feel ornamental.

Motion rules:

- Use spring-like easing: cubic-bezier(0.32, 0.72, 0, 1) for CSS transitions.
- Animate only transform and opacity for UI elements.
- Do not animate top, left, width, or height.
- Stagger marker entry by geography or timezone with short delays.
- Selected panels should originate from the marker position on desktop.
- Daylight changes should be slow and continuous, never flashy.
- Hover states should be tactile but restrained.

Required micro-interactions:

- Marker pulse for selected teammate.
- Gentle shimmer on the "Now" context strip when live context updates.
- Time rail thumb with physical drag feedback.
- Timezone hover fill fade.
- Popover entrance: translateY(8px) plus opacity, no hard scale bounce.

Performance constraints:

- MapLibre owns map panning and zooming.
- Keep heavy animation outside LiveView re-render loops.
- Use JavaScript hooks for map interactions and browser-only APIs.
- Do not use scroll listeners for animation.
- Do not attach large backdrop-blur effects to scrolling containers.

## 9. Context-Aware UX Rules

Zonely should adapt the interface based on the viewer's current question.

Context signals:

- Viewer local time.
- Selected teammate local time.
- Teammate work-hour window.
- Timezone offset from viewer.
- Daylight state.
- Holiday or regional exception.
- Team overlap window.
- Whether the user is browsing now or scrubbing future time.

Adaptive behaviors:

- If no teammate is selected, emphasize global overlap and daylight.
- If a teammate is selected, emphasize local time, reachability, and the next respectful action.
- If the user scrubs time, show simulated state clearly and provide reset to now.
- If the map has many nearby teammates, cluster first and reveal individuals on zoom.
- If a teammate is outside work hours, do not show urgent contact affordances as primary.
- If pronunciation is available, show it as a small audio icon beside the name or native name.

Copy style:

- Use concrete context, not product marketing.
- Good: "Tokyo is at 08:20. Workday starts in 40m."
- Good: "Three teammates are in daylight. London and Lisbon overlap now."
- Bad: "Unlock seamless collaboration across global teams."
- Bad: "Next-gen timezone intelligence."

## 10. Stitch Screen Prompt

Use this prompt in Stitch when generating the primary screen:

```text
Design Zonely, a map-first coordination app for distributed teams. The first viewport is a full-bleed global map with daylight and night overlay, timezone regions, and teammate markers placed geographically. The interface should feel like a calm live geographic instrument, not a SaaS dashboard. Use a detached navigation island, a compact Now context strip, a bottom time scrubber, and a selected-teammate floating panel. Do not place team member cards or status metric cards below the map. Directory is a separate route. Use the Zonely palette: Polar Canvas #F7F8F6, Instrument White #FFFFFF, Charcoal Ink #161A1D, Slate Signal #5F6B73, Live Meridian #1F8A70 as the single accent, Solar Amber #D99A2B only for daylight. Use Satoshi or Geist typography, JetBrains Mono for times and offsets. Build asymmetric floating controls over the map, with instrument glass panels, soft cartographic shadows, tactile marker interactions, and restrained spring motion. The UX adapts to local time, selected teammate, daylight, work-hour overlap, and future time scrubbing.
```

Use this prompt in Stitch for the selected teammate panel:

```text
Design a selected teammate context panel for Zonely. It opens from a geographic marker on desktop and as a bottom sheet on mobile. Show name, role, city/country, local time, work hours, daylight state, timezone offset from viewer, and a human sentence that explains whether now is a good time to reach out. Include small pronunciation controls as secondary profile aids only. Use instrument glass, Live Meridian for active state, no neon, no metric cards, no marketing copy.
```

Use this prompt in Stitch for the Directory route:

```text
Design the Zonely Directory route as the secondary scanning surface. It should support search, timezone or country grouping, compact teammate rows, and inline availability context. Preserve the geographic mental model with timezone headers and local-time metadata. Avoid equal three-column card grids and generic stat tiles. Keep pronunciation controls small and secondary. The design should feel related to the map workspace but denser and more operational.
```

## 11. Banned Patterns

- No emojis anywhere in UI or docs intended for UI generation.
- No Inter, Roboto, Arial, Helvetica, or generic default typography in Stitch outputs.
- No pure black.
- No neon glows or saturated gradients.
- No purple or blue AI aesthetic.
- No oversized centered hero section.
- No marketing landing page before the app experience.
- No team card list below the map.
- No equal three-column metric/card row on the home map.
- No nested cards.
- No generic names like John Doe or Acme in examples.
- No fake round metrics like 99.99 percent or 50 percent.
- No filler text such as "Scroll to explore" or "Swipe down."
- No custom mouse cursor.
- No decorative orbs, bokeh blobs, or gradient blobs.
- No large scroll containers with backdrop blur.
- No pronunciation feature expansion inside Zonely. Pronunciation remains a small profile action backed by the production API.

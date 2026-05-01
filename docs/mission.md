# Zonely Mission

Zonely helps distributed teams answer one practical question: who can I reasonably reach right now?

The product exists to make availability feel spatial and immediate. A teammate's location, local time, work window, daylight, and regional context should be visible through the map before someone decides to send a message, wait, or plan a handoff.

The durable product foundation is a composable availability and reachability
engine, not a specific map implementation. See
[foundational-capabilities.md](foundational-capabilities.md) for the core
capability model that future UI, API, calendar, holiday, leave, preference, and
integration work should build on.

## V1 Goal: Reachability Now

The smallest useful product is a fullscreen team map that turns local time into a clear reachability decision.

- Show where teammates are in the world.
- Label each teammate as reachable now, ask carefully, or wait.
- Explain the decision with local time, work window, and country context.
- Keep teammate scanning and selection inside the map instead of falling back to list-first status views.

## Product Boundaries

Zonely owns:

- Map-native teammate discovery and profile context
- Time zone, country, and local work-hour visibility
- Reachability signals for distributed teams
- Holiday and regional context that affects coordination
- Lightweight profile aids that make collaboration more respectful

Zonely does not own:

- A standalone pronunciation product
- Pronunciation provider selection, audio generation, or audio caching
- Usage analytics dashboards for pronunciation playback
- iOS app surfaces
- Generic social/profile sharing features unrelated to team coordination

Pronunciation is profile context only. Zonely calls the production pronunciation API at `https://saymyname.qingbo.us/api/v1/pronounce` for playback metadata and keeps that implementation outside this repo.

## Current Surface

- `/`: fullscreen team map with teammate orbit, reachability, work-hour, daylight, timezone, and profile context
- `/healthz` and `/readyz`: production health checks
- `/dev/dashboard`: Phoenix LiveDashboard in development only

## Roadmap

1. Make the fullscreen map the canonical answer to "who can I reach now?"
2. Make teammate scanning, selection, and local context feel native to the map.
3. Add holiday and regional context as teammate availability signals.
4. Explore meeting-time suggestions after overlap and holiday signals are dependable.
5. Keep integrations narrow: Slack, calendar, or presence work should support availability decisions rather than become separate product surfaces.

See [tech-stack-review.md](tech-stack-review.md) for the current stack recommendation.

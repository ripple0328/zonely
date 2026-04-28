# Zonely Mission

Zonely helps distributed teams decide when and how to reach teammates across time zones.

The product exists to make team availability easier to understand at a glance: where people are working from, whether they are inside normal work hours, which time zones overlap, and which local context might affect a handoff or meeting.

## Product Boundaries

Zonely owns:

- Map-native teammate discovery and profile context
- Time zone, country, and local work-hour visibility
- Availability and overlap signals for distributed teams
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

- `/`: fullscreen team map with teammate orbit, work-hour, daylight, timezone, and profile context
- `/healthz` and `/readyz`: production health checks
- `/dev/dashboard`: Phoenix LiveDashboard in development only

## Roadmap

1. Stabilize the fullscreen map as the canonical product surface.
2. Make teammate scanning, selection, and local context feel native to the map.
3. Add holiday and regional context as teammate availability signals.
4. Explore meeting-time suggestions after overlap and holiday signals are dependable.
5. Keep integrations narrow: Slack, calendar, or presence work should support availability decisions rather than become separate product surfaces.

See [tech-stack-review.md](tech-stack-review.md) for the current stack recommendation.

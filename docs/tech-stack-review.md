# Tech Stack Review

Date: 2026-04-28

This review treats the current codebase as disposable. The question is not "what is cheapest to preserve?" but "what stack should Zonely use if rebuilt around the current mission?"

## Product Shape

Zonely is a small, server-backed coordination app:

- Map-native teammate discovery and profile context
- Time zone, work-hour, and location signals
- Holiday and availability context
- Possible future real-time scheduling or presence
- Production deployment to a Mac Mini through `../mini-infra`

This is mostly data modeling, server-rendered product UI, and selective real-time interaction. It is not a heavy offline client, native mobile app, or standalone audio/pronunciation product.

## Recommendation

Keep Phoenix 1.8, LiveView, Ecto, PostgreSQL, Tailwind, and Req as the default stack for the next iteration.

If rebuilding from scratch, start with a clean Phoenix app rather than migrating every current module. Keep the stack, not the implementation.

Current upgraded baseline:

- Erlang/OTP 28.5
- Elixir 1.19.5
- Phoenix 1.8.5
- Phoenix LiveView 1.1.28
- Ecto SQL 3.13.5
- Bandit 1.10.4
- Req 0.5.17
- Tailwind Hex wrapper 0.4.1

The main cleanup direction is:

- Remove stale browser-testing and old feature harnesses.
- Keep tests focused on contexts, LiveViews, components, and health checks.
- Add end-to-end browser automation later only for stable user journeys.
- Use narrow JavaScript hooks only where the UI genuinely needs browser APIs, such as maps or audio playback.

## Why Phoenix Still Fits

Phoenix remains a good fit because the product wants server-owned data, durable background-friendly operations, and potentially real-time UI. Phoenix 1.8 also moved toward a simpler generated app shape and first-class agent guidance, which matches this repo's preference for small, explicit surfaces. LiveView 1.1 continues to improve server-rendered interactivity and colocated JavaScript, which is useful for keeping most UI server-owned while allowing small browser-specific behaviors.

The current debt came from product confusion and stale surfaces, not from Phoenix being the wrong tool. A rewrite in another framework would not automatically fix mission drift.

## Alternatives Considered

| Stack | Fit | Notes |
|---|---|---|
| Phoenix + LiveView | Best default | Strong for server-owned state, real-time scheduling, Postgres, Mini deployment, and small-team maintenance. |
| SvelteKit + Postgres | Best UI-first alternative | Good if the product becomes mostly rich frontend interaction. More JavaScript ownership and a separate backend/data discipline would be needed. |
| Next.js + React | Broad ecosystem | Strong hiring/ecosystem story and full-stack capabilities, but more framework churn and client/server boundary complexity than Zonely currently needs. |
| Rails 8 + Hotwire | Viable conventional CRUD | Great integrated web stack; less compelling than Phoenix for real-time coordination unless the app deliberately avoids LiveView-style interactions. |

## Decision Rule

Use Phoenix unless one of these becomes true:

- The primary product becomes a highly interactive map/timeline canvas that is awkward in LiveView.
- The project needs a large React/Svelte component ecosystem more than it needs server-owned real-time state.
- Deployment moves away from the Mini/OTP release path and toward a JavaScript-first hosting platform.
- A future team strongly prefers TypeScript and accepts the extra client/server split.

Until then, the practical path is a clean Phoenix/LiveView codebase with tighter product boundaries.

## Sources

- Phoenix 1.8 release notes: https://www.phoenixframework.org/blog/phoenix-1-8-released
- Phoenix LiveView 1.1 release notes: https://www.phoenixframework.org/blog/phoenix-liveview-1-1-released
- Next.js docs: https://nextjs.org/docs
- SvelteKit docs: https://svelte.dev/docs/kit/introduction
- Rails 8.0 release notes: https://edgeguides.rubyonrails.org/8_0_release_notes.html

# Analytics Module

Privacy-first analytics for SayMyName (Zonely).

## Quick Start

### Run Migration

```bash
mix ecto.migrate
```

### Track Events

```elixir
alias Zonely.Analytics

# Track a pronunciation
Analytics.track("pronunciation_generated", %{
  name_hash: Privacy.hash_name("John Doe"),
  language: "en",
  voice_id: "nova",
  audio_duration: 2.3,
  generation_time_ms: 450,
  tts_provider: "elevenlabs",
  character_count: 8
})

# Track a cache hit
Analytics.track("pronunciation_cache_hit", %{
  name_hash: Privacy.hash_name("Jane Smith"),
  language: "en",
  voice_id: "shimmer",
  cache_age_hours: 12.5
})

# Track a page view
Analytics.track("page_view_landing", %{
  utm_source: "twitter",
  utm_medium: "social",
  entry_point: "social"
}, session_id: session_id, user_context: Privacy.build_user_context(conn))
```

### Query Metrics

```elixir
# Date range
start_date = DateTime.add(DateTime.utc_now(), -7, :day)
end_date = DateTime.utc_now()

# Total pronunciations
Analytics.total_pronunciations(start_date, end_date)
# => 1234

# Cache hit rate
Analytics.cache_hit_rate(start_date, end_date)
# => 67.5

# Top 10 names
Analytics.top_requested_names(start_date, end_date, 10)
# => [{"a3f8b9c2e1d4f5a6", 45}, {"7b2c4d6e8f1a3b5c", 32}, ...]

# Provider performance
Analytics.tts_provider_performance(start_date, end_date)
# => [%{provider: "elevenlabs", avg_generation_time_ms: 450, ...}, ...]
```

### View Dashboard

Navigate to: `http://localhost:4000/admin/analytics`

## Files

- `analytics.ex` - Main context with query functions
- `analytics/event.ex` - Ecto schema for events
- `analytics/privacy.ex` - Privacy utilities (hashing, extraction)
- `analytics/README.md` - This file

## Privacy

**No PII collected:**
- Names are hashed (SHA-256, irreversible)
- User agents are hashed
- Only country-level location (no IP, no city)
- Referrers are domain-only (no paths)
- Session IDs are temporary UUIDs

See: `/docs/saymyname-analytics-schema.md` for full details.

## Testing

```bash
# Run analytics tests
mix test test/zonely/analytics_test.exs

# Add test data in IEx
iex -S mix
alias Zonely.Analytics

for _ <- 1..100 do
  Analytics.track("pronunciation_generated", %{
    name_hash: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
    language: "en",
    voice_id: "nova",
    audio_duration: :rand.uniform(5) + 1.0,
    generation_time_ms: :rand.uniform(500) + 200,
    tts_provider: Enum.random(["elevenlabs", "google"]),
    character_count: :rand.uniform(20) + 5
  })
end
```

## Next Steps

1. Add event tracking to pronunciation endpoints
2. Add authentication to `/admin/analytics` route
3. Integrate tracking into LiveViews
4. Add automated tests

See: `/docs/saymyname-analytics-dashboard.md` for implementation details.

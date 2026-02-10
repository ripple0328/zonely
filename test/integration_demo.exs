#!/usr/bin/env elixir

# Analytics Integration Demo Script
# Demonstrates complete event logging and querying workflow
#
# Run with: mix run test/integration_demo.exs

defmodule AnalyticsDemo do
  @moduledoc """
  Demonstrates the analytics system with realistic test data.
  
  This script:
  1. Logs various event types
  2. Queries events
  3. Calculates metrics
  4. Shows partition management
  """
  
  alias SayMyName.Analytics
  alias SayMyName.Analytics.Events
  
  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "=== SayMyName Analytics Demo ===" <> IO.ANSI.reset() <> "\n")
    
    session_id = Ecto.UUID.generate()
    IO.puts("📝 Test session ID: #{session_id}\n")
    
    # 1. Simulate user journey
    simulate_user_journey(session_id)
    
    # 2. Query session events
    IO.puts("\n#{IO.ANSI.yellow()}📊 Session Events:#{IO.ANSI.reset()}")
    query_session_events(session_id)
    
    # 3. Calculate metrics
    IO.puts("\n#{IO.ANSI.yellow()}📈 Metrics:#{IO.ANSI.reset()}")
    calculate_metrics()
    
    # 4. Show retention info
    IO.puts("\n#{IO.ANSI.yellow()}🗑️  Retention Policies:#{IO.ANSI.reset()}")
    show_retention_policies()
    
    IO.puts("\n#{IO.ANSI.green()}✅ Demo complete!#{IO.ANSI.reset()}\n")
  end
  
  defp simulate_user_journey(session_id) do
    IO.puts("#{IO.ANSI.blue()}🚀 Simulating user journey...#{IO.ANSI.reset()}\n")
    
    # 1. User lands on homepage from Twitter
    log_event("page_view_landing", session_id, %{
      entry_point: "social",
      utm_source: "twitter",
      utm_campaign: "launch"
    })
    
    Process.sleep(500)
    
    # 2. User generates a pronunciation
    name = "SayMyName"
    start_time = System.monotonic_time(:millisecond)
    
    log_event("pronunciation_generated", session_id, %{
      name: name,
      language: "en",
      voice_id: "nova",
      audio_duration: 2.3,
      generation_time_ms: 1450,
      tts_provider: "elevenlabs",
      character_count: String.length(name)
    })
    
    Process.sleep(300)
    
    # 3. User views pronunciation page
    log_event("page_view_pronunciation", session_id, %{
      name: name,
      language: "en",
      voice_id: "nova",
      source: "landing_form"
    })
    
    Process.sleep(800)
    
    # 4. User plays audio (twice)
    log_event("interaction_play_audio", session_id, %{
      name: name,
      language: "en",
      voice_id: "nova",
      playback_position: 0.0,
      audio_duration: 2.3,
      autoplay: false
    })
    
    Process.sleep(2300)
    
    log_event("interaction_play_audio", session_id, %{
      name: name,
      language: "en",
      voice_id: "nova",
      playback_position: 0.5,
      audio_duration: 2.3,
      autoplay: false
    })
    
    Process.sleep(1200)
    
    # 5. User shares on WhatsApp
    log_event("interaction_share", session_id, %{
      name: name,
      share_method: "social",
      platform: "whatsapp"
    })
    
    Process.sleep(400)
    
    # 6. User copies link
    log_event("interaction_copy_link", session_id, %{
      name: name,
      link_type: "share"
    })
    
    IO.puts("✅ Journey complete! 7 events logged")
  end
  
  defp log_event(event_name, session_id, properties) do
    result = Analytics.log_event(event_name, %{
      session_id: session_id,
      properties: properties,
      user_context: %{
        country: "US",
        viewport_width: 1920,
        viewport_height: 1080
      },
      metadata: %{
        app_version: "1.0.0",
        environment: "demo"
      }
    })
    
    case result do
      {:ok, _event} ->
        IO.puts("  ✓ #{event_name}")
      {:error, changeset} ->
        IO.puts("  ✗ #{event_name} - #{inspect(changeset.errors)}")
    end
    
    result
  end
  
  defp query_session_events(session_id) do
    events = Analytics.query_by_session(session_id)
    
    Enum.each(events, fn event ->
      time = event.timestamp |> DateTime.to_time() |> Time.to_string()
      IO.puts("  #{time} - #{event.event_name}")
    end)
    
    IO.puts("\n  Total events: #{length(events)}")
  end
  
  defp calculate_metrics do
    # Most popular names (if there's data)
    IO.puts("  Most popular names (last 30 days):")
    popular = Analytics.most_popular_names(5)
    
    if Enum.empty?(popular) do
      IO.puts("    (no data yet)")
    else
      Enum.each(popular, fn %{name_hash: hash, count: count} ->
        IO.puts("    #{hash}: #{count} pronunciations")
      end)
    end
    
    # Cache hit rate
    start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
    end_date = DateTime.utc_now()
    cache_stats = Analytics.cache_hit_rate(start_date, end_date)
    
    IO.puts("\n  Cache hit rate (last 7 days):")
    IO.puts("    Hit rate: #{cache_stats.hit_rate}%")
    IO.puts("    Hits: #{cache_stats.hits}")
    IO.puts("    Total: #{cache_stats.total}")
    
    # Conversion funnel
    today = Date.utc_today()
    funnel = Analytics.conversion_funnel(today)
    
    IO.puts("\n  Conversion funnel (today):")
    IO.puts("    Landed: #{funnel.landed}")
    IO.puts("    Converted: #{funnel.converted}")
    IO.puts("    Conversion rate: #{funnel.conversion_rate}%")
  end
  
  defp show_retention_policies do
    policies = [
      {"page_view_landing", "Page Views"},
      {"interaction_play_audio", "Interactions"},
      {"pronunciation_generated", "Pronunciations"},
      {"system_api_error", "System Events"}
    ]
    
    Enum.each(policies, fn {event_name, category} ->
      days = Analytics.get_retention_days(event_name)
      IO.puts("  #{category}: #{days} days")
    end)
  end
end

# Note: This demo assumes the SayMyName.Repo is configured and running
# In a real integration, you would run this with: mix run test/integration_demo.exs

IO.puts("""
#{IO.ANSI.yellow()}
⚠️  This is a demo script showing the analytics API.

To run this for real:
1. Set up your database and run migrations
2. Configure SayMyName.Repo
3. Run: mix run test/integration_demo.exs
#{IO.ANSI.reset()}
""")

# For standalone demo without DB, we just show the API
IO.puts("""
#{IO.ANSI.cyan()}
Example API calls that would be made:
#{IO.ANSI.reset()}

1. Log landing page view:
   Analytics.log_event("page_view_landing", %{
     session_id: "...",
     properties: %{entry_point: "social", utm_source: "twitter"}
   })

2. Log pronunciation generation:
   Analytics.log_event("pronunciation_generated", %{
     session_id: "...",
     properties: %{name: "SayMyName", generation_time_ms: 1450}
   })

3. Query session events:
   Analytics.query_by_session(session_id)

4. Get popular names:
   Analytics.most_popular_names(10)

5. Calculate cache hit rate:
   Analytics.cache_hit_rate(start_date, end_date)

#{IO.ANSI.green()}
See INTEGRATION_GUIDE.md for complete integration instructions.
#{IO.ANSI.reset()}
""")

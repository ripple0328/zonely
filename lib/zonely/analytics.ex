defmodule Zonely.Analytics do
  @moduledoc """
  The Analytics context for SayMyName usage tracking and metrics.
  
  Provides functions for:
  - Recording analytics events
  - Querying metrics and statistics
  - Computing dashboard data
  
  Privacy-first design: no PII, all names are hashed.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Zonely.Repo
  alias Zonely.Analytics.Event

  @doc """
  Records an analytics event.
  
  ## Examples
  
      iex> track("page_view_landing", %{utm_source: "twitter"})
      {:ok, %Event{}}
  """
  def track(event_name, properties, opts \\ []) do
    %Event{}
    |> Event.changeset(%{
      event_name: event_name,
      timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
      session_id: Keyword.get(opts, :session_id, generate_session_id()),
      user_context: Keyword.get(opts, :user_context, %{}),
      metadata: Keyword.get(opts, :metadata, default_metadata()),
      properties: properties
    })
    |> Repo.insert()
  end

  @doc """
  Fire-and-forget event logging (async).
  """
  def track_async(event_name, properties, opts \\ []) do
    Task.start(fn ->
      case track(event_name, properties, opts) do
        {:ok, _event} ->
          :ok

        {:error, changeset} ->
          Logger.error("Analytics track failed: #{inspect(changeset.errors)}")
      end
    end)

    :ok
  end

  @doc """
  Hash a name for privacy-safe analytics.
  """
  def hash_name(name) when is_binary(name) do
    :crypto.hash(:sha256, name)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Build a minimal user context map from request headers.
  """
  def user_context_from_headers(headers) when is_list(headers) do
    ua = headers |> Enum.find_value("", fn {k, v} -> if String.downcase(k) == "user-agent", do: v end)
    country = headers |> Enum.find_value(nil, fn {k, v} -> if String.downcase(k) == "cf-ipcountry", do: v end)

    %{
      user_agent: if(ua == "", do: nil, else: hash_name(ua)),
      country: country
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Enum.into(%{})
  end


  @doc """
  Get total pronunciation count for a date range.
  """
  def total_pronunciations(start_date, end_date) do
    from(e in Event,
      where: e.event_name == "interaction_play_audio",
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      select: count(e.id)
    )
    |> Repo.one()
  end

  @doc """
  Calculate cache hit rate for a date range.
  Returns percentage (0-100).
  """
  def cache_hit_rate(start_date, end_date) do
    hits =
      from(e in Event,
        where: e.event_name == "interaction_play_audio",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        where: fragment("properties->>'provider' LIKE 'cache_%'"),
        select: count(e.id)
      )
      |> Repo.one()

    total = total_pronunciations(start_date, end_date)

    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end

  def cache_hit_breakdown(start_date, end_date) do
    rows =
      from(e in Event,
        where: e.event_name == "interaction_play_audio",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        where: fragment("properties->>'provider' LIKE 'cache_%'"),
        select: {fragment("properties->>'provider'"), count(e.id)},
        group_by: fragment("properties->>'provider'")
      )
      |> Repo.all()

    rows
    |> Enum.reduce(%{"cache_local" => 0, "cache_remote" => 0, "cache_client" => 0}, fn {provider, count}, acc ->
      key = provider || "cache_local"
      Map.put(acc, key, count)
    end)
  end

  @doc """
  Get top N most requested names by hash.
  Returns list of {name_hash, count} tuples.
  """
  def top_requested_names(start_date, end_date, limit \\ 10) do
    rows =
      from(e in Event,
        where: e.event_name == "pronunciation_generated",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        where: fragment("properties->>'name_text' IS NOT NULL"),
        select: %{
          name: fragment("properties->>'name_text'"),
          lang: fragment("properties->>'lang'"),
          provider: fragment("properties->>'provider'"),
          count: count(e.id)
        },
        group_by: [
          fragment("properties->>'name_text'"),
          fragment("properties->>'lang'"),
          fragment("properties->>'provider'")
        ],
        order_by: [desc: count(e.id)]
      )
      |> Repo.all()

    rows
    |> Enum.reduce(%{}, fn row, acc ->
      key = {row.name || "Unknown", row.lang || "Unknown"}
      entry = Map.get(acc, key, %{name: elem(key, 0), lang: elem(key, 1), count: 0, provider_counts: %{}})
      provider_counts = Map.update(entry.provider_counts, row.provider || "unknown", row.count, &(&1 + row.count))
      Map.put(acc, key, %{entry | count: entry.count + row.count, provider_counts: provider_counts})
    end)
    |> Map.values()
    |> Enum.map(fn entry ->
      {provider, _} =
        entry.provider_counts
        |> Enum.sort_by(fn {_p, c} -> -c end)
        |> List.first() || {"unknown", 0}

      Map.put(entry, :provider, provider)
    end)
    |> Enum.sort_by(&(&1.count), :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get geographic distribution by country.
  Returns list of {country_code, session_count} tuples.
  """
  def geographic_distribution(start_date, end_date, limit \\ 10) do
    from(e in Event,
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      where: fragment("user_context->>'country' IS NOT NULL"),
      select: {fragment("user_context->>'country'"), count(fragment("DISTINCT ?", e.session_id))},
      group_by: fragment("user_context->>'country'"),
      order_by: [desc: count(fragment("DISTINCT ?", e.session_id))],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Top languages by pronunciation count.
  Returns list of {lang, count} tuples.
  """
  def top_languages(start_date, end_date, limit \\ 5) do
    from(e in Event,
      where: e.event_name == "pronunciation_generated",
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      select: {fragment("properties->>'lang'"), count(e.id)},
      group_by: fragment("properties->>'lang'"),
      order_by: [desc: count(e.id)],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Get TTS provider performance comparison.
  Returns list of maps with provider stats.
  """
  def tts_provider_performance(start_date, end_date) do
    from(e in Event,
      where: e.event_name == "pronunciation_generated",
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      select: %{
        provider: fragment("COALESCE(properties->>'tts_provider', properties->>'provider')"),
        avg_generation_time_ms:
          fragment("AVG((properties->>'generation_time_ms')::integer)::integer"),
        median_generation_time_ms:
          fragment(
            "PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (properties->>'generation_time_ms')::integer)::integer"
          ),
        p95_generation_time_ms:
          fragment(
            "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (properties->>'generation_time_ms')::integer)::integer"
          ),
        total_requests: count(e.id)
      },
      group_by: fragment("COALESCE(properties->>'tts_provider', properties->>'provider')"),
      order_by: [asc: fragment("AVG((properties->>'generation_time_ms')::integer)")]
    )
    |> Repo.all()
  end

  @doc """
  External provider performance (Forvo/NameShouts/Polly).
  Returns list of maps with provider stats based on external_api_call events.
  """
  def provider_usage(start_date, end_date) do
    counts =
      from(e in Event,
        where: e.event_name == "interaction_play_audio",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        select: {fragment("properties->>'provider'"), count(e.id)},
        group_by: fragment("properties->>'provider'")
      )
      |> Repo.all()
      |> Enum.reject(fn {provider, _} -> is_nil(provider) end)

    counts_map =
      counts
      |> Enum.reduce(%{}, fn {provider, count}, acc ->
        Map.put(acc, to_string(provider), %{provider: to_string(provider), total_requests: count})
      end)

    metrics_external =
      from(e in Event,
        where: e.event_name == "external_api_call",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        where: fragment("properties->>'provider' IN ('polly','forvo','name_shouts')"),
        select: %{
          provider: fragment("properties->>'provider'"),
          avg_generation_time_ms:
            fragment("AVG((properties->>'duration_ms')::integer)::integer"),
          p95_generation_time_ms:
            fragment(
              "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (properties->>'duration_ms')::integer)::integer"
            )
        },
        group_by: fragment("properties->>'provider'")
      )
      |> Repo.all()

    metrics_polly =
      from(e in Event,
        where: e.event_name == "pronunciation_generated",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        where: fragment("properties->>'provider' = 'polly'"),
        where: fragment("properties->>'generation_time_ms' IS NOT NULL"),
        select: %{
          provider: fragment("'polly'"),
          avg_generation_time_ms:
            fragment("AVG((properties->>'generation_time_ms')::integer)::integer"),
          p95_generation_time_ms:
            fragment(
              "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (properties->>'generation_time_ms')::integer)::integer"
            )
        }
      )
      |> Repo.all()

    metrics =
      (metrics_external ++ metrics_polly)
      |> Enum.reduce(%{}, fn row, acc -> Map.put(acc, to_string(row.provider), row) end)

    counts_map
    |> Map.values()
    |> Enum.map(fn row ->
      metrics_row = Map.get(metrics, row.provider, %{})

      row
      |> Map.merge(metrics_row)
      |> Map.put_new(:avg_generation_time_ms, nil)
      |> Map.put_new(:p95_generation_time_ms, nil)
    end)
    |> Enum.sort_by(&(&1.total_requests || 0), :desc)
  end

  @doc """
  Get error rate statistics.
  Returns map with error counts and rate.
  """
  def error_rate(start_date, end_date) do
    errors =
      from(e in Event,
        where: e.event_name in ["pronunciation_error", "system_api_error"],
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        select: count(e.id)
      )
      |> Repo.one()

    total =
      from(e in Event,
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        select: count(e.id)
      )
      |> Repo.one()

    if total > 0 do
      %{
        errors: errors,
        total: total,
        error_rate: Float.round(errors / total * 100, 2)
      }
    else
      %{errors: 0, total: 0, error_rate: 0.0}
    end
  end

  @doc """
  Get error breakdown by type.
  """
  def errors_by_type(start_date, end_date) do
    from(e in Event,
      where: e.event_name in ["pronunciation_error", "system_api_error"],
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      select: {fragment("properties->>'error_type'"), count(e.id)},
      group_by: fragment("properties->>'error_type'"),
      order_by: [desc: count(e.id)]
    )
    |> Repo.all()
  end

  @doc """
  Calculate conversion funnel: landing -> pronunciation.
  Returns map with landed sessions, converted sessions, and conversion rate.
  """
  def conversion_funnel(start_date, end_date) do
    # Get sessions that landed
    landing_sessions_query =
      from(e in Event,
        where: e.event_name == "page_view_landing",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        select: e.session_id,
        distinct: true
      )

    landing_sessions = Repo.all(landing_sessions_query)
    landing_count = length(landing_sessions)

    if landing_count > 0 do
      # Get sessions that converted
      converted_count =
        from(e in Event,
          where: e.event_name == "pronunciation_request",
          where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
          where: e.session_id in ^landing_sessions,
          select: count(fragment("DISTINCT ?", e.session_id))
        )
        |> Repo.one()

      %{
        landed: landing_count,
        converted: converted_count,
        conversion_rate: Float.round(converted_count / landing_count * 100, 2)
      }
    else
      %{landed: 0, converted: 0, conversion_rate: 0.0}
    end
  end

  @doc """
  Get hourly time series data for pronunciations.
  Returns list of {hour, count} tuples.
  """
  def pronunciations_time_series(start_date, end_date, granularity \\ "2h") do
    query =
      case granularity do
        "week" ->
          from(e in Event,
            where: e.event_name == "pronunciation_generated",
            where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
            select: {fragment("DATE_TRUNC('week', ?)", e.timestamp), count(e.id)},
            group_by: fragment("1"),
            order_by: [asc: fragment("1")]
          )

        "day" ->
          from(e in Event,
            where: e.event_name == "pronunciation_generated",
            where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
            select: {fragment("DATE_TRUNC('day', ?)", e.timestamp), count(e.id)},
            group_by: fragment("1"),
            order_by: [asc: fragment("1")]
          )

        "6h" ->
          from(e in Event,
            where: e.event_name == "pronunciation_generated",
            where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
            select: {
              fragment(
                "DATE_TRUNC('hour', ?) - (INTERVAL '1 hour' * (EXTRACT(hour FROM ?)::int % 6))",
                e.timestamp,
                e.timestamp
              ),
              count(e.id)
            },
            group_by: fragment("1"),
            order_by: [asc: fragment("1")]
          )

        _ ->
          from(e in Event,
            where: e.event_name == "pronunciation_generated",
            where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
            select: {
              fragment(
                "DATE_TRUNC('hour', ?) - (INTERVAL '1 hour' * (EXTRACT(hour FROM ?)::int % 2))",
                e.timestamp,
                e.timestamp
              ),
              count(e.id)
            },
            group_by: fragment("1"),
            order_by: [asc: fragment("1")]
          )
      end

    Repo.all(query)
  end
  # Private helpers

  defp generate_session_id do
    Ecto.UUID.generate()
  end

  defp default_metadata do
    %{
      app_version: Application.spec(:zonely, :vsn) |> to_string(),
      environment: Application.get_env(:zonely, :environment, :production) |> to_string()
    }
  end
end

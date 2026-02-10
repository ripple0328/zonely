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
  def track_async(event_name, properties, opts \ []) do
    Task.start(fn -> track(event_name, properties, opts) end)
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
      where: e.event_name == "pronunciation_generated",
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
        where: e.event_name == "pronunciation_cache_hit",
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        select: count(e.id)
      )
      |> Repo.one()

    total =
      from(e in Event,
        where: e.event_name in ["pronunciation_generated", "pronunciation_cache_hit"],
        where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
        select: count(e.id)
      )
      |> Repo.one()

    if total > 0 do
      Float.round(hits / total * 100, 2)
    else
      0.0
    end
  end

  @doc """
  Get top N most requested names by hash.
  Returns list of {name_hash, count} tuples.
  """
  def top_requested_names(start_date, end_date, limit \\ 10) do
    from(e in Event,
      where: e.event_name == "pronunciation_generated",
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      select: {fragment("properties->>'name_hash'"), count(e.id)},
      group_by: fragment("properties->>'name_hash'"),
      order_by: [desc: count(e.id)],
      limit: ^limit
    )
    |> Repo.all()
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
  Get TTS provider performance comparison.
  Returns list of maps with provider stats.
  """
  def tts_provider_performance(start_date, end_date) do
    from(e in Event,
      where: e.event_name == "pronunciation_generated",
      where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
      select: %{
        provider: fragment("properties->>'tts_provider'"),
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
      group_by: fragment("properties->>'tts_provider'"),
      order_by: [asc: fragment("AVG((properties->>'generation_time_ms')::integer)")]
    )
    |> Repo.all()
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
          where: e.event_name == "page_view_pronunciation",
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
  def pronunciations_time_series(start_date, end_date, granularity \\ "hour") do
    query =
      case granularity do
        "day" ->
          from(e in Event,
            where: e.event_name == "pronunciation_generated",
            where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
            select: {fragment("DATE_TRUNC('day', ?)", e.timestamp), count(e.id)},
            group_by: fragment("DATE_TRUNC('day', ?)", e.timestamp),
            order_by: [asc: fragment("DATE_TRUNC('day', ?)", e.timestamp)]
          )

        _ ->
          from(e in Event,
            where: e.event_name == "pronunciation_generated",
            where: e.timestamp >= ^start_date and e.timestamp < ^end_date,
            select: {fragment("DATE_TRUNC('hour', ?)", e.timestamp), count(e.id)},
            group_by: fragment("DATE_TRUNC('hour', ?)", e.timestamp),
            order_by: [asc: fragment("DATE_TRUNC('hour', ?)", e.timestamp)]
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

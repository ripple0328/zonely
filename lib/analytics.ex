defmodule SayMyName.Analytics do
  @moduledoc """
  Analytics context for logging and querying SayMyName events.
  
  This module provides functions to:
  - Log analytics events
  - Query events by various criteria
  - Calculate metrics and statistics
  - Manage data retention
  
  All events are privacy-safe and contain no PII.
  """
  
  import Ecto.Query, warn: false
  alias SayMyName.Repo
  alias SayMyName.Analytics.{Event, Privacy}
  
  # Retention policies (in days) by event category
  @retention_days %{
    "page_view" => 90,
    "interaction" => 90,
    "pronunciation" => 180,
    "system" => 30
  }
  
  @doc """
  Log an analytics event.
  
  ## Examples
  
      iex> SayMyName.Analytics.log_event("page_view_landing", %{
      ...>   session_id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   properties: %{entry_point: "direct"},
      ...>   user_context: %{country: "US"}
      ...> })
      {:ok, %Event{}}
      
      iex> SayMyName.Analytics.log_event("invalid-name", %{})
      {:error, %Ecto.Changeset{}}
  """
  @spec log_event(String.t(), map()) :: {:ok, Event.t()} | {:error, Ecto.Changeset.t()}
  def log_event(event_name, attrs \\ %{}) do
    attrs = 
      attrs
      |> Map.put(:event_name, event_name)
      |> Map.put_new(:timestamp, DateTime.utc_now())
      |> maybe_sanitize_user_context()
    
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Log an analytics event asynchronously (fire-and-forget).
  
  Useful for high-throughput scenarios where you don't need to wait for confirmation.
  Errors are logged but not returned.
  
  ## Examples
  
      iex> SayMyName.Analytics.log_event_async("interaction_play_audio", %{
      ...>   session_id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   properties: %{name_hash: "abc123", autoplay: false}
      ...> })
      :ok
  """
  @spec log_event_async(String.t(), map()) :: :ok
  def log_event_async(event_name, attrs \\ %{}) do
    Task.start(fn ->
      case log_event(event_name, attrs) do
        {:ok, _event} -> :ok
        {:error, changeset} ->
          require Logger
          Logger.error("Failed to log analytics event: #{inspect(changeset.errors)}")
      end
    end)
    
    :ok
  end
  
  @doc """
  Batch insert multiple events efficiently.
  
  ## Examples
  
      iex> SayMyName.Analytics.log_events([
      ...>   %{event_name: "page_view_landing", session_id: "uuid1", properties: %{}},
      ...>   %{event_name: "interaction_play_audio", session_id: "uuid2", properties: %{}}
      ...> ])
      {:ok, 2}
  """
  @spec log_events([map()]) :: {:ok, integer()} | {:error, term()}
  def log_events(events) when is_list(events) do
    timestamp = DateTime.utc_now()
    
    entries = 
      Enum.map(events, fn event ->
        event
        |> Map.put_new(:timestamp, timestamp)
        |> Map.put_new(:inserted_at, timestamp)
        |> Map.put_new(:user_context, %{})
        |> Map.put_new(:metadata, %{})
        |> Map.put_new(:properties, %{})
        |> maybe_sanitize_user_context()
      end)
    
    case Repo.insert_all(Event, entries, returning: false) do
      {count, _} -> {:ok, count}
      error -> error
    end
  end
  
  @doc """
  Query events by date range.
  
  ## Examples
  
      iex> start_date = ~U[2026-02-01 00:00:00Z]
      iex> end_date = ~U[2026-02-08 00:00:00Z]
      iex> SayMyName.Analytics.query_events(start_date, end_date)
      [%Event{}, ...]
  """
  @spec query_events(DateTime.t(), DateTime.t(), keyword()) :: [Event.t()]
  def query_events(start_date, end_date, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    
    Event
    |> where([e], e.timestamp >= ^start_date and e.timestamp < ^end_date)
    |> order_by([e], desc: e.timestamp)
    |> limit(^limit)
    |> Repo.all()
  end
  
  @doc """
  Query events by event name and optional date range.
  
  ## Examples
  
      iex> SayMyName.Analytics.query_by_event_name("page_view_landing", limit: 100)
      [%Event{}, ...]
  """
  @spec query_by_event_name(String.t(), keyword()) :: [Event.t()]
  def query_by_event_name(event_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    
    query = from e in Event, where: e.event_name == ^event_name
    
    query = if start_date, do: where(query, [e], e.timestamp >= ^start_date), else: query
    query = if end_date, do: where(query, [e], e.timestamp < ^end_date), else: query
    
    query
    |> order_by([e], desc: e.timestamp)
    |> limit(^limit)
    |> Repo.all()
  end
  
  @doc """
  Query events by session ID.
  
  ## Examples
  
      iex> SayMyName.Analytics.query_by_session("550e8400-e29b-41d4-a716-446655440000")
      [%Event{}, ...]
  """
  @spec query_by_session(String.t(), keyword()) :: [Event.t()]
  def query_by_session(session_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    
    Event
    |> where([e], e.session_id == ^session_id)
    |> order_by([e], asc: e.timestamp)
    |> limit(^limit)
    |> Repo.all()
  end
  
  @doc """
  Get most popular names based on pronunciation events.
  
  ## Examples
  
      iex> SayMyName.Analytics.most_popular_names(10)
      [
        %{name_hash: "abc123", count: 150},
        %{name_hash: "def456", count: 120},
        ...
      ]
  """
  @spec most_popular_names(integer(), keyword()) :: [map()]
  def most_popular_names(limit \\ 10, opts \\ []) do
    days_back = Keyword.get(opts, :days_back, 30)
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    Event
    |> where([e], e.event_name == "pronunciation_generated")
    |> where([e], e.timestamp >= ^cutoff)
    |> select([e], %{
        name_hash: fragment("?->>'name_hash'", e.properties),
        count: count(e.id)
      })
    |> group_by([e], fragment("?->>'name_hash'", e.properties))
    |> order_by([e], desc: count(e.id))
    |> limit(^limit)
    |> Repo.all()
  end
  
  @doc """
  Calculate cache hit rate for pronunciations.
  
  ## Examples
  
      iex> start_date = ~U[2026-02-01 00:00:00Z]
      iex> end_date = ~U[2026-02-08 00:00:00Z]
      iex> SayMyName.Analytics.cache_hit_rate(start_date, end_date)
      %{hit_rate: 85.5, hits: 855, total: 1000}
  """
  @spec cache_hit_rate(DateTime.t(), DateTime.t()) :: map()
  def cache_hit_rate(start_date, end_date) do
    result = 
      Event
      |> where([e], e.timestamp >= ^start_date and e.timestamp < ^end_date)
      |> where([e], e.event_name in ["pronunciation_generated", "pronunciation_cache_hit"])
      |> select([e], %{
          hits: filter(count(e.id), e.event_name == "pronunciation_cache_hit"),
          total: count(e.id)
        })
      |> Repo.one()
    
    hit_rate = if result.total > 0 do
      (result.hits / result.total) * 100
    else
      0.0
    end
    
    %{
      hit_rate: Float.round(hit_rate, 2),
      hits: result.hits,
      total: result.total
    }
  end
  
  @doc """
  Calculate conversion funnel: landing → pronunciation.
  
  ## Examples
  
      iex> date = ~D[2026-02-07]
      iex> SayMyName.Analytics.conversion_funnel(date)
      %{landed: 100, converted: 45, conversion_rate: 45.0}
  """
  @spec conversion_funnel(Date.t()) :: map()
  def conversion_funnel(date) do
    start_datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_datetime = DateTime.add(start_datetime, 1, :day)
    
    # Get unique sessions that landed
    landing_sessions = 
      Event
      |> where([e], e.event_name == "page_view_landing")
      |> where([e], e.timestamp >= ^start_datetime and e.timestamp < ^end_datetime)
      |> select([e], e.session_id)
      |> distinct(true)
      |> Repo.all()
      |> MapSet.new()
    
    # Get unique sessions that converted (viewed a pronunciation)
    converted_sessions = 
      Event
      |> where([e], e.event_name == "page_view_pronunciation")
      |> where([e], e.timestamp >= ^start_datetime and e.timestamp < ^end_datetime)
      |> where([e], e.session_id in ^MapSet.to_list(landing_sessions))
      |> select([e], e.session_id)
      |> distinct(true)
      |> Repo.all()
      |> MapSet.new()
    
    landed = MapSet.size(landing_sessions)
    converted = MapSet.size(converted_sessions)
    
    conversion_rate = if landed > 0 do
      (converted / landed) * 100
    else
      0.0
    end
    
    %{
      landed: landed,
      converted: converted,
      conversion_rate: Float.round(conversion_rate, 2)
    }
  end
  
  @doc """
  Get error rate trend over time (hourly buckets).
  
  ## Examples
  
      iex> SayMyName.Analytics.error_rate_trend(24)
      [
        %{hour: ~U[2026-02-07 12:00:00Z], error_rate: 2.5, errors: 5, total: 200},
        ...
      ]
  """
  @spec error_rate_trend(integer()) :: [map()]
  def error_rate_trend(hours_back \\ 24) do
    start_time = DateTime.utc_now() |> DateTime.add(-hours_back, :hour)
    
    Event
    |> where([e], e.timestamp >= ^start_time)
    |> select([e], %{
        hour: fragment("DATE_TRUNC('hour', ?)", e.timestamp),
        errors: filter(count(e.id), e.event_name in ["pronunciation_error", "system_api_error"]),
        total: count(e.id)
      })
    |> group_by([e], fragment("DATE_TRUNC('hour', ?)", e.timestamp))
    |> order_by([e], fragment("DATE_TRUNC('hour', ?)", e.timestamp))
    |> Repo.all()
    |> Enum.map(fn stat ->
      error_rate = if stat.total > 0 do
        (stat.errors / stat.total) * 100
      else
        0.0
      end
      
      Map.put(stat, :error_rate, Float.round(error_rate, 2))
    end)
  end
  
  @doc """
  Purge expired events based on retention policies.
  
  This should be run daily via a cron job or scheduled task.
  Returns a map of deleted counts by category.
  
  ## Examples
  
      iex> SayMyName.Analytics.purge_expired_events()
      %{system: 1500, page_view: 300, interaction: 250, pronunciation: 100}
  """
  @spec purge_expired_events() :: map()
  def purge_expired_events do
    results = 
      Enum.map(@retention_days, fn {category, days} ->
        cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)
        
        {deleted, _} = 
          Event
          |> where([e], fragment("? LIKE ?", e.event_name, ^"#{category}_%"))
          |> where([e], e.timestamp < ^cutoff)
          |> Repo.delete_all()
        
        {String.to_atom(category), deleted}
      end)
    
    Map.new(results)
  end
  
  @doc """
  Get retention period in days for an event name.
  
  ## Examples
  
      iex> SayMyName.Analytics.get_retention_days("page_view_landing")
      90
      
      iex> SayMyName.Analytics.get_retention_days("pronunciation_generated")
      180
  """
  @spec get_retention_days(String.t()) :: integer()
  def get_retention_days(event_name) do
    category = 
      event_name
      |> String.split("_")
      |> List.first()
    
    Map.get(@retention_days, category, 30)
  end
  
  # Private helpers
  
  defp maybe_sanitize_user_context(%{user_context: user_context} = attrs) when is_map(user_context) do
    sanitized = Privacy.build_user_context(user_context)
    Map.put(attrs, :user_context, sanitized)
  end
  
  defp maybe_sanitize_user_context(attrs), do: attrs
end

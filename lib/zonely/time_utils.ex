defmodule Zonely.TimeUtils do
  @moduledoc """
  Utility functions for time calculations and conversions using Elixir's standard library.
  
  This module focuses on leveraging built-in Elixir/Erlang functionality for time operations
  without requiring external dependencies.
  """

  @edge_minutes 60

  @doc """
  Converts fraction of day to UTC DateTime range using Elixir's standard library.
  
  ## Examples
  
      iex> Zonely.TimeUtils.frac_to_utc(0.5, 0.75, "UTC", ~D[2023-12-01])
      {~U[2023-12-01 12:00:00Z], ~U[2023-12-01 18:00:00Z]}
  """
  @spec frac_to_utc(float(), float(), String.t(), Date.t()) :: {DateTime.t(), DateTime.t()}
  def frac_to_utc(a, b, _viewer_tz, date) do
    {a, b} = if a <= b, do: {a, b}, else: {b, a}
    minutes = fn f -> round(f * 24 * 60) end

    # Use NaiveDateTime and convert to UTC using standard library
    start_naive = NaiveDateTime.new!(date, ~T[00:00:00])
    
    from_naive = NaiveDateTime.add(start_naive, minutes.(a) * 60, :second)
    to_naive = NaiveDateTime.add(start_naive, minutes.(b) * 60, :second)

    # Convert to UTC DateTime using standard library
    from_utc = DateTime.from_naive!(from_naive, "Etc/UTC")
    to_utc = DateTime.from_naive!(to_naive, "Etc/UTC")

    {from_utc, to_utc}
  end

  @doc """
  Classifies user availability during a time period.
  
  ## Examples
  
      iex> user = %{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      iex> from_utc = ~U[2023-12-01 10:00:00Z]
      iex> to_utc = ~U[2023-12-01 11:00:00Z]
      iex> Zonely.TimeUtils.classify_user(user, from_utc, to_utc)
      :working
  """
  @spec classify_user(map(), DateTime.t(), DateTime.t()) :: :working | :edge | :off
  def classify_user(user, from_utc, to_utc) do
    # Convert UTC times to minutes since midnight
    fmin = from_utc.hour * 60 + from_utc.minute
    tmin = to_utc.hour * 60 + to_utc.minute

    ws = time_to_minutes(user.work_start)
    we = time_to_minutes(user.work_end)

    # Simple overlap check (not timezone-aware for MVP)
    in_work = overlap?(fmin, tmin, ws, we)
    near_edge = within_edge?(fmin, tmin, ws, we, @edge_minutes)

    cond do
      in_work -> :working
      near_edge -> :edge
      true -> :off
    end
  end

  @doc """
  Converts status atom to integer for efficient JSON payload.
  
  ## Examples
  
      iex> Zonely.TimeUtils.status_to_int(:working)
      2
      iex> Zonely.TimeUtils.status_to_int(:edge)
      1
      iex> Zonely.TimeUtils.status_to_int(:off)
      0
  """
  @spec status_to_int(:working | :edge | :off) :: 0..2
  def status_to_int(:working), do: 2
  def status_to_int(:edge), do: 1
  def status_to_int(:off), do: 0

  @doc """
  Converts Time struct to minutes since midnight using standard library.
  
  ## Examples
  
      iex> Zonely.TimeUtils.time_to_minutes(~T[09:30:00])
      570
      iex> Zonely.TimeUtils.time_to_minutes(~T[00:00:00])
      0
      iex> Zonely.TimeUtils.time_to_minutes(~T[23:59:00])
      1439
  """
  @spec time_to_minutes(Time.t()) :: non_neg_integer()
  def time_to_minutes(%Time{hour: h, minute: m}), do: h * 60 + m

  @doc """
  Checks if two time ranges overlap using Erlang's min/max functions.
  
  ## Examples
  
      iex> Zonely.TimeUtils.overlap?(540, 600, 570, 630)
      true
      iex> Zonely.TimeUtils.overlap?(540, 570, 600, 630)
      false
  """
  @spec overlap?(integer(), integer(), integer(), integer()) :: boolean()
  def overlap?(a1, a2, b1, b2), do: max(a1, b1) < min(a2, b2)

  @doc """
  Checks if a time range is within edge minutes of work start/end.
  
  ## Examples
  
      iex> Zonely.TimeUtils.within_edge?(480, 540, 540, 1020, 60)
      true
  """
  @spec within_edge?(integer(), integer(), integer(), integer(), integer()) :: boolean()
  def within_edge?(a1, a2, ws, we, edge) do
    # any part of [a1,a2) within edge minutes of ws or we
    near_start = (ws - edge)..(ws + edge)
    near_end = (we - edge)..(we + edge)
    any_in?(a1, a2, near_start) or any_in?(a1, a2, near_end)
  end

  @doc """
  Formats time for display using standard library.
  
  ## Examples
  
      iex> Zonely.TimeUtils.format_time(~T[09:30:00])
      "09:30 AM"
      iex> Zonely.TimeUtils.format_time(~T[15:45:00])
      "03:45 PM"
  """
  @spec format_time(Time.t()) :: String.t()
  def format_time(%Time{} = time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  @doc """
  Gets current UTC time using standard library.
  
  ## Examples
  
      iex> utc_now = Zonely.TimeUtils.utc_now()
      iex> utc_now.__struct__
      DateTime
  """
  @spec utc_now() :: DateTime.t()
  def utc_now, do: DateTime.utc_now()

  @doc """
  Adds duration to datetime using standard library.
  
  ## Examples
  
      iex> dt = ~U[2023-12-01 10:00:00Z]
      iex> Zonely.TimeUtils.add_minutes(dt, 30)
      ~U[2023-12-01 10:30:00Z]
  """
  @spec add_minutes(DateTime.t(), integer()) :: DateTime.t()
  def add_minutes(%DateTime{} = datetime, minutes) do
    DateTime.add(datetime, minutes * 60, :second)
  end

  @doc """
  Calculates difference between two datetimes in minutes using standard library.
  
  ## Examples
  
      iex> dt1 = ~U[2023-12-01 10:00:00Z]
      iex> dt2 = ~U[2023-12-01 10:30:00Z]
      iex> Zonely.TimeUtils.diff_minutes(dt2, dt1)
      30
  """
  @spec diff_minutes(DateTime.t(), DateTime.t()) :: integer()
  def diff_minutes(%DateTime{} = dt1, %DateTime{} = dt2) do
    DateTime.diff(dt1, dt2, :second) |> div(60)
  end

  @doc """
  Converts naive datetime to UTC using standard library.
  
  ## Examples
  
      iex> naive = ~N[2023-12-01 10:00:00]
      iex> Zonely.TimeUtils.to_utc(naive)
      ~U[2023-12-01 10:00:00Z]
  """
  @spec to_utc(NaiveDateTime.t()) :: DateTime.t()
  def to_utc(%NaiveDateTime{} = naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Etc/UTC")
  end

  # Private helper functions

  defp any_in?(a1, a2, range) do
    # Handle the case where a2 might be less than a1
    start_range = min(a1, a2 - 1)
    end_range = max(a1, a2 - 1)
    Enum.any?(start_range..end_range, &(&1 in range))
  end
end
defmodule Zonely.Reachability do
  @moduledoc """
  Map-centric reachability language and calculations.

  This module is the product boundary for the V1 question:
  "Who can I reasonably reach right now?"
  """

  alias Zonely.Accounts.User
  alias Zonely.Geography
  alias Zonely.WorkingHours

  @type status :: :working | :edge | :off
  @type transition :: %{
          type: :workday_start | :workday_end | :back_tomorrow,
          instant: DateTime.t() | nil,
          local_time_label: String.t(),
          text: String.t()
        }

  @spec effective_at(DateTime.t() | nil, DateTime.t()) :: DateTime.t()
  def effective_at(%DateTime{} = preview_at, %DateTime{}), do: preview_at
  def effective_at(nil, %DateTime{} = live_now), do: live_now

  @spec status(User.t(), DateTime.t()) :: status()
  def status(%User{} = user, %DateTime{} = now \\ DateTime.utc_now()) do
    user
    |> local_time(now)
    |> then(&WorkingHours.classify_status(user, &1))
  end

  @spec summary([User.t()], DateTime.t()) :: %{
          working: non_neg_integer(),
          edge: non_neg_integer(),
          off: non_neg_integer(),
          timezones: %{String.t() => non_neg_integer()}
        }
  def summary(users, %DateTime{} = now \\ DateTime.utc_now()) when is_list(users) do
    status_counts = Enum.group_by(users, &status(&1, now))
    timezone_counts = Enum.frequencies_by(users, & &1.timezone)

    %{
      working: length(Map.get(status_counts, :working, [])),
      edge: length(Map.get(status_counts, :edge, [])),
      off: length(Map.get(status_counts, :off, [])),
      timezones: timezone_counts
    }
  end

  @spec marker_state(User.t(), DateTime.t()) :: String.t()
  def marker_state(%User{} = user, %DateTime{} = now \\ DateTime.utc_now()) do
    user
    |> status(now)
    |> Atom.to_string()
  end

  @spec orbit_status_class(User.t(), DateTime.t()) :: String.t()
  def orbit_status_class(%User{} = user, %DateTime{} = now \\ DateTime.utc_now()) do
    case status(user, now) do
      :working -> "is-working"
      :edge -> "is-edge"
      :off -> "is-off"
    end
  end

  @spec status_label(User.t(), DateTime.t()) :: String.t()
  def status_label(%User{} = user, %DateTime{} = now \\ DateTime.utc_now()) do
    case status(user, now) do
      :working -> "Reachable now"
      :edge -> "Ask carefully"
      :off -> "Wait"
    end
  end

  @spec reachable_label(non_neg_integer()) :: String.t()
  def reachable_label(1), do: "1 teammate reachable now"
  def reachable_label(count), do: "#{count} teammates reachable now"

  @spec format_count(non_neg_integer(), String.t()) :: String.t()
  def format_count(1, label), do: "1 #{label}"
  def format_count(count, label), do: "#{count} #{label}"

  @spec local_time_label(String.t() | nil, DateTime.t()) :: String.t()
  def local_time_label(timezone, now \\ DateTime.utc_now())

  def local_time_label(timezone, %DateTime{} = now) when is_binary(timezone) do
    case DateTime.shift_zone(now, timezone) do
      {:ok, datetime} -> Calendar.strftime(datetime, "%H:%M")
      _error -> "--:--"
    end
  end

  def local_time_label(_timezone, _now), do: "--:--"

  @spec local_date_label(User.t(), DateTime.t()) :: String.t()
  def local_date_label(%User{} = user, %DateTime{} = now) do
    user
    |> local_datetime(now)
    |> case do
      %DateTime{} = datetime -> Calendar.strftime(datetime, "%Y-%m-%d")
    end
  end

  @spec offset_label(String.t() | nil, DateTime.t()) :: String.t()
  def offset_label(timezone, now \\ DateTime.utc_now())

  def offset_label(timezone, %DateTime{} = now) when is_binary(timezone) do
    case DateTime.shift_zone(now, timezone) do
      {:ok, datetime} -> format_utc_offset(datetime.utc_offset + datetime.std_offset)
      _error -> "UTC"
    end
  end

  def offset_label(_timezone, _now), do: "UTC"

  @spec daylight_context_label(User.t(), DateTime.t()) :: String.t()
  def daylight_context_label(%User{} = user, %DateTime{} = now) do
    case local_datetime(user, now) do
      %DateTime{hour: hour} when hour in 5..7 -> "sunrise"
      %DateTime{hour: hour} when hour in 8..16 -> "daylight"
      %DateTime{hour: hour} when hour in 17..19 -> "dusk"
      %DateTime{} -> "night"
    end
  end

  @spec decision_sentence(User.t(), DateTime.t()) :: String.t()
  def decision_sentence(%User{} = user, %DateTime{} = now) do
    local_time = local_time_label(user.timezone, now)

    case status(user, now) do
      :working ->
        "This is a good moment to reach out. Local time is #{local_time} and the workday is active."

      :edge ->
        transition = next_transition(user, now)

        "Ask carefully: local time is #{local_time}, near a work-hour boundary. #{transition.text}."

      :off ->
        transition = next_transition(user, now)
        transition_text = String.replace_prefix(transition.text, "Back", "back")

        "Wait for a better moment: local time is #{local_time}, outside normal work hours; #{transition_text}."
    end
  end

  @spec context_sentence(User.t(), DateTime.t()) :: String.t()
  def context_sentence(%User{} = user, %DateTime{} = now \\ DateTime.utc_now()) do
    country = Geography.country_name(user.country)
    local_time = local_time_label(user.timezone, now)

    case status(user, now) do
      :working ->
        "Good time: #{country} is in the work window. Local time is #{local_time}."

      :edge ->
        "Use care: #{country} is near a work-hour boundary. Local time is #{local_time}."

      :off ->
        "Wait: #{country} is outside normal work hours. Local time is #{local_time}."
    end
  end

  @spec next_transition(User.t(), DateTime.t()) :: transition()
  def next_transition(%User{work_start: %Time{}, work_end: %Time{}} = user, %DateTime{} = now) do
    with %DateTime{} = local_now <- local_datetime(user, now),
         {:ok, transition_local} <- next_transition_local(user, local_now),
         {:ok, transition_utc} <- DateTime.shift_zone(transition_local, "Etc/UTC") do
      type = transition_type(user, local_now, transition_local)
      local_time = Calendar.strftime(transition_local, "%H:%M")

      %{
        type: type,
        instant: transition_utc,
        local_time_label: local_time,
        text: transition_text(type, local_time)
      }
    else
      _error ->
        %{
          type: :workday_start,
          instant: nil,
          local_time_label: "--:--",
          text: "Workday starts at --:--"
        }
    end
  end

  def next_transition(_user, _now) do
    %{
      type: :workday_start,
      instant: nil,
      local_time_label: "--:--",
      text: "Workday starts at --:--"
    }
  end

  defp next_transition_local(%User{work_start: work_start, work_end: work_end} = user, local_now) do
    local_date = DateTime.to_date(local_now)
    local_time = DateTime.to_time(local_now)

    cond do
      WorkingHours.is_working?(user, local_time) ->
        DateTime.new(local_date, work_end, local_now.time_zone)

      Time.compare(local_time, work_start) == :lt ->
        DateTime.new(local_date, work_start, local_now.time_zone)

      true ->
        local_date
        |> Date.add(1)
        |> DateTime.new(work_start, local_now.time_zone)
    end
  end

  defp transition_type(%User{work_end: work_end}, local_now, transition_local) do
    cond do
      DateTime.to_date(transition_local) != DateTime.to_date(local_now) -> :back_tomorrow
      Time.compare(DateTime.to_time(transition_local), work_end) == :eq -> :workday_end
      true -> :workday_start
    end
  end

  defp transition_text(:workday_end, local_time), do: "Workday ends at #{local_time}"
  defp transition_text(:workday_start, local_time), do: "Workday starts at #{local_time}"
  defp transition_text(:back_tomorrow, local_time), do: "Back tomorrow at #{local_time}"

  defp local_time(%User{timezone: timezone}, %DateTime{} = now) when is_binary(timezone) do
    case DateTime.shift_zone(now, timezone) do
      {:ok, datetime} -> DateTime.to_time(datetime)
      _error -> DateTime.to_time(now)
    end
  end

  defp local_time(_user, %DateTime{} = now), do: DateTime.to_time(now)

  defp local_datetime(%User{timezone: timezone}, %DateTime{} = now) when is_binary(timezone) do
    case DateTime.shift_zone(now, timezone) do
      {:ok, datetime} -> datetime
      _error -> now
    end
  end

  defp local_datetime(_user, %DateTime{} = now), do: now

  defp format_utc_offset(total_seconds) do
    sign = if total_seconds < 0, do: "-", else: "+"
    abs_seconds = abs(total_seconds)
    hours = div(abs_seconds, 3600)
    minutes = div(rem(abs_seconds, 3600), 60)

    "UTC#{sign}#{String.pad_leading(to_string(hours), 2, "0")}:#{String.pad_leading(to_string(minutes), 2, "0")}"
  end
end

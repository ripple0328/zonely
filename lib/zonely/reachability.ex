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

  @spec offset_label(String.t() | nil, DateTime.t()) :: String.t()
  def offset_label(timezone, now \\ DateTime.utc_now())

  def offset_label(timezone, %DateTime{} = now) when is_binary(timezone) do
    case DateTime.shift_zone(now, timezone) do
      {:ok, datetime} -> format_utc_offset(datetime.utc_offset + datetime.std_offset)
      _error -> "UTC"
    end
  end

  def offset_label(_timezone, _now), do: "UTC"

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

  defp local_time(%User{timezone: timezone}, %DateTime{} = now) when is_binary(timezone) do
    case DateTime.shift_zone(now, timezone) do
      {:ok, datetime} -> DateTime.to_time(datetime)
      _error -> DateTime.to_time(now)
    end
  end

  defp local_time(_user, %DateTime{} = now), do: DateTime.to_time(now)

  defp format_utc_offset(total_seconds) do
    sign = if total_seconds < 0, do: "-", else: "+"
    abs_seconds = abs(total_seconds)
    hours = div(abs_seconds, 3600)
    minutes = div(rem(abs_seconds, 3600), 60)

    "UTC#{sign}#{String.pad_leading(to_string(hours), 2, "0")}:#{String.pad_leading(to_string(minutes), 2, "0")}"
  end
end

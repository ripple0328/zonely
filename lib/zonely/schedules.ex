defmodule Zonely.Schedules do
  @moduledoc """
  Pure work-window schedule evaluation.

  This module evaluates plain in-memory schedule data at an explicit instant
  and IANA timezone. It is intentionally additive and does not depend on
  persistence, controllers, LiveView, `Zonely.WorkingHours`, hidden clocks, or
  outbound integrations.
  """

  alias Zonely.Availability.Evidence

  @boundary_minutes 30

  @type validation_error :: %{code: atom(), message: String.t()}

  @doc """
  Evaluates a plain schedule at an explicit instant in the provided IANA timezone.

  Expected schedule shape:

      %{
        working_days: [:monday, :tuesday, :wednesday, :thursday, :friday],
        windows: [%{start: ~T[09:00:00], end: ~T[17:00:00]}]
      }

  `working_days` may contain atoms or strings. Window `start` and `end` values
  may be `Time` structs or ISO8601 time strings. Windows are start-inclusive and
  end-exclusive. No default business hours are invented.
  """
  @spec evaluate(term(), term(), term()) :: {:ok, map()} | {:error, validation_error()}
  def evaluate(schedule, effective_at, timezone) do
    with {:ok, timezone} <- normalize_timezone(timezone),
         {:ok, effective_at} <- normalize_effective_at(effective_at),
         {:ok, schedule} <- normalize_schedule(schedule),
         {:ok, local_datetime} <- DateTime.shift_zone(effective_at, timezone) do
      local_date = DateTime.to_date(local_datetime)
      local_time = local_datetime |> DateTime.to_time() |> Time.truncate(:second)
      weekday = weekday(local_date)

      schedule
      |> evaluate_local_day(
        effective_at,
        timezone,
        local_datetime,
        local_date,
        local_time,
        weekday
      )
      |> build_result(schedule, effective_at, timezone, local_datetime, local_date, local_time)
    else
      {:error, %{code: :time_zone_not_found}} -> invalid_timezone()
      {:error, %{} = reason} -> {:error, reason}
      {:error, _reason} -> invalid_timezone()
    end
  end

  defp normalize_timezone(timezone) when is_binary(timezone) do
    timezone = String.trim(timezone)

    if timezone == "" do
      invalid_timezone()
    else
      case DateTime.shift_zone(~U[2026-01-01 00:00:00Z], timezone) do
        {:ok, _datetime} -> {:ok, timezone}
        {:error, _reason} -> invalid_timezone()
      end
    end
  end

  defp normalize_timezone(_timezone), do: invalid_timezone()

  defp normalize_effective_at(%DateTime{} = effective_at) do
    case DateTime.shift_zone(effective_at, "Etc/UTC") do
      {:ok, utc_datetime} -> {:ok, DateTime.truncate(utc_datetime, :second)}
      {:error, _reason} -> invalid_timestamp()
    end
  end

  defp normalize_effective_at(effective_at) when is_binary(effective_at) do
    effective_at = String.trim(effective_at)

    case DateTime.from_iso8601(effective_at) do
      {:ok, utc_datetime, _offset} -> {:ok, DateTime.truncate(utc_datetime, :second)}
      {:error, _reason} -> invalid_timestamp()
    end
  end

  defp normalize_effective_at(_effective_at), do: invalid_timestamp()

  defp normalize_schedule(schedule) when is_map(schedule) do
    with {:ok, working_days} <- normalize_working_days(value(schedule, :working_days)),
         {:ok, windows} <- normalize_windows(value(schedule, :windows)),
         {:ok, boundary_minutes} <-
           normalize_boundary_minutes(value(schedule, :boundary_minutes, @boundary_minutes)) do
      {:ok, %{working_days: working_days, windows: windows, boundary_minutes: boundary_minutes}}
    end
  end

  defp normalize_schedule(_schedule), do: invalid_schedule("schedule must be a map")

  defp normalize_working_days(days) when is_list(days) and days != [] do
    days
    |> Enum.reduce_while({:ok, MapSet.new()}, fn day, {:ok, acc} ->
      case normalize_weekday(day) do
        {:ok, weekday} -> {:cont, {:ok, MapSet.put(acc, weekday)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, days} ->
        if MapSet.size(days) > 0 do
          {:ok, days}
        else
          invalid_schedule("working_days must not be empty")
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_working_days(_days),
    do: invalid_schedule("working_days must be a non-empty list")

  defp normalize_weekday(day) when is_atom(day),
    do: day |> Atom.to_string() |> normalize_weekday()

  defp normalize_weekday(day) when is_binary(day) do
    day =
      day
      |> String.trim()
      |> String.downcase()

    if day in weekday_names() do
      {:ok, day}
    else
      invalid_schedule("working_days contains an unsupported day")
    end
  end

  defp normalize_weekday(_day), do: invalid_schedule("working_days contains an unsupported day")

  defp normalize_windows(windows) when is_list(windows) and windows != [] do
    windows
    |> Enum.reduce_while({:ok, []}, fn window, {:ok, acc} ->
      case normalize_window(window) do
        {:ok, window} -> {:cont, {:ok, [window | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, windows} -> {:ok, Enum.sort_by(windows, &time_seconds(&1.start))}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_windows(_windows), do: invalid_schedule("windows must be a non-empty list")

  defp normalize_window(window) when is_map(window) do
    with {:ok, start_time} <- normalize_time(value(window, :start), :start),
         {:ok, end_time} <- normalize_time(value(window, :end), :end),
         :ok <- validate_window_order(start_time, end_time) do
      {:ok, %{start: start_time, end: end_time}}
    end
  end

  defp normalize_window(_window), do: invalid_schedule("each window must be a map")

  defp normalize_time(%Time{} = time, _field), do: {:ok, Time.truncate(time, :second)}

  defp normalize_time(time, field) when is_binary(time) do
    case Time.from_iso8601(String.trim(time)) do
      {:ok, time} -> {:ok, Time.truncate(time, :second)}
      {:error, _reason} -> invalid_schedule("#{field} must be an ISO8601 time")
    end
  end

  defp normalize_time(_time, field),
    do: invalid_schedule("#{field} must be a Time or ISO8601 time")

  defp validate_window_order(start_time, end_time) do
    if Time.compare(start_time, end_time) == :lt do
      :ok
    else
      invalid_schedule("window start must be before window end")
    end
  end

  defp normalize_boundary_minutes(minutes)
       when is_integer(minutes) and minutes >= 0 and minutes <= 240,
       do: {:ok, minutes}

  defp normalize_boundary_minutes(_minutes),
    do: invalid_schedule("boundary_minutes must be an integer from 0 to 240")

  defp evaluate_local_day(
         schedule,
         effective_at,
         timezone,
         local_datetime,
         local_date,
         local_time,
         weekday
       ) do
    if MapSet.member?(schedule.working_days, weekday) do
      classify_against_windows(schedule.windows, schedule.boundary_minutes, local_time)
    else
      %{
        state: "non_working_day",
        reason_codes: ["non_working_day"],
        window: nil,
        next_transition: next_work_start(schedule, local_date, timezone, effective_at),
        evidence_kind: :non_working_day
      }
    end
    |> Map.put(:local_datetime, local_datetime)
  end

  defp classify_against_windows(windows, boundary_minutes, local_time) do
    boundary_seconds = boundary_minutes * 60

    Enum.reduce_while(windows, nil, fn window, _acc ->
      relation = relation_to_window(window, local_time, boundary_seconds)

      case relation.state do
        "outside_work_window" -> {:cont, relation}
        _state -> {:halt, relation}
      end
    end)
    |> case do
      nil ->
        outside_work_window()

      %{state: "outside_work_window"} = relation ->
        relation

      relation ->
        relation
    end
  end

  defp relation_to_window(window, local_time, boundary_seconds) do
    start_seconds = time_seconds(window.start)
    end_seconds = time_seconds(window.end)
    current_seconds = time_seconds(local_time)

    cond do
      current_seconds >= start_seconds and current_seconds < end_seconds ->
        classify_inside_window(
          window,
          current_seconds,
          start_seconds,
          end_seconds,
          boundary_seconds
        )

      current_seconds < start_seconds and start_seconds - current_seconds <= boundary_seconds ->
        %{
          state: "near_work_boundary",
          reason_codes: ["outside_work_window", "before_work_window_start"],
          window: window,
          next_transition_type: "work_window_start",
          evidence_kind: :work_window
        }

      current_seconds >= end_seconds and current_seconds - end_seconds <= boundary_seconds ->
        %{
          state: "near_work_boundary",
          reason_codes: ["outside_work_window", "after_work_window_end"],
          window: window,
          next_transition_type: "work_window_end",
          evidence_kind: :work_window
        }

      true ->
        outside_work_window()
    end
  end

  defp classify_inside_window(
         window,
         current_seconds,
         start_seconds,
         end_seconds,
         boundary_seconds
       ) do
    cond do
      current_seconds - start_seconds <= boundary_seconds ->
        %{
          state: "near_work_boundary",
          reason_codes: ["inside_work_window", "near_work_window_start"],
          window: window,
          next_transition_type: "work_window_end",
          evidence_kind: :work_window
        }

      end_seconds - current_seconds <= boundary_seconds ->
        %{
          state: "near_work_boundary",
          reason_codes: ["inside_work_window", "near_work_window_end"],
          window: window,
          next_transition_type: "work_window_end",
          evidence_kind: :work_window
        }

      true ->
        %{
          state: "inside_work_window",
          reason_codes: ["inside_work_window"],
          window: window,
          next_transition_type: "work_window_end",
          evidence_kind: :work_window
        }
    end
  end

  defp outside_work_window do
    %{
      state: "outside_work_window",
      reason_codes: ["outside_work_window"],
      window: nil,
      next_transition_type: nil,
      evidence_kind: :data_missing
    }
  end

  defp build_result(
         evaluation,
         schedule,
         effective_at,
         timezone,
         local_datetime,
         local_date,
         local_time
       ) do
    with {:ok, base_evidence} <- local_time_evidence(timezone, effective_at, local_datetime),
         {:ok, work_window} <- work_window_projection(evaluation.window, local_date, timezone),
         {:ok, state_evidence} <- state_evidence(evaluation, local_date, timezone, work_window),
         {:ok, evidence} <- Evidence.merge([base_evidence, state_evidence]),
         {:ok, next_transition} <-
           next_transition_projection(evaluation, schedule, local_date, timezone, effective_at) do
      {:ok,
       %{
         state: evaluation.state,
         reason_codes: evaluation.reason_codes,
         timezone: timezone,
         effective_at: format_datetime(effective_at),
         local_date: Date.to_iso8601(local_date),
         local_time: Time.to_iso8601(local_time),
         utc_offset: format_utc_offset(local_datetime.utc_offset + local_datetime.std_offset),
         work_window: work_window,
         next_transition: next_transition,
         evidence: evidence
       }}
    end
  end

  defp local_time_evidence(timezone, effective_at, local_datetime) do
    local_date = local_datetime |> DateTime.to_date() |> Date.to_iso8601()

    local_time =
      local_datetime |> DateTime.to_time() |> Time.truncate(:second) |> Time.to_iso8601()

    utc_offset = format_utc_offset(local_datetime.utc_offset + local_datetime.std_offset)

    Evidence.normalize(%{
      type: "local_time",
      impact: "informational",
      source: "iana_timezone_database",
      confidence: "high",
      label: "Local time in #{timezone}",
      observed_on: local_date,
      metadata: %{
        timezone: timezone,
        effective_at: format_datetime(effective_at),
        local_date: local_date,
        local_time: local_time,
        utc_offset: utc_offset
      }
    })
  end

  defp work_window_projection(nil, _local_date, _timezone), do: {:ok, nil}

  defp work_window_projection(window, local_date, timezone) do
    with {:ok, starts_at} <- local_to_utc(local_date, window.start, timezone),
         {:ok, ends_at} <- local_to_utc(local_date, window.end, timezone) do
      {:ok,
       %{
         start_time: Time.to_iso8601(window.start),
         end_time: Time.to_iso8601(window.end),
         starts_at: format_datetime(starts_at),
         ends_at: format_datetime(ends_at)
       }}
    end
  end

  defp state_evidence(%{evidence_kind: :non_working_day}, local_date, _timezone, _work_window) do
    Evidence.normalize(%{
      type: "weekend_or_non_working_day",
      impact: "blocks_scheduling",
      source: "schedule",
      confidence: "high",
      label: "Configured non-working day",
      observed_on: local_date,
      metadata: %{reason_code: "non_working_day"}
    })
  end

  defp state_evidence(
         %{state: "outside_work_window", window: nil},
         local_date,
         _timezone,
         _work_window
       ) do
    Evidence.normalize(%{
      type: "work_window",
      impact: "discourages_reachability",
      source: "schedule",
      confidence: "high",
      label: "Outside configured work windows",
      observed_on: local_date,
      metadata: %{reason_code: "outside_work_window"}
    })
  end

  defp state_evidence(evaluation, _local_date, _timezone, work_window) do
    Evidence.normalize(%{
      type: "work_window",
      impact: work_window_impact(evaluation.state),
      source: "schedule",
      confidence: "high",
      label: "Configured work window",
      starts_at: work_window.starts_at,
      ends_at: work_window.ends_at,
      metadata: %{
        state: evaluation.state,
        reason_codes: evaluation.reason_codes,
        start_time: work_window.start_time,
        end_time: work_window.end_time
      }
    })
  end

  defp work_window_impact("inside_work_window"), do: "informational"
  defp work_window_impact(_state), do: "discourages_reachability"

  defp next_transition_projection(
         %{window: window, next_transition_type: type},
         schedule,
         local_date,
         timezone,
         effective_at
       )
       when not is_nil(window) and not is_nil(type) do
    transition_time =
      case type do
        "work_window_start" -> window.start
        "work_window_end" -> window.end
      end

    with {:ok, at} <- local_to_utc(local_date, transition_time, timezone) do
      if future_datetime?(at, effective_at) do
        transition_projection(type, at, local_date, transition_time)
      else
        next_transition_projection(
          %{next_transition: next_work_start(schedule, local_date, timezone, effective_at)},
          schedule,
          local_date,
          timezone,
          effective_at
        )
      end
    end
  end

  defp next_transition_projection(
         %{next_transition: nil},
         _schedule,
         _local_date,
         _timezone,
         _effective_at
       ),
       do: {:ok, nil}

  defp next_transition_projection(
         %{next_transition: %{date: date, time: time, type: type}},
         _schedule,
         _local_date,
         timezone,
         effective_at
       ) do
    with {:ok, at} <- local_to_utc(date, time, timezone),
         true <- future_datetime?(at, effective_at) do
      transition_projection(type, at, date, time)
    else
      false -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  defp next_transition_projection(_evaluation, schedule, local_date, timezone, effective_at) do
    transition = next_work_start(schedule, local_date, timezone, effective_at)

    next_transition_projection(
      %{next_transition: transition},
      schedule,
      local_date,
      timezone,
      effective_at
    )
  end

  defp transition_evidence(type, at, local_date, local_time) do
    Evidence.normalize(%{
      type: "work_window",
      impact: "informational",
      source: "schedule",
      confidence: "high",
      label: "Next work-window transition",
      starts_at: at,
      ends_at: DateTime.add(at, 1, :second),
      metadata: %{
        transition_type: type,
        local_date: Date.to_iso8601(local_date),
        local_time: Time.to_iso8601(local_time)
      }
    })
  end

  defp transition_projection(type, at, local_date, local_time) do
    with {:ok, evidence} <- transition_evidence(type, at, local_date, local_time) do
      {:ok,
       %{
         type: type,
         at: format_datetime(at),
         local_date: Date.to_iso8601(local_date),
         local_time: Time.to_iso8601(local_time),
         evidence: evidence
       }}
    end
  end

  defp next_work_start(schedule, local_date, timezone, effective_at) do
    first_window = List.first(schedule.windows)

    0..14
    |> Enum.find_value(fn offset ->
      candidate = Date.add(local_date, offset)

      if MapSet.member?(schedule.working_days, weekday(candidate)) do
        with {:ok, starts_at} <- local_to_utc(candidate, first_window.start, timezone),
             true <- future_datetime?(starts_at, effective_at) do
          %{type: "work_window_start", date: candidate, time: first_window.start}
        else
          _not_future_or_invalid -> nil
        end
      end
    end)
  end

  defp future_datetime?(candidate, effective_at),
    do: DateTime.compare(candidate, effective_at) == :gt

  defp local_to_utc(date, time, timezone) do
    case DateTime.new(date, time, timezone) do
      {:ok, local_datetime} ->
        DateTime.shift_zone(local_datetime, "Etc/UTC")

      {:ambiguous, first_datetime, _second_datetime} ->
        DateTime.shift_zone(first_datetime, "Etc/UTC")

      {:gap, _before_gap, after_gap} ->
        DateTime.shift_zone(after_gap, "Etc/UTC")

      {:error, _reason} ->
        invalid_timezone()
    end
  end

  defp weekday(date) do
    date
    |> Date.day_of_week()
    |> case do
      1 -> "monday"
      2 -> "tuesday"
      3 -> "wednesday"
      4 -> "thursday"
      5 -> "friday"
      6 -> "saturday"
      7 -> "sunday"
    end
  end

  defp weekday_names do
    ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
  end

  defp time_seconds(%Time{} = time), do: time.hour * 3600 + time.minute * 60 + time.second

  defp value(map, field, default \\ nil) do
    cond do
      Map.has_key?(map, field) -> Map.get(map, field)
      Map.has_key?(map, Atom.to_string(field)) -> Map.get(map, Atom.to_string(field))
      true -> default
    end
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:extended)
  end

  defp format_utc_offset(offset_seconds) do
    sign = if offset_seconds < 0, do: "-", else: "+"
    absolute_seconds = abs(offset_seconds)
    hours = absolute_seconds |> div(3600) |> Integer.to_string() |> String.pad_leading(2, "0")

    minutes =
      absolute_seconds
      |> rem(3600)
      |> div(60)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "UTC#{sign}#{hours}:#{minutes}"
  end

  defp invalid_timezone do
    {:error, %{code: :invalid_timezone, message: "timezone must be an IANA timezone name"}}
  end

  defp invalid_timestamp do
    {:error,
     %{code: :invalid_timestamp, message: "effective_at must be an explicit ISO8601 datetime"}}
  end

  defp invalid_schedule(message), do: {:error, %{code: :invalid_schedule, message: message}}
end

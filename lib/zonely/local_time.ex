defmodule Zonely.LocalTime do
  @moduledoc """
  Pure, deterministic local-time conversion primitive.

  Converts an explicit instant into local date/time facts for an IANA timezone
  using the configured time zone database. It does not depend on people, teams,
  schedules, reachability, UI state, or hidden clocks.
  """

  alias Zonely.Availability.Evidence

  @version "zonely.local_time.v1"

  @type validation_error :: %{code: atom(), message: String.t()}

  @doc """
  Evaluates local-time facts for an IANA timezone at an explicit instant.
  """
  @spec evaluate(term(), term()) :: {:ok, map()} | {:error, validation_error()}
  def evaluate(timezone, effective_at) do
    with {:ok, timezone} <- normalize_timezone(timezone),
         {:ok, effective_at} <- normalize_effective_at(effective_at),
         {:ok, local_datetime} <- shift_to_local(effective_at, timezone) do
      build_result(timezone, effective_at, local_datetime)
    end
  end

  @doc """
  Evaluates local-time facts and projects them into the V1 JSON-ready API shape.
  """
  @spec to_api(term(), term()) :: {:ok, map()} | {:error, validation_error()}
  def to_api(timezone, effective_at) do
    with {:ok, result} <- evaluate(timezone, effective_at) do
      {:ok, Map.put(result, :version, @version)}
    end
  end

  defp normalize_timezone(timezone) when is_binary(timezone) do
    timezone = String.trim(timezone)

    if timezone == "" do
      invalid_timezone()
    else
      validate_timezone_identity(timezone)
    end
  end

  defp normalize_timezone(_timezone), do: invalid_timezone()

  defp validate_timezone_identity(timezone) do
    case DateTime.shift_zone(~U[2026-01-01 00:00:00Z], timezone) do
      {:ok, _datetime} -> {:ok, timezone}
      {:error, _reason} -> invalid_timezone()
    end
  end

  defp normalize_effective_at(%DateTime{} = effective_at) do
    case DateTime.shift_zone(effective_at, "Etc/UTC") do
      {:ok, utc_datetime} -> {:ok, DateTime.truncate(utc_datetime, :second)}
      {:error, _reason} -> invalid_timestamp()
    end
  end

  defp normalize_effective_at(effective_at) when is_binary(effective_at) do
    effective_at = String.trim(effective_at)

    case DateTime.from_iso8601(effective_at) do
      {:ok, utc_datetime, _offset} ->
        {:ok, DateTime.truncate(utc_datetime, :second)}

      {:error, _reason} ->
        invalid_timestamp()
    end
  end

  defp normalize_effective_at(_effective_at), do: invalid_timestamp()

  defp shift_to_local(effective_at, timezone) do
    case DateTime.shift_zone(effective_at, timezone) do
      {:ok, local_datetime} -> {:ok, local_datetime}
      {:error, _reason} -> invalid_timezone()
    end
  end

  defp build_result(timezone, effective_at, local_datetime) do
    effective_at = format_datetime(effective_at)
    local_date = local_datetime |> DateTime.to_date() |> Date.to_iso8601()

    local_time =
      local_datetime |> DateTime.to_time() |> Time.truncate(:second) |> Time.to_iso8601()

    utc_offset = format_utc_offset(local_datetime.utc_offset + local_datetime.std_offset)

    evidence_candidate = %{
      type: "local_time",
      impact: "informational",
      source: "iana_timezone_database",
      confidence: "high",
      label: "Local time in #{timezone}",
      observed_on: local_date,
      metadata: %{
        timezone: timezone,
        effective_at: effective_at,
        local_date: local_date,
        local_time: local_time,
        utc_offset: utc_offset
      }
    }

    with {:ok, evidence} <- Evidence.normalize(evidence_candidate) do
      {:ok,
       %{
         timezone: timezone,
         effective_at: effective_at,
         local_date: local_date,
         local_time: local_time,
         utc_offset: utc_offset,
         evidence: evidence
       }}
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
    {:error,
     %{
       code: :invalid_timezone,
       message: "timezone must be an IANA timezone name"
     }}
  end

  defp invalid_timestamp do
    {:error,
     %{
       code: :invalid_timestamp,
       message: "at is required and must be an ISO8601 datetime"
     }}
  end
end

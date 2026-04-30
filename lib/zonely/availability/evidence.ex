defmodule Zonely.Availability.Evidence do
  @moduledoc """
  Canonical availability evidence normalization.

  This module keeps evidence as independent facts. It validates and normalizes
  point-in-date and interval evidence without computing reachability,
  schedulability, scores, reason codes, or next-best times.
  """

  @required_fields [:type, :impact, :source, :confidence, :label]

  @types MapSet.new([
           "calendar_busy",
           "company_holiday",
           "data_missing",
           "data_stale",
           "daylight",
           "focus_block",
           "local_time",
           "personal_leave",
           "preferred_meeting_window",
           "presence",
           "public_holiday",
           "team_no_meeting_window",
           "travel",
           "weekend_or_non_working_day",
           "work_window"
         ])

  @impacts MapSet.new([
             "blocks_scheduling",
             "busy",
             "discourages_reachability",
             "informational"
           ])

  @sources MapSet.new([
             "calendar",
             "company_calendar",
             "holiday_calendar",
             "iana_timezone_database",
             "import",
             "manual",
             "presence_provider",
             "public_holiday_calendar",
             "schedule",
             "system"
           ])

  @confidences MapSet.new(["high", "medium", "low"])

  @type validation_error :: %{code: atom(), message: String.t()}
  @type canonical :: map()

  @doc """
  Builds a canonical evidence record from a candidate evidence map.
  """
  @spec new(term()) :: {:ok, canonical()} | {:error, validation_error()}
  def new(candidate), do: normalize(candidate)

  @doc """
  Normalizes one candidate evidence map into the canonical JSON-safe shape.
  """
  @spec normalize(term()) :: {:ok, canonical()} | {:error, validation_error()}
  def normalize(candidate) when is_map(candidate) do
    with {:ok, core} <- normalize_core(candidate),
         {:ok, temporal} <- normalize_temporal(candidate),
         {:ok, metadata} <- normalize_metadata(value(candidate, :metadata, %{})) do
      {:ok, Map.merge(core, temporal) |> Map.put(:metadata, metadata)}
    end
  end

  def normalize(_candidate) do
    {:error,
     %{
       code: :invalid_evidence,
       message: "evidence must be a map"
     }}
  end

  @doc """
  Normalizes a collection of evidence records, removes exact canonical
  duplicates, and returns a deterministic order.

  Duplicate policy: two evidence records are duplicates only when their full
  canonical maps are equal after normalization. Similar facts with different
  metadata, labels, sources, impacts, confidence, or temporal anchors remain
  separate.
  """
  @spec merge(term()) :: {:ok, [canonical()]} | {:error, validation_error()}
  def merge(evidence) when is_list(evidence) do
    evidence
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {candidate, index}, {:ok, acc} ->
      case normalize(candidate) do
        {:ok, normalized} ->
          {:cont, {:ok, [normalized | acc]}}

        {:error, reason} ->
          {:halt,
           {:error,
            %{
              code: :invalid_evidence,
              index: index,
              reason: reason,
              message: "evidence at index #{index} is invalid"
            }}}
      end
    end)
    |> case do
      {:ok, normalized} ->
        {:ok,
         normalized
         |> Enum.uniq()
         |> Enum.sort_by(&sort_key/1)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def merge(_evidence) do
    {:error,
     %{
       code: :invalid_evidence_collection,
       message: "evidence must be a list"
     }}
  end

  defp normalize_core(candidate) do
    with :ok <- validate_required_fields(candidate),
         {:ok, type} <- normalize_enum(candidate, :type, @types),
         {:ok, impact} <- normalize_enum(candidate, :impact, @impacts),
         {:ok, source} <- normalize_enum(candidate, :source, @sources),
         {:ok, confidence} <- normalize_enum(candidate, :confidence, @confidences),
         {:ok, label} <- normalize_label(value(candidate, :label)) do
      {:ok,
       %{
         type: type,
         impact: impact,
         source: source,
         confidence: confidence,
         label: label
       }}
    end
  end

  defp validate_required_fields(candidate) do
    case Enum.find(@required_fields, &(missing?(candidate, &1) or blank?(value(candidate, &1)))) do
      nil ->
        :ok

      field ->
        {:error,
         %{
           code: :missing_required_field,
           field: field,
           message: "#{field} is required"
         }}
    end
  end

  defp normalize_enum(candidate, field, allowed) do
    canonical =
      candidate
      |> value(field)
      |> enum_to_string()

    if MapSet.member?(allowed, canonical) do
      {:ok, canonical}
    else
      {:error,
       %{
         code: :"invalid_#{field}",
         field: field,
         value: canonical,
         message: "#{field} is not supported"
       }}
    end
  end

  defp normalize_label(label) when is_binary(label) do
    label = String.trim(label)

    if label == "" do
      {:error, %{code: :missing_required_field, field: :label, message: "label is required"}}
    else
      {:ok, label}
    end
  end

  defp normalize_label(_label) do
    {:error, %{code: :missing_required_field, field: :label, message: "label is required"}}
  end

  defp normalize_metadata(metadata) when is_map(metadata), do: {:ok, metadata}

  defp normalize_metadata(_metadata) do
    {:error,
     %{
       code: :invalid_metadata,
       message: "metadata must be a map"
     }}
  end

  defp normalize_temporal(candidate) do
    has_observed_on? = present?(candidate, :observed_on)
    has_starts_at? = present?(candidate, :starts_at)
    has_ends_at? = present?(candidate, :ends_at)

    cond do
      has_starts_at? or has_ends_at? ->
        normalize_interval(candidate, has_starts_at?, has_ends_at?)

      has_observed_on? ->
        normalize_observed_on(value(candidate, :observed_on))

      true ->
        {:error,
         %{
           code: :missing_temporal_anchor,
           message: "evidence requires observed_on or both starts_at and ends_at"
         }}
    end
  end

  defp normalize_interval(candidate, true, true) do
    with {:ok, starts_at} <- normalize_datetime(value(candidate, :starts_at), :starts_at),
         {:ok, ends_at} <- normalize_datetime(value(candidate, :ends_at), :ends_at),
         :ok <- validate_interval_order(starts_at, ends_at) do
      {:ok, %{starts_at: format_datetime(starts_at), ends_at: format_datetime(ends_at)}}
    end
  end

  defp normalize_interval(_candidate, false, true) do
    {:error,
     %{
       code: :invalid_temporal_anchor,
       field: :starts_at,
       message: "starts_at is required when ends_at is present"
     }}
  end

  defp normalize_interval(_candidate, true, false) do
    {:error,
     %{
       code: :invalid_temporal_anchor,
       field: :ends_at,
       message: "ends_at is required when starts_at is present"
     }}
  end

  defp normalize_observed_on(%Date{} = date), do: {:ok, %{observed_on: Date.to_iso8601(date)}}

  defp normalize_observed_on(observed_on) when is_binary(observed_on) do
    case Date.from_iso8601(observed_on) do
      {:ok, date} ->
        {:ok, %{observed_on: Date.to_iso8601(date)}}

      {:error, _reason} ->
        invalid_temporal_anchor(:observed_on, "observed_on must be an ISO8601 date")
    end
  end

  defp normalize_observed_on(_observed_on) do
    invalid_temporal_anchor(:observed_on, "observed_on must be a Date or ISO8601 date")
  end

  defp normalize_datetime(%DateTime{} = datetime, _field) do
    case DateTime.shift_zone(datetime, "Etc/UTC") do
      {:ok, utc_datetime} -> {:ok, utc_datetime}
      {:error, _reason} -> {:ok, datetime}
    end
  end

  defp normalize_datetime(datetime, field) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, utc_datetime, _offset} ->
        {:ok, utc_datetime}

      {:error, _reason} ->
        invalid_temporal_anchor(field, "#{field} must be an ISO8601 datetime")
    end
  end

  defp normalize_datetime(_datetime, field) do
    invalid_temporal_anchor(field, "#{field} must be a DateTime or ISO8601 datetime")
  end

  defp validate_interval_order(starts_at, ends_at) do
    if DateTime.compare(starts_at, ends_at) == :lt do
      :ok
    else
      {:error,
       %{
         code: :invalid_interval,
         message: "starts_at must be before ends_at"
       }}
    end
  end

  defp invalid_temporal_anchor(field, message) do
    {:error,
     %{
       code: :invalid_temporal_anchor,
       field: field,
       message: message
     }}
  end

  defp sort_key(evidence) do
    {
      evidence.type,
      Map.get(evidence, :observed_on, ""),
      Map.get(evidence, :starts_at, ""),
      Map.get(evidence, :ends_at, ""),
      evidence.impact,
      evidence.source,
      evidence.confidence,
      evidence.label,
      inspect(evidence.metadata, limit: :infinity, printable_limit: :infinity)
    }
  end

  defp value(map, field, default \\ nil)

  defp value(map, field, default) when is_map(map) do
    cond do
      Map.has_key?(map, field) -> Map.get(map, field)
      Map.has_key?(map, Atom.to_string(field)) -> Map.get(map, Atom.to_string(field))
      true -> default
    end
  end

  defp missing?(map, field), do: not present?(map, field)

  defp present?(map, field) do
    Map.has_key?(map, field) or Map.has_key?(map, Atom.to_string(field))
  end

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(value), do: is_nil(value)

  defp enum_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp enum_to_string(value) when is_binary(value), do: String.trim(value)
  defp enum_to_string(value), do: inspect(value)

  defp format_datetime(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:extended)
  end
end

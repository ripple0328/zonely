defmodule Zonely.PronunceName.Providers.NameShouts do
  @moduledoc false
  require Logger
  alias Zonely.PronunceName
  alias Zonely.Analytics

  # Legacy function for backward compatibility - delegates to fetch_single
  @spec fetch(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch(name, language) do
    fetch_single(name, language, name)
  end

  # Simplified function that handles a single name request
  @spec fetch_single(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch_single(name, language, original_name) do
    api_key = System.get_env("NS_API_KEY") |> to_string() |> String.trim()

    if api_key == "" do
      Logger.warning("No NameShouts API key configured (NS_API_KEY)")
      {:error, :no_api_key}
    else
      headers = [{"NS-API-KEY", api_key}, {"Accept", "application/json"}]
      lang_name = PronunceName.language_display_name_from_bcp47(language) |> String.downcase()

      Logger.info("🌐 NameShouts request for #{inspect(name)} lang=#{lang_name}")

      try_nameshouts_request(name, lang_name, headers, original_name, language)
    end
  end

  # Try a NameShouts request for a specific name
  defp try_nameshouts_request(name, lang_name, headers, original_name, language) do
    # Per docs, full-name path uses hyphen between parts when language is specified
    encoded_name_for_lang =
      name
      |> String.replace(~r/\s+/, "-")
      |> URI.encode()

    url_with_lang =
      "https://www.v1.nameshouts.com/api/names/#{encoded_name_for_lang}/#{URI.encode(lang_name)}"

    Logger.info("🌐 NameShouts single request to: #{url_with_lang}")

    started_ms = System.monotonic_time(:millisecond)
    case PronunceName.http_client().get(url_with_lang, headers) do
      {:ok, %{status: 200, body: body}} ->
        Analytics.track_async("external_api_call", %{provider: "name_shouts", status: 200, duration_ms: System.monotonic_time(:millisecond) - started_ms})
        Logger.info("🔍 DEBUG: NameShouts response body for '#{name}': #{inspect(body)}")
        handle_nameshouts_response(body, name, original_name, language)

      {:error, %Jason.DecodeError{data: data}} ->
        Logger.warning("NameShouts returned malformed JSON; attempting recovery")

        case PronunceName.recover_nameshouts_body_from_decode_error(data) do
          {:ok, body} ->
            handle_nameshouts_response(body, name, original_name, language)

          {:error, _} ->
            {:error, :invalid_response}
        end

      {:ok, %{status: 403}} ->
        Analytics.track_async("external_api_call", %{provider: "name_shouts", status: 403, duration_ms: System.monotonic_time(:millisecond) - started_ms})
        {:error, :invalid_api_key}

      {:ok, %{status: 404}} ->
        Analytics.track_async("external_api_call", %{provider: "name_shouts", status: 404, duration_ms: System.monotonic_time(:millisecond) - started_ms})
        Logger.info("❌ NameShouts: No pronunciation found for '#{name}'")
        {:error, :not_found}

      {:ok, %{status: status}} ->
        Analytics.track_async("external_api_call", %{provider: "name_shouts", status: status, duration_ms: System.monotonic_time(:millisecond) - started_ms})
        if status == 429 do
          Analytics.track_async("external_api_rate_limited", %{provider: "name_shouts", status: status})
        end
        {:error, :api_error}

      {:error, reason} ->
        Analytics.track_async("external_api_error", %{provider: "name_shouts", reason: inspect(reason)})
        {:error, :request_failed}
    end
  end

  # Handle NameShouts response and determine what it actually returned
  defp handle_nameshouts_response(body, requested_name, original_name, language) do
    case PronunceName.pick_nameshouts_variant(body, requested_name, language) do
      {:ok, paths} when is_list(paths) ->
        Logger.info(
          "🔗 NameShouts returned multiple paths (sequential playback): #{inspect(paths)}"
        )

        # Return direct URLs for sequential playback instead of concatenation
        urls =
          Enum.map(paths, fn path ->
            "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
          end)

        {:ok, {:sequence, urls}}

      {:ok, path} when is_binary(path) ->
        audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
        Logger.info("✅ NameShouts found audio for #{inspect(original_name)}; returning direct URL")

        Logger.info(
          "🔍 DEBUG: NameShouts returned path '#{path}' for requested name '#{requested_name}'"
        )

        # Detect which name part NameShouts actually returned based on the path
        actual_name_part = detect_actual_name_from_path(path, requested_name, original_name)

        # If full name requested but provider returned a single part:
        # - Accept if it is the FIRST name
        # - Reject if it is ONLY the LAST name (to avoid playing just the surname)
        parts = String.split(original_name, [" ", "-"], trim: true)
        name_has_multiple_parts = length(parts) > 1
        first_part = List.first(parts) || original_name
        last_part = List.last(parts) || original_name
        actual_is_first = String.downcase(actual_name_part) == String.downcase(first_part)
        actual_is_last = String.downcase(actual_name_part) == String.downcase(last_part)

        if name_has_multiple_parts and requested_name == original_name and
             actual_name_part != original_name and actual_is_last and not actual_is_first do
          Logger.info(
            "🚫 Rejecting last-name-only result ('#{actual_name_part}') for full name '#{original_name}'"
          )

          {:error, :partial_only}
        else
          {:ok, audio_url}
        end

      {:error, reason} ->
        Logger.info("❌ NameShouts has no pronunciation for: #{requested_name}")
        {:error, reason}
    end
  end

  # Detect which name part NameShouts actually returned based on the path
  @spec detect_actual_name_from_path(String.t(), String.t(), String.t()) :: String.t()
  defp detect_actual_name_from_path(path, requested_name, original_name) do
    Logger.info(
      "🔍 Detecting actual name from path '#{path}' (requested: '#{requested_name}', original: '#{original_name}')"
    )

    # Remove language suffix and convert to lowercase for analysis
    clean_path = path |> String.downcase() |> String.replace(~r/_[a-z]{2}$/, "")

    # Get all possible name parts from the original name
    original_parts = String.split(original_name, [" ", "-"], trim: true)

    Logger.info("🔍 Clean path: '#{clean_path}', original parts: #{inspect(original_parts)}")

    # Check if the path matches any specific name parts
    matching_parts =
      Enum.filter(original_parts, fn part ->
        String.contains?(clean_path, String.downcase(part))
      end)

    cond do
      # If path contains multiple name parts, likely represents full name
      length(matching_parts) > 1 ->
        Logger.info(
          "✅ Path contains multiple parts #{inspect(matching_parts)} - detected as full name"
        )

        original_name

      # If path contains exactly one name part, it's that specific part
      length(matching_parts) == 1 ->
        detected_part = List.first(matching_parts)
        Logger.info("📝 Path contains single part '#{detected_part}' - detected as partial")
        detected_part

      # If no obvious match, but we requested the full name, assume it's full
      requested_name == original_name ->
        Logger.info("⚠️ No clear match but requested full name - assuming full name")
        original_name

      # Otherwise, assume it's the part we requested
      true ->
        Logger.info("⚠️ No clear match - assuming requested part '#{requested_name}'")
        requested_name
    end
  end
end

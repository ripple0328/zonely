defmodule Zonely.PronunceName do
  @moduledoc """
  Unified module for name pronunciation functionality.

  This module provides a single, clean interface for all name pronunciation needs:
  - Fetching cached audio files
  - Downloading from external services (Forvo)
  - Falling back to text-to-speech

  ## Usage

      # For LiveView - returns ready-to-use event data
      {event_type, event_data} = PronunceName.play(name, language, country)
      push_event(socket, event_type, event_data)

      # Examples:
      PronunceName.play("María García", "es-ES", "ES")
      # → {:play_audio, %{url: "/audio/cache/maria_garcia.ogg"}}

      PronunceName.play("John Doe", "en-US", "US")
      # → {:play_tts, %{text: "John Doe", lang: "en-US"}}
  """

  require Logger

  @doc """
  Plays pronunciation for a name.

  This is the single public interface for all pronunciation functionality.
  Handles the complete flow:
  1. Check local cache
  2. Fetch from external services (Forvo)
  3. Fall back to text-to-speech

  ## Parameters
  - `name`: The name to pronounce (e.g., "María García")
  - `language`: Language code (e.g., "es-ES", "en-US") - can be nil
  - `country`: Country code for language derivation (e.g., "ES", "US")

  ## Returns
  - `{:play_audio, %{url: url}}` - for cached or downloaded audio files
  - `{:play_tts, %{text: text, lang: lang}}` - for text-to-speech fallback
  """
  @spec play(String.t(), String.t() | nil, String.t()) :: {:play_audio | :play_tts, map()}
  def play(name, language, country) when is_binary(name) and is_binary(country) do
    Logger.info("🎯 PronunceName.play: #{name} in #{language || "auto"} (#{country})")

    # Derive language from country if needed
    target_language = language || derive_language_from_country(country)

    # Try to get pronunciation
    case get_pronunciation(name, target_language, country) do
      {:audio_url, url} ->
        Logger.info("🔊 Using audio file: #{url}")
        {:play_audio, %{url: url}}

      {:tts, text, lang} ->
        Logger.info("🗣️ Using TTS: #{text} (#{lang})")
        {:play_tts, %{text: text, lang: lang}}
    end
  end

  # Private functions for internal logic

  @spec get_pronunciation(String.t(), String.t(), String.t()) ::
    {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  defp get_pronunciation(name, language, _country) do
    # Check cache first (TODO: implement proper cache lookup)
    # For now, try external service then fallback to TTS

    case fetch_from_external_service(name, language) do
      {:ok, audio_url} ->
        {:audio_url, audio_url}

      {:error, :not_found} ->
        # Fallback to TTS
        {:tts, name, language}
    end
  end

  @spec fetch_from_external_service(String.t(), String.t()) ::
    {:ok, String.t()} | {:error, :not_found}
  defp fetch_from_external_service(name, language) do
    # Try Forvo API
    case fetch_from_forvo(name, language) do
      {:ok, audio_url} -> {:ok, audio_url}
      {:error, _} -> {:error, :not_found}
    end
  end

  @spec fetch_from_forvo(String.t(), String.t()) ::
    {:ok, String.t()} | {:error, atom()}
  defp fetch_from_forvo(name, language) do
    # Get Forvo API key
    api_key = get_forvo_api_key()
    if !api_key do
      Logger.warning("No Forvo API key configured")
      {:error, :no_api_key}
    else
      # Convert language to Forvo format (e.g., "en-US" -> "en")
      forvo_lang = String.split(language, "-") |> List.first()

      # Try name variants
      name_variants = generate_name_variants(name)

      Enum.reduce_while(name_variants, {:error, :not_found}, fn variant, _acc ->
        case try_forvo_request(variant, forvo_lang, api_key) do
          {:ok, audio_url} -> {:halt, {:ok, audio_url}}
          {:error, _} -> {:cont, {:error, :not_found}}
        end
      end)
    end
  end

  @spec try_forvo_request(String.t(), String.t(), String.t()) ::
    {:ok, String.t()} | {:error, atom()}
  defp try_forvo_request(word, language, api_key) do
    url = "https://apifree.forvo.com/key/#{api_key}/format/json/action/standard-pronunciation/word/#{URI.encode(word)}/language/#{language}"

    Logger.debug("🌐 Forvo request: #{word} (#{language})")

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"items" => [item | _]} ->
            # Prefer OGG format, fallback to MP3
            audio_url = item["pathogg"] || item["pathmp3"]
            if audio_url do
              # Download and cache the audio
              case download_and_cache_audio(audio_url, word, language) do
                {:ok, local_path} -> {:ok, local_path}
                {:error, reason} -> {:error, reason}
              end
            else
              {:error, :no_audio_url}
            end

          %{"items" => []} ->
            {:error, :no_items}

          _ ->
            {:error, :unexpected_format}
        end

      {:ok, %{status: status}} ->
        Logger.warning("Forvo API returned status #{status}")
        {:error, :api_error}

      {:error, reason} ->
        Logger.error("Forvo API request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @spec download_and_cache_audio(String.t(), String.t(), String.t()) ::
    {:ok, String.t()} | {:error, atom()}
  defp download_and_cache_audio(audio_url, name, language) do
    # Generate cache filename
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    timestamp = System.system_time(:second)
    filename = "#{safe_name}_#{language}_#{timestamp}.ogg"

    # Ensure cache directory exists
    cache_dir = Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])
    File.mkdir_p!(cache_dir)

    local_path = Path.join(cache_dir, filename)
    web_path = "/audio/cache/#{filename}"

    Logger.info("💾 Downloading: #{audio_url} -> #{web_path}")

    case Req.get(audio_url) do
      {:ok, %{status: 200, body: audio_data}} ->
        case File.write(local_path, audio_data) do
          :ok ->
            Logger.info("✅ Audio cached: #{web_path}")
            {:ok, web_path}

          {:error, reason} ->
            Logger.error("Failed to write audio file: #{inspect(reason)}")
            {:error, :write_failed}
        end

      {:ok, %{status: status}} ->
        Logger.warning("Audio download failed with status #{status}")
        {:error, :download_failed}

      {:error, reason} ->
        Logger.error("Audio download request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @spec generate_name_variants(String.t()) :: [String.t()]
  defp generate_name_variants(name) do
    # Split name into parts and create variants
    parts = String.split(name, " ", trim: true)

    case parts do
      [single] -> [single]
      [first, last] -> [name, first, last]
      multiple -> [name | multiple]
    end
  end

  @spec get_forvo_api_key() :: String.t() | nil
  defp get_forvo_api_key do
    System.get_env("FORVO_API_KEY")
  end

  @doc """
  Gets the native language name for display purposes.

  ## Examples

      PronunceName.get_native_language_name("ES")
      # => "Spanish"

      PronunceName.get_native_language_name("JP")
      # => "Japanese"
  """
  @spec get_native_language_name(String.t()) :: String.t()
  def get_native_language_name(country_code) do
    case String.upcase(country_code) do
      "US" -> "English"
      "GB" -> "English"
      "CA" -> "English"
      "AU" -> "English"
      "ES" -> "Spanish"
      "MX" -> "Spanish"
      "FR" -> "French"
      "DE" -> "German"
      "IT" -> "Italian"
      "PT" -> "Portuguese"
      "BR" -> "Portuguese"
      "JP" -> "Japanese"
      "CN" -> "Chinese"
      "KR" -> "Korean"
      "IN" -> "Hindi"
      "EG" -> "Arabic"
      "SE" -> "Swedish"
      _ -> "English"  # Default fallback
    end
  end

  @spec derive_language_from_country(String.t()) :: String.t()
  defp derive_language_from_country(country_code) do
    case String.upcase(country_code) do
      "US" -> "en-US"
      "GB" -> "en-GB"
      "CA" -> "en-CA"
      "AU" -> "en-AU"
      "ES" -> "es-ES"
      "MX" -> "es-MX"
      "FR" -> "fr-FR"
      "DE" -> "de-DE"
      "IT" -> "it-IT"
      "PT" -> "pt-PT"
      "BR" -> "pt-BR"
      "JP" -> "ja-JP"
      "CN" -> "zh-CN"
      "KR" -> "ko-KR"
      "IN" -> "hi-IN"
      "EG" -> "ar-EG"
      "SE" -> "sv-SE"
      _ -> "en-US"  # Default fallback
    end
  end
end

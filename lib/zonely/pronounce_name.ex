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
  alias Countries

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
    Logger.info("🎯 PronunceName.play called: name=#{inspect(name)}, language=#{inspect(language) || "auto"}, country=#{country}")

    # Derive language from country if needed
    target_language = language || derive_language_from_country(country)

    # Try to get pronunciation
    case get_pronunciation(name, target_language, country) do
      {:audio_url, url} ->
        Logger.info("🔊 PronounceName result: cache_or_external_audio url=#{url}")
        {:play_audio, %{url: url}}

      {:tts, text, lang} ->
        Logger.info("🗣️ PronounceName result: tts text=#{inspect(text)} lang=#{lang}")
        {:play_tts, %{text: text, lang: lang}}
    end
  end

  # Private functions for internal logic

  @spec get_pronunciation(String.t(), String.t(), String.t()) ::
    {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  defp get_pronunciation(name, language, _country) do
    # 1) Local cache lookup
    case Zonely.PronunceName.Cache.lookup_cached_audio(name, language) do
      {:ok, cached_url} ->
        Logger.info("📦 Cache hit for name=#{inspect(name)} lang=#{language} -> #{cached_url}")
        {:audio_url, cached_url}

      :not_found ->
        Logger.info("📦 Cache miss for name=#{inspect(name)} lang=#{language}")
        # 2) External services: NameShouts first, then Forvo
        case fetch_from_external_service(name, language) do
          {:ok, audio_url} ->
            Logger.info("🌐 External audio found -> #{audio_url}")
            {:audio_url, audio_url}

          {:error, :not_found} ->
            Logger.info("↪️ External sources unavailable; attempting AWS Polly for #{inspect(name)} (#{language})")
            case Zonely.PronunceName.Providers.Polly.synthesize(name, language) do
              {:ok, web_path} ->
                Logger.info("✅ Polly synth success -> #{web_path}")
                {:audio_url, web_path}
              {:error, reason} ->
                Logger.warning("❌ Polly synth failed (#{inspect(reason)}); falling back to browser TTS")
                {:tts, name, language}
            end
        end
    end
  end

  # (AWS request indirection moved into Providers.Polly)

  # Remove old Polly helpers (moved to Providers.Polly)

  @spec pick_polly_voice(String.t()) :: String.t()
  def pick_polly_voice(bcp47) do
    base = bcp47 |> String.split("-") |> List.first() |> String.downcase()
    case String.downcase(bcp47) do
      # English variants (neural voices preferred)
      "en-us" -> "Joanna"
      "en-gb" -> "Amy"
      "en-au" -> "Olivia"
      "en-ca" -> "Emma"
      "en-in" -> "Aditi"

      # Spanish variants
      "es-es" -> "Lucia"
      "es-us" -> "Lupe"
      "es-mx" -> "Lupe"

      # Portuguese variants
      "pt-br" -> "Camila"
      "pt-pt" -> "Ines"

      # French variants
      "fr-fr" -> "Lea"
      "fr-ca" -> "Chantal"

      # German variants
      "de-de" -> "Vicki"
      "de-at" -> "Vicki"

      # Chinese variants
      "zh-cn" -> "Zhiyu"
      "zh-tw" -> "Zhiyu"

      # Arabic variants
      "ar-eg" -> "Zeina"
      "ar-sa" -> "Zeina"

      _ ->
        case base do
          # Major language families by base code
          "es" -> "Lucia"      # Spanish (Spain default)
          "pt" -> "Camila"     # Portuguese (Brazilian default)
          "fr" -> "Lea"        # French
          "de" -> "Vicki"      # German
          "it" -> "Bianca"     # Italian
          "ja" -> "Mizuki"     # Japanese
          "ko" -> "Seoyeon"    # Korean
          "hi" -> "Aditi"      # Hindi
          "zh" -> "Zhiyu"      # Chinese (Mandarin)
          "ar" -> "Zeina"      # Arabic
          "ru" -> "Tatyana"    # Russian
          "nl" -> "Lotte"      # Dutch
          "sv" -> "Astrid"     # Swedish
          "no" -> "Liv"        # Norwegian
          "da" -> "Naja"       # Danish
          "fi" -> "Suvi"       # Finnish
          "pl" -> "Ewa"        # Polish
          "tr" -> "Filiz"      # Turkish
          "th" -> "Zhiyu"      # Thai (fallback to multilingual voice)
          "vi" -> "Zhiyu"      # Vietnamese (fallback to multilingual voice)
          _ -> "Joanna"        # English fallback
        end
    end
  end

  # (binary cache writing lives in Zonely.PronunceName.Cache)

  @spec fetch_from_external_service(String.t(), String.t()) ::
    {:ok, String.t()} | {:error, :not_found}
  defp fetch_from_external_service(name, language) do
    Logger.info("🔎 Trying NameShouts for #{inspect(name)} (#{language})")
    case Zonely.PronunceName.Providers.NameShouts.fetch(name, language) do
      {:ok, url} ->
        Logger.info("✅ NameShouts hit -> #{url}")
        {:ok, url}

      {:error, reason} ->
        Logger.info("↪️ NameShouts miss (#{inspect(reason)}), trying Forvo for #{inspect(name)} (#{language})")
        case Zonely.PronunceName.Providers.Forvo.fetch(name, language) do
          {:ok, url} ->
            Logger.info("✅ Forvo hit -> #{url}")
            {:ok, url}

          {:error, reason2} ->
            Logger.info("❌ Forvo miss (#{inspect(reason2)})")
            {:error, :not_found}
        end
    end
  end

  # Submodules moved to their own files under lib/zonely/pronounce_name/

  # (Forvo fetch helpers moved to Providers.Forvo)

  # (Forvo request logic moved to Providers.Forvo)

  # (external download moved to Cache.write_external_and_cache/4)


  @spec generate_name_variants(String.t()) :: [String.t()]
  def generate_name_variants(name) do
    # Split name into parts and create variants
    parts = String.split(name, " ", trim: true)

    case parts do
      [single] -> [single]
      [first, last] -> [name, first, last]
      multiple -> [name | multiple]
    end
  end

  # (Forvo API key access handled in Providers.Forvo)

  # ————————————————————————————————————————————————————————————
  # NameShouts integration (https://v1.nameshouts.com/welcome/dev/docs#requests)
  # ————————————————————————————————————————————————————————————

  # (NameShouts integration moved to Providers.NameShouts)

  @spec pick_nameshouts_variant(map(), String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def pick_nameshouts_variant(%{"status" => status, "message" => message}, name, language)
       when is_binary(status) and is_map(message) do
    target_lang_name = language_display_name_from_bcp47(language)

    # Try multiple possible keys that NameShouts may use
    candidates = [
      String.downcase(name) |> String.replace(~r/\s+/, "-"),
      String.downcase(name),
      URI.encode(name),
      URI.encode(String.downcase(name))
    ]

    variants = Enum.find_value(candidates, fn k -> Map.get(message, k) end)

    cond do
      is_list(variants) ->
        select_variant_from_list(variants, target_lang_name)

      is_map(variants) ->
        select_variant_from_map(variants)

      true ->
        # Fallback: scan all message values to find any variant with a path
        message
        |> Map.values()
        |> Enum.find_value(fn v ->
          cond do
            is_list(v) ->
              case select_variant_from_list(v, target_lang_name) do
                {:ok, path} -> path
                _ -> nil
              end
            is_map(v) ->
              case select_variant_from_map(v) do
                {:ok, path} -> path
                _ -> nil
              end
            true -> nil
          end
        end)
        |> case do
          nil -> {:error, :not_found}
          path when is_binary(path) -> {:ok, path}
        end
    end
  end

  def pick_nameshouts_variant(_body, _name, _language), do: {:error, :unexpected_format}

  defp select_variant_from_list(list, target_lang_name) when is_list(list) do
    preferred = Enum.find(list, fn v ->
      String.downcase(v["lang_name"] || "") == String.downcase(target_lang_name)
    end)

    chosen = preferred || List.first(list)

    case chosen do
      %{"path" => path} when is_binary(path) -> {:ok, path}
      _ -> {:error, :no_path}
    end
  end

  defp select_variant_from_map(map) when is_map(map) do
    case map do
      %{"path" => path} when is_binary(path) -> {:ok, path}
      _ -> {:error, :no_path}
    end
  end

  # (NameShouts API key access handled in Providers.NameShouts)

  # Some NameShouts responses embed an HTML PHP warning before JSON. Attempt to strip the HTML and parse JSON.
  def recover_nameshouts_body_from_decode_error(raw) when is_binary(raw) do
    # Try to find the first JSON object start
    case :binary.match(raw, "{") do
      :nomatch -> {:error, :no_json}
      {pos, _len} ->
        json = binary_part(raw, pos, byte_size(raw) - pos)
        case Jason.decode(json) do
          {:ok, body} -> {:ok, body}
          _ -> {:error, :bad_json}
        end
    end
  end
  def recover_nameshouts_body_from_decode_error(_), do: {:error, :bad_data}

  @spec language_display_name_from_bcp47(String.t()) :: String.t()
  def language_display_name_from_bcp47(bcp47) do
    prefix = bcp47 |> String.split("-") |> List.first()
    case prefix do
      "en" -> "English"
      "es" -> "Spanish"
      "fr" -> "French"
      "de" -> "German"
      "it" -> "Italian"
      "pt" -> "Portuguese"
      "ja" -> "Japanese"
      "zh" -> "Chinese"
      "ko" -> "Korean"
      "hi" -> "Hindi"
      "ar" -> "Arabic"
      "sv" -> "Swedish"
      _ -> "English"
    end
  end

  # (duplicate Cache module removed)

  # Unified HTTP client indirection for testability
  def http_client do
    Application.get_env(:zonely, :http_client, Zonely.HttpClient.Req)
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

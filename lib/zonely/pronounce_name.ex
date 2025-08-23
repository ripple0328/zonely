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
    case lookup_cached_audio(name, language) do
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
            Logger.info("↪️ Falling back to TTS for #{inspect(name)} (#{language}) – no external sources")
            {:tts, name, language}
        end
    end
  end

  @spec fetch_from_external_service(String.t(), String.t()) ::
    {:ok, String.t()} | {:error, :not_found}
  defp fetch_from_external_service(name, language) do
    Logger.info("🔎 Trying NameShouts for #{inspect(name)} (#{language})")
    case fetch_from_nameshouts(name, language) do
      {:ok, url} ->
        Logger.info("✅ NameShouts hit -> #{url}")
        {:ok, url}

      {:error, reason} ->
        Logger.info("↪️ NameShouts miss (#{inspect(reason)}), trying Forvo for #{inspect(name)} (#{language})")
        case fetch_from_forvo(name, language) do
          {:ok, url} ->
            Logger.info("✅ Forvo hit -> #{url}")
            {:ok, url}

          {:error, reason2} ->
            Logger.info("❌ Forvo miss (#{inspect(reason2)})")
            {:error, :not_found}
        end
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

    case http_client().get(url) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"items" => [item | _]} ->
            # Prefer OGG format, fallback to MP3
            cond do
              is_binary(item["pathogg"]) ->
                audio_url = item["pathogg"]
                case download_and_cache_audio_with_ext(audio_url, word, language, ".ogg") do
                  {:ok, local_path} ->
                    Logger.info("💾 Cached Forvo OGG -> #{local_path}")
                    {:ok, local_path}
                  {:error, reason} -> {:error, reason}
                end

              is_binary(item["pathmp3"]) ->
                audio_url = item["pathmp3"]
                case download_and_cache_audio_with_ext(audio_url, word, language, ".mp3") do
                  {:ok, local_path} ->
                    Logger.info("💾 Cached Forvo MP3 -> #{local_path}")
                    {:ok, local_path}
                  {:error, reason} -> {:error, reason}
                end

              true ->
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

  @spec download_and_cache_audio_with_ext(String.t(), String.t(), String.t(), String.t()) ::
    {:ok, String.t()} | {:error, atom()}
  defp download_and_cache_audio_with_ext(audio_url, name, language, ext) do
    # Generate cache filename
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    timestamp = System.system_time(:second)
    filename = "#{safe_name}_#{language}_#{timestamp}#{ext}"

    # Ensure cache directory exists
    cache_dir = Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])
    File.mkdir_p!(cache_dir)

    local_path = Path.join(cache_dir, filename)
    web_path = "/audio/cache/#{filename}"

    Logger.info("💾 Downloading: #{audio_url} -> #{web_path}")

    case http_client().get(audio_url) do
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

  # ————————————————————————————————————————————————————————————
  # NameShouts integration (https://v1.nameshouts.com/welcome/dev/docs#requests)
  # ————————————————————————————————————————————————————————————

  @spec fetch_from_nameshouts(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp fetch_from_nameshouts(name, language) do
    api_key = get_nameshouts_api_key()

    if !api_key do
      Logger.warning("No NameShouts API key configured (NS_API_KEY)")
      {:error, :no_api_key}
    else
      headers = [{"NS-API-KEY", api_key}, {"Accept", "application/json"}]

      lang_name = language_display_name_from_bcp47(language) |> String.downcase()
      url_with_lang = "https://www.v1.nameshouts.com/api/names/#{URI.encode(name)}/#{URI.encode(lang_name)}"
      url_without_lang = "https://www.v1.nameshouts.com/api/names/#{URI.encode(name)}"

      prefer_without_lang_first = String.starts_with?(language || "", "en")

      Logger.info("🌐 NameShouts request for #{inspect(name)} pref_without_lang=#{prefer_without_lang_first} lang=#{lang_name}")

      case (prefer_without_lang_first && http_client().get(url_without_lang, headers)) || http_client().get(url_with_lang, headers) do
        {:ok, %{status: 200, body: body}} ->
          case pick_nameshouts_variant(body, name, language) do
            {:ok, path} ->
              audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
              download_and_cache_audio_with_ext(audio_url, name, language, ".mp3")

            {:error, reason} ->
              {:error, reason}
          end

        {:error, %Jason.DecodeError{data: data}} ->
          Logger.warning("NameShouts returned malformed JSON; attempting recovery")
          case recover_nameshouts_body_from_decode_error(data) do
            {:ok, body} ->
              case pick_nameshouts_variant(body, name, language) do
                {:ok, path} ->
                  audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
                  download_and_cache_audio_with_ext(audio_url, name, language, ".mp3")
                {:error, reason} -> {:error, reason}
              end
            {:error, _} -> {:error, :invalid_response}
          end

        {:ok, %{status: 404}} ->
          Logger.info("NameShouts 404; retrying alternate route")
          alt_resp = if prefer_without_lang_first, do: http_client().get(url_with_lang, headers), else: http_client().get(url_without_lang, headers)
          case alt_resp do
            {:ok, %{status: 200, body: body2}} ->
              case pick_nameshouts_variant(body2, name, language) do
                {:ok, path} ->
                  audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
                  download_and_cache_audio_with_ext(audio_url, name, language, ".mp3")
                {:error, reason} -> {:error, reason}
              end
            {:error, %Jason.DecodeError{data: data2}} ->
              Logger.warning("NameShouts returned malformed JSON on alt route; attempting recovery")
              case recover_nameshouts_body_from_decode_error(data2) do
                {:ok, body} ->
                  case pick_nameshouts_variant(body, name, language) do
                    {:ok, path} ->
                      audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
                      download_and_cache_audio_with_ext(audio_url, name, language, ".mp3")
                    {:error, reason} -> {:error, reason}
                  end
                {:error, _} -> {:error, :invalid_response}
              end
            {:ok, %{status: 403}} ->
              Logger.warning("NameShouts API returned 403 (invalid API key)")
              {:error, :invalid_api_key}
            {:ok, %{status: status}} ->
              Logger.warning("NameShouts API returned status #{status}")
              {:error, :api_error}
            {:error, reason} ->
              Logger.error("NameShouts API request failed: #{inspect(reason)}")
              {:error, :request_failed}
          end

        {:ok, %{status: 403}} ->
          Logger.warning("NameShouts API returned 403 (invalid API key)")
          {:error, :invalid_api_key}

        {:ok, %{status: status}} ->
          Logger.warning("NameShouts API returned status #{status}")
          {:error, :api_error}

        {:error, reason} ->
          Logger.error("NameShouts API request failed: #{inspect(reason)}")
          {:error, :request_failed}
      end
    end
  end

  @spec pick_nameshouts_variant(map(), String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp pick_nameshouts_variant(%{"status" => status, "message" => message}, name, language)
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

  defp pick_nameshouts_variant(_body, _name, _language), do: {:error, :unexpected_format}

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

  @spec get_nameshouts_api_key() :: String.t() | nil
  defp get_nameshouts_api_key do
    case System.get_env("NS_API_KEY") do
      nil -> nil
      val -> String.trim(val)
    end
  end

  # Some NameShouts responses embed an HTML PHP warning before JSON. Attempt to strip the HTML and parse JSON.
  defp recover_nameshouts_body_from_decode_error(raw) when is_binary(raw) do
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
  defp recover_nameshouts_body_from_decode_error(_), do: {:error, :bad_data}

  @spec language_display_name_from_bcp47(String.t()) :: String.t()
  defp language_display_name_from_bcp47(bcp47) do
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

  # ————————————————————————————————————————————————————————————
  # Local cache lookup
  # ————————————————————————————————————————————————————————————

  @spec lookup_cached_audio(String.t(), String.t()) :: {:ok, String.t()} | :not_found
  defp lookup_cached_audio(name, language) do
    cache_dir = Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])

    # Consider variants of the name (full and parts)
    variant_safe_names =
      [name | generate_name_variants(name)]
      |> Enum.uniq()
      |> Enum.map(&String.replace(&1, ~r/[^a-zA-Z0-9_-]/, "_"))

    # Consider both full BCP47 and base language (e.g., en-US and en)
    lang_candidates =
      case String.split(language || "", "-") do
        [base, _rest] when byte_size(base) > 0 -> [language, base]
        [only] when byte_size(only) > 0 -> [only]
        _ -> [language]
      end
      |> Enum.uniq()

    with {:ok, entries} <- File.ls(cache_dir) do
      entries
      |> Enum.filter(fn filename ->
        Enum.any?(variant_safe_names, fn vn ->
          Enum.any?(lang_candidates, fn lc -> String.starts_with?(filename, vn <> "_" <> lc <> "_") end)
        end)
      end)
      |> Enum.sort()
      |> List.last()
      |> case do
        nil -> :not_found
        filename -> {:ok, "/audio/cache/#{filename}"}
      end
    else
      _ -> :not_found
    end
  end

  # Unified HTTP client indirection for testability
  defp http_client do
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

defmodule Zonely.PronunceName do
  @moduledoc """
  Unified module for name pronunciation functionality.

  This module provides a single, clean interface for all name pronunciation needs:
  - Fetching cached audio files
  - Downloading from external services (Forvo)
  - Falling back to text-to-speech

  ## Usage

      # For LiveView - returns ready-to-use event data
      {event_type, event_data} = PronunceName.play(name, language)
      push_event(socket, event_type, event_data)

      # Examples:
      PronunceName.play("María García", "es-ES")
      # → {:play_audio, %{url: "/audio/cache/maria_garcia.ogg"}}

      PronunceName.play("John Doe", "en-US")
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
  - `language`: Language code (e.g., "es-ES", "en-US") - required

  ## Returns
  - `{:play_audio, %{url: url}}` - for cached or downloaded audio files
  - `{:play_tts, %{text: text, lang: lang}}` - for text-to-speech fallback
  """
  @spec play(String.t(), String.t()) :: {:play_audio | :play_tts | :play_tts_audio | :play_sequence, map()}
  def play(name, language) when is_binary(name) and is_binary(language) do
    Logger.info(
      "🎯 PronunceName.play called: name=#{inspect(name)}, language=#{language}"
    )

    # Try to get pronunciation
    case get_pronunciation(name, language) do
      {:audio_url, url} ->
        # Check if this is AI-generated audio (Polly) based on filename
        if String.contains?(url, "polly_") do
          Logger.info("🤖 PronounceName result: ai_generated_audio url=#{url}")
          {:play_tts_audio, %{url: url}}
        else
          Logger.info("🔊 PronounceName result: real_person_audio url=#{url}")
          {:play_audio, %{url: url}}
        end

      {:tts, text, lang} ->
        Logger.info("🗣️ PronounceName result: browser_tts text=#{inspect(text)} lang=#{lang}")
        {:play_tts, %{text: text, lang: lang}}

      {:sequence, urls} ->
        Logger.info("🔗 PronounceName result: sequential_parts count=#{length(urls)}")
        {:play_sequence, %{urls: urls}}
    end
  end

  # Private functions for internal logic

  @spec get_pronunciation(String.t(), String.t()) ::
          {:audio_url, String.t()} | {:tts, String.t(), String.t()} | {:sequence, [String.t()]}
  defp get_pronunciation(name, language) do
    # 1) Local cache lookup
    case Zonely.PronunceName.Cache.lookup_cached_audio(name, language) do
      {:ok, cached_url} ->
        Logger.info("📦 Cache hit for name=#{inspect(name)} lang=#{language} -> #{cached_url}")
        {:audio_url, cached_url}

      :not_found ->
        Logger.info("📦 Cache miss for name=#{inspect(name)} lang=#{language}")
        # 2) Try name variants systematically: full name first, then decide on fallback strategy
        case try_name_variants_with_providers(name, language) do
          {:ok, {:sequence, urls}} ->
            {:sequence, urls}
          {:ok, audio_url} ->
            Logger.info("🌐 External audio found -> #{audio_url}")
            {:audio_url, audio_url}

          {:error, :use_ai_fallback} ->
            Logger.info(
              "🤖 Using AI TTS for complete name due to partial provider coverage: #{inspect(name)} (#{language})"
            )

            case Zonely.PronunceName.Providers.Polly.synthesize(name, language) do
              {:ok, web_path} ->
                Logger.info("✅ Polly synth success for complete name -> #{web_path}")
                {:audio_url, web_path}

              {:error, reason} ->
                Logger.warning(
                  "❌ Polly synth failed (#{inspect(reason)}); falling back to browser TTS"
                )

                {:tts, name, language}
            end

          {:error, :not_found} ->
            Logger.info(
              "↪️ External sources unavailable; attempting AWS Polly for #{inspect(name)} (#{language})"
            )

            case Zonely.PronunceName.Providers.Polly.synthesize(name, language) do
              {:ok, web_path} ->
                Logger.info("✅ Polly synth success -> #{web_path}")
                {:audio_url, web_path}

              {:error, reason} ->
                Logger.warning(
                  "❌ Polly synth failed (#{inspect(reason)}); falling back to browser TTS"
                )

                {:tts, name, language}
            end
        end
    end
  end

  # Simple strategy: try full name, then first name, then fail to next provider
  @spec try_name_variants_with_providers(String.t(), String.t()) ::
          {:ok, String.t()} | {:ok, {:sequence, [String.t()]}} | {:error, :not_found}
  defp try_name_variants_with_providers(name, language) do
    Logger.info("🌍 Trying full name first: #{inspect(name)}")

    # First, try the complete name
    case try_single_name_with_providers(name, language, name) do
      {:ok, audio_url} ->
        Logger.info("✅ Found full name pronunciation: #{name}")
        {:ok, audio_url}

      {:error, _} ->
        # If full name failed, try just the first name
        name_parts = String.split(name, [" ", "-"], trim: true)
        case name_parts do
          [first_name | _rest] when first_name != name ->
            Logger.info("🔍 Full name failed, trying first name: #{inspect(first_name)}")
            case try_single_name_with_providers(first_name, language, name) do
              {:ok, audio_url} ->
                Logger.info("📝 Found first name pronunciation: #{first_name} (for #{name})")
                {:ok, audio_url}
              {:error, _} ->
                Logger.info("❌ Both full name and first name failed for: #{name}")
                {:error, :not_found}
            end

          _ ->
            # Single word name or other case
            Logger.info("❌ No pronunciation found for: #{name}")
            {:error, :not_found}
        end
    end
  end

  # Try a single name with all providers: NameShouts first, then Forvo
  @spec try_single_name_with_providers(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, atom()}
  defp try_single_name_with_providers(variant, language, original_name) do
    # Try NameShouts first
    case Zonely.PronunceName.Providers.NameShouts.fetch_single(variant, language, original_name) do
      {:ok, audio_url} ->
        {:ok, audio_url}
      {:error, _} ->
        # Try Forvo as fallback
        case Zonely.PronunceName.Providers.Forvo.fetch_single(variant, language, original_name) do
          {:ok, audio_url} -> {:ok, audio_url}
          {:error, reason} -> {:error, reason}
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
      "en-us" ->
        "Joanna"

      "en-gb" ->
        "Amy"

      "en-au" ->
        "Olivia"

      "en-ca" ->
        "Emma"

      "en-in" ->
        "Aditi"

      # Spanish variants
      "es-es" ->
        "Lucia"

      "es-us" ->
        "Lupe"

      "es-mx" ->
        "Lupe"

      # Portuguese variants
      "pt-br" ->
        "Camila"

      "pt-pt" ->
        "Ines"

      # French variants
      "fr-fr" ->
        "Lea"

      "fr-ca" ->
        "Chantal"

      # German variants
      "de-de" ->
        "Vicki"

      "de-at" ->
        "Vicki"

      # Chinese variants
      "zh-cn" ->
        "Zhiyu"

      "zh-tw" ->
        "Zhiyu"

      # Arabic variants
      "ar-eg" ->
        "Zeina"

      "ar-sa" ->
        "Zeina"

      _ ->
        case base do
          # Major language families by base code
          # Spanish (Spain default)
          "es" -> "Lucia"
          # Portuguese (Brazilian default)
          "pt" -> "Camila"
          # French
          "fr" -> "Lea"
          # German
          "de" -> "Vicki"
          # Italian
          "it" -> "Bianca"
          # Japanese
          "ja" -> "Mizuki"
          # Korean
          "ko" -> "Seoyeon"
          # Hindi
          "hi" -> "Aditi"
          # Chinese (Mandarin)
          "zh" -> "Zhiyu"
          # Arabic
          "ar" -> "Zeina"
          # Russian
          "ru" -> "Tatyana"
          # Dutch
          "nl" -> "Lotte"
          # Swedish
          "sv" -> "Astrid"
          # Norwegian
          "no" -> "Liv"
          # Danish
          "da" -> "Naja"
          # Finnish
          "fi" -> "Suvi"
          # Polish
          "pl" -> "Ewa"
          # Turkish
          "tr" -> "Filiz"
          # Thai (fallback to multilingual voice)
          "th" -> "Zhiyu"
          # Vietnamese (fallback to multilingual voice)
          "vi" -> "Zhiyu"
          # English fallback
          _ -> "Joanna"
        end
    end
  end

  # (binary cache writing lives in Zonely.PronunceName.Cache)


  # Submodules moved to their own files under lib/zonely/pronounce_name/

  # (Forvo fetch helpers moved to Providers.Forvo)

  # (Forvo request logic moved to Providers.Forvo)

  # (external download moved to Cache.write_external_and_cache/4)

  @spec generate_name_parts(String.t()) :: [String.t()]
  defp generate_name_parts(name) do
    # Split name into individual parts for partial coverage analysis
    String.split(name, [" ", "-"], trim: true)
  end

  # (Forvo API key access handled in Providers.Forvo)

  # ————————————————————————————————————————————————————————————
  # NameShouts integration (https://v1.nameshouts.com/welcome/dev/docs#requests)
  # ————————————————————————————————————————————————————————————

  # (NameShouts integration moved to Providers.NameShouts)

  @spec pick_nameshouts_variant(map(), String.t(), String.t()) ::
          {:ok, String.t()} | {:ok, [String.t()]} | {:error, atom()}
  def pick_nameshouts_variant(%{"status" => status, "message" => message}, name, language)
      when is_binary(status) and is_map(message) do
    target_lang_name = language_display_name_from_bcp47(language) |> String.downcase()

    Logger.info("🔍 Analyzing NameShouts response for requested name: '#{name}'")
    Logger.info("🔍 Available keys in NameShouts response: #{inspect(Map.keys(message))}")
    Logger.info("🔍 Target language: '#{target_lang_name}'")

    # Check if response is organized by language (like {"english" => [...]})
    case Map.get(message, target_lang_name) do
      variants when is_list(variants) ->
        Logger.info("🔍 Found language-based variants: #{inspect(variants)}")
        analyze_language_variants(variants, name, target_lang_name)

      _ ->
        # Fallback to original name-based lookup
        Logger.info("🔍 No language-based variants, trying name-based lookup")
        try_name_based_lookup(message, name, target_lang_name)
    end
  end


  def pick_nameshouts_variant(_body, _name, _language), do: {:error, :unexpected_format}

  # Analyze variants from language-based response structure
  defp analyze_language_variants(variants, name, _target_lang_name) do
    Logger.info("🔍 Analyzing #{length(variants)} variants for name '#{name}'")

    # Look for multiple parts that might need chaining
    name_parts = String.split(name, " ", trim: true) |> Enum.map(&String.downcase/1)
    Logger.info("🔍 Name parts: #{inspect(name_parts)}")

    # Group variants by what parts of the name they might represent
    part_matches = Enum.map(variants, fn variant ->
      path = variant["path"] || ""
      clean_path = String.downcase(path) |> String.replace(~r/_[a-z]{2}$/, "")

      matching_parts = Enum.filter(name_parts, fn part ->
        String.contains?(clean_path, part)
      end)

      Logger.info("🔍 Path '#{path}' matches parts: #{inspect(matching_parts)}")
      {variant, matching_parts, path}
    end)

    # Check if we have variants that cover all parts of the name
    all_covered_parts = part_matches
    |> Enum.flat_map(fn {_, parts, _} -> parts end)
    |> Enum.uniq()

    cond do
      # If we have variants covering all parts, return them for chaining
      length(all_covered_parts) == length(name_parts) and length(name_parts) > 1 ->
        paths = part_matches |> Enum.map(fn {_, _, path} -> path end) |> Enum.filter(&(&1 != ""))
        Logger.info("✅ Found multi-part pronunciation - paths for chaining: #{inspect(paths)}")
        {:ok, paths}

      # Otherwise, look for the best single match
      true ->
        best_match = Enum.find(part_matches, fn {_, matching_parts, path} ->
          path != "" and (length(matching_parts) > 0 or String.contains?(String.downcase(path), String.downcase(name)))
        end)

        case best_match do
          {_, _, path} when path != "" ->
            Logger.info("✅ Found single best match: #{path}")
            {:ok, path}
          _ ->
            # Fallback to first valid path
            case Enum.find(variants, fn v -> v["path"] != nil end) do
              %{"path" => path} ->
                Logger.info("🔄 Using fallback path: #{path}")
                {:ok, path}
              _ ->
                {:error, :no_path}
            end
        end
    end
  end

  # Fallback to original name-based lookup
  defp try_name_based_lookup(message, name, target_lang_name) do
    Logger.info("🔍 Trying name-based lookup for '#{name}' in message keys: #{inspect(Map.keys(message))}")

    # Check if message contains multiple name parts (like %{"John" => ..., "Doe" => ...})
    name_parts = String.split(name, [" ", "-"], trim: true)
    Logger.info("🔍 Name parts to look for: #{inspect(name_parts)}")

    # Find all matching parts in the response (handling URL encoding)
    matching_parts = name_parts
    |> Enum.map(fn part ->
        # Check both original and URL-encoded versions
        key = cond do
          Map.has_key?(message, part) -> part
          Map.has_key?(message, URI.encode(part)) -> URI.encode(part)
          true -> nil
        end

        if key do
          case Map.get(message, key) do
            %{"path" => path} when is_binary(path) -> {part, path}
            _ -> nil
          end
        else
          nil
        end
      end)
    |> Enum.filter(&(&1 != nil))

    Logger.info("🔍 Found matching parts: #{inspect(matching_parts)}")

    cond do
      # If we found multiple parts, return them for chaining
      length(matching_parts) > 1 ->
        paths = Enum.map(matching_parts, fn {_part, path} -> path end)
        Logger.info("✅ Found multiple name parts for chaining: #{inspect(paths)}")
        {:ok, paths}

      # If we found exactly one part, return it
      length(matching_parts) == 1 ->
        {_part, path} = List.first(matching_parts)
        Logger.info("✅ Found single name part: #{path}")
        {:ok, path}

      # Otherwise, try the original fallback logic
      true ->
        Logger.info("🔍 No direct name part matches, trying original candidates")
        try_original_candidates(message, name, target_lang_name)
    end
  end

  # Original candidate matching logic as fallback
  defp try_original_candidates(message, name, target_lang_name) do
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
        # Scan all message values to find any variant with a path
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

            true ->
              nil
          end
        end)
        |> case do
          nil -> {:error, :not_found}
          path when is_binary(path) -> {:ok, path}
        end
    end
  end

  defp select_variant_from_list(list, target_lang_name) when is_list(list) do
    preferred =
      Enum.find(list, fn v ->
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
      :nomatch ->
        {:error, :no_json}

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

end

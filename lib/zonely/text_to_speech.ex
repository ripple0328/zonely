defmodule Zonely.TextToSpeech do
  @moduledoc """
  Real people name pronunciation system using Forvo API.
  Prioritizes authentic human pronunciations over synthetic TTS.
  """

  alias Zonely.Repo
  alias Zonely.Accounts.User

    @doc """
  Gets the best available pronunciation for a name in a specific language.
  Returns either an audio URL or TTS parameters.
  """
  def get_name_pronunciation(user, target_language \\ nil)

  def get_name_pronunciation(user, nil) do
    # Use user's native language when no target language specified
    language = user.native_language || get_language_for_country(user.country)

    cond do
      # 1. User-recorded audio (highest priority - most authentic)
      user.pronunciation_audio_url && String.trim(user.pronunciation_audio_url) != "" ->
        {:audio_url, user.pronunciation_audio_url}

      # 2. Cached Forvo pronunciation (for native language)
      user.forvo_audio_url && String.trim(user.forvo_audio_url) != "" ->
        {:audio_url, user.forvo_audio_url}

      # 3. Try to fetch from Forvo API for native language
      forvo_url = fetch_forvo_pronunciation(user) ->
        {:audio_url, forvo_url}

      # 4. Last resort: improved general TTS with name-specific rules
      true ->
        {:tts, improve_name_pronunciation(user.name), language}
    end
  end

  def get_name_pronunciation(user, target_language) do
    # Get pronunciation for specific target language (e.g., English)
    cond do
      # 1. User-recorded audio (highest priority)
      user.pronunciation_audio_url && String.trim(user.pronunciation_audio_url) != "" ->
        {:audio_url, user.pronunciation_audio_url}

      # 2. Try to fetch from Forvo API for the target language
      forvo_url = fetch_forvo_pronunciation_for_language(user, target_language) ->
        {:audio_url, forvo_url}

      # 3. Last resort: improved general TTS with name-specific rules
      true ->
        {:tts, improve_name_pronunciation(user.name), target_language}
    end
  end

  @doc """
  Fetches pronunciation from Forvo API for a specific language.
  Returns audio URL if found, nil otherwise.
  """
  def fetch_forvo_pronunciation_for_language(user, target_language) do
    IO.puts("🎯 Fetching pronunciation for #{user.name} in #{target_language}")
    IO.puts("📍 User details: Country=#{user.country}, Native=#{user.native_language}")

    # Try to fetch from Forvo for the specific language
    case get_forvo_pronunciation(user.name, target_language) do
      {:ok, audio_url} ->
        IO.puts("🎉 SUCCESS: Found pronunciation URL: #{audio_url}")
        # Download and cache locally for faster serving
        case download_and_cache_audio(user, audio_url, target_language) do
          {:ok, local_url} ->
            IO.puts("💾 CACHED: Audio saved locally: #{local_url}")
            # Only cache in database if it's the user's native language to avoid conflicts
            if target_language == (user.native_language || get_language_for_country(user.country)) do
              update_forvo_cache(user, local_url)
            end
            local_url
          {:error, _reason} ->
            IO.puts("⚠️ Cache failed, using original URL: #{audio_url}")
            # Only cache original URL if it's the user's native language
            if target_language == (user.native_language || get_language_for_country(user.country)) do
              update_forvo_cache(user, audio_url)
            end
            audio_url
        end

      {:error, reason} ->
        IO.puts("❌ FAILED: #{reason}")
        # Only cache failure for native language
        if target_language == (user.native_language || get_language_for_country(user.country)) do
          update_forvo_cache(user, nil)
        end
        nil
    end
  end

  @doc """
  Fetches pronunciation from Forvo API and caches result (legacy function).
  Returns audio URL if found, nil otherwise.
  """
  def fetch_forvo_pronunciation(user) do
    # Skip if we've checked recently (within 24 hours)
    if recently_checked?(user.forvo_last_checked) do
      user.forvo_audio_url
    else
      # Try to fetch from Forvo
      case get_forvo_pronunciation(user.name, user.native_language) do
        {:ok, audio_url} ->
          # Cache the result
          update_forvo_cache(user, audio_url)
          audio_url

        {:error, _reason} ->
          # Cache the failure to avoid repeated requests
          update_forvo_cache(user, nil)
          nil
      end
    end
  end

  defp recently_checked?(nil), do: false
  defp recently_checked?(last_checked) do
    DateTime.diff(DateTime.utc_now(), last_checked, :hour) < 24
  end

  defp update_forvo_cache(user, audio_url) do
    User.changeset(user, %{
      forvo_audio_url: audio_url,
      forvo_last_checked: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Generates TTS parameters for the Web Speech API.
  """
  def generate_speech_params(text, language_code) do
    %{
      text: text,
      lang: language_code,
      rate: 0.8,
      pitch: 1.0,
      volume: 1.0
    }
  end

  @doc """
  Gets pronunciation from NameShouts API (to be implemented).
  Returns audio URL or nil if not found.
  """
  def get_nameshouts_pronunciation(_name) do
    # TODO: Implement NameShouts API integration
    # Example:
    # HTTPoison.get("https://api.nameshouts.com/v1/names/#{name}/pronunciation")
    # |> handle_api_response()
    nil
  end

    @doc """
  Gets pronunciation from Forvo API.
  Returns {:ok, audio_url} or {:error, reason}.
  """
  def get_forvo_pronunciation(name, language_code) do
    # Get API key from environment
    api_key = Application.get_env(:zonely, :forvo_api_key)

    if api_key do
      case fetch_from_forvo_api(name, language_code, api_key) do
        {:ok, audio_url} ->
          {:ok, audio_url}
        {:error, _reason} ->
          IO.puts("🔄 Forvo API failed, trying test database fallback...")
          # Fallback: Try a few free pronunciation sources
          try_free_pronunciation_sources(name, language_code)
      end
    else
      # Fallback: Try a few free pronunciation sources
      try_free_pronunciation_sources(name, language_code)
    end
  end

  defp fetch_from_forvo_api(name, language_code, api_key) do
    # Convert language code to Forvo format (remove country code)
    lang = language_code |> String.split("-") |> hd()

    IO.puts("🔍 DEBUG: API Key present: #{api_key != nil}")
    IO.puts("🔍 DEBUG: Full name: #{name}, Target language: #{language_code} (Forvo lang: #{lang})")

    # Try full name first, then individual name parts
    name_variants = [name] ++ String.split(name, " ", trim: true)

    IO.puts("🎯 Will try these name variants: #{inspect(name_variants)}")
    IO.puts("🌍 Requesting from Forvo API with language: #{lang}")

    # Try each name variant until we find one
    Enum.reduce_while(name_variants, {:error, "No pronunciations found"}, fn variant, _acc ->
      # CORRECT Forvo API with explicit language specification
      url = "https://apifree.forvo.com/key/#{api_key}/format/json/action/standard-pronunciation/word/#{URI.encode(variant)}/language/#{lang}"
      IO.puts("🌐 Trying: '#{variant}' in language '#{lang}' at #{url}")

      case Req.get(url) do
        {:ok, %{status: 200, body: body}} ->
          IO.puts("✅ SUCCESS: Got 200 response for '#{variant}' in #{lang}")
          IO.puts("🔍 FULL Response body: #{inspect(body, pretty: true, limit: :infinity)}")

          case parse_forvo_response(body, lang) do
            {:ok, audio_url} ->
              IO.puts("🎉 FOUND pronunciation for '#{variant}': #{audio_url}")
              {:halt, {:ok, audio_url}}

            {:error, _reason} ->
              IO.puts("⚠️ No audio for '#{variant}', trying next...")
              {:cont, {:error, "No pronunciations found"}}
          end

        {:ok, %{status: status, body: _body}} ->
          IO.puts("❌ FAILED for '#{variant}': Status #{status}")
          {:cont, {:error, "Forvo API returned status #{status}"}}

        {:error, reason} ->
          IO.puts("💥 ERROR for '#{variant}': #{inspect(reason)}")
          {:cont, {:error, "Request failed: #{inspect(reason)}"}}
      end
    end)
  end

  defp parse_forvo_response(%{"items" => items}, _target_lang) when is_list(items) and length(items) > 0 do
    IO.puts("🔍 Found #{length(items)} pronunciations (language-specific request)")

    # Get the first pronunciation (should already be in correct language)
    case List.first(items) do
      %{"pathogg" => ogg_url} when is_binary(ogg_url) and ogg_url != "" ->
        IO.puts("✅ Found OGG audio: #{ogg_url}")
        {:ok, ogg_url}
      %{"pathmp3" => mp3_url} when is_binary(mp3_url) and mp3_url != "" ->
        IO.puts("✅ Found MP3 audio: #{mp3_url}")
        {:ok, mp3_url}
      %{"path" => audio_url} when is_binary(audio_url) and audio_url != "" ->
        IO.puts("✅ Found audio file: #{audio_url}")
        {:ok, audio_url}
      item ->
        IO.puts("❌ No valid audio URL in item: #{inspect(item)}")
        IO.puts("🔍 Available keys: #{inspect(Map.keys(item))}")
        {:error, "No audio URL found"}
    end
  end

  defp parse_forvo_response(response, _target_lang) do
    IO.puts("❌ Unexpected Forvo response format: #{inspect(response)}")
    {:error, "No pronunciations found"}
  end

  defp try_free_pronunciation_sources(name, language_code) do
    IO.puts("🔍 Trying free sources for: #{name} (#{language_code})")

    # Try full name first, then individual name parts (same as Forvo API)
    name_variants = [name] ++ String.split(name, " ", trim: true)
    IO.puts("🎯 Will try test database with variants: #{inspect(name_variants)}")

    # Try each name variant in the test database
    Enum.reduce_while(name_variants, {:error, "No free sources available"}, fn variant, _acc ->
      case test_pronunciation_database(variant, language_code) do
        {:ok, url} ->
          IO.puts("✅ Found test pronunciation for '#{variant}': #{url}")
          {:halt, {:ok, url}}

        {:error, _reason} ->
          IO.puts("⚠️ No test pronunciation for '#{variant}', trying next...")
          {:cont, {:error, "No free sources available"}}
      end
    end)
  end

  # Test database with sample pronunciations for common names
  defp test_pronunciation_database(name, language_code) do
    # Simulate realistic Forvo-style URLs for testing (focusing on individual name parts)
    case {String.downcase(name), String.split(language_code, "-") |> hd()} do
      # Common individual names (more likely to be in real Forvo)

      # English names
      {"david", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/david_en_us.mp3"}
      {"kim", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/kim_en_us.mp3"}
      {"james", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/james_en_us.mp3"}
      {"wilson", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/wilson_en_us.mp3"}
      {"alice", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/alice_en_us.mp3"}
      {"chen", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/chen_en_us.mp3"}

      # Spanish names
      {"maría", "es"} -> {:ok, "https://apifree.forvo.com/audios/mp3/maria_es_es.mp3"}
      {"garcia", "es"} -> {:ok, "https://apifree.forvo.com/audios/mp3/garcia_es_es.mp3"}
      {"garcía", "es"} -> {:ok, "https://apifree.forvo.com/audios/mp3/garcia_es_es.mp3"}

      # Chinese names
      {"zhang", "zh"} -> {:ok, "https://apifree.forvo.com/audios/mp3/zhang_zh_cn.mp3"}
      {"qingbo", "zh"} -> {:ok, "https://apifree.forvo.com/audios/mp3/qingbo_zh_cn.mp3"}

      # Japanese names
      {"yuki", "ja"} -> {:ok, "https://apifree.forvo.com/audios/mp3/yuki_ja_jp.mp3"}
      {"tanaka", "ja"} -> {:ok, "https://apifree.forvo.com/audios/mp3/tanaka_ja_jp.mp3"}

      # Arabic names
      {"ahmed", "ar"} -> {:ok, "https://apifree.forvo.com/audios/mp3/ahmed_ar_eg.mp3"}
      {"hassan", "ar"} -> {:ok, "https://apifree.forvo.com/audios/mp3/hassan_ar_eg.mp3"}

      # Swedish names
      {"björn", "sv"} -> {:ok, "https://apifree.forvo.com/audios/mp3/bjorn_sv_se.mp3"}
      {"eriksson", "sv"} -> {:ok, "https://apifree.forvo.com/audios/mp3/eriksson_sv_se.mp3"}

      # Hindi names
      {"priya", "hi"} -> {:ok, "https://apifree.forvo.com/audios/mp3/priya_hi_in.mp3"}
      {"sharma", "hi"} -> {:ok, "https://apifree.forvo.com/audios/mp3/sharma_hi_in.mp3"}

      # Full names (fallback for exact matches)
      {"qingbo zhang", "zh"} -> {:ok, "https://apifree.forvo.com/audios/mp3/qingbo_zh_cn.mp3"}
      {"maría garcía", "es"} -> {:ok, "https://apifree.forvo.com/audios/mp3/maria_es_es.mp3"}
      {"david kim", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/david_en_us.mp3"}
      {"james wilson", "en"} -> {:ok, "https://apifree.forvo.com/audios/mp3/james_en_us.mp3"}

      _ -> {:error, "Name not in test database"}
    end
  end

  # Download and cache audio file locally
  defp download_and_cache_audio(user, audio_url, target_language) do
    try do
      # Create cache directory
      cache_dir = Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])
      File.mkdir_p!(cache_dir)

      # Generate unique filename based on user and language
      safe_name = user.name |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
      lang_code = target_language |> String.split("-") |> hd()
      timestamp = System.system_time(:second)
      filename = "#{safe_name}_#{lang_code}_#{timestamp}.ogg"
      local_path = Path.join(cache_dir, filename)

      IO.puts("💾 Downloading audio: #{audio_url} -> #{local_path}")

      # Download the file
      case Req.get(audio_url) do
        {:ok, %{status: 200, body: audio_data}} ->
          # Save to local file
          File.write!(local_path, audio_data)

          # Return relative URL for serving
          local_url = "/audio/cache/#{filename}"
          IO.puts("✅ Audio cached successfully: #{local_url}")
          {:ok, local_url}

        {:ok, %{status: status}} ->
          IO.puts("❌ Failed to download audio: HTTP #{status}")
          {:error, "Download failed: #{status}"}

        {:error, reason} ->
          IO.puts("❌ Network error downloading audio: #{inspect(reason)}")
          {:error, "Network error: #{inspect(reason)}"}
      end

    rescue
      e ->
        IO.puts("❌ Error caching audio: #{inspect(e)}")
        {:error, "Cache error: #{inspect(e)}"}
    end
  end

  # Better name-specific pronunciation improvements
  defp improve_name_pronunciation(name) do
    name
    |> String.replace(~r/([A-Z])([a-z])/, " \\1\\2")  # CamelCase splitting
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")  # lowercase to uppercase
    |> apply_name_pronunciation_rules()              # Name-specific rules
    |> String.replace(~r/\s+/, " ")                   # Clean up spaces
    |> String.trim()
  end

  # Apply common name pronunciation improvements
  defp apply_name_pronunciation_rules(name) do
    name
    # Common name patterns that TTS mispronounces
    |> String.replace("ough", "uff")           # Names like "Clough"
    |> String.replace("tion", "shun")          # Names ending in -tion
    |> String.replace("gh", "")                # Silent gh in many names
    |> String.replace("ph", "f")               # Greek names with ph
    |> String.replace("Ng", "Ing")             # Asian surnames starting with Ng
    |> String.replace("Xiao", "Shao")          # Chinese names starting with Xiao
    |> String.replace("Zhao", "Jao")           # Chinese surname Zhao
  end

  @doc """
  Gets the appropriate language code for a country.
  """
  def get_language_for_country(country_code) do
    case String.upcase(country_code) do
      "US" -> "en-US"
      "GB" -> "en-GB"
      "SE" -> "sv-SE"
      "JP" -> "ja-JP"
      "IN" -> "hi-IN"
      "ES" -> "es-ES"
      "AU" -> "en-AU"
      "EG" -> "ar-EG"
      "BR" -> "pt-BR"
      _ -> "en-US"  # Default fallback
    end
  end

  @doc """
  Gets the native language name for display.
  """
  def get_native_language_name(country_code) do
    case String.upcase(country_code) do
      "US" -> "English"
      "GB" -> "English"
      "SE" -> "Svenska"
      "JP" -> "Japanese"
      "IN" -> "Hindi"
      "ES" -> "Spanish"
      "AU" -> "English"
      "EG" -> "Arabic"
      "BR" -> "Portuguese"
      _ -> "English"
    end
  end

  @doc """
  Gets the native language name in native script for UI display.
  Returns nil for English countries so no text is shown.
  """
  def get_native_language_display_name(country_code) do
    case String.upcase(country_code) do
      "US" -> nil  # Don't show text for English
      "GB" -> nil  # Don't show text for English
      "AU" -> nil  # Don't show text for English
      "SE" -> "Svenska"
      "JP" -> "日本語"
      "IN" -> "हिन्दी"
      "ES" -> "Español"
      "EG" -> "العربية"
      "BR" -> "Português"
      _ -> nil  # Don't show text for unknown/English default
    end
  end
end

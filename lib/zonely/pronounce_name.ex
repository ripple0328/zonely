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
  @spec play(String.t(), String.t()) ::
          {:play_audio | :play_tts | :play_tts_audio | :play_sequence, map()}
  def play(name, language) when is_binary(name) and is_binary(language) do
    Logger.info("🎯 PronunceName.play called: name=#{inspect(name)}, language=#{language}")

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
        Analytics.track_async("pronunciation_cache_hit", %{name_hash: Analytics.hash_name(name), lang: language, provider: "cache"})
        {:audio_url, cached_url}

      :not_found ->
        Logger.info("📦 Cache miss for name=#{inspect(name)} lang=#{language}")
        Analytics.track_async("pronunciation_cache_miss", %{name_hash: Analytics.hash_name(name), lang: language})
        # 2) Try name variants systematically: full name first, then decide on fallback strategy
        case try_name_variants_with_providers(name, language) do
          {:ok, {:sequence, urls}} ->
            {:sequence, urls}

          {:ok, audio_url} ->
            Logger.info("🌐 External audio found -> #{audio_url}")
            Analytics.track_async("pronunciation_generated", %{name_hash: Analytics.hash_name(name), lang: language, provider: "external"})
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
                Analytics.track_async("pronunciation_error", %{name_hash: Analytics.hash_name(name), lang: language, provider: "polly", reason: inspect(reason)})

                {:tts, name, language}
            end

          {:error, :not_found} ->
            Logger.info(
              "↪️ External sources unavailable; attempting AWS Polly for #{inspect(name)} (#{language})"
            )

            case Zonely.PronunceName.Providers.Polly.synthesize(name, language) do
              {:ok, web_path} ->
                Logger.info("✅ Polly synth success -> #{web_path}")
                Analytics.track_async("pronunciation_generated", %{name_hash: Analytics.hash_name(name), lang: language, provider: "polly"})
                {:audio_url, web_path}

              {:error, reason} ->
                Logger.warning(
                  "❌ Polly synth failed (#{inspect(reason)}); falling back to browser TTS"
                )
                Analytics.track_async("pronunciation_error", %{name_hash: Analytics.hash_name(name), lang: language, provider: "polly", reason: inspect(reason)})

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
    # Race providers in parallel and return the first success
    race_timeout_ms = Application.get_env(:zonely, :provider_race_timeout_ms, 1500)

    providers =
      [
        {:name_shouts, fn ->
           Zonely.PronunceName.Providers.NameShouts.fetch_single(variant, language, original_name)
         end},
        {:forvo, fn ->
           Zonely.PronunceName.Providers.Forvo.fetch_single(variant, language, original_name)
         end}
      ]
      |> Enum.reject(fn {provider, _fun} ->
        Zonely.PronunceName.NegativeCache.failed_recently?(provider, variant, language)
      end)

    # Start tasks manually so we can attribute timeouts to providers
    tasks =
      Enum.map(providers, fn {tag, fun} ->
        task =
          Task.async(fn ->
            started_ms = System.monotonic_time(:millisecond)
            value = fun.()
            duration_ms = System.monotonic_time(:millisecond) - started_ms
            {tag, duration_ms, value}
          end)

        {tag, task}
      end)

    # Wait up to race_timeout_ms for all tasks
    results = Task.yield_many(Enum.map(tasks, &elem(&1, 1)), race_timeout_ms)

    # Handle results, record negatives on failures/timeouts, and prefer NameShouts
    acc =
      Enum.reduce(results, %{ns: nil, fv: nil}, fn {task, res}, acc ->
        {tag, _task} = Enum.find(tasks, fn {_t_tag, t} -> t.ref == task.ref end)

        case res do
          {:ok, {:name_shouts, duration_ms, {:ok, {:sequence, _} = seq}}} ->
            Logger.info("⚡ Provider :name_shouts succeeded in #{duration_ms}ms for #{inspect(variant)} (sequence)")
            Map.put(acc, :ns, {:ok, seq})

          {:ok, {:name_shouts, duration_ms, {:ok, url}}} when is_binary(url) ->
            Logger.info("⚡ Provider :name_shouts succeeded in #{duration_ms}ms for #{inspect(variant)}")
            Map.put(acc, :ns, {:ok, url})

          {:ok, {:forvo, duration_ms, {:ok, {:sequence, _} = seq}}} ->
            Logger.info("⚡ Provider :forvo succeeded in #{duration_ms}ms for #{inspect(variant)} (sequence)")
            Map.put(acc, :fv, {:ok, seq})

          {:ok, {:forvo, duration_ms, {:ok, url}}} when is_binary(url) ->
            Logger.info("⚡ Provider :forvo succeeded in #{duration_ms}ms for #{inspect(variant)}")
            Map.put(acc, :fv, {:ok, url})

          {:ok, {^tag, duration_ms, {:error, reason}}} ->
            Logger.info("⏭ Provider #{inspect(tag)} failed in #{duration_ms}ms (#{inspect(reason)}) for #{inspect(variant)}")
            Zonely.PronunceName.NegativeCache.put_failure(tag, variant, language, reason)
            acc

          nil ->
            Logger.warning("⛔ Provider task exited: :timeout for #{inspect(variant)} (#{inspect(tag)})")
            Task.shutdown(task, :brutal_kill)
            Zonely.PronunceName.NegativeCache.put_failure(tag, variant, language, :timeout)
            acc

          {:exit, reason} ->
            Logger.warning("⛔ Provider task exited: #{inspect(reason)} for #{inspect(variant)} (#{inspect(tag)})")
            acc
        end
      end)

    cond do
      match?({:ok, _}, acc.ns) -> acc.ns
      match?({:ok, _}, acc.fv) -> acc.fv
      true -> {:error, :not_found}
    end
  end

  # (AWS request indirection moved into Providers.Polly)

  # Remove old Polly helpers (moved to Providers.Polly)

  @doc """
  Selects appropriate Polly voice for a language.
  Delegates to VoiceSelector module.
  """
  @spec pick_polly_voice(String.t()) :: String.t()
  def pick_polly_voice(bcp47) do
    Zonely.VoiceSelector.select_polly_voice(bcp47)
  end

  # (binary cache writing lives in Zonely.PronunceName.Cache)

  # Submodules moved to their own files under lib/zonely/pronounce_name/

  # (Forvo fetch helpers moved to Providers.Forvo)

  # (Forvo request logic moved to Providers.Forvo)

  # (external download moved to Cache.write_external_and_cache/4)

  # (Name parts generation moved to NameShoutsParser module)

  # (Forvo API key access handled in Providers.Forvo)

  # ————————————————————————————————————————————————————————————
  # NameShouts integration (https://v1.nameshouts.com/welcome/dev/docs#requests)
  # ————————————————————————————————————————————————————————————

  # (NameShouts integration moved to Providers.NameShouts)

  @doc """
  Analyzes NameShouts API response and selects best variant.
  Delegates to NameShoutsParser module.
  """
  @spec pick_nameshouts_variant(map(), String.t(), String.t()) ::
          {:ok, String.t()} | {:ok, [String.t()]} | {:error, atom()}
  def pick_nameshouts_variant(response_body, name, language) do
    Zonely.NameShoutsParser.pick_variant(response_body, name, language)
  end

  # (Language variant analysis moved to NameShoutsParser module)

  # (Name-based lookup functions moved to NameShoutsParser module)

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

  @doc """
  Converts BCP47 language code to display name.
  Delegates to NameShoutsParser module.
  """
  @spec language_display_name_from_bcp47(String.t()) :: String.t()
  def language_display_name_from_bcp47(bcp47) do
    Zonely.NameShoutsParser.language_display_name(bcp47)
  end

  # (duplicate Cache module removed)

  # Unified HTTP client indirection for testability
  def http_client do
    Application.get_env(:zonely, :http_client, Zonely.HttpClient.Req)
  end
end

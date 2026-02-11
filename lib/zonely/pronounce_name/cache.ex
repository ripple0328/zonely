defmodule Zonely.PronunceName.Cache do
  @moduledoc false
  alias Zonely.AudioCache
  require Logger
  require Logger

  @spec lookup_cached_audio(String.t(), String.t()) :: {:ok, String.t(), :local | :remote} | :not_found
  def lookup_cached_audio(name, language) do
    primary_dir = AudioCache.dir()
    legacy_dir = Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])

    variant_safe_names =
      [name | local_variants(name)]
      |> Enum.uniq()
      |> Enum.map(&String.replace(&1, ~r/[^a-zA-Z0-9_-]/, "_"))

    lang_candidates =
      case String.split(language || "", "-") do
        [base, _rest] when byte_size(base) > 0 -> [language, base]
        [only] when byte_size(only) > 0 -> [only]
        _ -> [language]
      end
      |> Enum.uniq()

    # Policy: Do not cache or look up real-person provider audio.
    # We only consider AI TTS (Polly) files in local storage.

    # Collect candidate files from both primary and legacy directories (local caches)
    candidate_lists =
      [primary_dir, legacy_dir]
      |> Enum.filter(&File.dir?/1)
      |> Enum.map(fn dir ->
        case File.ls(dir) do
          {:ok, entries} -> {dir, entries}
          _ -> {dir, []}
        end
      end)

    with true <- length(candidate_lists) > 0 do
      # Find matches in each directory, but only consider Polly cached files (AI TTS)
      matches =
        Enum.flat_map(candidate_lists, fn {dir, entries} ->
          # Look for Polly cached files (AI-generated audio)
          polly_voice = Zonely.PronunceName.pick_polly_voice(language)

          polly_key =
            # Use original name to avoid collisions for non-Latin characters
            :crypto.hash(:sha256, Enum.join([name, language, polly_voice], ":"))
            |> Base.encode16(case: :lower)

          expected_polly_prefix = "polly_#{polly_key}"

          polly_files =
            entries
            |> Enum.filter(fn filename ->
              String.starts_with?(filename, expected_polly_prefix)
            end)
            |> Enum.map(&{dir, &1, :polly})

          polly_files
        end)

      # Pick newest Polly file (lexicographically last). If none, not_found.
      case (
             matches
             |> Enum.filter(fn {_d, _f, k} -> k == :polly end)
             |> Enum.map(&elem(&1, 1))
             |> Enum.sort()
             |> List.last()
           ) do
        nil ->
          # Try remote cache (S3) if enabled
          polly_voice = Zonely.PronunceName.pick_polly_voice(language)

          polly_key =
            :crypto.hash(:sha256, Enum.join([name, language, polly_voice], ":"))
            |> Base.encode16(case: :lower)

          polly_filename = "polly_#{polly_key}.mp3"
          remote_key = "polly/" <> polly_filename

          if Zonely.Storage.exists?(remote_key) do
            {:ok, Zonely.Storage.public_url(remote_key), :remote}
          else
            :not_found
          end

        polly_filename ->
          which_dir =
            Enum.find_value(candidate_lists, fn {dir, entries} ->
              if polly_filename in entries, do: dir, else: nil
            end)

          web_path =
            if which_dir == legacy_dir,
              do: "/audio/cache/#{polly_filename}",
              else: "/audio-cache/#{polly_filename}"

          {:ok, web_path, :local}
      end
    end
  end

  # S3 lookup for provider audio is disabled by policy. We only use local Polly cache.
  defp s3_lookup_key(_name, _language, _variant_safe_names, _lang_candidates, _bucket), do: nil

  @spec write_binary_to_cache(binary(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def write_binary_to_cache(audio_bin, name, language, ext) do
    voice = Zonely.PronunceName.pick_polly_voice(language)

    # Use original name for hashing to align with lookup logic
    key =
      :crypto.hash(:sha256, Enum.join([name, language, voice], ":"))
      |> Base.encode16(case: :lower)

    filename = "polly_#{key}#{ext}"

    # Write to external storage when configured (preferred)
    key = "polly/" <> filename

    case Zonely.Storage.put(key, audio_bin) do
      :ok ->
        # Best-effort local cache for faster hits
        cache_dir = AudioCache.dir()
        File.mkdir_p!(cache_dir)
        local_path = Path.join(cache_dir, filename)
        _ = File.write(local_path, audio_bin)

        {:ok, Zonely.Storage.public_url(key)}

      {:error, _} ->
        # Fallback to local FS
        cache_dir = AudioCache.dir()
        File.mkdir_p!(cache_dir)
        local_path = Path.join(cache_dir, filename)
        web_path = "/audio-cache/#{filename}"

        case File.write(local_path, audio_bin) do
          :ok -> {:ok, web_path}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec write_external_and_cache(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, atom()}
  def write_external_and_cache(_audio_url, _name, _language, _ext) do
    Logger.warning("External provider caching disabled by policy")
    {:error, :disabled_by_policy}
  end

  @spec write_external_and_cache_with_metadata(
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t()
        ) ::
          {:ok, String.t()} | {:error, atom()}
  def write_external_and_cache_with_metadata(_audio_url, _cache_name, _original_name, _found_variant, _language, _ext) do
    Logger.warning("External provider caching disabled by policy")
    {:error, :disabled_by_policy}
  end

  defp local_variants(name) do
    parts = String.split(name, " ", trim: true)

    case parts do
      [single] -> [single]
      [first, last] -> [name, first, last]
      multiple -> [name | multiple]
    end
  end
end

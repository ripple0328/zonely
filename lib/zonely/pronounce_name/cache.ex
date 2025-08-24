defmodule Zonely.PronunceName.Cache do
  @moduledoc false
  alias Zonely.AudioCache
  require Logger
  require Logger

  @spec lookup_cached_audio(String.t(), String.t()) :: {:ok, String.t()} | :not_found
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

    # If configured to use S3, consult the bucket first so cached files written
    # by other machines are visible across instances.
    case Application.get_env(:zonely, :audio_cache, []) do
      %{backend: backend, s3_bucket: bucket} when is_binary(backend) and backend == "s3" and is_binary(bucket) ->
        s3_key = s3_lookup_key(name, language, variant_safe_names, lang_candidates, bucket)
        case s3_key do
          nil -> :noop
          key when is_binary(key) ->
            return_url = Zonely.Storage.public_url(key)
            Logger.info("📦 Cache hit (S3) -> #{return_url}")
            {:ok, return_url}
        end
      _ -> :noop
    end

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
      # Find matches in each directory
      # Use the same safe-name transformation used when writing files
      safe_name_for_hash = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")

      matches =
        Enum.flat_map(candidate_lists, fn {dir, entries} ->
          # Look for regular cached files (real person audio)
          regular_files =
            entries
            |> Enum.filter(fn filename ->
              Enum.any?(variant_safe_names, fn vn ->
                Enum.any?(lang_candidates, fn lc ->
                  String.starts_with?(filename, vn <> "_" <> lc <> "_")
                end)
              end)
            end)
            |> Enum.map(&{dir, &1, :regular})

          # Look for Polly cached files (AI-generated audio)
          polly_voice = Zonely.PronunceName.pick_polly_voice(language)
          polly_key =
            :crypto.hash(:sha256, Enum.join([safe_name_for_hash, language, polly_voice], ":"))
            |> Base.encode16(case: :lower)
          expected_polly_prefix = "polly_#{polly_key}"

          polly_files =
            entries
            |> Enum.filter(fn filename -> String.starts_with?(filename, expected_polly_prefix) end)
            |> Enum.map(&{dir, &1, :polly})

          regular_files ++ polly_files
        end)

      # Prefer regular files; if none, fall back to Polly. Pick newest (lexicographically last)
      case {
             matches |> Enum.filter(fn {_d, _f, k} -> k == :regular end) |> Enum.map(&elem(&1, 1)) |> Enum.sort() |> List.last(),
             matches |> Enum.filter(fn {_d, _f, k} -> k == :polly end) |> Enum.map(&elem(&1, 1)) |> Enum.sort() |> List.last()
           } do
        {nil, nil} -> :not_found
        {filename, _} when is_binary(filename) ->
          # Determine which dir this filename was found in
          which_dir =
            Enum.find_value(candidate_lists, fn {dir, entries} ->
              if filename in entries, do: dir, else: nil
            end)
          web_path = if which_dir == legacy_dir, do: "/audio/cache/#{filename}", else: "/audio-cache/#{filename}"
          {:ok, web_path}
        {nil, polly_filename} ->
          which_dir =
            Enum.find_value(candidate_lists, fn {dir, entries} ->
              if polly_filename in entries, do: dir, else: nil
            end)
          web_path = if which_dir == legacy_dir, do: "/audio/cache/#{polly_filename}", else: "/audio-cache/#{polly_filename}"
          {:ok, web_path}
      end
    end
  end

  # Build the best S3 object key for a name/language pair if present.
  # Prefers real-person audio under "real/" prefix, falls back to deterministic
  # Polly key under "polly/".
  defp s3_lookup_key(name, language, variant_safe_names, lang_candidates, bucket) do
    safe_name_for_hash = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")

    # First, try deterministic real-person key
    deterministic_real_key = "real/#{safe_name_for_hash}_#{language}.mp3"
    case ExAws.S3.head_object(bucket, deterministic_real_key) |> ExAws.request() do
      {:ok, _} -> deterministic_real_key
      _ ->
        # Fallback to legacy timestamped objects
        real_prefixes = for vn <- variant_safe_names, lc <- lang_candidates, do: "real/#{vn}_#{lc}_"

        list_keys = fn prefix ->
          case ExAws.S3.list_objects_v2(bucket, prefix: prefix) |> ExAws.request() do
            {:ok, %{body: %{contents: contents}}} when is_list(contents) -> Enum.map(contents, & &1.key)
            {:ok, %{body: %{contents: nil}}} -> []
            _ -> []
          end
        end

        real_keys = real_prefixes |> Enum.flat_map(list_keys)
        best_real = real_keys |> Enum.sort() |> List.last()

        if is_binary(best_real) do
          best_real
        else
          # Try Polly hash key (deterministic)
          polly_voice = Zonely.PronunceName.pick_polly_voice(language)
          polly_key =
            :crypto.hash(:sha256, Enum.join([safe_name_for_hash, language, polly_voice], ":"))
            |> Base.encode16(case: :lower)
          key = "polly/polly_#{polly_key}.mp3"

          case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
            {:ok, _} -> key
            _ -> nil
          end
        end
    end
  end

  @spec write_binary_to_cache(binary(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def write_binary_to_cache(audio_bin, name, language, ext) do
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    voice = Zonely.PronunceName.pick_polly_voice(language)

    key =
      :crypto.hash(:sha256, Enum.join([safe_name, language, voice], ":"))
      |> Base.encode16(case: :lower)

    filename = "polly_#{key}#{ext}"

    # Write to external storage when configured (preferred)
    key = "polly/" <> filename
    case Zonely.Storage.put(key, audio_bin) do
      :ok -> {:ok, Zonely.Storage.public_url(key)}
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
  def write_external_and_cache(audio_url, name, language, ext) do
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    # Deterministic filename (no timestamp) so we only store one per name/lang
    filename = "#{safe_name}_#{language}#{ext}"

    cfg = Application.get_env(:zonely, :audio_cache, [])
    backend = (cfg[:backend] || "local") |> String.downcase()

    if backend == "s3" and is_binary(cfg[:s3_bucket]) do
      bucket = cfg[:s3_bucket]
      key = "real/#{filename}"

      # If it already exists, return URL immediately
      case ExAws.S3.head_object(bucket, key) |> ExAws.request() do
        {:ok, _} ->
          url = Zonely.Storage.public_url(key)
          Logger.info("📦 Cache hit (S3, deterministic) -> #{url}")
          {:ok, url}

        _ ->
          # Download from provider then upload to S3 once
          case Zonely.PronunceName.http_client().get(audio_url) do
            {:ok, %{status: 200, body: audio_data}} ->
              case Zonely.Storage.put(key, audio_data) do
                :ok -> {:ok, Zonely.Storage.public_url(key)}
                {:error, _} -> {:error, :write_failed}
              end

            {:ok, %{status: _}} -> {:error, :download_failed}
            {:error, _} -> {:error, :request_failed}
          end
      end
    else
      # Local backend: write once to deterministic filename
      cache_dir = AudioCache.dir()
      File.mkdir_p!(cache_dir)
      local_path = Path.join(cache_dir, filename)
      web_path = "/audio-cache/#{filename}"

      if File.exists?(local_path) do
        {:ok, web_path}
      else
        case Zonely.PronunceName.http_client().get(audio_url) do
          {:ok, %{status: 200, body: audio_data}} ->
            case File.write(local_path, audio_data) do
              :ok -> {:ok, web_path}
              {:error, _} -> {:error, :write_failed}
            end

          {:ok, %{status: _}} -> {:error, :download_failed}
          {:error, _} -> {:error, :request_failed}
        end
      end
    end
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

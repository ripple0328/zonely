defmodule Zonely.PronunceName.Cache do
  @moduledoc false
  alias Zonely.AudioCache

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

    # Collect candidate files from both primary and legacy directories
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

  @spec write_binary_to_cache(binary(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def write_binary_to_cache(audio_bin, name, language, ext) do
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    voice = Zonely.PronunceName.pick_polly_voice(language)

    key =
      :crypto.hash(:sha256, Enum.join([safe_name, language, voice], ":"))
      |> Base.encode16(case: :lower)

    filename = "polly_#{key}#{ext}"

    cache_dir = AudioCache.dir()
    File.mkdir_p!(cache_dir)

    local_path = Path.join(cache_dir, filename)
    web_path = "/audio-cache/#{filename}"

    case File.exists?(local_path) do
      true ->
        {:ok, web_path}

      false ->
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
    timestamp = System.system_time(:second)
    filename = "#{safe_name}_#{language}_#{timestamp}#{ext}"

    cache_dir = AudioCache.dir()
    File.mkdir_p!(cache_dir)

    local_path = Path.join(cache_dir, filename)
    web_path = "/audio-cache/#{filename}"

    case Zonely.PronunceName.http_client().get(audio_url) do
      {:ok, %{status: 200, body: audio_data}} ->
        case File.write(local_path, audio_data) do
          :ok -> {:ok, web_path}
          {:error, _} -> {:error, :write_failed}
        end

      {:ok, %{status: _}} ->
        {:error, :download_failed}

      {:error, _} ->
        {:error, :request_failed}
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

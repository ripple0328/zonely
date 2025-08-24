defmodule Zonely.PronunceName.Cache do
  @moduledoc false

  @cache_dir Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])

  @spec lookup_cached_audio(String.t(), String.t()) :: {:ok, String.t()} | :not_found
  def lookup_cached_audio(name, language) do
    cache_dir = @cache_dir
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

  @spec write_binary_to_cache(binary(), String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def write_binary_to_cache(audio_bin, name, language, ext) do
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    voice = Zonely.PronunceName.pick_polly_voice(language)
    key = :crypto.hash(:sha256, Enum.join([safe_name, language, voice], ":")) |> Base.encode16(case: :lower)
    filename = "polly_#{key}#{ext}"

    cache_dir = @cache_dir
    File.mkdir_p!(cache_dir)

    local_path = Path.join(cache_dir, filename)
    web_path = "/audio/cache/#{filename}"

    case File.exists?(local_path) do
      true -> {:ok, web_path}
      false ->
        case File.write(local_path, audio_bin) do
          :ok -> {:ok, web_path}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec write_external_and_cache(String.t(), String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def write_external_and_cache(audio_url, name, language, ext) do
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    timestamp = System.system_time(:second)
    filename = "#{safe_name}_#{language}_#{timestamp}#{ext}"

    cache_dir = @cache_dir
    File.mkdir_p!(cache_dir)

    local_path = Path.join(cache_dir, filename)
    web_path = "/audio/cache/#{filename}"

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

  defp local_variants(name) do
    parts = String.split(name, " ", trim: true)
    case parts do
      [single] -> [single]
      [first, last] -> [name, first, last]
      multiple -> [name | multiple]
    end
  end
end

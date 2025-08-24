defmodule Zonely.Storage do
  @moduledoc """
  Minimal storage abstraction for audio cache.
  Supports :s3 backend (via ExAws) or :local (filesystem fallback).
  """

  require Logger

  @type key :: String.t()

  def config do
    cfg = Application.get_env(:zonely, :audio_cache, [])
    backend = (cfg[:backend] || "s3") |> String.downcase()
    %{
      backend: backend,
      bucket: cfg[:s3_bucket] || "zonely-cache",
      public_base_url: cfg[:public_base_url] || "https://zonely-cache.s3.amazonaws.com",
      s3_endpoint: cfg[:s3_endpoint]
    }
  end

  @doc """
  Upload binary to storage under key.
  """
  @spec put(key(), binary()) :: :ok | {:error, term()}
  def put(key, bin) when is_binary(key) and is_binary(bin) do
    case config().backend do
      "s3" -> put_s3(key, bin)
      _ -> put_local(key, bin)
    end
  end

  @doc """
  Return public URL for the given key.
  """
  @spec public_url(key()) :: String.t()
  def public_url(key) do
    case config().backend do
      "s3" ->
        base = config().public_base_url |> String.trim_trailing("/")
        base <> "/" <> key

      _ ->
        # Local fallback uses app-served route
        "/audio-cache/" <> Path.basename(key)
    end
  end

  defp put_s3(key, bin) do
    cfg = config()
    opts =
      []
      |> maybe_endpoint(cfg.s3_endpoint)

    case ExAws.S3.put_object(cfg.bucket, key, bin, content_type: MIME.from_path(key) || "audio/mpeg")
         |> ExAws.request(opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_endpoint(opts, nil), do: opts
  defp maybe_endpoint(opts, endpoint), do: Keyword.put(opts, :endpoint, endpoint)

  defp put_local(key, bin) do
    dir = Zonely.AudioCache.dir()
    filename = Path.basename(key)
    path = Path.join(dir, filename)
    case File.write(path, bin) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end

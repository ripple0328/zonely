defmodule Zonely.AudioCache do
  @moduledoc """
  Config-driven audio cache for runtime-generated audio files.

  - Directory is configured via `:audio_cache_dir` in application env
  - Files are served through `ZonelyWeb.AudioCacheController` at `/audio-cache/:filename`
  """

  @app :zonely

  @doc """
  Returns the configured cache directory and ensures it exists.
  """
  @spec dir() :: String.t()
  def dir do
    dir = Application.fetch_env!(@app, :audio_cache_dir)
    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Validates and returns an absolute path for a cached filename.
  Only allows letters, numbers, underscore, hyphen and dot to prevent traversal.
  """
  @spec path_for(String.t()) :: String.t()
  def path_for(filename) when is_binary(filename) do
    if Regex.match?(~r/^[\w\-.]+$/, filename) do
      Path.join(dir(), filename)
    else
      raise ArgumentError, "invalid filename"
    end
  end

  @doc """
  Saves a binary to the cache using the provided filename.
  Returns the absolute file path.
  """
  @spec save!(String.t(), binary()) :: String.t()
  def save!(filename, binary) when is_binary(binary) do
    path = path_for(filename)
    File.write!(path, binary)
    path
  end
end

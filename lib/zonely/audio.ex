defmodule Zonely.Audio do
  @moduledoc """
  Domain module for handling audio-related functionality including pronunciation, TTS, and audio caching.

  This module provides a clean interface for:
  - Playing name pronunciations with multiple fallback strategies
  - Managing audio cache and downloads
  - Text-to-speech integration
  - External pronunciation service integration
  """

  alias Zonely.Accounts.User
  alias Zonely.Geography

  require Logger

  @doc """
  Plays pronunciation for a user's name in English.

  This is the main interface for English pronunciation, handling:
  1. Cached audio lookup
  2. External service fetching
  3. TTS fallback

  ## Examples

      iex> user = %User{name: "John Doe", country: "US"}
      iex> Zonely.Audio.play_english_pronunciation(user)
      {:play_tts, %{text: "John Doe", lang: "en-US"}}
  """
  @spec play_english_pronunciation(User.t()) :: {:play_audio | :play_tts | :play_tts_audio, map()}
  def play_english_pronunciation(%User{name: name, country: country}) do
    Logger.info("🔊 Playing English pronunciation: #{name}")

    english_locale = derive_english_locale(country)

    case Zonely.PronunceName.play(name, english_locale) do
      result ->
        Logger.info("✅ English pronunciation result: #{inspect(result)}")
        result
    end
  end

  @doc """
  Plays pronunciation for a user's name in their native language.

  Only used when the user has a different native name than their English name.

  ## Examples

      iex> user = %User{name: "Jose Garcia", name_native: "José García", country: "ES"}
      iex> Zonely.Audio.play_native_pronunciation(user)
      {:play_tts, %{text: "José García", lang: "es-ES"}}
  """
  @spec play_native_pronunciation(User.t()) :: {:play_audio | :play_tts | :play_tts_audio, map()}
  def play_native_pronunciation(%User{name_native: native_name, country: country})
      when is_binary(native_name) do
    Logger.info("🌍 Playing native pronunciation: #{native_name} (#{country})")

    native_locale = Geography.country_to_locale(country)

    case Zonely.PronunceName.play(native_name, native_locale) do
      result ->
        Logger.info("✅ Native pronunciation result: #{inspect(result)}")
        result
    end
  end

  def play_native_pronunciation(%User{name: name, country: country}) do
    # Fallback to regular name if no native name
    Logger.info("🔄 No native name, falling back to regular name: #{name}")
    play_english_pronunciation(%User{name: name, country: country})
  end

  @doc """
  Determines the appropriate English locale based on user's country.

  ## Examples

      iex> Zonely.Audio.derive_english_locale("US")
      "en-US"

      iex> Zonely.Audio.derive_english_locale("GB")
      "en-GB"

      iex> Zonely.Audio.derive_english_locale("ES")
      "en-US"  # Default for non-English countries
  """
  @spec derive_english_locale(String.t() | nil) :: String.t()
  def derive_english_locale(country) when is_binary(country) do
    case String.upcase(country) do
      "US" -> "en-US"
      "GB" -> "en-GB"
      "CA" -> "en-CA"
      "AU" -> "en-AU"
      "IE" -> "en-IE"
      "NZ" -> "en-NZ"
      "ZA" -> "en-ZA"
      # Default to US English for other countries
      _ -> "en-US"
    end
  end

  def derive_english_locale(_), do: "en-US"

  @doc """
  Checks if audio file exists in cache for a given name and language.

  ## Examples

      iex> Zonely.Audio.cached_audio_exists?("John Doe", "en-US")
      false
  """
  @spec cached_audio_exists?(String.t(), String.t()) :: boolean()
  def cached_audio_exists?(name, language) when is_binary(name) and is_binary(language) do
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9_-]/, "_")
    cache_dir = get_cache_directory()

    # Check for various possible cached files
    patterns = [
      "#{safe_name}_#{language}_*.ogg",
      "#{safe_name}_#{language}_*.mp3"
    ]

    Enum.any?(patterns, fn pattern ->
      cache_dir
      |> Path.join(pattern)
      |> Path.wildcard()
      |> length() > 0
    end)
  end

  @doc """
  Gets the cache directory path for audio files.

  ## Examples

      iex> Zonely.Audio.get_cache_directory()
      "/path/to/app/priv/static/audio/cache"
  """
  @spec get_cache_directory() :: String.t()
  def get_cache_directory do
    cache_path = Path.join([Application.app_dir(:zonely, "priv"), "static", "audio", "cache"])
    File.mkdir_p!(cache_path)
    cache_path
  end

  @doc """
  Clears old cached audio files to manage disk space.

  Removes files older than the specified number of days.

  ## Examples

      iex> Zonely.Audio.cleanup_cache(30)
      {:ok, 5}  # Removed 5 old files
  """
  @spec cleanup_cache(pos_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def cleanup_cache(days_old \\ 30) do
    cache_dir = get_cache_directory()
    cutoff_time = System.system_time(:second) - days_old * 24 * 60 * 60

    try do
      files_removed =
        cache_dir
        |> Path.join("*")
        |> Path.wildcard()
        |> Enum.filter(fn file ->
          case File.stat(file) do
            {:ok, %{mtime: mtime}} ->
              file_time = :calendar.datetime_to_gregorian_seconds(mtime) - 62_167_219_200
              file_time < cutoff_time

            _ ->
              false
          end
        end)
        |> Enum.map(&File.rm/1)
        |> Enum.count(fn result -> result == :ok end)

      {:ok, files_removed}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Gets statistics about the audio cache.

  ## Examples

      iex> Zonely.Audio.cache_statistics()
      %{
        total_files: 25,
        total_size_mb: 12.5,
        oldest_file_days: 45,
        file_types: %{"ogg" => 20, "mp3" => 5}
      }
  """
  @spec cache_statistics() :: %{
          total_files: non_neg_integer(),
          total_size_mb: float(),
          oldest_file_days: non_neg_integer(),
          file_types: %{String.t() => non_neg_integer()}
        }
  def cache_statistics do
    cache_dir = get_cache_directory()
    current_time = System.system_time(:second)

    files =
      cache_dir
      |> Path.join("*")
      |> Path.wildcard()

    total_size =
      files
      |> Enum.map(fn file ->
        case File.stat(file) do
          {:ok, %{size: size}} -> size
          _ -> 0
        end
      end)
      |> Enum.sum()

    oldest_days =
      files
      |> Enum.map(fn file ->
        case File.stat(file) do
          {:ok, %{mtime: mtime}} ->
            file_time = :calendar.datetime_to_gregorian_seconds(mtime) - 62_167_219_200
            div(current_time - file_time, 24 * 60 * 60)

          _ ->
            0
        end
      end)
      |> Enum.max(fn -> 0 end)

    file_types =
      files
      |> Enum.map(fn file ->
        file |> Path.extname() |> String.trim_leading(".")
      end)
      |> Enum.frequencies()

    %{
      total_files: length(files),
      total_size_mb: Float.round(total_size / (1024 * 1024), 1),
      oldest_file_days: oldest_days,
      file_types: file_types
    }
  end

  @doc """
  Validates if an audio file URL is accessible.

  ## Examples

      iex> Zonely.Audio.validate_audio_url("https://example.com/audio.mp3")
      {:ok, "audio/mpeg"}
  """
  @spec validate_audio_url(String.t()) :: {:ok, String.t()} | {:error, term()}
  def validate_audio_url(url) when is_binary(url) and url != "" do
    try do
      case Req.head(url) do
        {:ok, %{status: 200, headers: headers}} ->
          content_type =
            headers
            |> Map.new()
            |> Map.get("content-type", "unknown")

          {:ok, content_type}

        {:ok, %{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      ArgumentError -> {:error, "Invalid URL format"}
      _ -> {:error, "URL validation failed"}
    end
  end

  def validate_audio_url(_), do: {:error, "Invalid or empty URL"}

  @doc """
  Gets supported audio formats for the application.

  ## Examples

      iex> Zonely.Audio.supported_formats()
      ["ogg", "mp3", "wav"]
  """
  @spec supported_formats() :: [String.t()]
  def supported_formats do
    ["ogg", "mp3", "wav", "m4a"]
  end

  @doc """
  Checks if an audio format is supported.

  ## Examples

      iex> Zonely.Audio.format_supported?("ogg")
      true

      iex> Zonely.Audio.format_supported?("xyz")
      false
  """
  @spec format_supported?(String.t()) :: boolean()
  def format_supported?(format) when is_binary(format) do
    String.downcase(format) in supported_formats()
  end

  @doc """
  Estimates audio file duration based on file size (rough approximation).

  ## Examples

      iex> Zonely.Audio.estimate_duration_seconds("/path/to/audio.ogg")
      {:ok, 15.2}
  """
  @spec estimate_duration_seconds(String.t()) :: {:ok, float()} | {:error, term()}
  def estimate_duration_seconds(file_path) when is_binary(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        # Very rough estimate: assume ~8KB per second for compressed audio
        estimated_seconds = size / 8192
        {:ok, Float.round(estimated_seconds, 1)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

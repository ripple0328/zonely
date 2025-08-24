defmodule Zonely.PronunceName.Providers.NameShouts do
  @moduledoc false
  require Logger
  alias Zonely.PronunceName
  alias Zonely.PronunceName.Cache

  # Legacy function for backward compatibility - delegates to fetch_single
  @spec fetch(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch(name, language) do
    fetch_single(name, language, name)
  end
  
  # Simplified function that handles a single name request
  @spec fetch_single(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch_single(name, language, original_name) do
    api_key = System.get_env("NS_API_KEY") |> to_string() |> String.trim()

    if api_key == "" do
      Logger.warning("No NameShouts API key configured (NS_API_KEY)")
      {:error, :no_api_key}
    else
      headers = [{"NS-API-KEY", api_key}, {"Accept", "application/json"}]
      lang_name = PronunceName.language_display_name_from_bcp47(language) |> String.downcase()
      
      Logger.info("🌐 NameShouts request for #{inspect(name)} lang=#{lang_name}")
      
      try_nameshouts_request(name, lang_name, headers, original_name, language)
    end
  end

  # Try a NameShouts request for a specific name
  defp try_nameshouts_request(name, lang_name, headers, original_name, language) do
    # Per docs, full-name path uses hyphen between parts when language is specified
    encoded_name_for_lang =
      name
      |> String.replace(~r/\s+/, "-")
      |> URI.encode()

    url_with_lang =
      "https://www.v1.nameshouts.com/api/names/#{encoded_name_for_lang}/#{URI.encode(lang_name)}"

    Logger.info("🌐 NameShouts single request to: #{url_with_lang}")
    
    case PronunceName.http_client().get(url_with_lang, headers) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("🔍 DEBUG: NameShouts response body for '#{name}': #{inspect(body)}")
        handle_nameshouts_response(body, name, original_name, language)

      {:error, %Jason.DecodeError{data: data}} ->
        Logger.warning("NameShouts returned malformed JSON; attempting recovery")
        case PronunceName.recover_nameshouts_body_from_decode_error(data) do
          {:ok, body} ->
            handle_nameshouts_response(body, name, original_name, language)
          {:error, _} ->
            {:error, :invalid_response}
        end

      {:ok, %{status: 403}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 404}} ->
        Logger.info("❌ NameShouts: No pronunciation found for '#{name}'")
        {:error, :not_found}

      {:ok, %{status: _}} ->
        {:error, :api_error}

      {:error, _} ->
        {:error, :request_failed}
    end
  end

  # Handle NameShouts response and determine what it actually returned
  defp handle_nameshouts_response(body, requested_name, original_name, language) do
    case PronunceName.pick_nameshouts_variant(body, requested_name, language) do
      {:ok, paths} when is_list(paths) ->
        Logger.info("🔗 NameShouts returned multiple paths for chaining: #{inspect(paths)}")
        case chain_audio_parts(paths, original_name, language) do
          {:ok, cached_url} ->
            Logger.info("✅ Serving chained audio URL -> #{cached_url} (requested: #{requested_name})")
            {:ok, cached_url}
          other -> other
        end

      {:ok, path} when is_binary(path) ->
        audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
        Logger.info("☁️  Uploading to cache (S3/local) -> #{audio_url}")
        Logger.info("🔍 DEBUG: NameShouts returned path '#{path}' for requested name '#{requested_name}'")
        
        # Detect which name part NameShouts actually returned based on the path
        actual_name_part = detect_actual_name_from_path(path, requested_name, original_name)
        
        cache_name = if actual_name_part == original_name do
          Logger.info("✅ NameShouts returned full name pronunciation for: #{original_name}")
          original_name
        else
          Logger.info("📝 NameShouts returned pronunciation for '#{actual_name_part}' (part of '#{original_name}')")
          "#{original_name}_partial_#{actual_name_part}"
        end
        
        case Cache.write_external_and_cache_with_metadata(audio_url, cache_name, original_name, actual_name_part, language, ".mp3") do
          {:ok, cached_url} ->
            Logger.info("✅ Serving cached URL -> #{cached_url} (actual: #{actual_name_part})")
            {:ok, cached_url}
          other -> other
        end

      {:error, reason} ->
        Logger.info("❌ NameShouts has no pronunciation for: #{requested_name}")
        {:error, reason}
    end
  end

  # Detect which name part NameShouts actually returned based on the path
  @spec detect_actual_name_from_path(String.t(), String.t(), String.t()) :: String.t()
  defp detect_actual_name_from_path(path, requested_name, original_name) do
    Logger.info("🔍 Detecting actual name from path '#{path}' (requested: '#{requested_name}', original: '#{original_name}')")
    
    # Remove language suffix and convert to lowercase for analysis
    clean_path = path |> String.downcase() |> String.replace(~r/_[a-z]{2}$/, "")
    
    # Get all possible name parts from the original name
    original_parts = String.split(original_name, [" ", "-"], trim: true)
    
    Logger.info("🔍 Clean path: '#{clean_path}', original parts: #{inspect(original_parts)}")
    
    # Check if the path matches any specific name parts
    matching_parts = Enum.filter(original_parts, fn part ->
      String.contains?(clean_path, String.downcase(part))
    end)
    
    cond do
      # If path contains multiple name parts, likely represents full name
      length(matching_parts) > 1 ->
        Logger.info("✅ Path contains multiple parts #{inspect(matching_parts)} - detected as full name")
        original_name
      
      # If path contains exactly one name part, it's that specific part
      length(matching_parts) == 1 ->
        detected_part = List.first(matching_parts)
        Logger.info("📝 Path contains single part '#{detected_part}' - detected as partial")
        detected_part
      
      # If no obvious match, but we requested the full name, assume it's full
      requested_name == original_name ->
        Logger.info("⚠️ No clear match but requested full name - assuming full name")
        original_name
      
      # Otherwise, assume it's the part we requested
      true ->
        Logger.info("⚠️ No clear match - assuming requested part '#{requested_name}'")
        requested_name
    end
  end
  
  # Chain multiple audio parts together for full name pronunciation
  @spec chain_audio_parts([String.t()], String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp chain_audio_parts(paths, original_name, language) when is_list(paths) do
    Logger.info("🔗 Chaining #{length(paths)} audio parts for '#{original_name}'")
    
    # Convert paths to URLs
    audio_urls = Enum.map(paths, fn path -> 
      "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
    end)
    
    Logger.info("🔗 Audio URLs to chain: #{inspect(audio_urls)}")
    
    case download_and_concatenate_audio(audio_urls, original_name, language) do
      {:ok, concatenated_file} ->
        Logger.info("✅ Audio parts concatenated successfully: #{concatenated_file}")
        
        # Cache the concatenated audio
        case File.read(concatenated_file) do
          {:ok, audio_binary} ->
            case Cache.write_binary_to_cache(audio_binary, original_name, language, ".mp3") do
              {:ok, cached_url} ->
                Logger.info("✅ Cached concatenated audio: #{cached_url}")
                # Clean up temporary file
                File.rm(concatenated_file)
                {:ok, cached_url}
              error ->
                Logger.error("❌ Failed to cache concatenated audio: #{inspect(error)}")
                # Clean up temporary file
                File.rm(concatenated_file)
                error
            end
          error ->
            Logger.error("❌ Failed to read concatenated file: #{inspect(error)}")
            File.rm(concatenated_file)
            error
        end
        
      error ->
        Logger.error("❌ Failed to concatenate audio parts: #{inspect(error)}")
        error
    end
  end
  
  # Download and concatenate multiple audio files using FFmpeg
  @spec download_and_concatenate_audio([String.t()], String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defp download_and_concatenate_audio(audio_urls, _name, _language) do
    temp_dir = System.tmp_dir!()
    unique_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    
    # Download all audio files to temporary locations
    temp_files = Enum.with_index(audio_urls, fn url, index ->
      temp_file = Path.join(temp_dir, "nameshouts_part_#{unique_id}_#{index}.mp3")
      {url, temp_file}
    end)
    
    Logger.info("🔗 Downloading #{length(audio_urls)} audio parts to temporary files")
    
    try do
      # Download all files
      downloaded_files = Enum.map(temp_files, fn {url, temp_file} ->
        case download_audio_file(url, temp_file) do
          :ok -> temp_file
          error -> 
            Logger.error("❌ Failed to download #{url}: #{inspect(error)}")
            throw(error)
        end
      end)
      
      # Concatenate using FFmpeg
      output_file = Path.join(temp_dir, "nameshouts_concatenated_#{unique_id}.mp3")
      
      case concatenate_with_ffmpeg(downloaded_files, output_file) do
        :ok ->
          Logger.info("✅ Successfully concatenated #{length(downloaded_files)} audio files")
          # Clean up temporary download files
          Enum.each(downloaded_files, &File.rm/1)
          {:ok, output_file}
        error ->
          # Clean up all temporary files
          Enum.each(downloaded_files, &File.rm/1)
          File.rm(output_file)
          error
      end
      
    catch
      error ->
        # Clean up any temporary files that were created
        Enum.each(temp_files, fn {_url, temp_file} -> File.rm(temp_file) end)
        error
    end
  end
  
  # Download a single audio file
  @spec download_audio_file(String.t(), String.t()) :: :ok | {:error, atom()}
  defp download_audio_file(url, output_path) do
    case PronunceName.http_client().get(url) do
      {:ok, %{status: 200, body: body}} ->
        File.write(output_path, body)
      {:ok, %{status: status}} ->
        Logger.error("❌ HTTP #{status} when downloading #{url}")
        {:error, :http_error}
      {:error, reason} ->
        Logger.error("❌ Network error downloading #{url}: #{inspect(reason)}")
        {:error, :network_error}
    end
  end
  
  # Concatenate audio files using FFmpeg
  @spec concatenate_with_ffmpeg([String.t()], String.t()) :: :ok | {:error, atom()}
  defp concatenate_with_ffmpeg(input_files, output_file) do
    # Create a concat demuxer input file for FFmpeg
    temp_dir = System.tmp_dir!()
    unique_id = :crypto.strong_rand_bytes(4) |> Base.encode16()
    concat_file = Path.join(temp_dir, "ffmpeg_concat_#{unique_id}.txt")
    
    # Build the concat file content
    concat_content = Enum.map_join(input_files, "\n", fn file ->
      "file '#{String.replace(file, "'", "\\'")}'"
    end)
    
    case File.write(concat_file, concat_content) do
      :ok ->
        # Run FFmpeg to concatenate
        cmd_args = [
          "-f", "concat",
          "-safe", "0", 
          "-i", concat_file,
          "-c", "copy",
          "-y",  # Overwrite output file if it exists
          output_file
        ]
        
        Logger.info("🔗 Running FFmpeg: ffmpeg #{Enum.join(cmd_args, " ")}")
        
        case System.cmd("ffmpeg", cmd_args, stderr_to_stdout: true) do
          {_output, 0} ->
            Logger.info("✅ FFmpeg concatenation successful")
            File.rm(concat_file)
            :ok
          {error_output, exit_code} ->
            Logger.error("❌ FFmpeg failed (exit #{exit_code}): #{error_output}")
            File.rm(concat_file)
            {:error, :ffmpeg_failed}
        end
        
      error ->
        Logger.error("❌ Failed to create FFmpeg concat file: #{inspect(error)}")
        error
    end
  end
end
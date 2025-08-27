defmodule Zonely.PronunceName.Providers.Forvo do
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
    api_key = System.get_env("FORVO_API_KEY")

    if !api_key do
      Logger.warning("No Forvo API key configured")
      {:error, :no_api_key}
    else
      forvo_lang = String.split(language, "-") |> List.first()
      Logger.info("🌐 Forvo request for #{inspect(name)} (#{forvo_lang})")

      try_forvo_request(name, forvo_lang, api_key, original_name, language)
    end
  end

  defp try_forvo_request(name, language, api_key, original_name, full_language) do
    url =
      "https://apifree.forvo.com/key/#{api_key}/format/json/action/standard-pronunciation/word/#{URI.encode(name)}/language/#{language}"

    Logger.debug("🌐 Forvo request: #{name} (#{language})")

    case PronunceName.http_client().get(url) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"items" => [item | _]} ->
            cond do
              # Prefer MP3 for broadest client compatibility (iOS/Android)
              is_binary(item["pathmp3"]) ->
                audio_url = item["pathmp3"]
                Logger.info("☁️  Uploading to cache (S3/local) -> #{audio_url}")

                cache_name =
                  if name == original_name do
                    Logger.info("✅ Found full name pronunciation for: #{original_name}")
                    original_name
                  else
                    Logger.info(
                      "📝 Found partial name pronunciation: '#{name}' (part of '#{original_name}')"
                    )

                    "#{original_name}_partial_#{name}"
                  end

                case Cache.write_external_and_cache_with_metadata(
                       audio_url,
                       cache_name,
                       original_name,
                       name,
                       full_language,
                       ".mp3"
                     ) do
                  {:ok, cached_url} ->
                    Logger.info("✅ Serving cached URL -> #{cached_url} (requested: #{name})")
                    {:ok, cached_url}

                  other ->
                    other
                end

              # Fallback to OGG when MP3 is not available
              is_binary(item["pathogg"]) ->
                audio_url = item["pathogg"]
                Logger.info("☁️  Uploading to cache (S3/local) -> #{audio_url}")

                cache_name =
                  if name == original_name do
                    Logger.info("✅ Found full name pronunciation for: #{original_name}")
                    original_name
                  else
                    Logger.info(
                      "📝 Found partial name pronunciation: '#{name}' (part of '#{original_name}')"
                    )

                    "#{original_name}_partial_#{name}"
                  end

                case Cache.write_external_and_cache_with_metadata(
                       audio_url,
                       cache_name,
                       original_name,
                       name,
                       full_language,
                       ".ogg"
                     ) do
                  {:ok, cached_url} ->
                    Logger.info("✅ Serving cached URL -> #{cached_url} (requested: #{name})")
                    {:ok, cached_url}

                  other ->
                    other
                end

              true ->
                {:error, :no_audio_url}
            end

          %{"items" => []} ->
            {:error, :no_items}

          _ ->
            {:error, :unexpected_format}
        end

      {:ok, %{status: _}} ->
        {:error, :api_error}

      {:error, _} ->
        {:error, :request_failed}
    end
  end
end

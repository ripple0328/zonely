defmodule Zonely.PronunceName.Providers.Forvo do
  @moduledoc false
  require Logger
  alias Zonely.PronunceName

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

  defp try_forvo_request(name, language, api_key, original_name, _full_language) do
    url =
      "https://apifree.forvo.com/key/#{api_key}/format/json/action/standard-pronunciation/word/#{URI.encode(name)}/language/#{language}"

    Logger.debug("🌐 Forvo request: #{name} (#{language})")

    case PronunceName.http_client().get(url) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"items" => [item | _]} ->
            cond do
              is_binary(item["pathmp3"]) ->
                Logger.info("✅ Forvo found MP3 for #{inspect(original_name)}; returning direct URL")
                {:ok, item["pathmp3"]}

              # OGG is not supported on iOS/Safari; do not return OGG
              is_binary(item["pathogg"]) ->
                Logger.info(
                  "🚫 Forvo returned only OGG for #{inspect(original_name)}; skipping unsupported format"
                )
                {:error, :no_audio_url}

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

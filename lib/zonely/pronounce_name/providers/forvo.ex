defmodule Zonely.PronunceName.Providers.Forvo do
  @moduledoc false
  require Logger
  alias Zonely.PronunceName
  alias Zonely.PronunceName.Cache

  @spec fetch(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch(name, language) do
    api_key = System.get_env("FORVO_API_KEY")
    if !api_key do
      Logger.warning("No Forvo API key configured")
      {:error, :no_api_key}
    else
      forvo_lang = String.split(language, "-") |> List.first()
      name_variants = PronunceName.generate_name_variants(name)
      Enum.reduce_while(name_variants, {:error, :not_found}, fn variant, _acc ->
        case try_forvo_request(variant, forvo_lang, api_key) do
          {:ok, audio_url} -> {:halt, {:ok, audio_url}}
          {:error, _} -> {:cont, {:error, :not_found}}
        end
      end)
    end
  end

  defp try_forvo_request(word, language, api_key) do
    url = "https://apifree.forvo.com/key/#{api_key}/format/json/action/standard-pronunciation/word/#{URI.encode(word)}/language/#{language}"
    Logger.debug("🌐 Forvo request: #{word} (#{language})")
    case PronunceName.http_client().get(url) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"items" => [item | _]} ->
            cond do
              is_binary(item["pathogg"]) -> Cache.write_external_and_cache(item["pathogg"], word, language, ".ogg")
              is_binary(item["pathmp3"]) -> Cache.write_external_and_cache(item["pathmp3"], word, language, ".mp3")
              true -> {:error, :no_audio_url}
            end
          %{"items" => []} -> {:error, :no_items}
          _ -> {:error, :unexpected_format}
        end
      {:ok, %{status: _}} -> {:error, :api_error}
      {:error, _} -> {:error, :request_failed}
    end
  end
end

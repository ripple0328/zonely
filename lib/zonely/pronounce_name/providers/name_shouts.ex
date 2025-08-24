defmodule Zonely.PronunceName.Providers.NameShouts do
  @moduledoc false
  require Logger
  alias Zonely.PronunceName
  alias Zonely.PronunceName.Cache

  @spec fetch(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch(name, language) do
    api_key = System.get_env("NS_API_KEY")
    if !api_key do
      Logger.warning("No NameShouts API key configured (NS_API_KEY)")
      {:error, :no_api_key}
    else
      headers = [{"NS-API-KEY", api_key}, {"Accept", "application/json"}]
      lang_name = PronunceName.language_display_name_from_bcp47(language) |> String.downcase()
      url_with_lang = "https://www.v1.nameshouts.com/api/names/#{URI.encode(name)}/#{URI.encode(lang_name)}"
      url_without_lang = "https://www.v1.nameshouts.com/api/names/#{URI.encode(name)}"
      prefer_without_lang_first = String.starts_with?(language || "", "en")
      Logger.info("🌐 NameShouts request for #{inspect(name)} pref_without_lang=#{prefer_without_lang_first} lang=#{lang_name}")

      case (prefer_without_lang_first && PronunceName.http_client().get(url_without_lang, headers)) || PronunceName.http_client().get(url_with_lang, headers) do
        {:ok, %{status: 200, body: body}} ->
          case PronunceName.pick_nameshouts_variant(body, name, language) do
            {:ok, path} ->
              audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
              Cache.write_external_and_cache(audio_url, name, language, ".mp3")
            {:error, reason} -> {:error, reason}
          end
        {:error, %Jason.DecodeError{data: data}} ->
          Logger.warning("NameShouts returned malformed JSON; attempting recovery")
          case PronunceName.recover_nameshouts_body_from_decode_error(data) do
            {:ok, body} ->
              case PronunceName.pick_nameshouts_variant(body, name, language) do
                {:ok, path} ->
                  audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
                  Cache.write_external_and_cache(audio_url, name, language, ".mp3")
                {:error, reason} -> {:error, reason}
              end
            {:error, _} -> {:error, :invalid_response}
          end
        {:ok, %{status: 404}} ->
          alt_resp = if prefer_without_lang_first, do: PronunceName.http_client().get(url_with_lang, headers), else: PronunceName.http_client().get(url_without_lang, headers)
          case alt_resp do
            {:ok, %{status: 200, body: body2}} ->
              case PronunceName.pick_nameshouts_variant(body2, name, language) do
                {:ok, path} ->
                  audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
                  Cache.write_external_and_cache(audio_url, name, language, ".mp3")
                {:error, reason} -> {:error, reason}
              end
            {:error, %Jason.DecodeError{data: data2}} ->
              Logger.warning("NameShouts returned malformed JSON on alt route; attempting recovery")
              case PronunceName.recover_nameshouts_body_from_decode_error(data2) do
                {:ok, body} ->
                  case PronunceName.pick_nameshouts_variant(body, name, language) do
                    {:ok, path} ->
                      audio_url = "https://nslibrary01.blob.core.windows.net/ns-audio/#{path}.mp3"
                      Cache.write_external_and_cache(audio_url, name, language, ".mp3")
                    {:error, reason} -> {:error, reason}
                  end
                {:error, _} -> {:error, :invalid_response}
              end
            {:ok, %{status: 403}} -> {:error, :invalid_api_key}
            {:ok, %{status: _}} -> {:error, :api_error}
            {:error, _} -> {:error, :request_failed}
          end
        {:ok, %{status: 403}} -> {:error, :invalid_api_key}
        {:ok, %{status: _}} -> {:error, :api_error}
        {:error, _} -> {:error, :request_failed}
      end
    end
  end
end

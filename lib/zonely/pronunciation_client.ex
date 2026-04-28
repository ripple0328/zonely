defmodule Zonely.PronunciationClient do
  @moduledoc """
  Client for the production pronunciation service.

  Zonely does not own pronunciation providers, audio caching, or local
  pronunciation fallback logic. This module is the single boundary to the
  production pronunciation API.
  """

  require Logger

  @production_base_url "https://saymyname.qingbo.us"
  @v1_path "/api/v1/pronounce"

  @type playback_event ::
          {:play_audio, map()}
          | {:play_sequence, map()}
          | {:play_tts_audio, map()}
          | {:play_tts, map()}

  @doc "Returns the production service origin used for all pronunciation requests."
  @spec production_base_url() :: String.t()
  def production_base_url, do: @production_base_url

  @doc """
  Requests pronunciation playback metadata from the production service.
  """
  @spec pronounce(String.t(), String.t()) :: {:ok, playback_event()} | {:error, term()}
  def pronounce(name, language) when is_binary(name) and is_binary(language) do
    name = String.trim(name)
    language = String.trim(language)

    cond do
      name == "" ->
        {:error, :missing_name}

      language == "" ->
        {:error, :missing_language}

      true ->
        request(name, language)
    end
  end

  def pronounce(_name, _language), do: {:error, :invalid_params}

  defp request(name, language) do
    request_fun = Application.get_env(:zonely, :pronunciation_request_fun, &Req.request/1)

    opts = [
      method: :get,
      url: @production_base_url <> @v1_path,
      params: [name: name, lang: language],
      headers: auth_headers(),
      receive_timeout: 3_000,
      connect_options: [timeout: 1_000],
      retry: false
    ]

    case request_fun.(opts) do
      {:ok, %{status: 200, body: body}} ->
        normalize(body)

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Pronunciation API returned HTTP #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.warning("Pronunciation API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp auth_headers do
    case System.get_env("PRONUNCIATION_API_KEY") do
      key when is_binary(key) and key != "" -> [{"authorization", "Bearer " <> key}]
      _ -> []
    end
  end

  defp normalize(%{"audio_urls" => urls, "provider" => provider}) when is_list(urls) do
    {:ok, {:play_sequence, %{urls: urls, provider: provider}}}
  end

  defp normalize(%{"audio_url" => url, "kind" => "real_voice", "provider" => provider})
       when is_binary(url) do
    {:ok, {:play_audio, %{url: url, provider: provider}}}
  end

  defp normalize(%{"audio_url" => url, "kind" => "ai_voice", "provider" => provider})
       when is_binary(url) do
    {:ok, {:play_tts_audio, %{url: url, provider: provider}}}
  end

  defp normalize(%{"tts_text" => text, "tts_language" => language, "provider" => provider}) do
    {:ok, {:play_tts, %{text: text, lang: language, provider: provider}}}
  end

  defp normalize(body), do: {:error, {:unexpected_response, body}}
end

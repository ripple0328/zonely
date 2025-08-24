defmodule Zonely.PronunceName.Providers.Polly do
  @moduledoc false
  alias Zonely.PronunceName
  alias Zonely.PronunceName.Cache

  @spec synthesize(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def synthesize(text, language) when is_binary(text) and is_binary(language) do
    voice_id = PronunceName.pick_polly_voice(language)

    # Use the 2-arity form: synthesize_speech(text, options)
    op =
      ExAws.Polly.synthesize_speech(
        to_string(text),
        voice_id: to_string(voice_id),
        output_format: "mp3",
        engine: "neural",
        text_type: "text"
      )

    case aws_request(op) do
      {:ok, %{status_code: 200, body: audio_bin}} when is_binary(audio_bin) ->
        Cache.write_binary_to_cache(audio_bin, text, language, ".mp3")

      {:ok, %{status_code: status} = resp} ->
        {:error, {:bad_status, status, resp}}

      {:error, {:http_error, 400, _}} ->
        # Retry with standard engine
        op2 =
          ExAws.Polly.synthesize_speech(
            to_string(text),
            voice_id: to_string(voice_id),
            output_format: "mp3",
            engine: "standard",
            text_type: "text"
          )

        case aws_request(op2) do
          {:ok, %{status_code: 200, body: audio_bin}} when is_binary(audio_bin) ->
            Cache.write_binary_to_cache(audio_bin, text, language, ".mp3")

          other ->
            {:error, other}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp aws_request(request) do
    case Application.get_env(:zonely, :aws_request_fun) do
      fun when is_function(fun, 1) -> fun.(request)
      _ -> ExAws.request(request)
    end
  end
end

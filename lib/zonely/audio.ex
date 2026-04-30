defmodule Zonely.Audio do
  @moduledoc """
  Pronunciation playback boundary for team profiles.

  Zonely always delegates pronunciation capability to the production
  pronunciation API and falls back only to client-side device TTS metadata.
  """

  alias Zonely.Accounts.Person
  alias Zonely.Geography
  alias Zonely.PronunciationClient

  require Logger

  @type playback_event ::
          {:play_audio, map()}
          | {:play_sequence, map()}
          | {:play_tts_audio, map()}
          | {:play_tts, map()}

  @doc "Builds a playback event for a user's English name pronunciation."
  @spec play_english_pronunciation(Person.t()) :: playback_event()
  def play_english_pronunciation(%Person{name: name, country: country}) do
    request_pronunciation(name, derive_english_locale(country))
  end

  @doc "Builds a playback event for a user's native-name pronunciation."
  @spec play_native_pronunciation(Person.t()) :: playback_event()
  def play_native_pronunciation(%Person{name_native: native_name, country: country})
      when is_binary(native_name) do
    request_pronunciation(native_name, Geography.country_to_locale(country))
  end

  def play_native_pronunciation(%Person{} = user), do: play_english_pronunciation(user)

  @doc """
  Determines the appropriate English locale based on a user's country.
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
      _ -> "en-US"
    end
  end

  def derive_english_locale(_country), do: "en-US"

  defp request_pronunciation(name, language) do
    case PronunciationClient.pronounce(name || "", language || "en-US") do
      {:ok, event} ->
        event

      {:error, reason} ->
        Logger.info("Using device TTS fallback after pronunciation API miss: #{inspect(reason)}")
        {:play_tts, %{text: name || "", lang: language || "en-US", provider: "device"}}
    end
  end
end

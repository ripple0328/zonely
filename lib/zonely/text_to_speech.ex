defmodule Zonely.TextToSpeech do
  @moduledoc """
  Text-to-speech functionality for name pronunciation.
  Uses Web Speech API on the frontend for native language pronunciation.
  """

  @doc """
  Generates TTS parameters for the Web Speech API.
  """
  def generate_speech_params(text, language_code) do
    %{
      text: text,
      lang: language_code,
      rate: 0.8,
      pitch: 1.0,
      volume: 1.0
    }
  end

  @doc """
  Gets the appropriate language code for a country.
  """
  def get_language_for_country(country_code) do
    case String.upcase(country_code) do
      "US" -> "en-US"
      "GB" -> "en-GB" 
      "SE" -> "sv-SE"
      "JP" -> "ja-JP"
      "IN" -> "hi-IN"
      "ES" -> "es-ES"
      "AU" -> "en-AU"
      "EG" -> "ar-EG"
      "BR" -> "pt-BR"
      _ -> "en-US"  # Default fallback
    end
  end

  @doc """
  Gets the native language name for display.
  """
  def get_native_language_name(country_code) do
    case String.upcase(country_code) do
      "US" -> "English"
      "GB" -> "English"
      "SE" -> "Svenska"
      "JP" -> "日本語"
      "IN" -> "हिन्दी"
      "ES" -> "Español"
      "AU" -> "English"
      "EG" -> "العربية"
      "BR" -> "Português"
      _ -> "English"
    end
  end
end
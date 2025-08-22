defmodule Zonely.Audio.PronunciationService do
  @moduledoc """
  Service for handling pronunciation data retrieval.
  
  This module encapsulates the logic for getting pronunciation data,
  including integration with external services like Forvo and fallback
  to text-to-speech.
  """

  alias Zonely.Accounts.User
  alias Zonely.TextToSpeech

  @doc """
  Gets pronunciation data for a user in the specified language.
  
  First attempts to get a pre-recorded audio URL, then falls back to TTS.
  """
  @spec get_pronunciation(User.t(), String.t()) :: 
    {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  def get_pronunciation(%User{} = user, language) do
    # Try to get pre-recorded pronunciation first
    case TextToSpeech.get_name_pronunciation(user, language) do
      {:audio_url, url} -> {:audio_url, url}
      {:tts, text, lang} -> {:tts, text, lang}
    end
  end

  @doc """
  Determines the best text to use for TTS based on user data and language.
  """
  @spec get_tts_text(User.t(), String.t()) :: String.t()
  def get_tts_text(%User{} = user, language) do
    cond do
      # Use native name if available and language matches user's native language
      user.name_native && language == user.native_language ->
        user.name_native
      
      # Use native name if available and it's not English
      user.name_native && !String.starts_with?(language, "en") ->
        user.name_native
      
      # Default to regular name
      true ->
        user.name
    end
  end

  @doc """
  Validates if a language code is supported for TTS.
  """
  @spec supported_language?(String.t()) :: boolean()
  def supported_language?(language) do
    language in [
      "en-US", "en-GB", "en-CA", "en-AU", "en-ZA", "en-SG", "en-PH", "en-NZ",
      "es-ES", "es-MX", "es-AR", "es-CL", "es-CO", "es-PE", "es-VE",
      "fr-FR", "de-DE", "it-IT", "pt-PT", "pt-BR",
      "ja-JP", "zh-CN", "zh-TW", "zh-HK", "ko-KR", "ru-RU",
      "hi-IN", "sv-SE", "nb-NO", "da-DK", "fi-FI", "nl-NL", "nl-BE",
      "de-CH", "de-AT", "pl-PL", "cs-CZ", "hu-HU", "el-GR", "tr-TR",
      "ar-EG", "th-TH", "vi-VN", "id-ID", "ms-MY"
    ]
  end
end

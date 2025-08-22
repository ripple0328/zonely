defmodule Zonely.Audio do
  @moduledoc """
  The Audio context for handling pronunciation and audio playback functionality.

  This module provides functions for:
  - Getting pronunciation data for user names
  - Handling text-to-speech requests
  - Managing audio URLs and playback
  """

  alias Zonely.Accounts.User
  alias Zonely.Audio.PronunciationService

  @doc """
  Gets pronunciation data for a user in the specified language.

  Returns either an audio URL for pre-recorded pronunciation or
  text data for text-to-speech synthesis.

  ## Examples

      iex> get_user_pronunciation(%User{name: "José"}, "es-ES")
      {:audio_url, "https://forvo.com/..."}

      iex> get_user_pronunciation(%User{name: "John"}, "en-US")
      {:tts, "John", "en-US"}
  """
  @spec get_user_pronunciation(User.t(), String.t()) ::
    {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  def get_user_pronunciation(%User{} = user, language) do
    PronunciationService.get_pronunciation(user, language)
  end

  @doc """
  Gets the native language pronunciation for a user.

  Uses the user's native_language field or derives it from their country.
  """
  @spec get_native_pronunciation(User.t()) ::
    {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  def get_native_pronunciation(%User{} = user) do
    native_lang = user.native_language || derive_language_from_country(user.country)
    get_user_pronunciation(user, native_lang)
  end

  @doc """
  Gets English pronunciation for a user.
  """
  @spec get_english_pronunciation(User.t()) ::
    {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  def get_english_pronunciation(%User{} = user) do
    get_user_pronunciation(user, "en-US")
  end

      @doc """
  Plays pronunciation for a name in the specified language.
  
  Handles the complete flow internally:
  1. Check cache
  2. Fetch from remote if needed
  3. Fall back to TTS if no audio available
  
  Returns a single event type that LiveView can push directly.
  
  ## Parameters
  - name: The name to pronounce (e.g., "María García")
  - language: Language code (e.g., "es-ES", "en-US", nil)
  - country: Country code for language derivation fallback (e.g., "ES", "US")
  """
  @spec play_pronunciation(String.t(), String.t() | nil, String.t()) :: {:play_audio | :play_tts, map()}
  def play_pronunciation(name, language, country) when is_binary(name) and is_binary(country) do
    # Use the language directly, or derive from country if needed
    target_lang = if language && language != "", do: language, else: derive_language_from_country(country)
    
    case get_name_pronunciation(name, target_lang) do
      {:audio_url, url} ->
        {:play_audio, %{url: url}}
        
      {:tts, text, lang} ->
        {:play_tts, %{text: text, lang: lang}}
    end
  end

    @doc """
  Gets pronunciation for a name in the specified language.
  
  ## Parameters
  - name: The name to get pronunciation for
  - language: Target language code
  """
  @spec get_name_pronunciation(String.t(), String.t()) :: {:audio_url, String.t()} | {:tts, String.t(), String.t()}
  def get_name_pronunciation(name, language) do
    # Create a minimal user-like struct for the PronunciationService
    # TODO: Refactor PronunciationService to not depend on User struct
    user_like = %User{
      name: name,
      id: nil,
      country: nil,
      native_language: nil,
      forvo_audio_url: nil,
      forvo_last_checked: nil
    }
    PronunciationService.get_pronunciation(user_like, language)
  end

  @doc """
  Gets the native language name for display purposes.

  ## Examples

      iex> Zonely.Audio.get_native_language_name("ES")
      "Spanish"

      iex> Zonely.Audio.get_native_language_name("US")
      "English"
  """
  @spec get_native_language_name(String.t()) :: String.t()
  def get_native_language_name(country_code) do
    case country_code do
      "US" -> "English"
      "GB" -> "English"
      "CA" -> "English"
      "AU" -> "English"
      "ES" -> "Spanish"
      "MX" -> "Spanish"
      "FR" -> "French"
      "DE" -> "German"
      "IT" -> "Italian"
      "PT" -> "Portuguese"
      "BR" -> "Portuguese"
      "JP" -> "Japanese"
      "CN" -> "Chinese"
      "KR" -> "Korean"
      "RU" -> "Russian"
      "IN" -> "Hindi"
      "SE" -> "Swedish"
      "NO" -> "Norwegian"
      "DK" -> "Danish"
      "FI" -> "Finnish"
      "NL" -> "Dutch"
      "BE" -> "Dutch"
      "CH" -> "German"
      "AT" -> "German"
      "PL" -> "Polish"
      "CZ" -> "Czech"
      "HU" -> "Hungarian"
      "GR" -> "Greek"
      "TR" -> "Turkish"
      "EG" -> "Arabic"
      "ZA" -> "English"
      "AR" -> "Spanish"
      "CL" -> "Spanish"
      "CO" -> "Spanish"
      "PE" -> "Spanish"
      "VE" -> "Spanish"
      "TH" -> "Thai"
      "VN" -> "Vietnamese"
      "ID" -> "Indonesian"
      "MY" -> "Malay"
      "SG" -> "English"
      "PH" -> "English"
      "TW" -> "Chinese"
      "HK" -> "Chinese"
      "NZ" -> "English"
      _ -> "English" # Default fallback
    end
  end

  @doc """
  Derives a language code from a country code.

  ## Examples

      iex> Zonely.Audio.derive_language_from_country("ES")
      "es-ES"

      iex> Zonely.Audio.derive_language_from_country("US")
      "en-US"
  """
  @spec derive_language_from_country(String.t()) :: String.t()
  def derive_language_from_country(country_code) do
    case country_code do
      "US" -> "en-US"
      "GB" -> "en-GB"
      "CA" -> "en-CA"
      "AU" -> "en-AU"
      "ES" -> "es-ES"
      "MX" -> "es-MX"
      "FR" -> "fr-FR"
      "DE" -> "de-DE"
      "IT" -> "it-IT"
      "PT" -> "pt-PT"
      "BR" -> "pt-BR"
      "JP" -> "ja-JP"
      "CN" -> "zh-CN"
      "KR" -> "ko-KR"
      "RU" -> "ru-RU"
      "IN" -> "hi-IN"
      "SE" -> "sv-SE"
      "NO" -> "nb-NO"
      "DK" -> "da-DK"
      "FI" -> "fi-FI"
      "NL" -> "nl-NL"
      "BE" -> "nl-BE"
      "CH" -> "de-CH"
      "AT" -> "de-AT"
      "PL" -> "pl-PL"
      "CZ" -> "cs-CZ"
      "HU" -> "hu-HU"
      "GR" -> "el-GR"
      "TR" -> "tr-TR"
      "EG" -> "ar-EG"
      "ZA" -> "en-ZA"
      "AR" -> "es-AR"
      "CL" -> "es-CL"
      "CO" -> "es-CO"
      "PE" -> "es-PE"
      "VE" -> "es-VE"
      "TH" -> "th-TH"
      "VN" -> "vi-VN"
      "ID" -> "id-ID"
      "MY" -> "ms-MY"
      "SG" -> "en-SG"
      "PH" -> "en-PH"
      "TW" -> "zh-TW"
      "HK" -> "zh-HK"
      "NZ" -> "en-NZ"
      _ -> "en-US" # Default fallback
    end
  end
end

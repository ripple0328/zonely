defmodule Zonely.VoiceSelector do
  @moduledoc """
  Handles voice selection for text-to-speech services.

  This module encapsulates the logic for selecting appropriate voices
  for different languages and regions, primarily for AWS Polly.
  """

  @doc """
  Selects an appropriate Polly voice for a given language code.

  ## Parameters
  - `bcp47`: Language code in BCP47 format (e.g., "en-US", "es-ES")

  ## Returns
  - String: Voice name suitable for AWS Polly

  ## Examples

      iex> VoiceSelector.select_polly_voice("en-US")
      "Joanna"
      
      iex> VoiceSelector.select_polly_voice("es-ES")
      "Lucia"
      
      iex> VoiceSelector.select_polly_voice("unknown")
      "Joanna"
  """
  @spec select_polly_voice(String.t()) :: String.t()
  def select_polly_voice(bcp47) when is_binary(bcp47) do
    base = bcp47 |> String.split("-") |> List.first() |> String.downcase()

    case String.downcase(bcp47) do
      # English variants (neural voices preferred)
      "en-us" -> "Joanna"
      "en-gb" -> "Amy"
      "en-au" -> "Olivia"
      "en-ca" -> "Emma"
      "en-in" -> "Aditi"
      # Spanish variants
      "es-es" -> "Lucia"
      "es-us" -> "Lupe"
      "es-mx" -> "Lupe"
      # Portuguese variants
      "pt-br" -> "Camila"
      "pt-pt" -> "Ines"
      # French variants
      "fr-fr" -> "Lea"
      "fr-ca" -> "Chantal"
      # German variants
      "de-de" -> "Vicki"
      "de-at" -> "Vicki"
      # Chinese variants
      "zh-cn" -> "Zhiyu"
      "zh-tw" -> "Zhiyu"
      # Arabic variants
      "ar-eg" -> "Zeina"
      "ar-sa" -> "Zeina"
      _ -> select_voice_by_base_language(base)
    end
  end

  def select_polly_voice(_), do: "Joanna"

  @spec select_voice_by_base_language(String.t()) :: String.t()
  defp select_voice_by_base_language(base) do
    case base do
      # Major language families by base code
      # Spanish (Spain default)
      "es" -> "Lucia"
      # Portuguese (Brazilian default)
      "pt" -> "Camila"
      # French
      "fr" -> "Lea"
      # German
      "de" -> "Vicki"
      # Italian
      "it" -> "Bianca"
      # Japanese
      "ja" -> "Mizuki"
      # Korean
      "ko" -> "Seoyeon"
      # Hindi
      "hi" -> "Aditi"
      # Chinese (Mandarin)
      "zh" -> "Zhiyu"
      # Arabic
      "ar" -> "Zeina"
      # Russian
      "ru" -> "Tatyana"
      # Dutch
      "nl" -> "Lotte"
      # Swedish
      "sv" -> "Astrid"
      # Norwegian
      "no" -> "Liv"
      # Danish
      "da" -> "Naja"
      # Finnish
      "fi" -> "Suvi"
      # Polish
      "pl" -> "Ewa"
      # Turkish
      "tr" -> "Filiz"
      # Thai (fallback to multilingual voice)
      "th" -> "Zhiyu"
      # Vietnamese (fallback to multilingual voice)
      "vi" -> "Zhiyu"
      # English fallback
      _ -> "Joanna"
    end
  end

  @doc """
  Returns all supported languages with their default voices.

  Useful for UI display or validation.
  """
  @spec supported_languages() :: %{String.t() => String.t()}
  def supported_languages do
    %{
      "en-US" => "Joanna",
      "en-GB" => "Amy",
      "en-AU" => "Olivia",
      "en-CA" => "Emma",
      "en-IN" => "Aditi",
      "es-ES" => "Lucia",
      "es-US" => "Lupe",
      "es-MX" => "Lupe",
      "pt-BR" => "Camila",
      "pt-PT" => "Ines",
      "fr-FR" => "Lea",
      "fr-CA" => "Chantal",
      "de-DE" => "Vicki",
      "de-AT" => "Vicki",
      "zh-CN" => "Zhiyu",
      "zh-TW" => "Zhiyu",
      "ar-EG" => "Zeina",
      "ar-SA" => "Zeina",
      "it-IT" => "Bianca",
      "ja-JP" => "Mizuki",
      "ko-KR" => "Seoyeon",
      "hi-IN" => "Aditi",
      "ru-RU" => "Tatyana",
      "nl-NL" => "Lotte",
      "sv-SE" => "Astrid",
      "no-NO" => "Liv",
      "da-DK" => "Naja",
      "fi-FI" => "Suvi",
      "pl-PL" => "Ewa",
      "tr-TR" => "Filiz"
    }
  end

  @doc """
  Checks if a language is supported for voice synthesis.
  """
  @spec language_supported?(String.t()) :: boolean()
  def language_supported?(language) do
    Map.has_key?(supported_languages(), String.upcase(language)) or
      language
      |> String.split("-")
      |> List.first()
      |> String.downcase()
      |> then(&Map.has_key?(base_language_voices(), &1))
  end

  defp base_language_voices do
    %{
      "es" => "Lucia",
      "pt" => "Camila",
      "fr" => "Lea",
      "de" => "Vicki",
      "it" => "Bianca",
      "ja" => "Mizuki",
      "ko" => "Seoyeon",
      "hi" => "Aditi",
      "zh" => "Zhiyu",
      "ar" => "Zeina",
      "ru" => "Tatyana",
      "nl" => "Lotte",
      "sv" => "Astrid",
      "no" => "Liv",
      "da" => "Naja",
      "fi" => "Suvi",
      "pl" => "Ewa",
      "tr" => "Filiz"
    }
  end
end

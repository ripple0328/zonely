defmodule Zonely.LanguageService do
  @moduledoc """
  Service module for handling language and country mappings using the Countries library.

  This module provides a clean interface for language-related functionality,
  leveraging the existing Countries library to avoid duplication and ensure
  data accuracy.
  """

  alias Countries

  @doc """
  Gets the native language name for display purposes.
  Leverages the Countries library for accurate country information.

  ## Examples

      iex> LanguageService.get_native_language_name("ES")
      "Spanish"

      iex> LanguageService.get_native_language_name("JP")
      "Japanese"
  """
  @spec get_native_language_name(String.t()) :: String.t()
  def get_native_language_name(country_code) do
    try do
      case Countries.get(country_code) do
        %{name: _name} = _country ->
          # Use our custom mapping for now since Countries library
          # doesn't provide language info directly
          get_language_name_from_country_code(country_code)

        [] ->
          get_language_name_from_country_code(country_code)
          
        nil ->
          get_language_name_from_country_code(country_code)
      end
    rescue
      _ ->
        get_language_name_from_country_code(country_code)
    end
  end

  @doc """
  Derives a full language code from a country code.

  ## Examples

      iex> LanguageService.derive_language_from_country("ES")
      "es-ES"

      iex> LanguageService.derive_language_from_country("US")
      "en-US"
  """
  @spec derive_language_from_country(String.t()) :: String.t()
  def derive_language_from_country(country_code) do
    country_code
    |> String.upcase()
    |> get_locale_from_country_code()
  end

  @doc """
  Gets the primary language code (without locale) for a country.

  ## Examples

      iex> LanguageService.get_language_code("ES")
      "es"

      iex> LanguageService.get_language_code("US")
      "en"
  """
  @spec get_language_code(String.t()) :: String.t()
  def get_language_code(country_code) do
    country_code
    |> derive_language_from_country()
    |> String.split("-")
    |> List.first()
  end

  @doc """
  Validates if a country code exists using the Countries library.

  ## Examples

      iex> LanguageService.valid_country?("ES")
      true

      iex> LanguageService.valid_country?("XX")
      false
  """
  @spec valid_country?(String.t()) :: boolean()
  def valid_country?(country_code) do
    try do
      case Countries.get(country_code) do
        [] -> false
        nil -> false
        _ -> true
      end
    rescue
      _ -> false
    end
  end

  @doc """
  Gets country information using the Countries library.

  Returns a map with country details if found, nil otherwise.
  """
  @spec get_country_info(String.t()) :: map() | nil
  def get_country_info(country_code) do
    try do
      case Countries.get(country_code) do
        [] -> nil
        country -> country
      end
    rescue
      _ -> nil
    end
  end

  # Private mapping functions
  # These could be enhanced in the future to use a more comprehensive
  # language mapping library like ex_cldr

  @spec get_language_name_from_country_code(String.t()) :: String.t()
  defp get_language_name_from_country_code(country_code) do
    case String.upcase(country_code) do
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
      "IN" -> "Hindi"
      "EG" -> "Arabic"
      "SE" -> "Swedish"
      "NL" -> "Dutch"
      "RU" -> "Russian"
      "NO" -> "Norwegian"
      "DK" -> "Danish"
      "FI" -> "Finnish"
      "IS" -> "Icelandic"
      "BE" -> "Dutch"
      "AT" -> "German"
      "CH" -> "German"
      _ -> "English"  # Default fallback
    end
  end

  @spec get_locale_from_country_code(String.t()) :: String.t()
  defp get_locale_from_country_code(country_code) do
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
      "IN" -> "hi-IN"
      "EG" -> "ar-EG"
      "SE" -> "sv-SE"
      "NL" -> "nl-NL"
      "RU" -> "ru-RU"
      "NO" -> "no-NO"
      "DK" -> "da-DK"
      "FI" -> "fi-FI"
      "IS" -> "is-IS"
      "BE" -> "nl-BE"
      "AT" -> "de-AT"
      "CH" -> "de-CH"
      _ -> "en-US"  # Default fallback
    end
  end
end


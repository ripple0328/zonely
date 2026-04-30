defmodule Zonely.NameProfileContract do
  @moduledoc """
  Converts Zonely users into the portable SayMyName profile contract.

  Zonely owns the team/profile context. SayMyName owns immutable pronunciation
  share snapshots and playback semantics.
  """

  alias Zonely.Accounts.User
  alias Zonely.Geography

  @default_english_locale "en-US"
  @default_list_name "Zonely Team"
  @say_my_name_language_aliases %{
    "ar" => "ar-SA",
    "ar-sa" => "ar-SA",
    "de" => "de-DE",
    "de-de" => "de-DE",
    "en" => "en-US",
    "en-us" => "en-US",
    "es" => "es-ES",
    "es-es" => "es-ES",
    "fr" => "fr-FR",
    "fr-fr" => "fr-FR",
    "hi" => "hi-IN",
    "hi-in" => "hi-IN",
    "ja" => "ja-JP",
    "ja-jp" => "ja-JP",
    "ko" => "ko-KR",
    "ko-kr" => "ko-KR",
    "pt" => "pt-BR",
    "pt-br" => "pt-BR",
    "zh" => "zh-CN",
    "zh-cn" => "zh-CN",
    "zh-hans" => "zh-CN",
    "zh-hant" => "zh-CN",
    "zh-tw" => "zh-CN"
  }

  @spec from_user(User.t()) :: map()
  def from_user(%User{} = user) do
    %{
      "id" => user.id && to_string(user.id),
      "display_name" => normalize_text(user.name),
      "variants" => variants_for(user)
    }
  end

  @spec from_users(String.t() | nil, [User.t()]) :: map()
  def from_users(name, users) when is_list(users) do
    %{
      "name" => normalize_text(name) || @default_list_name,
      "entries" => Enum.map(users, &from_user/1)
    }
  end

  @spec variants_for(User.t()) :: [map()]
  def variants_for(%User{} = user) do
    [
      variant(@default_english_locale, user.name),
      native_variant(user)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp native_variant(%User{name_native: native_name} = user) do
    native_name = normalize_text(native_name)

    cond do
      is_nil(native_name) ->
        nil

      native_name == normalize_text(user.name) ->
        nil

      true ->
        variant(normalize_language(user.native_language, user.country), native_name)
    end
  end

  defp variant(nil, _text), do: nil

  defp variant(language, text) do
    case normalize_text(text) do
      nil -> nil
      text -> %{"lang" => language, "text" => text}
    end
  end

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp normalize_text(_value), do: nil

  defp normalize_language(language, country) do
    country_locale = Geography.country_to_locale(country || "")

    language
    |> normalize_text()
    |> do_normalize_language(country_locale)
  end

  defp do_normalize_language(nil, country_locale), do: canonical_share_language(country_locale)

  defp do_normalize_language(language, country_locale) do
    language
    |> normalize_language_format(country_locale)
    |> canonical_share_language()
  end

  defp normalize_language_format(language, country_locale) do
    cond do
      Regex.match?(~r/^[A-Za-z]{2,3}-[A-Za-z]{2,4}$/, language) ->
        [lang, region] = String.split(language, "-", parts: 2)
        "#{String.downcase(lang)}-#{format_language_region(region)}"

      Regex.match?(~r/^[A-Za-z]{2,3}$/, language) ->
        normalize_short_language(language, country_locale)

      true ->
        country_locale
    end
  end

  defp normalize_short_language(language, country_locale) do
    language = String.downcase(language)

    case String.split(country_locale, "-", parts: 2) do
      [^language, _region] -> country_locale
      _ -> language
    end
  end

  defp canonical_share_language(nil), do: nil

  defp canonical_share_language(language) do
    normalized = String.downcase(String.replace(language, "_", "-"))

    Map.get(@say_my_name_language_aliases, normalized) ||
      normalized
      |> String.split("-", parts: 2)
      |> List.first()
      |> then(&Map.get(@say_my_name_language_aliases, &1))
  end

  defp format_language_region(region) when byte_size(region) == 4, do: String.capitalize(region)
  defp format_language_region(region), do: String.upcase(region)
end

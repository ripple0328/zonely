defmodule Zonely.NameProfileContract do
  @moduledoc """
  Converts Zonely people into the shared profile contract.

  Zonely owns team location and availability context. SayMyName owns
  pronunciation snapshots and playback semantics. The shared contract uses
  `person`, `team`, `membership`, `location`, and `availability` terms so either
  app can import/export a subset cleanly.
  """

  alias Zonely.Accounts.Person
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

  @spec from_person(Person.t()) :: map()
  def from_person(%Person{} = person) do
    %{
      "version" => "shared_profile_v1",
      "person" => person_map(person),
      "location" => location_map(person),
      "availability" => availability_map(person)
    }
  end

  @spec from_team(String.t() | nil, [Person.t()]) :: map()
  def from_team(name, people) when is_list(people) do
    %{
      "version" => "shared_profile_v1",
      "team" => %{"name" => normalize_text(name) || @default_list_name},
      "memberships" => Enum.map(people, &membership_map/1)
    }
  end

  @spec variants_for(Person.t()) :: [map()]
  def variants_for(%Person{name_variants: variants}) when is_list(variants) and variants != [] do
    variants
    |> Enum.map(&normalize_variant/1)
    |> Enum.reject(&is_nil/1)
  end

  def variants_for(%Person{} = person) do
    [variant(@default_english_locale, person.name), native_variant(person)]
    |> Enum.reject(&is_nil/1)
  end

  defp person_map(%Person{} = person) do
    %{
      "id" => person.id && to_string(person.id),
      "display_name" => normalize_text(person.name),
      "pronouns" => normalize_text(person.pronouns),
      "role" => normalize_text(person.role),
      "name_variants" => variants_for(person)
    }
    |> reject_nil_values()
  end

  defp location_map(%Person{} = person) do
    %{
      "country" => normalize_text(person.country),
      "latitude" => decimal_to_float(person.latitude),
      "longitude" => decimal_to_float(person.longitude)
    }
    |> reject_nil_values()
  end

  defp availability_map(%Person{} = person) do
    %{
      "timezone" => normalize_text(person.timezone),
      "work_start" => time_to_iso8601(person.work_start),
      "work_end" => time_to_iso8601(person.work_end)
    }
    |> reject_nil_values()
  end

  defp membership_map(%Person{} = person) do
    %{
      "person" => person_map(person),
      "location" => location_map(person),
      "availability" => availability_map(person),
      "role" => normalize_text(person.role)
    }
    |> reject_nil_values()
  end

  defp native_variant(%Person{name_native: native_name} = person) do
    native_name = normalize_text(native_name)

    cond do
      is_nil(native_name) ->
        nil

      native_name == normalize_text(person.name) ->
        nil

      true ->
        variant(normalize_language(person.native_language, person.country), native_name)
    end
  end

  defp variant(nil, _text), do: nil

  defp variant(language, text) do
    case normalize_text(text) do
      nil -> nil
      text -> %{"lang" => language, "text" => text}
    end
  end

  defp normalize_variant(%{"lang" => lang, "text" => text}),
    do: variant(canonical_share_language(lang), text)

  defp normalize_variant(%{lang: lang, text: text}),
    do: variant(canonical_share_language(lang), text)

  defp normalize_variant(_variant), do: nil

  defp reject_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) or value == %{} or value == [] end)
  end

  defp decimal_to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp decimal_to_float(value) when is_float(value) or is_integer(value), do: value
  defp decimal_to_float(_value), do: nil

  defp time_to_iso8601(%Time{} = time), do: Time.to_iso8601(time)
  defp time_to_iso8601(value) when is_binary(value), do: value
  defp time_to_iso8601(_value), do: nil

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

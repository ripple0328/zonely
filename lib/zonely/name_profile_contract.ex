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

  @doc """
  Parses a `shared_profile_v1` card or team/list payload into Zonely's import projection.

  The parser is intentionally pure and conservative: it accepts only the canonical
  shared contract version, preserves supplied SayMyName-owned name/pronunciation
  fields, keeps absent Zonely-owned location/availability fields absent, and only
  retains coordinates when a valid latitude/longitude pair is explicitly present.
  """
  @spec parse(term()) :: {:ok, map()} | {:error, term()}
  def parse(payload) do
    with {:ok, payload} <- normalize_link_payload(payload),
         {:ok, payload} <- validate_version(payload) do
      parse_contract_shape(payload)
    end
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

  defp normalize_link_payload(%{"payload" => payload}) when is_map(payload), do: {:ok, payload}
  defp normalize_link_payload(%{"payload" => _payload}), do: {:error, :invalid_payload}

  defp normalize_link_payload(%{"data" => %{"payload" => payload}}) when is_map(payload),
    do: {:ok, payload}

  defp normalize_link_payload(%{"data" => %{"payload" => _payload}}),
    do: {:error, :invalid_payload}

  defp normalize_link_payload(payload) when is_map(payload), do: {:ok, payload}
  defp normalize_link_payload(_payload), do: {:error, :invalid_payload}

  defp validate_version(%{"version" => "shared_profile_v1"} = payload), do: {:ok, payload}
  defp validate_version(%{"version" => _version}), do: {:error, :unsupported_version}
  defp validate_version(_payload), do: {:error, :unsupported_shape}

  defp parse_contract_shape(%{"person" => person} = payload)
       when is_map(person) and not is_map_key(payload, "team") and
              not is_map_key(payload, "memberships") do
    case project_person(person) do
      {:ok, person} ->
        with {:ok, projection} <-
               put_optional_location(
                 %{kind: :person, version: "shared_profile_v1", person: person},
                 payload
               ),
             {:ok, projection} <- put_optional_availability(projection, payload) do
          {:ok, projection}
        end

      {:error, reason} ->
        {:error, {:invalid_person, reason}}
    end
  end

  defp parse_contract_shape(%{"team" => team, "memberships" => memberships})
       when is_map(team) and is_list(memberships) do
    with {:ok, team} <- project_team(team),
         {:ok, memberships} <- project_memberships(memberships) do
      {:ok,
       %{
         kind: :team,
         version: "shared_profile_v1",
         team: team,
         memberships: memberships
       }}
    end
  end

  defp parse_contract_shape(%{"team" => team, "memberships" => _memberships}) when is_map(team),
    do: {:error, :invalid_memberships}

  defp parse_contract_shape(_payload), do: {:error, :unsupported_shape}

  defp project_person(%{"display_name" => display_name} = person) do
    case normalize_text(display_name) do
      nil ->
        {:error, :missing_display_name}

      display_name ->
        with {:ok, name_variants} <- project_name_variants(Map.get(person, "name_variants")),
             {:ok, pronunciation} <- project_pronunciation(Map.get(person, "pronunciation")) do
          projected =
            %{
              "id" => normalize_text(Map.get(person, "id")),
              "display_name" => display_name,
              "pronouns" => normalize_text(Map.get(person, "pronouns")),
              "role" => normalize_text(Map.get(person, "role")),
              "name_variants" => name_variants,
              "pronunciation" => pronunciation
            }
            |> reject_nil_values()

          {:ok, projected}
        end
    end
  end

  defp project_person(_person), do: {:error, :missing_display_name}

  defp project_team(team) do
    case normalize_text(Map.get(team, "name")) do
      nil ->
        {:error, :missing_team_name}

      name ->
        {:ok,
         %{
           "id" => normalize_text(Map.get(team, "id")),
           "name" => name
         }
         |> reject_nil_values()}
    end
  end

  defp project_memberships([]), do: {:error, :empty_memberships}

  defp project_memberships(memberships) do
    memberships
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {membership, index}, {:ok, projected} ->
      case project_membership(membership) do
        {:ok, membership} -> {:cont, {:ok, [membership | projected]}}
        {:error, reason} -> {:halt, {:error, {:invalid_membership, index, reason}}}
      end
    end)
    |> case do
      {:ok, projected} -> {:ok, Enum.reverse(projected)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp project_membership(%{"person" => person} = membership) when is_map(person) do
    with {:ok, person} <- project_person(person),
         {:ok, projected} <- put_optional_location(%{"person" => person}, membership),
         {:ok, projected} <- put_optional_availability(projected, membership) do
      projected =
        projected
        |> Map.put("role", normalize_text(Map.get(membership, "role")))
        |> reject_nil_values()

      {:ok, projected}
    end
  end

  defp project_membership(_membership), do: {:error, :missing_person}

  defp put_optional_location(projection, %{"location" => location}) do
    case project_location(location) do
      {:ok, location} -> {:ok, maybe_put(projection, location_key(projection), location)}
      {:error, reason} -> {:error, {:invalid_location, reason}}
    end
  end

  defp put_optional_location(projection, _payload), do: {:ok, projection}

  defp put_optional_availability(projection, %{"availability" => availability}) do
    case project_availability(availability) do
      {:ok, availability} ->
        {:ok, maybe_put(projection, availability_key(projection), availability)}

      {:error, reason} ->
        {:error, {:invalid_availability, reason}}
    end
  end

  defp put_optional_availability(projection, _payload), do: {:ok, projection}

  defp location_key(%{"person" => _person}), do: "location"
  defp location_key(_projection), do: :location

  defp availability_key(%{"person" => _person}), do: "availability"
  defp availability_key(_projection), do: :availability

  defp maybe_put(projection, _key, value) when value == %{}, do: projection
  defp maybe_put(projection, key, value), do: Map.put(projection, key, value)

  defp project_location(location) when is_map(location) do
    with {:ok, coordinates} <- project_coordinates(location) do
      location =
        %{
          "country" => normalize_text(Map.get(location, "country")),
          "label" => normalize_text(Map.get(location, "label"))
        }
        |> Map.merge(coordinates)
        |> reject_nil_values()

      {:ok, location}
    end
  end

  defp project_location(_location), do: {:error, :invalid_shape}

  defp project_coordinates(location) do
    latitude = Map.get(location, "latitude")
    longitude = Map.get(location, "longitude")

    cond do
      is_nil(latitude) and is_nil(longitude) ->
        {:ok, %{}}

      is_nil(latitude) or is_nil(longitude) ->
        {:error, :partial_coordinates}

      valid_latitude?(latitude) and valid_longitude?(longitude) ->
        {:ok, %{"latitude" => latitude, "longitude" => longitude}}

      true ->
        {:error, :invalid_coordinates}
    end
  end

  defp project_availability(availability) when is_map(availability) do
    with {:ok, timezone} <- project_timezone(Map.get(availability, "timezone")),
         {:ok, work_start} <- project_work_time(Map.get(availability, "work_start"), :work_start),
         {:ok, work_end} <- project_work_time(Map.get(availability, "work_end"), :work_end) do
      {:ok,
       %{
         "timezone" => timezone,
         "work_start" => work_start,
         "work_end" => work_end
       }
       |> reject_nil_values()}
    end
  end

  defp project_availability(_availability), do: {:error, :invalid_shape}

  defp project_timezone(nil), do: {:ok, nil}

  defp project_timezone(timezone) when is_binary(timezone) do
    timezone = String.trim(timezone)

    cond do
      timezone == "" -> {:ok, nil}
      valid_iana_timezone?(timezone) -> {:ok, timezone}
      true -> {:error, :invalid_timezone}
    end
  end

  defp project_timezone(_timezone), do: {:error, :invalid_timezone}

  defp project_work_time(nil, _field), do: {:ok, nil}

  defp project_work_time(value, field) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" ->
        {:ok, nil}

      valid_work_time?(value) ->
        {:ok, value}

      true ->
        {:error, :"invalid_#{field}"}
    end
  end

  defp project_work_time(_value, field), do: {:error, :"invalid_#{field}"}

  defp project_name_variants(nil), do: {:ok, nil}

  defp project_name_variants(variants) when is_list(variants) and variants != [] do
    variants
    |> Enum.reduce_while({:ok, []}, fn variant, {:ok, projected} ->
      case project_name_variant(variant) do
        {:ok, variant} -> {:cont, {:ok, [variant | projected]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, projected} -> {:ok, Enum.reverse(projected)}
      {:error, _reason} -> {:error, :invalid_name_variants}
    end
  end

  defp project_name_variants(_variants), do: {:error, :invalid_name_variants}

  defp project_name_variant(%{"lang" => lang, "text" => text} = variant) do
    with lang when not is_nil(lang) <- normalize_text(lang),
         text when not is_nil(text) <- normalize_text(text),
         {:ok, pronunciation} <- project_pronunciation(Map.get(variant, "pronunciation")) do
      projected =
        %{
          "lang" => lang,
          "text" => text,
          "script" => normalize_text(Map.get(variant, "script")),
          "pronunciation" => pronunciation
        }
        |> reject_nil_values()

      {:ok, projected}
    else
      nil -> {:error, :invalid_name_variant}
      {:error, reason} -> {:error, reason}
    end
  end

  defp project_name_variant(_variant), do: {:error, :invalid_name_variant}

  defp project_pronunciation(nil), do: {:ok, nil}

  defp project_pronunciation(pronunciation) when is_map(pronunciation) do
    {:ok,
     %{
       "audio_url" => normalize_text(Map.get(pronunciation, "audio_url")),
       "source_kind" => normalize_text(Map.get(pronunciation, "source_kind")),
       "phonetic" => normalize_text(Map.get(pronunciation, "phonetic")),
       "source_url" => normalize_text(Map.get(pronunciation, "source_url"))
     }
     |> reject_nil_values()}
  end

  defp project_pronunciation(_pronunciation), do: {:error, :invalid_pronunciation}

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

  defp valid_latitude?(latitude) when is_number(latitude), do: latitude >= -90 and latitude <= 90
  defp valid_latitude?(_latitude), do: false

  defp valid_longitude?(longitude) when is_number(longitude),
    do: longitude >= -180 and longitude <= 180

  defp valid_longitude?(_longitude), do: false

  defp valid_iana_timezone?(timezone) do
    case DateTime.now(timezone) do
      {:ok, _datetime} -> true
      {:error, _reason} -> false
    end
  end

  defp valid_work_time?(value) do
    cond do
      match?({:ok, _time}, Time.from_iso8601(value)) ->
        true

      Regex.match?(~r/^\d{2}:\d{2}$/, value) ->
        match?({:ok, _time}, Time.from_iso8601(value <> ":00"))

      true ->
        false
    end
  end

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

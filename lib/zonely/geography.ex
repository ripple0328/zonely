defmodule Zonely.Geography do
  @moduledoc """
  Domain module for handling geographical information, countries, timezones, and locations.

  This module encapsulates business logic related to:
  - Country name resolution and validation
  - Language derivation from country codes  
  - Timezone handling and validation
  - Location-based user grouping and filtering
  """

  alias Zonely.Accounts.Person
  alias Zonely.LanguageService

  @country_display_overrides %{
    "BO" => "Bolivia",
    "BN" => "Brunei",
    "CD" => "Democratic Republic of the Congo",
    "CG" => "Republic of the Congo",
    "FK" => "Falkland Islands",
    "FM" => "Micronesia",
    "GB" => "United Kingdom",
    "IR" => "Iran",
    "KP" => "North Korea",
    "KR" => "South Korea",
    "LA" => "Laos",
    "MD" => "Moldova",
    "MK" => "North Macedonia",
    "RU" => "Russia",
    "SY" => "Syria",
    "TW" => "Taiwan",
    "TZ" => "Tanzania",
    "US" => "United States",
    "VE" => "Venezuela",
    "VN" => "Vietnam"
  }

  @doc """
  Resolves a country code to its full name.

  ## Examples

      iex> Zonely.Geography.country_name("US")
      "United States of America"
      
      iex> Zonely.Geography.country_name("GB") 
      "United Kingdom of Great Britain and Northern Ireland"
      
      iex> Zonely.Geography.country_name("INVALID")
      "Unknown Country"
  """
  @spec country_name(String.t() | nil) :: String.t()
  def country_name(country_code) when is_binary(country_code) and country_code != "" do
    try do
      case Countries.get(country_code) do
        %{name: name} when is_binary(name) -> name
        [] -> "Unknown Country"
        _ -> "Unknown Country"
      end
    rescue
      _ -> "Unknown Country"
    end
  end

  def country_name(_), do: "Unknown Country"

  @doc """
  Returns active country options sorted by display name for controlled forms.
  """
  @spec country_options() :: [%{code: String.t(), name: String.t()}]
  def country_options do
    Countries.all()
    |> Enum.reject(& &1.dissolved_on)
    |> Enum.map(&%{code: &1.alpha2, name: display_country_name(&1)})
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  @doc """
  Resolves a country form value to an ISO 3166-1 alpha-2 code.

  The input may already be a two-letter code or may be a display name from
  `country_options/0`. Unknown values are returned trimmed so normal changeset
  validation can reject them.
  """
  @spec country_code_from_input(String.t() | nil) :: String.t() | nil
  def country_code_from_input(input) when is_binary(input) do
    value = String.trim(input)
    code = String.upcase(value)

    cond do
      value == "" ->
        nil

      String.length(code) == 2 and valid_country?(code) ->
        code

      true ->
        case Enum.find(country_options(), &(String.downcase(&1.name) == String.downcase(value))) do
          %{code: code} -> code
          nil -> value
        end
    end
  end

  def country_code_from_input(_input), do: nil

  @doc """
  Returns the controlled-form display value for a country code.
  """
  @spec country_display_value(String.t() | nil) :: String.t()
  def country_display_value(country_code) when is_binary(country_code) do
    code = String.upcase(String.trim(country_code))

    case Enum.find(country_options(), &(&1.code == code)) do
      %{name: name} -> name
      nil -> String.trim(country_code)
    end
  end

  def country_display_value(_country_code), do: ""

  defp display_country_name(%{alpha2: code}) when is_map_key(@country_display_overrides, code),
    do: Map.fetch!(@country_display_overrides, code)

  defp display_country_name(%{name: name}) when is_binary(name), do: name

  @doc """
  Returns valid IANA timezone options for controlled forms.
  """
  @spec timezone_options() :: [String.t()]
  def timezone_options do
    Tzdata.canonical_zone_list()
    |> Enum.concat(["UTC"])
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Validates if a country code is valid according to ISO standards.

  ## Examples

      iex> Zonely.Geography.valid_country?("US")
      true
      
      iex> Zonely.Geography.valid_country?("XX")
      false
  """
  @spec valid_country?(String.t()) :: boolean()
  def valid_country?(country_code) when is_binary(country_code) do
    LanguageService.valid_country?(country_code)
  end

  @doc """
  Gets the native language name for a country.

  ## Examples

      iex> Zonely.Geography.native_language("ES")
      "Spanish"
      
      iex> Zonely.Geography.native_language("JP")
      "Japanese"
  """
  @spec native_language(String.t()) :: String.t()
  def native_language(country_code) when is_binary(country_code) do
    LanguageService.get_native_language_name(country_code)
  end

  @doc """
  Derives locale code from country code.

  ## Examples

      iex> Zonely.Geography.country_to_locale("US")
      "en-US"
      
      iex> Zonely.Geography.country_to_locale("ES")
      "es-ES"
  """
  @spec country_to_locale(String.t()) :: String.t()
  def country_to_locale(country_code) when is_binary(country_code) do
    LanguageService.derive_language_from_country(country_code)
  end

  @doc """
  Gets users filtered by country.

  ## Examples

      iex> users = [%Person{country: "US"}, %Person{country: "ES"}]
      iex> Zonely.Geography.users_by_country(users, "US")
      [%Person{country: "US"}]
  """
  @spec users_by_country([Person.t()], String.t()) :: [Person.t()]
  def users_by_country(users, country) when is_list(users) and is_binary(country) do
    Enum.filter(users, fn user -> user.country == country end)
  end

  @doc """
  Gets users grouped by country.

  ## Examples

      iex> users = [%Person{country: "US"}, %Person{country: "ES"}, %Person{country: "US"}]
      iex> Zonely.Geography.group_users_by_country(users)
      %{"US" => [%Person{}, %Person{}], "ES" => [%Person{}]}
  """
  @spec group_users_by_country([Person.t()]) :: %{String.t() => [Person.t()]}
  def group_users_by_country(users) when is_list(users) do
    Enum.group_by(users, & &1.country)
  end

  @doc """
  Gets users filtered by timezone.

  ## Examples

      iex> users = [%Person{timezone: "America/New_York"}, %Person{timezone: "Europe/London"}]
      iex> Zonely.Geography.users_by_timezone(users, "America/New_York")
      [%Person{timezone: "America/New_York"}]
  """
  @spec users_by_timezone([Person.t()], String.t()) :: [Person.t()]
  def users_by_timezone(users, timezone) when is_list(users) and is_binary(timezone) do
    Enum.filter(users, fn user -> user.timezone == timezone end)
  end

  @doc """
  Gets users grouped by timezone.

  ## Examples

      iex> users = [%Person{timezone: "America/New_York"}, %Person{timezone: "Europe/London"}]
      iex> Zonely.Geography.group_users_by_timezone(users)
      %{"America/New_York" => [%Person{}], "Europe/London" => [%Person{}]}
  """
  @spec group_users_by_timezone([Person.t()]) :: %{String.t() => [Person.t()]}
  def group_users_by_timezone(users) when is_list(users) do
    Enum.group_by(users, & &1.timezone)
  end

  @doc """
  Gets all unique countries from a list of users.

  ## Examples

      iex> users = [%Person{country: "US"}, %Person{country: "ES"}, %Person{country: "US"}]
      iex> Zonely.Geography.unique_countries(users)
      ["ES", "US"]
  """
  @spec unique_countries([Person.t()]) :: [String.t()]
  def unique_countries(users) when is_list(users) do
    users
    |> Enum.map(& &1.country)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Gets all unique timezones from a list of users.

  ## Examples

      iex> users = [%Person{timezone: "America/New_York"}, %Person{timezone: "Europe/London"}]
      iex> Zonely.Geography.unique_timezones(users)
      ["America/New_York", "Europe/London"]
  """
  @spec unique_timezones([Person.t()]) :: [String.t()]
  def unique_timezones(users) when is_list(users) do
    users
    |> Enum.map(& &1.timezone)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Gets geographic statistics for a list of users.

  Returns counts by country and timezone.

  ## Examples

      iex> Zonely.Geography.get_statistics(users)
      %{
        countries: %{"US" => 3, "ES" => 2},
        timezones: %{"America/New_York" => 2, "Europe/Madrid" => 2},
        total_countries: 2,
        total_timezones: 2
      }
  """
  @spec get_statistics([Person.t()]) :: %{
          countries: %{String.t() => non_neg_integer()},
          timezones: %{String.t() => non_neg_integer()},
          total_countries: non_neg_integer(),
          total_timezones: non_neg_integer()
        }
  def get_statistics(users) when is_list(users) do
    country_counts = Enum.frequencies_by(users, & &1.country)
    timezone_counts = Enum.frequencies_by(users, & &1.timezone)

    %{
      countries: country_counts,
      timezones: timezone_counts,
      total_countries: map_size(country_counts),
      total_timezones: map_size(timezone_counts)
    }
  end

  @doc """
  Validates timezone string format.

  This is a basic validation - for production you'd want to use a proper timezone library.

  ## Examples

      iex> Zonely.Geography.valid_timezone?("America/New_York")
      true
      
      iex> Zonely.Geography.valid_timezone?("Invalid/Timezone")
      false
  """
  @spec valid_timezone?(String.t()) :: boolean()
  def valid_timezone?(timezone) when is_binary(timezone) do
    # Basic validation - contains region/city format with known regions
    case String.split(timezone, "/") do
      [region, city | _]
      when region in [
             "America",
             "Europe",
             "Asia",
             "Africa",
             "Australia",
             "Pacific",
             "Atlantic",
             "Indian",
             "UTC",
             "GMT"
           ] and byte_size(city) > 0 ->
        true

      _ ->
        false
    end
  end

  @doc """
  Gets country information including native language and locale.

  ## Examples

      iex> Zonely.Geography.country_info("ES")
      %{
        code: "ES",
        name: "Spain", 
        native_language: "Spanish",
        locale: "es-ES"
      }
  """
  @spec country_info(String.t()) :: %{
          code: String.t(),
          name: String.t(),
          native_language: String.t(),
          locale: String.t()
        }
  def country_info(country_code) when is_binary(country_code) do
    %{
      code: country_code,
      name: country_name(country_code),
      native_language: native_language(country_code),
      locale: country_to_locale(country_code)
    }
  end

  @doc """
  Checks if a user is in a specific geographic region.

  Currently uses simple country matching but could be extended for regions.
  """
  @spec user_in_region?(Person.t(), String.t() | [String.t()]) :: boolean()
  def user_in_region?(%Person{country: country}, region) when is_binary(region) do
    country == region
  end

  def user_in_region?(%Person{country: country}, regions) when is_list(regions) do
    country in regions
  end
end

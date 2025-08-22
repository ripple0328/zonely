defmodule Zonely.Geography do
  @moduledoc """
  Domain module for handling geographical information, countries, timezones, and locations.
  
  This module encapsulates business logic related to:
  - Country name resolution and validation
  - Language derivation from country codes  
  - Timezone handling and validation
  - Location-based user grouping and filtering
  """

  alias Zonely.Accounts.User
  alias Zonely.LanguageService

  @doc """
  Resolves a country code to its full name.
  
  ## Examples
  
      iex> Zonely.Geography.country_name("US")
      "United States"
      
      iex> Zonely.Geography.country_name("GB") 
      "United Kingdom"
      
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
  
      iex> users = [%User{country: "US"}, %User{country: "ES"}]
      iex> Zonely.Geography.users_by_country(users, "US")
      [%User{country: "US"}]
  """
  @spec users_by_country([User.t()], String.t()) :: [User.t()]
  def users_by_country(users, country) when is_list(users) and is_binary(country) do
    Enum.filter(users, fn user -> user.country == country end)
  end

  @doc """
  Gets users grouped by country.
  
  ## Examples
  
      iex> users = [%User{country: "US"}, %User{country: "ES"}, %User{country: "US"}]
      iex> Zonely.Geography.group_users_by_country(users)
      %{"US" => [%User{}, %User{}], "ES" => [%User{}]}
  """
  @spec group_users_by_country([User.t()]) :: %{String.t() => [User.t()]}
  def group_users_by_country(users) when is_list(users) do
    Enum.group_by(users, & &1.country)
  end

  @doc """
  Gets users filtered by timezone.
  
  ## Examples
  
      iex> users = [%User{timezone: "America/New_York"}, %User{timezone: "Europe/London"}]
      iex> Zonely.Geography.users_by_timezone(users, "America/New_York")
      [%User{timezone: "America/New_York"}]
  """
  @spec users_by_timezone([User.t()], String.t()) :: [User.t()]
  def users_by_timezone(users, timezone) when is_list(users) and is_binary(timezone) do
    Enum.filter(users, fn user -> user.timezone == timezone end)
  end

  @doc """
  Gets users grouped by timezone.
  
  ## Examples
  
      iex> users = [%User{timezone: "America/New_York"}, %User{timezone: "Europe/London"}]
      iex> Zonely.Geography.group_users_by_timezone(users)
      %{"America/New_York" => [%User{}], "Europe/London" => [%User{}]}
  """
  @spec group_users_by_timezone([User.t()]) :: %{String.t() => [User.t()]}
  def group_users_by_timezone(users) when is_list(users) do
    Enum.group_by(users, & &1.timezone)
  end

  @doc """
  Gets all unique countries from a list of users.
  
  ## Examples
  
      iex> users = [%User{country: "US"}, %User{country: "ES"}, %User{country: "US"}]
      iex> Zonely.Geography.unique_countries(users)
      ["ES", "US"]
  """
  @spec unique_countries([User.t()]) :: [String.t()]
  def unique_countries(users) when is_list(users) do
    users
    |> Enum.map(& &1.country)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Gets all unique timezones from a list of users.
  
  ## Examples
  
      iex> users = [%User{timezone: "America/New_York"}, %User{timezone: "Europe/London"}]
      iex> Zonely.Geography.unique_timezones(users)
      ["America/New_York", "Europe/London"]
  """
  @spec unique_timezones([User.t()]) :: [String.t()]
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
  @spec get_statistics([User.t()]) :: %{
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
      [region, city | _] when region in ["America", "Europe", "Asia", "Africa", "Australia", "Pacific", "Atlantic", "Indian", "UTC", "GMT"] and byte_size(city) > 0 -> true
      _ -> false
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
  @spec user_in_region?(User.t(), String.t() | [String.t()]) :: boolean()
  def user_in_region?(%User{country: country}, region) when is_binary(region) do
    country == region
  end

  def user_in_region?(%User{country: country}, regions) when is_list(regions) do
    country in regions
  end
end
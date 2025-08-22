defmodule Zonely.GeographyTest do
  use ExUnit.Case, async: true
  
  alias Zonely.Geography
  alias Zonely.Accounts.User

  describe "country_name/1" do
    test "returns correct country names" do
      assert Geography.country_name("US") == "United States of America"
      assert Geography.country_name("GB") == "United Kingdom of Great Britain and Northern Ireland" 
      assert Geography.country_name("DE") == "Germany"
      assert Geography.country_name("JP") == "Japan"
    end
    
    test "handles invalid country codes" do
      assert Geography.country_name("XX") == "Unknown Country"
      assert Geography.country_name("ZZ") == "Unknown Country"
    end
    
    test "handles empty string" do
      assert Geography.country_name("") == "Unknown Country"
    end
  end

  describe "valid_country?/1" do
    test "validates real country codes" do
      assert Geography.valid_country?("US") == true
      assert Geography.valid_country?("GB") == true
      assert Geography.valid_country?("DE") == true
    end
    
    test "rejects invalid country codes" do
      assert Geography.valid_country?("XX") == false
      assert Geography.valid_country?("ZZ") == false
      assert Geography.valid_country?("") == false
    end
  end

  describe "native_language/1" do
    test "returns correct native languages" do
      assert Geography.native_language("ES") == "Spanish"
      assert Geography.native_language("FR") == "French"
      assert Geography.native_language("DE") == "German"
      assert Geography.native_language("JP") == "Japanese"
    end
    
    test "returns default for unknown countries" do
      assert Geography.native_language("XX") == "English"
    end
  end

  describe "country_to_locale/1" do
    test "converts country codes to locales" do
      assert Geography.country_to_locale("US") == "en-US"
      assert Geography.country_to_locale("ES") == "es-ES"
      assert Geography.country_to_locale("FR") == "fr-FR"
      assert Geography.country_to_locale("DE") == "de-DE"
    end
    
    test "returns default locale for unknown countries" do
      assert Geography.country_to_locale("XX") == "en-US"
    end
  end

  describe "users_by_country/2" do
    setup do
      users = [
        %User{id: 1, country: "US", name: "John"},
        %User{id: 2, country: "ES", name: "Maria"},
        %User{id: 3, country: "US", name: "Bob"}
      ]
      {:ok, users: users}
    end
    
    test "filters users by country correctly", %{users: users} do
      us_users = Geography.users_by_country(users, "US")
      es_users = Geography.users_by_country(users, "ES")
      
      assert length(us_users) == 2
      assert length(es_users) == 1
      assert Enum.all?(us_users, fn user -> user.country == "US" end)
      assert Enum.all?(es_users, fn user -> user.country == "ES" end)
    end
    
    test "returns empty list for non-existent country", %{users: users} do
      result = Geography.users_by_country(users, "XX")
      assert result == []
    end
  end

  describe "group_users_by_country/1" do
    setup do
      users = [
        %User{id: 1, country: "US", name: "John"},
        %User{id: 2, country: "ES", name: "Maria"},
        %User{id: 3, country: "US", name: "Bob"}
      ]
      {:ok, users: users}
    end
    
    test "groups users by country", %{users: users} do
      grouped = Geography.group_users_by_country(users)
      
      assert Map.has_key?(grouped, "US")
      assert Map.has_key?(grouped, "ES")
      assert length(grouped["US"]) == 2
      assert length(grouped["ES"]) == 1
    end
  end

  describe "users_by_timezone/2" do
    setup do
      users = [
        %User{id: 1, timezone: "America/New_York", name: "John"},
        %User{id: 2, timezone: "Europe/London", name: "Alice"},
        %User{id: 3, timezone: "America/New_York", name: "Bob"}
      ]
      {:ok, users: users}
    end
    
    test "filters users by timezone", %{users: users} do
      ny_users = Geography.users_by_timezone(users, "America/New_York")
      london_users = Geography.users_by_timezone(users, "Europe/London")
      
      assert length(ny_users) == 2
      assert length(london_users) == 1
    end
  end

  describe "group_users_by_timezone/1" do
    setup do
      users = [
        %User{id: 1, timezone: "America/New_York", name: "John"},
        %User{id: 2, timezone: "Europe/London", name: "Alice"}
      ]
      {:ok, users: users}
    end
    
    test "groups users by timezone", %{users: users} do
      grouped = Geography.group_users_by_timezone(users)
      
      assert Map.has_key?(grouped, "America/New_York")
      assert Map.has_key?(grouped, "Europe/London")
      assert length(grouped["America/New_York"]) == 1
      assert length(grouped["Europe/London"]) == 1
    end
  end

  describe "unique_countries/1" do
    setup do
      users = [
        %User{country: "US", name: "John"},
        %User{country: "ES", name: "Maria"},
        %User{country: "US", name: "Bob"},
        %User{country: "FR", name: "Pierre"}
      ]
      {:ok, users: users}
    end
    
    test "returns sorted unique countries", %{users: users} do
      countries = Geography.unique_countries(users)
      
      assert countries == ["ES", "FR", "US"]
      assert length(countries) == 3
    end
    
    test "handles empty user list" do
      countries = Geography.unique_countries([])
      assert countries == []
    end
  end

  describe "unique_timezones/1" do
    setup do
      users = [
        %User{timezone: "America/New_York", name: "John"},
        %User{timezone: "Europe/London", name: "Alice"},
        %User{timezone: "America/New_York", name: "Bob"}
      ]
      {:ok, users: users}
    end
    
    test "returns sorted unique timezones", %{users: users} do
      timezones = Geography.unique_timezones(users)
      
      assert timezones == ["America/New_York", "Europe/London"]
      assert length(timezones) == 2
    end
  end

  describe "get_statistics/1" do
    setup do
      users = [
        %User{country: "US", timezone: "America/New_York", name: "John"},
        %User{country: "US", timezone: "America/Los_Angeles", name: "Alice"},
        %User{country: "ES", timezone: "Europe/Madrid", name: "Maria"}
      ]
      {:ok, users: users}
    end
    
    test "returns correct statistics", %{users: users} do
      stats = Geography.get_statistics(users)
      
      assert stats.countries["US"] == 2
      assert stats.countries["ES"] == 1
      assert stats.timezones["America/New_York"] == 1
      assert stats.timezones["America/Los_Angeles"] == 1
      assert stats.timezones["Europe/Madrid"] == 1
      assert stats.total_countries == 2
      assert stats.total_timezones == 3
    end
  end

  describe "valid_timezone?/1" do
    test "validates timezone format" do
      assert Geography.valid_timezone?("America/New_York") == true
      assert Geography.valid_timezone?("Europe/London") == true
      assert Geography.valid_timezone?("Asia/Tokyo") == true
    end
    
    test "rejects invalid timezone format" do
      assert Geography.valid_timezone?("InvalidTimezone") == false
      assert Geography.valid_timezone?("America") == false
      assert Geography.valid_timezone?("") == false
    end
  end

  describe "country_info/1" do
    test "returns comprehensive country information" do
      info = Geography.country_info("ES")
      
      assert info.code == "ES"
      assert info.name == "Spain"
      assert info.native_language == "Spanish"
      assert info.locale == "es-ES"
    end
    
    test "handles unknown countries" do
      info = Geography.country_info("XX")
      
      assert info.code == "XX"
      assert info.name == "Unknown Country"
      assert info.native_language == "English"
      assert info.locale == "en-US"
    end
  end

  describe "user_in_region?/2" do
    setup do
      user_us = %User{country: "US", name: "John"}
      user_es = %User{country: "ES", name: "Maria"}
      {:ok, user_us: user_us, user_es: user_es}
    end
    
    test "matches single region", %{user_us: user_us, user_es: user_es} do
      assert Geography.user_in_region?(user_us, "US") == true
      assert Geography.user_in_region?(user_us, "ES") == false
      assert Geography.user_in_region?(user_es, "ES") == true
    end
    
    test "matches multiple regions", %{user_us: user_us, user_es: user_es} do
      regions = ["US", "CA", "MX"]
      
      assert Geography.user_in_region?(user_us, regions) == true
      assert Geography.user_in_region?(user_es, regions) == false
    end
  end

  describe "edge cases and robustness" do
    test "handles nil and empty values gracefully" do
      # These should not crash
      assert Geography.users_by_country([], "US") == []
      assert Geography.unique_countries([]) == []
      assert Geography.unique_timezones([]) == []
    end
    
    test "handles case variations in country codes" do
      # The underlying LanguageService should handle case normalization
      assert is_binary(Geography.native_language("us"))
      assert is_binary(Geography.country_to_locale("gb"))
    end
  end
end
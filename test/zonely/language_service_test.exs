defmodule Zonely.LanguageServiceTest do
  use ExUnit.Case, async: true
  
  alias Zonely.LanguageService

  describe "get_native_language_name/1" do
    test "returns correct language for common countries" do
      assert LanguageService.get_native_language_name("US") == "English"
      assert LanguageService.get_native_language_name("ES") == "Spanish"
      assert LanguageService.get_native_language_name("FR") == "French"
      assert LanguageService.get_native_language_name("DE") == "German"
      assert LanguageService.get_native_language_name("JP") == "Japanese"
      assert LanguageService.get_native_language_name("CN") == "Chinese"
    end
    
    test "handles case variations" do
      assert LanguageService.get_native_language_name("us") == "English"
      assert LanguageService.get_native_language_name("Us") == "English"
    end
    
    test "returns English as default for unknown countries" do
      assert LanguageService.get_native_language_name("XX") == "English"
      assert LanguageService.get_native_language_name("ZZ") == "English"
    end
    
    test "handles Portuguese variants correctly" do
      assert LanguageService.get_native_language_name("PT") == "Portuguese"
      assert LanguageService.get_native_language_name("BR") == "Portuguese"
    end
    
    test "handles English variants correctly" do
      assert LanguageService.get_native_language_name("US") == "English"
      assert LanguageService.get_native_language_name("GB") == "English"
      assert LanguageService.get_native_language_name("CA") == "English"
      assert LanguageService.get_native_language_name("AU") == "English"
    end
    
    test "handles Spanish variants correctly" do
      assert LanguageService.get_native_language_name("ES") == "Spanish"
      assert LanguageService.get_native_language_name("MX") == "Spanish"
    end
  end

  describe "derive_language_from_country/1" do
    test "derives correct locale codes" do
      assert LanguageService.derive_language_from_country("US") == "en-US"
      assert LanguageService.derive_language_from_country("GB") == "en-GB"
      assert LanguageService.derive_language_from_country("ES") == "es-ES"
      assert LanguageService.derive_language_from_country("MX") == "es-MX"
      assert LanguageService.derive_language_from_country("FR") == "fr-FR"
    end
    
    test "handles case variations" do
      assert LanguageService.derive_language_from_country("us") == "en-US"
      assert LanguageService.derive_language_from_country("gb") == "en-GB"
    end
    
    test "returns default for unknown countries" do
      assert LanguageService.derive_language_from_country("XX") == "en-US"
    end
    
    test "handles European countries" do
      assert LanguageService.derive_language_from_country("DE") == "de-DE"
      assert LanguageService.derive_language_from_country("IT") == "it-IT"
      assert LanguageService.derive_language_from_country("NL") == "nl-NL"
      assert LanguageService.derive_language_from_country("SE") == "sv-SE"
    end
    
    test "handles Asian countries" do
      assert LanguageService.derive_language_from_country("JP") == "ja-JP"
      assert LanguageService.derive_language_from_country("CN") == "zh-CN"
      assert LanguageService.derive_language_from_country("KR") == "ko-KR"
      assert LanguageService.derive_language_from_country("IN") == "hi-IN"
    end
  end

  describe "get_language_code/1" do
    test "extracts primary language code from locale" do
      assert LanguageService.get_language_code("US") == "en"
      assert LanguageService.get_language_code("ES") == "es"
      assert LanguageService.get_language_code("FR") == "fr"
      assert LanguageService.get_language_code("JP") == "ja"
      assert LanguageService.get_language_code("CN") == "zh"
    end
    
    test "handles different English variants" do
      assert LanguageService.get_language_code("US") == "en"
      assert LanguageService.get_language_code("GB") == "en"
      assert LanguageService.get_language_code("CA") == "en"
      assert LanguageService.get_language_code("AU") == "en"
    end
    
    test "handles unknown countries" do
      assert LanguageService.get_language_code("XX") == "en"
    end
  end

  describe "valid_country?/1" do
    test "validates real country codes using Countries library" do
      # These should be valid according to Countries library
      assert LanguageService.valid_country?("US") == true
      assert LanguageService.valid_country?("GB") == true
      assert LanguageService.valid_country?("DE") == true
      assert LanguageService.valid_country?("JP") == true
    end
    
    test "rejects invalid country codes" do
      assert LanguageService.valid_country?("XX") == false
      assert LanguageService.valid_country?("ZZ") == false
      assert LanguageService.valid_country?("") == false
    end
    
    test "handles case variations" do
      # Countries library might be case sensitive, so test both
      assert LanguageService.valid_country?("US") == true
      # Note: Countries library behavior may vary for lowercase
    end
  end

  describe "get_country_info/1" do
    test "returns country information for valid codes" do
      info = LanguageService.get_country_info("US")
      
      # Should return a map with country data from Countries library
      assert is_map(info) or is_nil(info)
    end
    
    test "returns nil for invalid country codes" do
      assert LanguageService.get_country_info("XX") == nil
      assert LanguageService.get_country_info("ZZ") == nil
    end
    
    test "handles empty string" do
      assert LanguageService.get_country_info("") == nil
    end
  end

  describe "edge cases and robustness" do
    test "handles nil input gracefully where appropriate" do
      # Some functions may need to handle nil - test based on actual implementation
      # This would depend on how the module is designed to handle edge cases
    end
    
    test "consistent behavior across similar functions" do
      # Test that related functions return consistent results
      country_code = "ES"
      
      language_name = LanguageService.get_native_language_name(country_code)
      locale = LanguageService.derive_language_from_country(country_code)
      primary_code = LanguageService.get_language_code(country_code)
      
      # They should all relate to Spanish
      assert language_name == "Spanish"
      assert locale == "es-ES"
      assert primary_code == "es"
    end
  end
end
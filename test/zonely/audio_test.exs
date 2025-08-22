defmodule Zonely.AudioTest do
  use ExUnit.Case, async: true
  
  alias Zonely.Audio
  alias Zonely.Accounts.User

  describe "derive_language_from_country/1" do
    test "returns correct language for common countries" do
      assert Audio.derive_language_from_country("US") == "en-US"
      assert Audio.derive_language_from_country("GB") == "en-GB"
      assert Audio.derive_language_from_country("ES") == "es-ES"
      assert Audio.derive_language_from_country("FR") == "fr-FR"
      assert Audio.derive_language_from_country("DE") == "de-DE"
      assert Audio.derive_language_from_country("JP") == "ja-JP"
    end

    test "returns default for unknown countries" do
      assert Audio.derive_language_from_country("XX") == "en-US"
      assert Audio.derive_language_from_country("") == "en-US"
    end

    test "handles regional variations" do
      assert Audio.derive_language_from_country("MX") == "es-MX"
      assert Audio.derive_language_from_country("BR") == "pt-BR"
      assert Audio.derive_language_from_country("CA") == "en-CA"
      assert Audio.derive_language_from_country("CH") == "de-CH"
    end
  end

  describe "get_native_language_name/1" do
    test "returns correct language names for countries" do
      assert Audio.get_native_language_name("US") == "English"
      assert Audio.get_native_language_name("ES") == "Spanish"
      assert Audio.get_native_language_name("FR") == "French"
      assert Audio.get_native_language_name("DE") == "German"
      assert Audio.get_native_language_name("JP") == "Japanese"
    end

    test "returns default for unknown countries" do
      assert Audio.get_native_language_name("XX") == "English"
      assert Audio.get_native_language_name("") == "English"
    end

    test "handles regional variations correctly" do
      assert Audio.get_native_language_name("MX") == "Spanish"
      assert Audio.get_native_language_name("BR") == "Portuguese"
      assert Audio.get_native_language_name("CA") == "English"
      assert Audio.get_native_language_name("CH") == "German"
    end
  end
end

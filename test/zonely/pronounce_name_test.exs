defmodule Zonely.PronunceNameTest do
  use ExUnit.Case, async: true

  alias Zonely.PronunceName

  describe "get_native_language_name/1" do
    test "returns correct language names for various countries" do
      assert PronunceName.get_native_language_name("US") == "English"
      assert PronunceName.get_native_language_name("GB") == "English"
      assert PronunceName.get_native_language_name("ES") == "Spanish"
      assert PronunceName.get_native_language_name("MX") == "Spanish"
      assert PronunceName.get_native_language_name("FR") == "French"
      assert PronunceName.get_native_language_name("DE") == "German"
      assert PronunceName.get_native_language_name("IT") == "Italian"
      assert PronunceName.get_native_language_name("PT") == "Portuguese"
      assert PronunceName.get_native_language_name("BR") == "Portuguese"
      assert PronunceName.get_native_language_name("JP") == "Japanese"
      assert PronunceName.get_native_language_name("CN") == "Chinese"
      assert PronunceName.get_native_language_name("KR") == "Korean"
      assert PronunceName.get_native_language_name("IN") == "Hindi"
      assert PronunceName.get_native_language_name("EG") == "Arabic"
      assert PronunceName.get_native_language_name("SE") == "Swedish"
    end

    test "handles lowercase country codes" do
      assert PronunceName.get_native_language_name("us") == "English"
      assert PronunceName.get_native_language_name("es") == "Spanish"
    end

    test "returns default for unknown country codes" do
      assert PronunceName.get_native_language_name("XX") == "English"
      assert PronunceName.get_native_language_name("ZZ") == "English"
    end
  end

  describe "play/3" do
    test "returns play_tts for names without API key" do
      # Without FORVO_API_KEY, should fallback to TTS
      System.delete_env("FORVO_API_KEY")

      result = PronunceName.play("Test Name", "en-US", "US")
      assert {:play_tts, %{text: "Test Name", lang: "en-US"}} = result
    end

    test "derives language from country when language is nil" do
      System.delete_env("FORVO_API_KEY")

      result = PronunceName.play("Hans Mueller", nil, "DE")
      assert {:play_tts, %{text: "Hans Mueller", lang: "de-DE"}} = result
    end

    test "handles various country codes for language derivation" do
      System.delete_env("FORVO_API_KEY")

      # Test a few key mappings
      result_us = PronunceName.play("John", nil, "US")
      assert {:play_tts, %{text: "John", lang: "en-US"}} = result_us

      result_es = PronunceName.play("María", nil, "ES")
      assert {:play_tts, %{text: "María", lang: "es-ES"}} = result_es

      result_jp = PronunceName.play("Yuki", nil, "JP")
      assert {:play_tts, %{text: "Yuki", lang: "ja-JP"}} = result_jp
    end
  end
end

defmodule Zonely.Audio.PronunciationServiceTest do
  use ExUnit.Case, async: true
  
  alias Zonely.Audio.PronunciationService
  alias Zonely.Accounts.User

  describe "get_tts_text/2" do
    test "uses native name when language matches user's native language" do
      user = %User{
        name: "Jose",
        name_native: "José",
        native_language: "es-ES"
      }

      assert PronunciationService.get_tts_text(user, "es-ES") == "José"
    end

    test "uses native name for non-English languages even if not exact match" do
      user = %User{
        name: "Jose",
        name_native: "José",
        native_language: "es-ES"
      }

      assert PronunciationService.get_tts_text(user, "es-MX") == "José"
    end

    test "uses regular name for English when native name exists" do
      user = %User{
        name: "Jose",
        name_native: "José",
        native_language: "es-ES"
      }

      assert PronunciationService.get_tts_text(user, "en-US") == "Jose"
    end

    test "uses regular name when no native name available" do
      user = %User{
        name: "John",
        name_native: nil,
        native_language: nil
      }

      assert PronunciationService.get_tts_text(user, "en-US") == "John"
      assert PronunciationService.get_tts_text(user, "es-ES") == "John"
    end
  end

  describe "supported_language?/1" do
    test "returns true for supported languages" do
      assert PronunciationService.supported_language?("en-US")
      assert PronunciationService.supported_language?("es-ES")
      assert PronunciationService.supported_language?("fr-FR")
      assert PronunciationService.supported_language?("de-DE")
      assert PronunciationService.supported_language?("ja-JP")
    end

    test "returns false for unsupported languages" do
      refute PronunciationService.supported_language?("xx-XX")
      refute PronunciationService.supported_language?("invalid")
      refute PronunciationService.supported_language?("")
    end

    test "supports regional variations" do
      assert PronunciationService.supported_language?("en-GB")
      assert PronunciationService.supported_language?("en-CA")
      assert PronunciationService.supported_language?("es-MX")
      assert PronunciationService.supported_language?("pt-BR")
      assert PronunciationService.supported_language?("zh-CN")
      assert PronunciationService.supported_language?("zh-TW")
    end
  end
end

defmodule Zonely.AudioTest do
  use ExUnit.Case, async: false

  alias Zonely.Accounts.Person
  alias Zonely.Audio

  setup do
    previous = Application.get_env(:zonely, :pronunciation_request_fun)

    on_exit(fn ->
      if previous do
        Application.put_env(:zonely, :pronunciation_request_fun, previous)
      else
        Application.delete_env(:zonely, :pronunciation_request_fun)
      end
    end)

    :ok
  end

  describe "play_english_pronunciation/1" do
    test "requests the production pronunciation API" do
      Application.put_env(:zonely, :pronunciation_request_fun, fn opts ->
        assert opts[:url] == "https://saymyname.qingbo.us/api/v1/pronounce"
        assert opts[:params][:name] == "John Doe"
        assert opts[:params][:lang] == "en-US"

        {:ok,
         %{
           status: 200,
           body: %{
             "kind" => "real_voice",
             "provider" => "production_api",
             "audio_url" => "https://cdn.example.com/john.mp3"
           }
         }}
      end)

      assert {:play_audio, %{url: "https://cdn.example.com/john.mp3", provider: "production_api"}} =
               Audio.play_english_pronunciation(%Person{name: "John Doe", country: "US"})
    end

    test "falls back to device TTS metadata if the production API misses" do
      Application.put_env(:zonely, :pronunciation_request_fun, fn _opts ->
        {:ok, %{status: 404, body: %{"error" => "not_found"}}}
      end)

      assert {:play_tts, %{text: "John Doe", lang: "en-US", provider: "device"}} =
               Audio.play_english_pronunciation(%Person{name: "John Doe", country: "US"})
    end
  end

  describe "play_native_pronunciation/1" do
    test "uses native name and locale" do
      Application.put_env(:zonely, :pronunciation_request_fun, fn opts ->
        assert opts[:url] == "https://saymyname.qingbo.us/api/v1/pronounce"
        assert opts[:params][:name] == "José García"
        assert opts[:params][:lang] == "es-ES"

        {:ok,
         %{
           status: 200,
           body: %{
             "kind" => "ai_voice",
             "provider" => "production_api",
             "audio_url" => "https://cdn.example.com/jose.mp3"
           }
         }}
      end)

      assert {:play_tts_audio, %{url: "https://cdn.example.com/jose.mp3"}} =
               Audio.play_native_pronunciation(%Person{
                 name: "Jose Garcia",
                 name_native: "José García",
                 country: "ES"
               })
    end

    test "falls back to English pronunciation when native name is absent" do
      Application.put_env(:zonely, :pronunciation_request_fun, fn opts ->
        assert opts[:params][:name] == "John Doe"
        assert opts[:params][:lang] == "en-US"

        {:ok,
         %{
           status: 200,
           body: %{
             "tts_text" => "John Doe",
             "tts_language" => "en-US",
             "provider" => "production_api"
           }
         }}
      end)

      assert {:play_tts, %{text: "John Doe", lang: "en-US"}} =
               Audio.play_native_pronunciation(%Person{name: "John Doe", country: "US"})
    end
  end

  describe "derive_english_locale/1" do
    test "returns country-specific English locales" do
      assert Audio.derive_english_locale("US") == "en-US"
      assert Audio.derive_english_locale("GB") == "en-GB"
      assert Audio.derive_english_locale("CA") == "en-CA"
      assert Audio.derive_english_locale("AU") == "en-AU"
    end

    test "defaults to US English" do
      assert Audio.derive_english_locale("ES") == "en-US"
      assert Audio.derive_english_locale(nil) == "en-US"
      assert Audio.derive_english_locale("invalid") == "en-US"
    end
  end
end

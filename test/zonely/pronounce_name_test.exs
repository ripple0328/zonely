defmodule Zonely.PronunceNameTest do
  use ExUnit.Case, async: false

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
    setup do
      Application.put_env(:zonely, :http_client, Zonely.HttpClient.Fake)
      on_exit(fn -> Application.delete_env(:zonely, :http_client) end)
      # Clear cache directory before each test to avoid cross-test interference
      cache_dir = Zonely.AudioCache.dir()
      for f <- File.ls!(cache_dir), do: File.rm!(Path.join(cache_dir, f))
      :ok
    end

    test "returns Polly audio when external services unavailable (no FORVO/NS)" do
      System.delete_env("FORVO_API_KEY")
      System.delete_env("NS_API_KEY")
      # Stub AWS request to return fake mp3 bytes
      Application.put_env(:zonely, :aws_request_fun, fn _req ->
        {:ok, %{status_code: 200, body: <<"FAKE_MP3"::binary>>}}
      end)

      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      {:play_tts_audio, %{url: url}} = PronunceName.play("TTS Only Name", "en-US", "US")
      assert String.ends_with?(url, ".mp3")
    end

    test "derives language from country when language is nil" do
      System.delete_env("FORVO_API_KEY")

      # Stub Polly to avoid network
      Application.put_env(:zonely, :aws_request_fun, fn _req ->
        {:ok, %{status_code: 200, body: <<"FAKE_MP3"::binary>>}}
      end)

      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      {:play_tts_audio, %{url: url}} = PronunceName.play("Hans Mueller", nil, "DE")
      assert String.ends_with?(url, ".mp3")
    end

    test "handles various country codes for language derivation" do
      System.delete_env("FORVO_API_KEY")

      # Test a few key mappings
      Application.put_env(:zonely, :aws_request_fun, fn _req ->
        {:ok, %{status_code: 200, body: <<"FAKE_MP3"::binary>>}}
      end)

      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      {:play_tts_audio, %{url: url_us}} = PronunceName.play("John", nil, "US")
      assert String.ends_with?(url_us, ".mp3")

      {:play_tts_audio, %{url: url_es}} = PronunceName.play("María", nil, "ES")
      assert String.ends_with?(url_es, ".mp3")

      {:play_tts_audio, %{url: url_jp}} = PronunceName.play("Yuki", nil, "JP")
      assert String.ends_with?(url_jp, ".mp3")
    end

    test "cache hit returns cached audio without external calls" do
      cache_dir = Zonely.AudioCache.dir()
      filename = "Test_Name_en-US_12345.mp3"
      File.write!(Path.join(cache_dir, filename), "FAKE")

      result = PronunceName.play("Test Name", "en-US", "US")
      assert {:play_audio, %{url: "/audio-cache/" <> ^filename}} = result
    end

    test "nameshouts success returns audio and caches mp3" do
      System.put_env("NS_API_KEY", "test")
      Application.put_env(:zonely, :http_fake_scenario, :nameshouts_success)
      on_exit(fn -> Application.delete_env(:zonely, :http_fake_scenario) end)

      {:play_audio, %{url: url}} = PronunceName.play("Alice", "en-US", "US")
      assert String.ends_with?(url, ".mp3")
    end

    test "forvo success when nameshouts fails" do
      System.put_env("NS_API_KEY", "test")
      System.put_env("FORVO_API_KEY", "forvo")
      Application.put_env(:zonely, :http_fake_scenario, :forvo_success)
      on_exit(fn -> Application.delete_env(:zonely, :http_fake_scenario) end)

      {:play_audio, %{url: url}} = PronunceName.play("Bob", "en-US", "US")
      assert String.starts_with?(url, "http") or String.starts_with?(url, "/audio-cache/")
    end

    test "falls back to browser TTS when Polly fails" do
      System.put_env("NS_API_KEY", "test")
      System.put_env("FORVO_API_KEY", "forvo")
      Application.put_env(:zonely, :http_fake_scenario, :all_fail)
      Application.put_env(:zonely, :aws_request_fun, fn _req -> {:error, :network_fail} end)
      on_exit(fn -> Application.delete_env(:zonely, :http_fake_scenario) end)
      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      assert {:play_tts, %{text: "Charlie Unique", lang: "en-US"}} =
               PronunceName.play("Charlie Unique", "en-US", "US")
    end
  end
end

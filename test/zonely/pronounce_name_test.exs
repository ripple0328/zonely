defmodule Zonely.PronunceNameTest do
  use ExUnit.Case, async: false

  alias Zonely.PronunceName

  describe "play/2" do
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

      {:play_tts_audio, %{url: url}} = PronunceName.play("TTS Only Name", "en-US")
      assert String.ends_with?(url, ".mp3")
    end

    test "handles various language codes directly" do
      System.delete_env("FORVO_API_KEY")

      # Test direct language codes
      Application.put_env(:zonely, :aws_request_fun, fn _req ->
        {:ok, %{status_code: 200, body: <<"FAKE_MP3"::binary>>}}
      end)

      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      {:play_tts_audio, %{url: url_us}} = PronunceName.play("John", "en-US")
      assert String.ends_with?(url_us, ".mp3")

      {:play_tts_audio, %{url: url_es}} = PronunceName.play("María", "es-ES")
      assert String.ends_with?(url_es, ".mp3")

      {:play_tts_audio, %{url: url_jp}} = PronunceName.play("Yuki", "ja-JP")
      assert String.ends_with?(url_jp, ".mp3")
    end

    test "cache hit returns AI TTS audio without external calls" do
      # Write a fake Polly file that matches language/voice hashing
      Application.put_env(:zonely, :aws_request_fun, fn _req -> {:error, :no_call_expected} end)
      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      # Simulate Polly cached file by calling write_binary_to_cache directly
      # Use local backend so the file is written to the local cache directory
      Application.put_env(:zonely, :audio_cache, [backend: "local"])
      on_exit(fn -> Application.delete_env(:zonely, :audio_cache) end)

      {:ok, url} = Zonely.PronunceName.Cache.write_binary_to_cache("FAKE_MP3", "Test Name", "en-US", ".mp3")
      assert String.ends_with?(url, ".mp3")

      result = PronunceName.play("Test Name", "en-US")
      assert match?({:play_tts_audio, %{url: ^url}}, result)
    end

    test "nameshouts success returns audio and caches mp3" do
      System.put_env("NS_API_KEY", "test")
      Application.put_env(:zonely, :http_fake_scenario, :nameshouts_success)
      on_exit(fn -> Application.delete_env(:zonely, :http_fake_scenario) end)

      {:play_audio, %{url: url}} = PronunceName.play("Alice", "en-US")
      assert String.starts_with?(url, "http")
    end

    test "forvo success when nameshouts fails" do
      System.put_env("NS_API_KEY", "test")
      System.put_env("FORVO_API_KEY", "forvo")
      Application.put_env(:zonely, :http_fake_scenario, :forvo_success)
      on_exit(fn -> Application.delete_env(:zonely, :http_fake_scenario) end)

      {:play_audio, %{url: url}} = PronunceName.play("Bob", "en-US")
      assert String.starts_with?(url, "http")
    end

    test "falls back to browser TTS when Polly fails" do
      System.put_env("NS_API_KEY", "test")
      System.put_env("FORVO_API_KEY", "forvo")
      Application.put_env(:zonely, :http_fake_scenario, :all_fail)
      Application.put_env(:zonely, :aws_request_fun, fn _req -> {:error, :network_fail} end)
      on_exit(fn -> Application.delete_env(:zonely, :http_fake_scenario) end)
      on_exit(fn -> Application.delete_env(:zonely, :aws_request_fun) end)

      assert {:play_tts, %{text: "Charlie Unique", lang: "en-US"}} =
               PronunceName.play("Charlie Unique", "en-US")
    end
  end
end

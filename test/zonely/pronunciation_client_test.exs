defmodule Zonely.PronunciationClientTest do
  use ExUnit.Case, async: false

  alias Zonely.PronunciationClient

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

  test "production_base_url/0 is fixed to production" do
    assert PronunciationClient.production_base_url() == "https://saymyname.qingbo.us"
  end

  test "normalizes real voice responses" do
    Application.put_env(:zonely, :pronunciation_request_fun, fn opts ->
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/pronounce"
      assert opts[:params] == [name: "Alice", lang: "en-US"]

      {:ok,
       %{
         status: 200,
         body: %{
           "kind" => "real_voice",
           "provider" => "production_api",
           "audio_url" => "https://cdn.example.com/alice.mp3"
         }
       }}
    end)

    assert {:ok, {:play_audio, %{url: "https://cdn.example.com/alice.mp3"}}} =
             PronunciationClient.pronounce("Alice", "en-US")
  end

  test "normalizes sequence responses" do
    Application.put_env(:zonely, :pronunciation_request_fun, fn _opts ->
      {:ok,
       %{
         status: 200,
         body: %{
           "provider" => "production_api",
           "audio_urls" => ["https://cdn.example.com/a.mp3", "https://cdn.example.com/b.mp3"]
         }
       }}
    end)

    assert {:ok,
            {:play_sequence,
             %{urls: ["https://cdn.example.com/a.mp3", "https://cdn.example.com/b.mp3"]}}} =
             PronunciationClient.pronounce("Alice Smith", "en-US")
  end

  test "rejects missing name before making a request" do
    Application.put_env(:zonely, :pronunciation_request_fun, fn _opts ->
      flunk("request should not be made")
    end)

    assert {:error, :missing_name} = PronunciationClient.pronounce(" ", "en-US")
  end
end

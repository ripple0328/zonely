defmodule Zonely.StorageTest do
  use ExUnit.Case, async: true

  alias Zonely.Storage

  setup do
    # Force local backend for these tests
    Application.put_env(:zonely, :audio_cache, backend: "local")
    dir = Zonely.AudioCache.dir()

    on_exit(fn ->
      for f <- File.ls!(dir), do: File.rm!(Path.join(dir, f))
    end)

    :ok
  end

  test "put/2 writes to local cache dir and public_url points to /audio-cache" do
    key = "real/Test_en-US_12345.mp3"
    bin = <<"FAKE_MP3">>
    assert :ok == Storage.put(key, bin)

    # Local file should exist under AudioCache dir with basename
    dir = Zonely.AudioCache.dir()
    assert File.exists?(Path.join(dir, Path.basename(key)))

    # Public URL should be app-served path
    assert Storage.public_url(key) == "/audio-cache/" <> Path.basename(key)
  end

  test "public_url/1 formats s3 URL when backend is s3" do
    Application.put_env(:zonely, :audio_cache,
      backend: "s3",
      s3_bucket: "zonely-cache",
      public_base_url: "https://zonely-cache.s3.amazonaws.com"
    )

    key = "polly/abc123.mp3"
    assert Storage.public_url(key) == "https://zonely-cache.s3.amazonaws.com/polly/abc123.mp3"
  end
end

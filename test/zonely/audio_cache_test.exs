defmodule Zonely.AudioCacheTest do
  use ExUnit.Case

  alias Zonely.AudioCache

  @temp_dir System.tmp_dir!() |> Path.join("zonely_audio_cache_test")

  setup do
    # Set up a temporary directory for testing
    File.rm_rf(@temp_dir)
    File.mkdir_p!(@temp_dir)

    # Override the audio cache directory for tests
    original_env = Application.get_env(:zonely, :audio_cache_dir)
    Application.put_env(:zonely, :audio_cache_dir, @temp_dir)

    on_exit(fn ->
      File.rm_rf(@temp_dir)

      if original_env do
        Application.put_env(:zonely, :audio_cache_dir, original_env)
      else
        Application.delete_env(:zonely, :audio_cache_dir)
      end
    end)

    :ok
  end

  describe "dir/0" do
    test "returns configured cache directory" do
      assert AudioCache.dir() == @temp_dir
    end

    test "creates directory if it doesn't exist" do
      File.rm_rf(@temp_dir)
      refute File.exists?(@temp_dir)

      dir = AudioCache.dir()

      assert File.exists?(@temp_dir)
      assert File.dir?(@temp_dir)
      assert dir == @temp_dir
    end
  end

  describe "path_for/1" do
    test "returns valid path for simple filename" do
      path = AudioCache.path_for("test.mp3")
      assert path == Path.join(@temp_dir, "test.mp3")
    end

    test "allows letters, numbers, underscore, hyphen and dot" do
      valid_filename = "test_file-123.mp3"
      path = AudioCache.path_for(valid_filename)
      assert path == Path.join(@temp_dir, valid_filename)
    end

    test "raises ArgumentError for invalid characters" do
      invalid_filenames = [
        # path traversal attempt
        "test/../file.mp3",
        # space
        "test file.mp3",
        # special character
        "test@file.mp3",
        # slash
        "test/file.mp3",
        # backslash
        "test\\file.mp3"
      ]

      for filename <- invalid_filenames do
        assert_raise ArgumentError, "invalid filename", fn ->
          AudioCache.path_for(filename)
        end
      end
    end

    test "raises ArgumentError for empty filename" do
      assert_raise ArgumentError, "invalid filename", fn ->
        AudioCache.path_for("")
      end
    end
  end

  describe "save!/2" do
    test "saves binary data to file and returns path" do
      filename = "test_audio.mp3"
      binary_data = <<1, 2, 3, 4, 5>>

      path = AudioCache.save!(filename, binary_data)

      assert path == Path.join(@temp_dir, filename)
      assert File.exists?(path)
      assert File.read!(path) == binary_data
    end

    test "overwrites existing file" do
      filename = "existing_file.mp3"
      original_data = "original content"
      new_data = "new content"

      # Create initial file
      initial_path = AudioCache.save!(filename, original_data)
      assert File.read!(initial_path) == original_data

      # Overwrite with new content
      new_path = AudioCache.save!(filename, new_data)
      assert new_path == initial_path
      assert File.read!(new_path) == new_data
    end

    test "raises for invalid filename" do
      assert_raise ArgumentError, "invalid filename", fn ->
        AudioCache.save!("invalid/../filename.mp3", "data")
      end
    end

    test "handles various binary sizes" do
      # Empty binary
      path = AudioCache.save!("empty.mp3", "")
      assert File.read!(path) == ""

      # Large binary
      large_data = :crypto.strong_rand_bytes(10_000)
      path = AudioCache.save!("large.mp3", large_data)
      assert File.read!(path) == large_data
    end

    test "creates nested directory structure if needed" do
      # This ensures the directory exists when save! is called
      File.rm_rf(@temp_dir)
      refute File.exists?(@temp_dir)

      filename = "test.mp3"
      data = "test data"

      path = AudioCache.save!(filename, data)

      assert File.exists?(@temp_dir)
      assert File.read!(path) == data
    end
  end

  describe "integration scenarios" do
    test "typical audio caching workflow" do
      # Simulate downloading and caching audio
      filename = "user_pronunciation.ogg"
      audio_data = "fake audio binary data"

      # Save to cache
      cached_path = AudioCache.save!(filename, audio_data)

      # Verify we can read it back
      assert File.read!(cached_path) == audio_data

      # Verify path generation works consistently
      expected_path = AudioCache.path_for(filename)
      assert cached_path == expected_path
    end
  end
end

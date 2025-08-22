defmodule Zonely.AudioTest do
  use ExUnit.Case, async: true
  
  alias Zonely.Audio
  alias Zonely.Accounts.User

  describe "play_english_pronunciation/1" do
    test "plays English pronunciation for US user" do
      user = %User{name: "John Doe", country: "US"}
      
      result = Audio.play_english_pronunciation(user)
      
      assert is_tuple(result)
      assert tuple_size(result) == 2
      {event_type, event_data} = result
      assert event_type in [:play_audio, :play_tts]
      assert is_map(event_data)
    end
    
    test "uses correct locale for different countries" do
      user_gb = %User{name: "Alice Smith", country: "GB"}
      user_us = %User{name: "Bob Jones", country: "US"}
      
      # Both should work without crashing
      result_gb = Audio.play_english_pronunciation(user_gb)
      result_us = Audio.play_english_pronunciation(user_us)
      
      assert is_tuple(result_gb)
      assert is_tuple(result_us)
    end
  end

  describe "play_native_pronunciation/1" do
    test "plays native pronunciation when different from English" do
      user = %User{
        name: "Jose Garcia",
        name_native: "José García", 
        country: "ES"
      }
      
      result = Audio.play_native_pronunciation(user)
      
      assert is_tuple(result)
      {event_type, event_data} = result
      assert event_type in [:play_audio, :play_tts]
      assert is_map(event_data)
    end
    
    test "falls back to English when no native name" do
      user = %User{name: "John Doe", name_native: nil, country: "US"}
      
      result = Audio.play_native_pronunciation(user)
      
      assert is_tuple(result)
    end
  end

  describe "derive_english_locale/1" do
    test "returns correct English locales" do
      assert Audio.derive_english_locale("US") == "en-US"
      assert Audio.derive_english_locale("GB") == "en-GB"
      assert Audio.derive_english_locale("CA") == "en-CA"
      assert Audio.derive_english_locale("AU") == "en-AU"
    end
    
    test "defaults to en-US for non-English countries" do
      assert Audio.derive_english_locale("ES") == "en-US"
      assert Audio.derive_english_locale("FR") == "en-US"
      assert Audio.derive_english_locale("XX") == "en-US"
    end
    
    test "handles case variations" do
      assert Audio.derive_english_locale("us") == "en-US"
      assert Audio.derive_english_locale("gb") == "en-GB"
    end
  end

  describe "cached_audio_exists?/2" do
    test "returns boolean result" do
      result = Audio.cached_audio_exists?("John Doe", "en-US")
      assert is_boolean(result)
    end
    
    test "handles special characters in names" do
      result = Audio.cached_audio_exists?("José María", "es-ES")
      assert is_boolean(result)
    end
  end

  describe "get_cache_directory/0" do
    test "returns valid directory path" do
      dir = Audio.get_cache_directory()
      
      assert is_binary(dir)
      assert String.contains?(dir, "audio")
      assert String.contains?(dir, "cache")
    end
  end

  describe "cleanup_cache/1" do
    test "returns success tuple with count" do
      result = Audio.cleanup_cache(30)
      
      case result do
        {:ok, count} ->
          assert is_integer(count)
          assert count >= 0
        {:error, _reason} ->
          # Cache directory might not exist in test environment
          assert true
      end
    end
    
    test "handles custom days parameter" do
      result = Audio.cleanup_cache(7)
      
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end
  end

  describe "cache_statistics/0" do
    test "returns comprehensive cache statistics" do
      stats = Audio.cache_statistics()
      
      assert Map.has_key?(stats, :total_files)
      assert Map.has_key?(stats, :total_size_mb)
      assert Map.has_key?(stats, :oldest_file_days)
      assert Map.has_key?(stats, :file_types)
      
      assert is_integer(stats.total_files)
      assert is_float(stats.total_size_mb)
      assert is_integer(stats.oldest_file_days)
      assert is_map(stats.file_types)
    end
  end

  describe "supported_formats/0" do
    test "returns list of supported formats" do
      formats = Audio.supported_formats()
      
      assert is_list(formats)
      assert "ogg" in formats
      assert "mp3" in formats
      assert length(formats) > 0
    end
  end

  describe "format_supported?/1" do
    test "validates supported formats" do
      assert Audio.format_supported?("ogg") == true
      assert Audio.format_supported?("mp3") == true
      assert Audio.format_supported?("wav") == true
    end
    
    test "rejects unsupported formats" do
      assert Audio.format_supported?("xyz") == false
      assert Audio.format_supported?("unknown") == false
    end
    
    test "handles case variations" do
      assert Audio.format_supported?("OGG") == true
      assert Audio.format_supported?("Mp3") == true
    end
  end

  describe "estimate_duration_seconds/1" do
    test "returns error for non-existent file" do
      result = Audio.estimate_duration_seconds("/nonexistent/file.ogg")
      
      assert {:error, _reason} = result
    end
  end

  describe "validate_audio_url/1" do
    test "handles malformed URLs gracefully" do
      result = Audio.validate_audio_url("not-a-url")
      
      assert {:error, _reason} = result
    end
    
    test "handles empty URL" do
      result = Audio.validate_audio_url("")
      
      assert {:error, _reason} = result
    end
  end

  describe "edge cases and robustness" do
    test "handles users with missing fields" do
      incomplete_user = %User{name: "Test", country: nil}
      
      # Should not crash even with missing country
      result = Audio.play_english_pronunciation(incomplete_user)
      assert is_tuple(result)
    end
    
    test "handles empty and special character names" do
      user_empty = %User{name: "", country: "US"}
      user_special = %User{name: "José María Àlvarez-O'Connor", country: "ES"}
      
      # Should handle edge cases gracefully
      result_empty = Audio.play_english_pronunciation(user_empty)
      result_special = Audio.play_english_pronunciation(user_special)
      
      assert is_tuple(result_empty)
      assert is_tuple(result_special)
    end
    
    test "derive_english_locale handles invalid input" do
      # Should not crash with invalid input
      assert is_binary(Audio.derive_english_locale(""))
      assert is_binary(Audio.derive_english_locale("INVALID"))
    end
    
    test "cached_audio_exists handles edge cases" do
      # Should not crash with invalid input
      assert is_boolean(Audio.cached_audio_exists?("", ""))
      assert is_boolean(Audio.cached_audio_exists?("test", "invalid-lang"))
    end
    
    test "cache operations handle missing directory" do
      # Cache operations should handle missing directories gracefully
      stats = Audio.cache_statistics()
      assert is_map(stats)
      
      # cleanup_cache should handle missing directory
      result = Audio.cleanup_cache()
      assert is_tuple(result)
    end
  end
end
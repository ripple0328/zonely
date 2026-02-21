defmodule Zonely.Collections.ShareUrlTest do
  use ExUnit.Case
  alias Zonely.Collections.ShareUrl

  describe "encode_entries/1" do
    test "encodes entries to base64url format" do
      entries = [
        %{
          "name" => "John Doe",
          "entries" => [
            %{"lang" => "en-US", "text" => "John Doe"},
            %{"lang" => "zh-CN", "text" => "约翰"}
          ]
        }
      ]

      encoded = ShareUrl.encode_entries(entries)
      assert is_binary(encoded)
      assert String.length(encoded) > 0
      # Should not contain padding
      refute String.contains?(encoded, "=")
    end
  end

  describe "decode_entries/1" do
    test "decodes base64url back to entries" do
      original = [
        %{
          "name" => "Jane Smith",
          "entries" => [
            %{"lang" => "en-US", "text" => "Jane Smith"}
          ]
        }
      ]

      encoded = ShareUrl.encode_entries(original)
      {:ok, decoded} = ShareUrl.decode_entries(encoded)

      assert decoded == original
    end

    test "returns error for invalid base64" do
      {:error, _reason} = ShareUrl.decode_entries("!!!invalid!!!")
    end
  end

  describe "generate_url/1" do
    test "generates a full share URL" do
      entries = [
        %{
          "name" => "Test Name",
          "entries" => [%{"lang" => "en-US", "text" => "Test"}]
        }
      ]

      url = ShareUrl.generate_url(entries)
      assert String.starts_with?(url, "https://saymyname.qingbo.us?s=")
    end

    test "generates URL with custom base" do
      entries = [
        %{
          "name" => "Test",
          "entries" => [%{"lang" => "en-US", "text" => "Test"}]
        }
      ]

      url = ShareUrl.generate_url(entries, "http://localhost:4000")
      assert String.starts_with?(url, "http://localhost:4000?s=")
    end
  end

  describe "extract_from_url/1" do
    test "extracts entries from a share URL" do
      original = [
        %{
          "name" => "Ming Wang",
          "entries" => [
            %{"lang" => "en-US", "text" => "Ming"},
            %{"lang" => "zh-CN", "text" => "王明"}
          ]
        }
      ]

      url = ShareUrl.generate_url(original)
      {:ok, extracted} = ShareUrl.extract_from_url(url)

      assert extracted == original
    end

    test "returns error for URL without s parameter" do
      {:error, _reason} = ShareUrl.extract_from_url("https://saymyname.qingbo.us")
    end
  end

  describe "validate_entries/1" do
    test "validates correct entry structure" do
      entries = [
        %{
          "name" => "Valid Name",
          "entries" => [
            %{"lang" => "en-US", "text" => "Valid"}
          ]
        }
      ]

      assert ShareUrl.validate_entries(entries) == true
    end

    test "rejects entries without name" do
      entries = [
        %{
          "entries" => [%{"lang" => "en-US", "text" => "Test"}]
        }
      ]

      assert ShareUrl.validate_entries(entries) == false
    end

    test "rejects entries without lang" do
      entries = [
        %{
          "name" => "Test",
          "entries" => [%{"text" => "Test"}]
        }
      ]

      assert ShareUrl.validate_entries(entries) == false
    end
  end
end

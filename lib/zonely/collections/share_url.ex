defmodule Zonely.Collections.ShareUrl do
  @moduledoc """
  Handles encoding and decoding of collection share URLs.
  Uses the same format as iOS deep links for compatibility.
  """

  @doc """
  Encodes collection entries to a shareable URL parameter.
  Format: base64url-encoded JSON array of entries
  """
  def encode_entries(entries) when is_list(entries) do
    entries
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Decodes a share URL parameter back to entries.
  Returns {:ok, entries} or {:error, reason}
  """
  def decode_entries(encoded) when is_binary(encoded) do
    with {:ok, json} <- Base.url_decode64(encoded, padding: false),
         {:ok, entries} <- Jason.decode(json) do
      {:ok, entries}
    else
      :error -> {:error, "Invalid base64 encoding"}
      {:error, reason} -> {:error, "Invalid JSON: #{reason}"}
    end
  end

  @doc """
  Generates a full share URL for a collection.
  """
  def generate_url(entries, base_url \\ "https://saymyname.qingbo.us") do
    encoded = encode_entries(entries)
    "#{base_url}?s=#{encoded}"
  end

  @doc """
  Extracts entries from a share URL.
  """
  def extract_from_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{query: query} when is_binary(query) ->
        query
        |> URI.decode_query()
        |> Map.get("s")
        |> case do
          nil -> {:error, "No 's' parameter in URL"}
          encoded -> decode_entries(encoded)
        end

      _ ->
        {:error, "Invalid URL format"}
    end
  end

  @doc """
  Validates that entries have the correct structure.
  """
  def validate_entries(entries) when is_list(entries) do
    Enum.all?(entries, &valid_entry?/1)
  end

  def validate_entries(_), do: false

  defp valid_entry?(entry) when is_map(entry) do
    Map.has_key?(entry, "name") and Map.has_key?(entry, "entries") and
      is_list(entry["entries"]) and
      Enum.all?(entry["entries"], &valid_lang_item?/1)
  end

  defp valid_entry?(_), do: false

  defp valid_lang_item?(item) when is_map(item) do
    Map.has_key?(item, "lang") and Map.has_key?(item, "text") and
      is_binary(item["lang"]) and is_binary(item["text"])
  end

  defp valid_lang_item?(_), do: false
end


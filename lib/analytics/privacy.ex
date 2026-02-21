defmodule SayMyName.Analytics.Privacy do
  @moduledoc """
  Privacy-focused helper functions for analytics data.

  These functions ensure that no PII (Personally Identifiable Information) is stored
  in the analytics system by hashing or anonymizing sensitive data.
  """

  @doc """
  Hash user agent to prevent fingerprinting while allowing bot detection.

  ## Examples

      iex> SayMyName.Analytics.Privacy.hash_user_agent("Mozilla/5.0...")
      "7a3f8c4e1b9d2a5f"
  """
  @spec hash_user_agent(String.t()) :: String.t()
  def hash_user_agent(ua) when is_binary(ua) do
    :crypto.hash(:sha256, ua)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  def hash_user_agent(nil), do: nil
  def hash_user_agent(_), do: nil

  @doc """
  Extract domain from referrer URL, discard path/query.

  This ensures we only track the referring domain, not specific pages
  which might contain sensitive query parameters.

  ## Examples

      iex> SayMyName.Analytics.Privacy.extract_referrer_domain("https://example.com/path?query=secret")
      "example.com"
      
      iex> SayMyName.Analytics.Privacy.extract_referrer_domain("invalid")
      nil
  """
  @spec extract_referrer_domain(String.t() | nil) :: String.t() | nil
  def extract_referrer_domain(referrer) when is_binary(referrer) do
    case URI.parse(referrer) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  def extract_referrer_domain(nil), do: nil

  @doc """
  Hash name for analytics, irreversible.

  Names are normalized (lowercased, trimmed) before hashing to ensure
  the same name always produces the same hash.

  ## Examples

      iex> SayMyName.Analytics.Privacy.hash_name("John")
      "61409aa1fd47d4a5"
      
      iex> SayMyName.Analytics.Privacy.hash_name("  John  ")
      "61409aa1fd47d4a5"
  """
  @spec hash_name(String.t()) :: String.t()
  def hash_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  @doc """
  Build sanitized user context from request data.

  ## Examples

      iex> SayMyName.Analytics.Privacy.build_user_context(%{
      ...>   user_agent: "Mozilla/5.0...",
      ...>   country: "US",
      ...>   referrer: "https://google.com/search?q=test",
      ...>   viewport_width: 1920,
      ...>   viewport_height: 1080
      ...> })
      %{
        user_agent: "7a3f8c4e1b9d2a5f",
        country: "US",
        referrer: "google.com",
        viewport_width: 1920,
        viewport_height: 1080
      }
  """
  @spec build_user_context(map()) :: map()
  def build_user_context(attrs) when is_map(attrs) do
    %{}
    |> put_if_present(:user_agent, hash_user_agent(attrs[:user_agent] || attrs["user_agent"]))
    |> put_if_present(:country, attrs[:country] || attrs["country"])
    |> put_if_present(:referrer, extract_referrer_domain(attrs[:referrer] || attrs["referrer"]))
    |> put_if_present(:viewport_width, attrs[:viewport_width] || attrs["viewport_width"])
    |> put_if_present(:viewport_height, attrs[:viewport_height] || attrs["viewport_height"])
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end

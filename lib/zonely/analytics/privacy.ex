defmodule Zonely.Analytics.Privacy do
  @moduledoc """
  Privacy utilities for analytics.
  
  Ensures all tracking is privacy-first:
  - No PII collection
  - Name hashing (irreversible)
  - User agent hashing
  - Domain-only referrers
  """

  @doc """
  Hash user agent to prevent fingerprinting while allowing bot detection.
  
  ## Examples
  
      iex> hash_user_agent("Mozilla/5.0...")
      "a3f8b9c2e1d4f5a6"
  """
  def hash_user_agent(ua) when is_binary(ua) do
    :crypto.hash(:sha256, ua)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  def hash_user_agent(_), do: nil

  @doc """
  Extract domain from referrer URL, discard path/query.
  
  ## Examples
  
      iex> extract_referrer_domain("https://example.com/path?query=1")
      "example.com"
  """
  def extract_referrer_domain(referrer) when is_binary(referrer) do
    case URI.parse(referrer) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  def extract_referrer_domain(_), do: nil

  @doc """
  Hash name for analytics, irreversible.
  
  ## Examples
  
      iex> hash_name("John Doe")
      "7a3f8c4e1b9d2a5f"
  """
  def hash_name(name) when is_binary(name) do
    :crypto.hash(:sha256, String.downcase(String.trim(name)))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  def hash_name(_), do: nil

  @doc """
  Extract country code from Plug.Conn headers.
  Uses Cloudflare-provided country header if available.
  """
  def extract_country_code(conn) do
    # Try Cloudflare header first
    case Plug.Conn.get_req_header(conn, "cf-ipcountry") do
      [country] when country not in ["", "XX", "T1"] -> String.upcase(country)
      _ -> nil
    end
  end

  @doc """
  Build user context map from conn.
  """
  def build_user_context(conn) do
    %{
      user_agent: hash_user_agent(get_user_agent(conn)),
      country: extract_country_code(conn),
      referrer: extract_referrer_domain(get_referrer(conn)),
      viewport_width: nil,
      viewport_height: nil
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua] -> ua
      _ -> nil
    end
  end

  defp get_referrer(conn) do
    case Plug.Conn.get_req_header(conn, "referer") do
      [ref] -> ref
      _ -> nil
    end
  end
end

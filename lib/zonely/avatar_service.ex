defmodule Zonely.AvatarService do
  @moduledoc """
  Service module for generating user avatars.

  This module centralizes avatar generation logic that was previously
  duplicated across multiple LiveView modules. Uses external services
  for consistent, deterministic avatar generation.
  """

  @doc """
  Generates a profile picture URL for a given name.

  Uses DiceBear Avatars API for consistent, deterministic avatar generation.
  The same name will always generate the same avatar.

  ## Parameters
  - `name`: The user's name
  - `size`: Optional size in pixels (default: 64)
  - `style`: Optional avatar style (default: "avataaars")

  ## Examples

      iex> AvatarService.generate_avatar_url("John Doe")
      "https://api.dicebear.com/7.x/avataaars/svg?seed=john-doe&backgroundColor=b6e3f4,c0aede,d1d4f9&size=64"

      iex> AvatarService.generate_avatar_url("María García", 32)
      "https://api.dicebear.com/7.x/avataaars/svg?seed=maria-garcia&backgroundColor=b6e3f4,c0aede,d1d4f9&size=32"
  """
  @spec generate_avatar_url(String.t(), integer(), String.t()) :: String.t()
  def generate_avatar_url(name, size \\ 64, style \\ "avataaars") do
    seed = normalize_name_for_seed(name)
    background_colors = "b6e3f4,c0aede,d1d4f9"

    "https://api.dicebear.com/7.x/#{style}/svg?seed=#{seed}&backgroundColor=#{background_colors}&size=#{size}"
  end

  @doc """
  Generates a fallback avatar with initials.

  Creates a CSS class-based avatar with the user's initials for cases
  where external avatar services fail or are unavailable.

  ## Parameters
  - `name`: The user's name
  - `class`: Optional CSS class for styling

  ## Examples

      iex> AvatarService.generate_initials_avatar("John Doe")
      %{initials: "JD", class: "bg-gradient-to-br from-blue-500 to-purple-600"}

      iex> AvatarService.generate_initials_avatar("María")
      %{initials: "M", class: "bg-gradient-to-br from-blue-500 to-purple-600"}
  """
  @spec generate_initials_avatar(String.t(), String.t()) :: %{initials: String.t(), class: String.t()}
  def generate_initials_avatar(name, class \\ "bg-gradient-to-br from-blue-500 to-purple-600") do
    initials = extract_initials(name)
    %{initials: initials, class: class}
  end

  @doc """
  Generates both avatar URL and fallback initials.

  Returns a complete avatar configuration that can be used in templates
  with proper fallback handling.

  ## Examples

      iex> AvatarService.generate_complete_avatar("John Doe", 32)
      %{
        url: "https://api.dicebear.com/7.x/avataaars/svg?seed=john-doe&backgroundColor=b6e3f4,c0aede,d1d4f9&size=32",
        fallback: %{initials: "JD", class: "bg-gradient-to-br from-blue-500 to-purple-600"}
      }
  """
  @spec generate_complete_avatar(String.t(), integer()) :: %{url: String.t(), fallback: map()}
  def generate_complete_avatar(name, size \\ 64) do
    %{
      url: generate_avatar_url(name, size),
      fallback: generate_initials_avatar(name)
    }
  end

  @doc """
  Generates different avatar styles for variety.

  Returns a list of different avatar URLs using various DiceBear styles
  to provide options or variety in avatar generation.
  """
  @spec generate_avatar_variants(String.t(), integer()) :: [%{style: String.t(), url: String.t()}]
  def generate_avatar_variants(name, size \\ 64) do
    styles = ["avataaars", "big-smile", "bottts", "croodles", "fun-emoji"]

    Enum.map(styles, fn style ->
      %{
        style: style,
        url: generate_avatar_url(name, size, style)
      }
    end)
  end

  # Private functions

  @spec normalize_name_for_seed(String.t()) :: String.t()
  defp normalize_name_for_seed(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")  # Remove special characters
    |> String.replace(" ", "-")
  end

  @spec extract_initials(String.t()) :: String.t()
  defp extract_initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.take(2)  # Maximum 2 initials
    |> Enum.join()
    |> String.upcase()
  end
end

defmodule Zonely.NameShoutsParser do
  @moduledoc """
  Handles parsing and analysis of NameShouts API responses.

  This module extracts the complex logic for analyzing NameShouts responses
  and selecting appropriate pronunciation variants from the main PronunceName module.
  """

  require Logger

  @doc """
  Analyzes a NameShouts API response and selects the best pronunciation variant.

  ## Parameters
  - `response_body`: Decoded JSON response from NameShouts API
  - `name`: The original name being requested
  - `language`: The target language code

  ## Returns
  - `{:ok, String.t()}` - Path to single pronunciation
  - `{:ok, [String.t()]}` - List of paths for chained pronunciation
  - `{:error, atom()}` - Error reason
  """
  @spec pick_variant(map(), String.t(), String.t()) ::
          {:ok, String.t()} | {:ok, [String.t()]} | {:error, atom()}
  def pick_variant(%{"status" => _status, "message" => message}, name, language)
      when is_map(message) do
    target_lang_name = language_display_name(language) |> String.downcase()

    Logger.info("🔍 Analyzing NameShouts response for requested name: '#{name}'")
    Logger.info("🔍 Available keys in NameShouts response: #{inspect(Map.keys(message))}")
    Logger.info("🔍 Target language: '#{target_lang_name}'")

    # Check if response is organized by language (like {"english" => [...]})
    case Map.get(message, target_lang_name) do
      variants when is_list(variants) ->
        Logger.info("🔍 Found language-based variants: #{inspect(variants)}")
        analyze_language_variants(variants, name, target_lang_name)

      _ ->
        # Fallback to original name-based lookup
        Logger.info("🔍 No language-based variants, trying name-based lookup")
        try_name_based_lookup(message, name, target_lang_name)
    end
  end

  def pick_variant(_body, _name, _language), do: {:error, :unexpected_format}

  # Analyze variants from language-based response structure
  defp analyze_language_variants(variants, name, _target_lang_name) do
    Logger.info("🔍 Analyzing #{length(variants)} variants for name '#{name}'")

    # Look for multiple parts that might need chaining
    name_parts = String.split(name, " ", trim: true) |> Enum.map(&String.downcase/1)
    Logger.info("🔍 Name parts: #{inspect(name_parts)}")

    # Group variants by what parts of the name they might represent
    part_matches =
      Enum.map(variants, fn variant ->
        path = variant["path"] || ""
        clean_path = String.downcase(path) |> String.replace(~r/_[a-z]{2}$/, "")

        matching_parts =
          Enum.filter(name_parts, fn part ->
            String.contains?(clean_path, part)
          end)

        Logger.info("🔍 Path '#{path}' matches parts: #{inspect(matching_parts)}")
        {variant, matching_parts, path}
      end)

    # Check if we have variants that cover all parts of the name
    all_covered_parts =
      part_matches
      |> Enum.flat_map(fn {_, parts, _} -> parts end)
      |> Enum.uniq()

    cond do
      # If we have variants covering all parts, return them for chaining
      length(all_covered_parts) == length(name_parts) and length(name_parts) > 1 ->
        paths = part_matches |> Enum.map(fn {_, _, path} -> path end) |> Enum.filter(&(&1 != ""))
        Logger.info("✅ Found multi-part pronunciation - paths for chaining: #{inspect(paths)}")
        {:ok, paths}

      # Otherwise, look for the best single match
      true ->
        find_best_single_match(part_matches, name)
    end
  end

  defp find_best_single_match(part_matches, name) do
    best_match =
      Enum.find(part_matches, fn {_, matching_parts, path} ->
        path != "" and
          (length(matching_parts) > 0 or
             String.contains?(String.downcase(path), String.downcase(name)))
      end)

    case best_match do
      {_, _, path} when path != "" ->
        Logger.info("✅ Found single best match: #{path}")
        {:ok, path}

      _ ->
        # Fallback to first valid path
        case Enum.find_value(part_matches, fn {variant, _, _} -> variant["path"] end) do
          path when is_binary(path) ->
            Logger.info("🔄 Using fallback path: #{path}")
            {:ok, path}

          _ ->
            {:error, :no_path}
        end
    end
  end

  # Fallback to original name-based lookup
  defp try_name_based_lookup(message, name, target_lang_name) do
    Logger.info(
      "🔍 Trying name-based lookup for '#{name}' in message keys: #{inspect(Map.keys(message))}"
    )

    # Check if message contains multiple name parts (like %{"John" => ..., "Doe" => ...})
    name_parts = String.split(name, [" ", "-"], trim: true)
    Logger.info("🔍 Name parts to look for: #{inspect(name_parts)}")

    # Find all matching parts in the response (handling URL encoding)
    matching_parts =
      name_parts
      |> Enum.map(fn part ->
        # Check both original and URL-encoded versions
        key =
          cond do
            Map.has_key?(message, part) -> part
            Map.has_key?(message, URI.encode(part)) -> URI.encode(part)
            true -> nil
          end

        if key do
          case Map.get(message, key) do
            %{"path" => path} when is_binary(path) -> {part, path}
            _ -> nil
          end
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    Logger.info("🔍 Found matching parts: #{inspect(matching_parts)}")

    cond do
      # If we found multiple parts, return them for chaining
      length(matching_parts) > 1 ->
        paths = Enum.map(matching_parts, fn {_part, path} -> path end)
        Logger.info("✅ Found multiple name parts for chaining: #{inspect(paths)}")
        {:ok, paths}

      # If we found exactly one part, return it
      length(matching_parts) == 1 ->
        {_part, path} = List.first(matching_parts)
        Logger.info("✅ Found single name part: #{path}")
        {:ok, path}

      # Otherwise, try the original fallback logic
      true ->
        Logger.info("🔍 No direct name part matches, trying original candidates")
        try_original_candidates(message, name, target_lang_name)
    end
  end

  # Original candidate matching logic as fallback
  defp try_original_candidates(message, name, target_lang_name) do
    candidates = [
      String.downcase(name) |> String.replace(~r/\s+/, "-"),
      String.downcase(name),
      URI.encode(name),
      URI.encode(String.downcase(name))
    ]

    variants = Enum.find_value(candidates, fn k -> Map.get(message, k) end)

    cond do
      is_list(variants) ->
        select_variant_from_list(variants, target_lang_name)

      is_map(variants) ->
        select_variant_from_map(variants)

      true ->
        # Scan all message values to find any variant with a path
        message
        |> Map.values()
        |> Enum.find_value(fn v ->
          cond do
            is_list(v) ->
              case select_variant_from_list(v, target_lang_name) do
                {:ok, path} -> path
                _ -> nil
              end

            is_map(v) ->
              case select_variant_from_map(v) do
                {:ok, path} -> path
                _ -> nil
              end

            true ->
              nil
          end
        end)
        |> case do
          nil -> {:error, :not_found}
          path when is_binary(path) -> {:ok, path}
        end
    end
  end

  defp select_variant_from_list(list, target_lang_name) when is_list(list) do
    preferred =
      Enum.find(list, fn v ->
        String.downcase(v["lang_name"] || "") == String.downcase(target_lang_name)
      end)

    chosen = preferred || List.first(list)

    case chosen do
      %{"path" => path} when is_binary(path) -> {:ok, path}
      _ -> {:error, :no_path}
    end
  end

  defp select_variant_from_map(map) when is_map(map) do
    case map do
      %{"path" => path} when is_binary(path) -> {:ok, path}
      _ -> {:error, :no_path}
    end
  end

  @doc """
  Converts a BCP47 language code to display name for NameShouts API.
  """
  @spec language_display_name(String.t()) :: String.t()
  def language_display_name(bcp47) do
    prefix = bcp47 |> String.split("-") |> List.first()

    case prefix do
      "en" -> "English"
      "es" -> "Spanish"
      "fr" -> "French"
      "de" -> "German"
      "it" -> "Italian"
      "pt" -> "Portuguese"
      "ja" -> "Japanese"
      "zh" -> "Chinese"
      "ko" -> "Korean"
      "hi" -> "Hindi"
      "ar" -> "Arabic"
      "sv" -> "Swedish"
      _ -> "English"
    end
  end
end

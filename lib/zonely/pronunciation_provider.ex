defprotocol Zonely.PronunciationProvider do
  @moduledoc """
  Protocol for pronunciation providers that can fetch audio for names.

  This protocol standardizes the interface for different pronunciation services
  like Forvo, NameShouts, and Polly, making it easier to add new providers
  and test the pronunciation system.
  """

  @doc """
  Fetches pronunciation audio for a name in the given language.

  ## Parameters
  - `provider`: The provider implementation
  - `name`: The name to get pronunciation for
  - `language`: Language code (e.g., "en-US", "es-ES")
  - `original_name`: The original full name (for context)

  ## Returns
  - `{:ok, url}` - URL to the audio file
  - `{:error, reason}` - Error with reason atom
  """
  @spec fetch_pronunciation(t(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, atom()}
  def fetch_pronunciation(provider, name, language, original_name)
end

defimpl Zonely.PronunciationProvider, for: Atom do
  alias Zonely.PronunceName.Providers

  def fetch_pronunciation(:forvo, name, language, original_name) do
    Providers.Forvo.fetch_single(name, language, original_name)
  end

  def fetch_pronunciation(:name_shouts, name, language, original_name) do
    Providers.NameShouts.fetch_single(name, language, original_name)
  end

  def fetch_pronunciation(:polly, name, language, _original_name) do
    Providers.Polly.synthesize(name, language)
  end

  def fetch_pronunciation(provider, _name, _language, _original_name) do
    {:error, {:unknown_provider, provider}}
  end
end

defmodule Zonely.PronunciationProviders do
  @moduledoc """
  Utility functions for working with pronunciation providers.
  """

  alias Zonely.PronunciationProvider

  @providers [:forvo, :name_shouts, :polly]

  @doc """
  Returns the list of available pronunciation providers in priority order.
  """
  def available_providers, do: @providers

  @doc """
  Tries to fetch pronunciation from providers in order until one succeeds.

  ## Parameters
  - `name`: The name to get pronunciation for
  - `language`: Language code (e.g., "en-US", "es-ES") 
  - `original_name`: The original full name (for context)
  - `providers`: List of providers to try (defaults to all available)

  ## Returns
  - `{:ok, url}` - URL to the audio file from the first successful provider
  - `{:error, :all_failed}` - All providers failed
  """
  @spec try_providers(String.t(), String.t(), String.t(), [atom()]) ::
          {:ok, String.t()} | {:error, atom()}
  def try_providers(name, language, original_name, providers \\ @providers) do
    try_providers_recursive(providers, name, language, original_name)
  end

  defp try_providers_recursive([], _name, _language, _original_name) do
    {:error, :all_failed}
  end

  defp try_providers_recursive([provider | rest], name, language, original_name) do
    case PronunciationProvider.fetch_pronunciation(provider, name, language, original_name) do
      {:ok, url} -> {:ok, url}
      {:error, _reason} -> try_providers_recursive(rest, name, language, original_name)
    end
  end

  @doc """
  Checks if a provider is available/configured.
  """
  @spec provider_available?(atom()) :: boolean()
  def provider_available?(:forvo) do
    not is_nil(System.get_env("FORVO_API_KEY"))
  end

  def provider_available?(:name_shouts) do
    not is_nil(System.get_env("NAME_SHOUTS_API_KEY"))
  end

  def provider_available?(:polly) do
    # Polly availability depends on AWS configuration
    aws_config = Application.get_env(:ex_aws, :s3, [])
    not is_nil(aws_config[:region])
  end

  def provider_available?(_), do: false

  @doc """
  Returns only the providers that are currently available/configured.
  """
  @spec available_configured_providers() :: [atom()]
  def available_configured_providers do
    Enum.filter(@providers, &provider_available?/1)
  end
end

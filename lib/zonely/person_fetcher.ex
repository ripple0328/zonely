defmodule Zonely.PersonFetcher do
  @moduledoc """
  Utility module for fetching people with caching and error handling.

  This module provides helpers to reduce repetitive `Accounts.get_person!` calls
  across LiveView modules and provides consistent error handling.
  """

  alias Zonely.Accounts
  alias Zonely.Accounts.Person

  @doc """
  Fetches a person by ID with error handling.

  Unlike `Accounts.get_person!`, this returns {:ok, person} or {:error, reason}
  instead of raising an exception.

  ## Examples

      iex> PersonFetcher.fetch_person("123")
      {:ok, %Person{id: "123", name: "John Doe"}}
      
      iex> PersonFetcher.fetch_person("nonexistent") 
      {:error, :not_found}
  """
  @spec fetch_person(String.t() | integer()) :: {:ok, Person.t()} | {:error, :not_found}
  def fetch_person(person_id) when is_binary(person_id) or is_integer(person_id) do
    try do
      person = Accounts.get_person!(person_id)
      {:ok, person}
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  @doc """
  Fetches a person by ID, raising on error (equivalent to get_person!).

  This is a convenience function that maintains the same behavior as 
  `Accounts.get_person!` but can be mocked/stubbed more easily in tests.
  """
  @spec fetch_person!(String.t() | integer()) :: Person.t()
  def fetch_person!(person_id) do
    Accounts.get_person!(person_id)
  end

  @doc """
  Fetches multiple people by their IDs.

  Returns a map with person IDs as keys and people as values.
  Missing people are omitted from the result.

  ## Examples

      iex> PersonFetcher.fetch_people(["1", "2", "999"])
      %{
        "1" => %Person{id: "1", name: "Alice"},
        "2" => %Person{id: "2", name: "Bob"}
      }
  """
  @spec fetch_people([String.t() | integer()]) :: %{String.t() => Person.t()}
  def fetch_people(person_ids) when is_list(person_ids) do
    person_ids
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn person_id, acc ->
      case fetch_person(person_id) do
        {:ok, person} -> Map.put(acc, to_string(person_id), person)
        {:error, :not_found} -> acc
      end
    end)
  end

  @doc """
  Validates that a person exists and is accessible.

  Useful for validating person IDs from client input before processing.
  """
  @spec valid_person_id?(String.t() | integer()) :: boolean()
  def valid_person_id?(person_id) do
    case fetch_person(person_id) do
      {:ok, _person} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Fetches a person with a default fallback.

  Returns the person if found, otherwise returns the default person.
  Useful for handling optional person selections in UI.
  """
  @spec fetch_person_with_default(String.t() | integer() | nil, Person.t()) :: Person.t()
  def fetch_person_with_default(nil, default_person), do: default_person

  def fetch_person_with_default(person_id, default_person) do
    case fetch_person(person_id) do
      {:ok, person} -> person
      {:error, :not_found} -> default_person
    end
  end

  @doc """
  Caches person data in the socket assigns for repeated access.

  This is useful in LiveView when you need to access the same person
  multiple times during event handling.
  """
  @spec cache_person_in_socket(Phoenix.LiveView.Socket.t(), String.t() | integer(), atom()) ::
          Phoenix.LiveView.Socket.t()
  def cache_person_in_socket(socket, person_id, assign_key \\ :cached_person) do
    case fetch_person(person_id) do
      {:ok, person} ->
        Phoenix.Component.assign(socket, assign_key, person)

      {:error, :not_found} ->
        socket
    end
  end

  @doc """
  Gets cached person from socket or fetches and caches it.

  Combines caching with fetching for efficient person access patterns.
  """
  @spec get_or_cache_person(Phoenix.LiveView.Socket.t(), String.t() | integer(), atom()) ::
          {Phoenix.LiveView.Socket.t(), Person.t() | nil}
  def get_or_cache_person(socket, person_id, assign_key \\ :cached_person) do
    case socket.assigns[assign_key] do
      %Person{id: ^person_id} = person ->
        {socket, person}

      _ ->
        case fetch_person(person_id) do
          {:ok, person} ->
            updated_socket = Phoenix.Component.assign(socket, assign_key, person)
            {updated_socket, person}

          {:error, :not_found} ->
            {socket, nil}
        end
    end
  end
end

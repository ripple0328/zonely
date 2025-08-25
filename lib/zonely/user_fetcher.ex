defmodule Zonely.UserFetcher do
  @moduledoc """
  Utility module for fetching users with caching and error handling.

  This module provides helpers to reduce repetitive `Accounts.get_user!` calls
  across LiveView modules and provides consistent error handling.
  """

  alias Zonely.Accounts
  alias Zonely.Accounts.User

  @doc """
  Fetches a user by ID with error handling.

  Unlike `Accounts.get_user!`, this returns {:ok, user} or {:error, reason}
  instead of raising an exception.

  ## Examples

      iex> UserFetcher.fetch_user("123")
      {:ok, %User{id: "123", name: "John Doe"}}
      
      iex> UserFetcher.fetch_user("nonexistent") 
      {:error, :not_found}
  """
  @spec fetch_user(String.t() | integer()) :: {:ok, User.t()} | {:error, :not_found}
  def fetch_user(user_id) when is_binary(user_id) or is_integer(user_id) do
    try do
      user = Accounts.get_user!(user_id)
      {:ok, user}
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  @doc """
  Fetches a user by ID, raising on error (equivalent to get_user!).

  This is a convenience function that maintains the same behavior as 
  `Accounts.get_user!` but can be mocked/stubbed more easily in tests.
  """
  @spec fetch_user!(String.t() | integer()) :: User.t()
  def fetch_user!(user_id) do
    Accounts.get_user!(user_id)
  end

  @doc """
  Fetches multiple users by their IDs.

  Returns a map with user IDs as keys and users as values.
  Missing users are omitted from the result.

  ## Examples

      iex> UserFetcher.fetch_users(["1", "2", "999"])
      %{
        "1" => %User{id: "1", name: "Alice"},
        "2" => %User{id: "2", name: "Bob"}
      }
  """
  @spec fetch_users([String.t() | integer()]) :: %{String.t() => User.t()}
  def fetch_users(user_ids) when is_list(user_ids) do
    user_ids
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn user_id, acc ->
      case fetch_user(user_id) do
        {:ok, user} -> Map.put(acc, to_string(user_id), user)
        {:error, :not_found} -> acc
      end
    end)
  end

  @doc """
  Validates that a user exists and is accessible.

  Useful for validating user IDs from client input before processing.
  """
  @spec valid_user_id?(String.t() | integer()) :: boolean()
  def valid_user_id?(user_id) do
    case fetch_user(user_id) do
      {:ok, _user} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Fetches a user with a default fallback.

  Returns the user if found, otherwise returns the default user.
  Useful for handling optional user selections in UI.
  """
  @spec fetch_user_with_default(String.t() | integer() | nil, User.t()) :: User.t()
  def fetch_user_with_default(nil, default_user), do: default_user

  def fetch_user_with_default(user_id, default_user) do
    case fetch_user(user_id) do
      {:ok, user} -> user
      {:error, :not_found} -> default_user
    end
  end

  @doc """
  Caches user data in the socket assigns for repeated access.

  This is useful in LiveView when you need to access the same user
  multiple times during event handling.
  """
  @spec cache_user_in_socket(Phoenix.LiveView.Socket.t(), String.t() | integer(), atom()) ::
          Phoenix.LiveView.Socket.t()
  def cache_user_in_socket(socket, user_id, assign_key \\ :cached_user) do
    case fetch_user(user_id) do
      {:ok, user} ->
        Phoenix.Component.assign(socket, assign_key, user)

      {:error, :not_found} ->
        socket
    end
  end

  @doc """
  Gets cached user from socket or fetches and caches it.

  Combines caching with fetching for efficient user access patterns.
  """
  @spec get_or_cache_user(Phoenix.LiveView.Socket.t(), String.t() | integer(), atom()) ::
          {Phoenix.LiveView.Socket.t(), User.t() | nil}
  def get_or_cache_user(socket, user_id, assign_key \\ :cached_user) do
    case socket.assigns[assign_key] do
      %User{id: ^user_id} = user ->
        {socket, user}

      _ ->
        case fetch_user(user_id) do
          {:ok, user} ->
            updated_socket = Phoenix.Component.assign(socket, assign_key, user)
            {updated_socket, user}

          {:error, :not_found} ->
            {socket, nil}
        end
    end
  end
end

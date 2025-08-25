defmodule ZonelyWeb.LiveViewHelpers do
  @moduledoc """
  Common patterns and utilities shared across LiveView modules.

  This module provides reusable functions for common LiveView operations
  like user profile handling, audio events, and error handling.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  alias Zonely.{Accounts, UserFetcher}

  @doc """
  Common mount setup for LiveViews that need user data.

  Returns the socket with users assigned and common initialization.
  """
  def mount_with_users(socket, additional_assigns \\ %{}) do
    users = Accounts.list_users()

    default_assigns = %{
      users: users,
      selected_user: nil,
      loading_states: %{},
      error_message: nil
    }

    assigns = Map.merge(default_assigns, additional_assigns)

    Enum.reduce(assigns, socket, fn {key, value}, acc_socket ->
      assign(acc_socket, key, value)
    end)
  end

  @doc """
  Handles show_profile event common to many LiveViews.
  """
  def handle_show_profile(socket, %{"user_id" => user_id}) do
    case UserFetcher.fetch_user(user_id) do
      {:ok, user} ->
        {:noreply, assign(socket, selected_user: user)}

      {:error, :not_found} ->
        {:noreply, assign(socket, error_message: "User not found")}
    end
  end

  @doc """
  Handles hide_profile event common to many LiveViews.
  """
  def handle_hide_profile(socket, _params) do
    {:noreply, assign(socket, selected_user: nil)}
  end

  @doc """
  Common pronunciation event handler setup.

  Sets loading state and sends async message for processing.
  """
  def handle_pronunciation_event(socket, event_type, %{"user_id" => user_id}) do
    case UserFetcher.fetch_user(user_id) do
      {:ok, user} ->
        # Set loading state
        loading_key = "#{user_id}_#{event_type}"
        updated_loading = Map.put(socket.assigns.loading_states, loading_key, true)

        socket = assign(socket, loading_states: updated_loading)

        # Send async message to self
        send(self(), {:process_pronunciation, event_type, user})
        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, assign(socket, error_message: "User not found")}
    end
  end

  @doc """
  Clears loading state for a pronunciation event.
  """
  def clear_pronunciation_loading(socket, user_id, event_type) do
    loading_key = "#{user_id}_#{event_type}"
    updated_loading = Map.delete(socket.assigns.loading_states, loading_key)
    assign(socket, loading_states: updated_loading)
  end

  @doc """
  Common error handling for pronunciation processing.
  """
  def handle_pronunciation_error(socket, user_id, event_type, error) do
    socket
    |> clear_pronunciation_loading(user_id, event_type)
    |> assign(error_message: "Failed to load pronunciation: #{inspect(error)}")
  end

  @doc """
  Common success handling for pronunciation processing.
  """
  def handle_pronunciation_success(socket, user_id, event_type, event_name, event_data) do
    socket = clear_pronunciation_loading(socket, user_id, event_type)

    # Push the audio event to the client
    case Phoenix.LiveView.push_event(socket, event_name, event_data) do
      {:ok, socket} -> socket
      _error -> assign(socket, error_message: "Failed to play audio")
    end
  end

  @doc """
  Validates user_id parameter and returns user or error.
  """
  def validate_user_param(%{"user_id" => user_id}) do
    UserFetcher.fetch_user(user_id)
  end

  def validate_user_param(_params) do
    {:error, :missing_user_id}
  end

  @doc """
  Common pattern for handling user-specific events.

  Takes a socket, params with user_id, and a callback function.
  Validates the user and calls the callback with the user if valid.
  """
  def with_valid_user(socket, params, callback) when is_function(callback, 2) do
    case validate_user_param(params) do
      {:ok, user} ->
        callback.(socket, user)

      {:error, :not_found} ->
        {:noreply, assign(socket, error_message: "User not found")}

      {:error, :missing_user_id} ->
        {:noreply, assign(socket, error_message: "Missing user ID")}
    end
  end

  @doc """
  Clears error messages from the socket.
  """
  def clear_error_message(socket) do
    assign(socket, error_message: nil)
  end

  @doc """
  Common apply_action handler for profile-based LiveViews.
  """
  def apply_profile_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Directory")
    |> assign(:selected_user, nil)
  end

  def apply_profile_action(socket, action, params) when action in [:show, :profile] do
    case params do
      %{"id" => user_id} ->
        case UserFetcher.fetch_user(user_id) do
          {:ok, user} ->
            assign(socket, selected_user: user, page_title: "Profile - #{user.name}")

          {:error, :not_found} ->
            assign(socket, selected_user: nil, error_message: "User not found")
        end

      _ ->
        assign(socket, selected_user: nil)
    end
  end

  def apply_profile_action(socket, _action, _params) do
    socket
  end

  @doc """
  Helper to check if a user is currently selected.
  """
  def user_selected?(socket) do
    not is_nil(socket.assigns[:selected_user])
  end

  @doc """
  Helper to get the selected user ID if any.
  """
  def selected_user_id(socket) do
    case socket.assigns[:selected_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Common pattern for toggling UI state.
  """
  def toggle_assign(socket, assign_key, default \\ false) do
    current_value = Map.get(socket.assigns, assign_key, default)
    assign(socket, assign_key, not current_value)
  end
end

defmodule ZonelyWeb.Live.PronunciationHandlers do
  @moduledoc """
  Shared pronunciation event handlers for LiveViews.

  This module provides common functionality for handling pronunciation
  events across different LiveView modules.
  """

  alias Zonely.Accounts
  alias Zonely.Audio

  @doc """
  Handles native pronunciation events.

  This can be used in any LiveView by calling:

      def handle_event("play_native_pronunciation", params, socket) do
        PronunciationHandlers.handle_native_pronunciation(params, socket)
      end
  """
  def handle_native_pronunciation(%{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    IO.puts("🎯 NATIVE: Fetching pronunciation for #{user.name}")

    case Audio.get_native_pronunciation(user) do
      {:audio_url, url} ->
        IO.puts("🔊 AUDIO URL (Native): #{user.name} → #{url}")
        {:noreply,
         Phoenix.Socket.assign(socket, [current_audio_url: url])
         |> Phoenix.LiveView.push_event("play_audio", %{url: url})}

      {:tts, text, lang} ->
        IO.puts("🔊 TTS (Native): #{user.name} → '#{text}' (#{lang})")
        {:noreply,
         Phoenix.Socket.assign(socket, [current_tts_text: text])
         |> Phoenix.LiveView.push_event("speak_simple", %{text: text, lang: lang})}
    end
  end

  @doc """
  Handles English pronunciation events.

  This can be used in any LiveView by calling:

      def handle_event("play_english_pronunciation", params, socket) do
        PronunciationHandlers.handle_english_pronunciation(params, socket)
      end
  """
  def handle_english_pronunciation(%{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    IO.puts("🎯 ENGLISH: Fetching pronunciation for #{user.name}")

    case Audio.get_english_pronunciation(user) do
      {:audio_url, url} ->
        IO.puts("🔊 AUDIO URL (English): #{user.name} → #{url}")
        {:noreply,
         Phoenix.Socket.assign(socket, [current_audio_url: url])
         |> Phoenix.LiveView.push_event("play_audio", %{url: url})}

      {:tts, text, lang} ->
        IO.puts("🔊 TTS (English): #{user.name} → '#{text}' (#{lang})")
        {:noreply,
         Phoenix.Socket.assign(socket, [current_tts_text: text])
         |> Phoenix.LiveView.push_event("speak_simple", %{text: text, lang: lang})}
    end
  end
end

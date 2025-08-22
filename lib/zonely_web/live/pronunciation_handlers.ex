defmodule ZonelyWeb.Live.PronunciationHandlers do
  @moduledoc """
  Shared pronunciation logic for LiveViews.
  
  This module provides common functionality for handling pronunciation
  events across different LiveView modules. It returns data that the
  calling LiveView can use to update its socket and push events.
  """

  alias Zonely.Accounts
  alias Zonely.Audio

  @doc """
  Processes native pronunciation request and returns LiveView response data.
  
  Returns a tuple that can be used directly in a LiveView handle_event:
  - {:noreply, socket} with appropriate assigns and push_event calls
  """
  def handle_native_pronunciation(%{"user_id" => user_id}, _socket) do
    user = Accounts.get_user!(user_id)

    IO.puts("🎯 NATIVE: Fetching pronunciation for #{user.name}")

    case Audio.get_native_pronunciation(user) do
      {:audio_url, url} ->
        IO.puts("🔊 AUDIO URL (Native): #{user.name} → #{url}")
        {:audio_url, url}

      {:tts, text, lang} ->
        IO.puts("🔊 TTS (Native): #{user.name} → '#{text}' (#{lang})")
        {:tts, text, lang}
    end
  end

  @doc """
  Processes English pronunciation request and returns LiveView response data.
  
  Returns a tuple that can be used directly in a LiveView handle_event:
  - {:noreply, socket} with appropriate assigns and push_event calls
  """
  def handle_english_pronunciation(%{"user_id" => user_id}, _socket) do
    user = Accounts.get_user!(user_id)

    IO.puts("🎯 ENGLISH: Fetching pronunciation for #{user.name}")

    case Audio.get_english_pronunciation(user) do
      {:audio_url, url} ->
        IO.puts("🔊 AUDIO URL (English): #{user.name} → #{url}")
        {:audio_url, url}

      {:tts, text, lang} ->
        IO.puts("🔊 TTS (English): #{user.name} → '#{text}' (#{lang})")
        {:tts, text, lang}
    end
  end
end
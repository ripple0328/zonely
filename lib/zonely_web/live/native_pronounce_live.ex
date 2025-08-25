defmodule ZonelyWeb.NativePronounceLive do
  use ZonelyWeb, :live_view

  alias Zonely.PronunceName

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(names: [])
     |> assign(loading: false)}
  end

  @impl true
  def handle_event("pronounce", %{"name" => name, "lang" => lang}, socket) do
    case PronunceName.play(name, lang) do
      {:play_audio, %{url: url}} ->
        {:noreply, push_event(socket, :play_audio, %{url: url})}

      {:play_tts_audio, %{url: url}} ->
        {:noreply, push_event(socket, :play_tts_audio, %{url: url})}

      {:play_tts, %{text: text, lang: tts_lang}} ->
        {:noreply, push_event(socket, :play_tts, %{text: text, lang: tts_lang})}

      {:play_sequence, %{urls: urls}} ->
        {:noreply, push_event(socket, :play_sequence, %{urls: urls})}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <!-- LV Native iOS/Android clients will not render HTML; they listen for push_event -->
    </div>
    """
  end
end

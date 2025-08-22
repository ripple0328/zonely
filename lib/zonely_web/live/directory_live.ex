defmodule ZonelyWeb.DirectoryLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.TextToSpeech

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    {:ok, assign(socket, users: users, selected_user: nil, expanded_action: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Directory")
    |> assign(:selected_user, nil)
  end

  @impl true
  def handle_event("show_profile", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    {:noreply, assign(socket, selected_user: user)}
  end

  @impl true
  def handle_event("hide_profile", _params, socket) do
    {:noreply, assign(socket, selected_user: nil)}
  end

  @impl true
  def handle_event("play_native_pronunciation", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    # Get the native language for Forvo API call
    native_lang = user.native_language || TextToSpeech.get_language_for_country(user.country)

    IO.puts(
      "🎯 NATIVE: Fetching pronunciation for #{user.name} in native language #{native_lang} (country: #{user.country})"
    )

    # Use the improved name pronunciation system with explicit native language
    case TextToSpeech.get_name_pronunciation(user, native_lang) do
      {:audio_url, url} ->
        IO.puts("🔊 AUDIO URL (Native): #{user.name} → #{url}")
        {:noreply, socket |> push_event("play_audio_url", %{url: url})}

      {:tts, _text, _lang} ->
        # For native pronunciation, use the native name and language
        native_text = user.name_native || user.name

        IO.puts("🔊 TTS (Native): #{user.name} → '#{native_text}' (#{native_lang})")

        {:noreply,
         socket
         |> push_event("speak_text", %{
           text: native_text,
           lang: native_lang,
           rate: 0.9,
           pitch: 1.0
         })}
    end
  end

  @impl true
  def handle_event("play_english_pronunciation", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    IO.puts(
      "🎯 ENGLISH: Fetching pronunciation for #{user.name} in en-US (country: #{user.country}, native: #{user.native_language})"
    )

    # Use the improved name pronunciation system specifically for English
    case TextToSpeech.get_name_pronunciation(user, "en-US") do
      {:audio_url, url} ->
        IO.puts("🔊 AUDIO URL (English): #{user.name} → #{url}")
        {:noreply, socket |> push_event("play_audio_url", %{url: url})}

      {:tts, text, _lang} ->
        IO.puts("🔊 TTS (English): #{user.name} → '#{text}' (en-US)")
        # Enhanced parameters for better English pronunciation
        {:noreply,
         socket
         |> push_event("speak_text", %{
           text: text,
           lang: "en-US",
           rate: 0.85,
           pitch: 1.05
         })}
    end
  end

  # Inline Actions Event Handlers
  @impl true
  def handle_event("toggle_action", %{"action" => action, "user_id" => user_id}, socket) do
    current_action = socket.assigns.expanded_action
    new_action = if current_action == action, do: nil, else: action
    {:noreply, assign(socket, expanded_action: new_action)}
  end

  @impl true
  def handle_event("cancel_action", _params, socket) do
    {:noreply, assign(socket, expanded_action: nil)}
  end

  # Phase 1 Actions
  @impl true
  def handle_event("send_message", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📨 Sending message to #{user.name}")

    {:noreply,
     socket |> assign(expanded_action: nil) |> put_flash(:info, "Message sent to #{user.name}!")}
  end

  @impl true
  def handle_event("propose_meeting", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📅 Proposing meeting with #{user.name}")

    {:noreply,
     socket
     |> assign(expanded_action: nil)
     |> put_flash(:info, "Meeting proposal sent to #{user.name}!")}
  end

  @impl true
  def handle_event("pin_timezone", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📌 Pinning #{user.name}'s timezone: #{user.timezone}")

    {:noreply,
     socket
     |> assign(expanded_action: nil)
     |> put_flash(:info, "#{user.name}'s timezone pinned to favorites!")}
  end

  # Phase 2 Actions
  @impl true
  def handle_event("set_reminder", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("⏰ Setting reminder for #{user.name}")

    {:noreply,
     socket |> assign(expanded_action: nil) |> put_flash(:info, "Reminder set for #{user.name}!")}
  end

  @impl true
  def handle_event("notify_team", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("🔔 Notifying team about #{user.name}")

    {:noreply,
     socket |> assign(expanded_action: nil) |> put_flash(:info, "Team notification sent!")}
  end

  @impl true
  def handle_event("update_status", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("✅ Updating status for #{user.name}")
    {:noreply, socket |> assign(expanded_action: nil) |> put_flash(:info, "Status updated!")}
  end

  # Phase 3 Actions
  @impl true
  def handle_event("create_whiteboard", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("🎨 Creating whiteboard with #{user.name}")

    {:noreply,
     socket
     |> assign(expanded_action: nil)
     |> put_flash(:info, "Whiteboard created and shared with #{user.name}!")}
  end

  @impl true
  def handle_event("create_poll", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📊 Creating poll with #{user.name}")

    {:noreply,
     socket
     |> assign(expanded_action: nil)
     |> put_flash(:info, "Poll created and shared with #{user.name}!")}
  end

  @impl true
  def handle_event("share_document", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📄 Sharing document with #{user.name}")

    {:noreply,
     socket
     |> assign(expanded_action: nil)
     |> put_flash(:info, "Document shared with #{user.name}!")}
  end

  # Catch-all for debugging
  @impl true
  def handle_event(event_name, params, socket) do
    IO.puts("🔧 UNKNOWN EVENT: #{event_name}")
    IO.inspect(params, label: "🔧 PARAMS")
    {:noreply, socket}
  end

  defp user_avatar_url(name) do
    seed = name |> String.downcase() |> String.replace(" ", "-")

    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{seed}&backgroundColor=b6e3f4,c0aede,d1d4f9&size=64"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Team Directory</h1>
        <p class="mt-2 text-gray-600">Connect with your distributed team members</p>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={user <- @users}
          class="relative bg-white overflow-hidden shadow rounded-lg border border-gray-200 hover:shadow-md transition-shadow cursor-pointer"
          phx-click="show_profile"
          phx-value-user_id={user.id}
        >
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <img
                  src={user_avatar_url(user.name)}
                  alt={"#{user.name}'s avatar"}
                  class="h-12 w-12 rounded-full shadow-sm border border-gray-200"
                />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate flex items-center gap-2">
                    <span><%= user.name %></span>
                    <div class="flex items-center gap-1">
                                                                                                              <!-- English pronunciation button -->
                      <button
                        phx-click="play_english_pronunciation"
                        phx-value-user_id={user.id}
                        onclick="console.log('🔴 Button clicked!', this);"
                        class="inline-flex items-center justify-center gap-1 px-2 py-1 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-full transition-colors text-xs"
                        title="Play English pronunciation"
                      >
                        <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"></path>
                        </svg>
                        <span class="font-medium">EN</span>
                      </button>

                      <!-- Native pronunciation button (if different from English) -->
                      <button
                        :if={user.name_native && user.name_native != user.name}
                        phx-click="play_native_pronunciation"
                        phx-value-user_id={user.id}
                        onclick="console.log('🔴 Native button clicked!', this);"
                        class={if TextToSpeech.get_native_language_display_name(user.country) do
                          "inline-flex items-center justify-center gap-1 px-2 py-1 text-gray-500 hover:text-emerald-600 hover:bg-emerald-50 rounded-full transition-colors text-xs"
                        else
                          "inline-flex items-center justify-center w-6 h-6 text-gray-500 hover:text-emerald-600 hover:bg-emerald-50 rounded-full transition-colors"
                        end}
                        title={"Play #{TextToSpeech.get_native_language_name(user.country)} pronunciation"}
                      >
                        <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"></path>
                        </svg>
                        <span :if={TextToSpeech.get_native_language_display_name(user.country)} class="font-medium"><%= TextToSpeech.get_native_language_display_name(user.country) %></span>
                      </button>
                    </div>
                  </dt>
                  <dd class="text-sm text-gray-900">
                    <%= user.role || "Team Member" %>
                  </dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <div class="flex items-center justify-between text-sm text-gray-500">
                <span><%= user.timezone %></span>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                  <%= user.country %>
                </span>
              </div>

              <div :if={user.name_native && user.name_native != user.name} class="mt-2">
                <div class="text-xs text-gray-500"><%= TextToSpeech.get_native_language_name(user.country) %></div>
                <div class="text-sm font-medium text-gray-800"><%= user.name_native %></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Inline Actions Popup -->
      <div
        :if={@selected_user}
        class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        phx-click="hide_profile"
      >
        <div class="relative top-20 mx-auto p-5 border shadow-lg rounded-md bg-white max-w-sm">
          <.inline_actions_popup
            user={@selected_user}
            expanded_action={@expanded_action}
            class="border-0 shadow-none p-0 w-full"
          />
          <button
            phx-click="hide_profile"
            class="absolute top-2 right-2 text-gray-400 hover:text-gray-600"
          >
            <span class="sr-only">Close</span>
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>
      </div>
    </div>
    """
  end
end

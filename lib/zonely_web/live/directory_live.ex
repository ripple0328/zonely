defmodule ZonelyWeb.DirectoryLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.Audio

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    {:ok,
     assign(socket,
       users: users,
       selected_user: nil,
       expanded_action: nil,
       loading_pronunciation: %{},
       playing_pronunciation: %{}
     )}
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

    socket =
      assign(socket,
        loading_pronunciation: Map.put(socket.assigns.loading_pronunciation, user_id, "native")
      )

    # Send message to self to process audio after UI update
    send(self(), {:process_pronunciation, :native, user})
    {:noreply, socket}
  end

  @impl true
  def handle_event("play_english_pronunciation", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    socket =
      assign(socket,
        loading_pronunciation: Map.put(socket.assigns.loading_pronunciation, user_id, "english")
      )

    # Send message to self to process audio after UI update
    send(self(), {:process_pronunciation, :english, user})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_ended", %{"user_id" => user_id}, socket) do
    socket =
      assign(socket,
        playing_pronunciation: Map.delete(socket.assigns.playing_pronunciation, user_id)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:process_pronunciation, :native, user}, socket) do
    {event_type, event_data} = Audio.play_native_pronunciation(user)

    # Determine audio source type
    source =
      case event_type do
        # Real person
        :play_audio -> "audio"
        # AI synthetic (pre-generated audio file)
        :play_tts_audio -> "tts"
        # AI synthetic (browser TTS)
        :play_tts -> "tts"
        # Sequence of real person parts
        :play_sequence -> "audio"
      end

    socket =
      socket
      |> assign(loading_pronunciation: Map.delete(socket.assigns.loading_pronunciation, user.id))
      |> assign(
        playing_pronunciation:
          Map.put(socket.assigns.playing_pronunciation, user.id, %{type: "native", source: source})
      )

    # Add user_id to the event data for JavaScript callback
    enhanced_event_data = Map.put(event_data, :user_id, user.id)
    {:noreply, push_event(socket, event_type, enhanced_event_data)}
  end

  @impl true
  def handle_info({:process_pronunciation, :english, user}, socket) do
    {event_type, event_data} = Audio.play_english_pronunciation(user)

    # Determine audio source type
    source =
      case event_type do
        :play_audio -> "audio"
        :play_tts_audio -> "tts"
        :play_tts -> "tts"
        :play_sequence -> "audio"
      end

    socket =
      socket
      |> assign(loading_pronunciation: Map.delete(socket.assigns.loading_pronunciation, user.id))
      |> assign(
        playing_pronunciation:
          Map.put(socket.assigns.playing_pronunciation, user.id, %{
            type: "english",
            source: source
          })
      )

    # Add user_id to the event data for JavaScript callback
    enhanced_event_data = Map.put(event_data, :user_id, user.id)
    {:noreply, push_event(socket, event_type, enhanced_event_data)}
  end

  # Inline Actions Event Handlers
  @impl true
  def handle_event("toggle_action", %{"action" => action, "user_id" => _user_id}, socket) do
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

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Audio event hook for handling audio end events -->
    <div phx-hook="AudioHook" id="audio-hook" style="display: none;"></div>

    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Team Directory</h1>
        <p class="mt-2 text-gray-600">Connect with your distributed team members</p>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <.user_card :for={user <- @users} user={user} loading_pronunciation={Map.get(@loading_pronunciation, user.id)}
        playing_pronunciation={@playing_pronunciation} />
      </div>

      <!-- Profile Modal using new ProfileCard component -->
      <div
        :if={@selected_user}
        class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        phx-click="hide_profile"
      >
        <div class="relative top-20 mx-auto p-2 max-w-md">
          <.profile_card
            user={@selected_user}
            show_actions={true}
            show_local_time={true}
            class="relative"
            loading_pronunciation={Map.get(@loading_pronunciation, @selected_user.id)}
            playing_pronunciation={@playing_pronunciation}
          />
          <button
            phx-click="hide_profile"
            class="absolute top-4 right-4 text-gray-400 hover:text-gray-600 bg-white rounded-full p-1 shadow-sm"
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

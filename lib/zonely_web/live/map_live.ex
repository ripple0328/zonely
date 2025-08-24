defmodule ZonelyWeb.MapLive do
  use ZonelyWeb, :live_view

  alias Zonely.{Accounts, Audio, Geography, TimeUtils}
  require Logger

  @topic "users:schedule"

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    maptiler_api_key = Application.get_env(:zonely, :maptiler)[:api_key]

    # Subscribe to schedule changes for real-time updates
    Phoenix.PubSub.subscribe(Zonely.PubSub, @topic)

    {:ok,
     assign(socket,
       users: users,
       selected_user: nil,
       maptiler_api_key: maptiler_api_key,
       expanded_action: nil,
       viewer_tz: "UTC",
       base_date: Date.utc_today(),
       overlap_panel_expanded: true,
       selected_a_frac: nil,
       selected_b_frac: nil
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Map")
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
    {event_type, event_data} = Audio.play_native_pronunciation(user)
    {:noreply, push_event(socket, event_type, event_data)}
  end

  @impl true
  def handle_event("play_english_pronunciation", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    {event_type, event_data} = Audio.play_english_pronunciation(user)
    {:noreply, push_event(socket, event_type, event_data)}
  end

  # Quick Actions Event Handlers
  @impl true
  def handle_event("toggle_quick_action", %{"action" => action, "user_id" => _user_id}, socket) do
    current_action = socket.assigns.expanded_action
    new_action = if current_action == action, do: nil, else: action
    {:noreply, assign(socket, expanded_action: new_action)}
  end

  @impl true
  def handle_event("cancel_quick_action", _params, socket) do
    {:noreply, assign(socket, expanded_action: nil)}
  end

  # Quick Actions (Top 3 most frequent)
  @impl true
  def handle_event("quick_message", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📨 Quick message to #{user.name}")
    {:noreply, socket |> assign(expanded_action: nil) |> put_flash(:info, "Message sent to #{user.name}!")}
  end

  @impl true
  def handle_event("quick_meeting", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📅 Quick meeting with #{user.name}")
    {:noreply, socket |> assign(expanded_action: nil) |> put_flash(:info, "Meeting proposal sent to #{user.name}!")}
  end

  @impl true
  def handle_event("quick_pin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📌 Quick pin #{user.name}'s timezone: #{user.timezone}")
    {:noreply, socket |> assign(expanded_action: nil) |> put_flash(:info, "#{user.name}'s timezone pinned!")}
  end

  # Time Scrubber Event Handlers
  @impl true
  def handle_event("hover_range", %{"a_frac" => a, "b_frac" => b}, socket) do
    {from_utc, to_utc} = TimeUtils.frac_to_utc(a, b, socket.assigns.viewer_tz, socket.assigns.base_date)

    statuses =
      socket.assigns.users
      |> Task.async_stream(fn u -> {u.id, TimeUtils.classify_user(u, from_utc, to_utc)} end,
           max_concurrency: 8, timeout: 200)
      |> Enum.map(fn {:ok, kv} -> kv end)
      |> Map.new()

    # Convert atoms to tiny ints for payload efficiency
    payload = for {id, st} <- statuses, into: %{}, do: {id, TimeUtils.status_to_int(st)}
    {:noreply, push_event(socket, "overlap_update", %{statuses: payload})}
  end

  @impl true
  def handle_event("commit_range", %{"a_frac" => a, "b_frac" => b}, socket) do
    # For now, handle the same as hover (no server persistence of the selection)
    handle_event("hover_range", %{"a_frac" => a, "b_frac" => b}, socket)
  end

  @impl true
  def handle_event("set_viewer_tz", %{"tz" => tz}, socket) when is_binary(tz) do
    # Update viewer timezone and base_date based on viewer's local date
    base_date =
      case DateTime.now(tz) do
        {:ok, dt} -> DateTime.to_date(dt)
        _ -> Date.utc_today()
      end
    {:noreply, assign(socket, viewer_tz: tz, base_date: base_date)}
  end

  @impl true
  def handle_event("toggle_overlap_panel", _params, socket) do
    {:noreply, assign(socket, overlap_panel_expanded: !socket.assigns.overlap_panel_expanded)}
  end

  # PubSub handler for real-time schedule changes (placeholder)
  @impl true
  def handle_info({:schedule_changed, _user_id, _new_hours}, socket) do
    # For now, just refresh users - could optimize to update single user
    users = Accounts.list_users()
    {:noreply, assign(socket, users: users)}
  end

  # Convert users to JSON for JavaScript
  defp users_to_json(users) do
    users
    |> Enum.filter(&(&1.latitude && &1.longitude))
    |> Enum.map(fn user ->
      %{
        id: user.id,
        name: user.name,
        role: user.role || "Team Member",
        country: Geography.country_name(user.country),
        country_code: user.country,
        timezone: user.timezone,
        latitude: Decimal.to_float(user.latitude),
        longitude: Decimal.to_float(user.longitude),
        pronouns: user.pronouns,
        name_native: user.name_native,
        native_language: user.native_language,
        work_start: TimeUtils.format_time(user.work_start),
        work_end: TimeUtils.format_time(user.work_end),
        profile_picture: fake_profile_picture(user.name)
      }
    end)
    |> Jason.encode!()
  end

  # Generate fake profile pictures using AvatarService for consistency
  defp fake_profile_picture(name) do
    Zonely.AvatarService.generate_avatar_url(name, 64)
  end




  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed left-0 top-16 w-full h-[calc(100vh-4rem)] z-10">
      <!-- MapLibre GL JS Map Container -->
      <div
        id="map-container"
        class="h-full w-full"
        phx-hook="TeamMap"
        phx-update="ignore"
        data-api-key={@maptiler_api_key}
        data-users={users_to_json(@users)}
        data-testid="team-map"
      >
      </div>

      <!-- Profile Modal -->
      <div
        :if={@selected_user}
        class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        phx-click="hide_profile"
        data-testid="profile-modal"
      >
        <div class="relative top-20 mx-auto p-2 max-w-md">
          <.profile_card
            user={@selected_user}
            show_actions={false}
            show_local_time={true}
            class="relative"
          />

          <!-- Quick Actions Bar for Map -->
          <div class="mt-2">
            <.quick_actions_bar user={@selected_user} expanded_action={@expanded_action} />
          </div>

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

    <!-- Working Hours Overlap Selector (Outside map container) -->
    <div class="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-40 px-4">
      <!-- Toggle Button (always visible) -->
      <div class="flex justify-center mb-2">
        <.panel_toggle
          expanded={@overlap_panel_expanded}
          label="Hide Panel"
          collapsed_label="Working Hours Overlap"
          click_event="toggle_overlap_panel"
        />
      </div>

      <!-- Panel Content -->
      <.time_range_selector expanded={@overlap_panel_expanded} selected_a_frac={@selected_a_frac} selected_b_frac={@selected_b_frac} />
    </div>
    """
  end
end

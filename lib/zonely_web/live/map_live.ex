defmodule ZonelyWeb.MapLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.Audio
  alias Zonely.Geography
  alias Zonely.TimeUtils
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
       selected_b_frac: nil,
       loading_pronunciation: %{},
       playing_pronunciation: %{},
       demo_on?: false,
       demo_paused?: false,
       demo_step_index: 0,
       demo_timer_ref: nil,
       demo_ui: nil,
       hero_dismissed: false,
       # Onboarding state tracking
       onboarding: %{
         first_avatar_clicked: false,
         first_pronunciation_played: false,
         first_timeline_interaction: false,
         inactivity_hint_shown: false,
         active_hint: nil,
         inactivity_timer: nil
       }
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    # Autoplay demo mode for map page when ?demo=1 is present
    socket =
      case Map.get(params, "demo") do
        "1" ->
          socket
          |> assign(:demo_on?, true)
          |> assign(:demo_step_index, 0)
          |> assign(:demo_paused?, false)
          |> assign(:demo_timer_ref, nil)
          |> schedule_demo_step(0)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_demo", _params, socket) do
    socket =
      socket
      |> assign(:demo_on?, true)
      |> assign(:demo_step_index, 0)
      |> assign(:demo_paused?, false)
      |> assign(:demo_timer_ref, nil)
      |> schedule_demo_step(0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("dismiss_hero", _params, socket) do
    socket =
      socket
      |> assign(:hero_dismissed, true)
      |> schedule_inactivity_hint()

    {:noreply, socket}
  end

  @impl true
  def handle_event("dismiss_hint", _params, socket) do
    onboarding = Map.put(socket.assigns.onboarding, :active_hint, nil)
    {:noreply, assign(socket, :onboarding, onboarding)}
  end

  @impl true
  def handle_event("user_activity", _params, socket) do
    {:noreply, reset_inactivity_timer(socket)}
  end

  @impl true
  def handle_event("show_profile", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    # Track first avatar click and show pronunciation hint (if not yet played)
    socket =
      if !socket.assigns.onboarding.first_pronunciation_played do
        onboarding =
          socket.assigns.onboarding
          |> Map.put(:first_avatar_clicked, true)
          |> Map.put(:active_hint, :pronunciation_hint)
          |> Map.put(:inactivity_timer, nil)

        socket
        |> assign(:onboarding, onboarding)
      else
        # Just cancel inactivity timer if already played
        onboarding = Map.put(socket.assigns.onboarding, :inactivity_timer, nil)
        assign(socket, :onboarding, onboarding)
      end

    {:noreply, assign(socket, selected_user: user)}
  end

  @impl true
  def handle_event("hide_profile", _params, socket) do
    # Just hide the hint visually - it will reappear when profile opens again
    # (unless pronunciation was already played)
    {:noreply, assign(socket, selected_user: nil)}
  end

  @impl true
  def handle_event("play_native_pronunciation", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    # Track first pronunciation play and dismiss hint
    socket =
      if !socket.assigns.onboarding.first_pronunciation_played do
        onboarding =
          socket.assigns.onboarding
          |> Map.put(:first_pronunciation_played, true)
          |> Map.put(:active_hint, nil)

        socket
        |> assign(:onboarding, onboarding)
      else
        socket
      end

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

    # Track first pronunciation play and dismiss hint
    socket =
      if !socket.assigns.onboarding.first_pronunciation_played do
        onboarding =
          socket.assigns.onboarding
          |> Map.put(:first_pronunciation_played, true)
          |> Map.put(:active_hint, nil)

        socket
        |> assign(:onboarding, onboarding)
      else
        socket
      end

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

  # Quick Actions Event Handlers
  @impl true
  def handle_event("toggle_quick_action", %{"action" => action, "user_id" => _user_id}, socket) do
    current_action = socket.assigns.expanded_action
    new_action = if current_action == action, do: nil, else: action
    {:noreply, assign(socket, expanded_action: new_action)}
  end

  # Demo overlay events
  @impl true
  def handle_event("demo_toggle", _params, socket) do
    paused? = !(socket.assigns.demo_paused? || false)
    socket = assign(socket, :demo_paused?, paused?)

    # If resuming, schedule next step immediately
    socket = if !paused?, do: schedule_demo_step(socket, 0), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("demo_skip", _params, socket) do
    {:noreply, next_demo_step(socket, 0)}
  end

  @impl true
  def handle_event("demo_replay", _params, socket) do
    socket =
      socket
      |> assign(:demo_step_index, 0)
      |> assign(:demo_paused?, false)

    {:noreply, schedule_demo_step(socket, 0)}
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

    {:noreply,
     socket |> assign(expanded_action: nil) |> put_flash(:info, "Message sent to #{user.name}!")}
  end

  @impl true
  def handle_event("quick_meeting", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📅 Quick meeting with #{user.name}")

    {:noreply,
     socket
     |> assign(expanded_action: nil)
     |> put_flash(:info, "Meeting proposal sent to #{user.name}!")}
  end

  @impl true
  def handle_event("quick_pin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    IO.puts("📌 Quick pin #{user.name}'s timezone: #{user.timezone}")

    {:noreply,
     socket |> assign(expanded_action: nil) |> put_flash(:info, "#{user.name}'s timezone pinned!")}
  end

  # Time Scrubber Event Handlers
  @impl true
  def handle_event("hover_range", %{"a_frac" => a, "b_frac" => b}, socket) do
    # Track first timeline interaction and dismiss hint
    socket =
      if !socket.assigns.onboarding.first_timeline_interaction do
        onboarding =
          socket.assigns.onboarding
          |> Map.put(:first_timeline_interaction, true)
          |> Map.put(:active_hint, nil)

        socket
        |> assign(:onboarding, onboarding)
      else
        socket
      end

    {from_utc, to_utc} =
      TimeUtils.frac_to_utc(a, b, socket.assigns.viewer_tz, socket.assigns.base_date)

    statuses =
      socket.assigns.users
      |> Task.async_stream(fn u -> {u.id, TimeUtils.classify_user(u, from_utc, to_utc)} end,
        max_concurrency: 8,
        timeout: 200
      )
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
        # Real person parts in sequence
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
        # Real person
        :play_audio -> "audio"
        # AI synthetic (pre-generated audio file)
        :play_tts_audio -> "tts"
        # AI synthetic (browser TTS)
        :play_tts -> "tts"
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

  # PubSub handler for real-time schedule changes
  @impl true
  def handle_info({:schedule_changed, _user_id, _new_hours}, socket) do
    # For now, just refresh users - could optimize to update single user
    users = Accounts.list_users()
    {:noreply, assign(socket, users: users)}
  end

  # Demo driver
  @impl true
  def handle_info(:demo_tick, %{assigns: %{demo_on?: true}} = socket) do
    # If paused, skip executing current step and wait
    if socket.assigns[:demo_paused?] do
      {:noreply, socket}
    else
      {:noreply, perform_demo_step(socket)}
    end
  end

  def handle_info(:demo_tick, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:demo_drag, a, b}, socket) do
    {:noreply, push_event(socket, "time_selection_set", %{a_frac: a, b_frac: b})}
  end

  @impl true
  def handle_info(:show_inactivity_hint, socket) do
    socket =
      if !socket.assigns.onboarding.inactivity_hint_shown &&
           !socket.assigns.onboarding.first_avatar_clicked do
        onboarding =
          socket.assigns.onboarding
          |> Map.put(:inactivity_hint_shown, true)
          |> Map.put(:active_hint, :inactivity_hint)

        assign(socket, :onboarding, onboarding)
      else
        socket
      end

    {:noreply, socket}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Map")
    |> assign(:selected_user, nil)
  end

  defp schedule_demo_step(socket, ms) when is_integer(ms) do
    if socket.assigns[:demo_paused?] do
      socket
    else
      ref = Process.send_after(self(), :demo_tick, ms)
      assign(socket, :demo_timer_ref, ref)
    end
  end

  defp next_demo_step(socket, delay_ms) do
    socket
    |> assign(:demo_step_index, (socket.assigns.demo_step_index || 0) + 1)
    |> schedule_demo_step(delay_ms)
  end

  defp demo_steps do
    [
      %{
        action: :open_day_tz,
        delay_ms: 1800,
        highlight: "#map-container",
        title: "Daytime timezone",
        desc: "See live local time by clicking day regions. Great for quick checks."
      },
      %{
        action: :open_night_tz,
        delay_ms: 1800,
        highlight: "#map-container",
        title: "Nighttime timezone",
        desc: "Night overlay shows who is off-hours now across the world."
      },
      %{
        action: :open_avatar,
        delay_ms: 1400,
        highlight: "[data-user-id]",
        title: "Open teammate profile",
        desc: "Click an avatar to view profile, timezone and quick actions."
      },
      %{
        action: :pronounce_name,
        delay_ms: 2200,
        highlight: "[data-testid=pronunciation-native]",
        title: "Hear their name",
        desc: "Play native or English name pronunciation to get it right."
      },
      %{
        action: :select_overlap,
        delay_ms: 4200,
        highlight: "#time-scrubber",
        title: "Find overlap",
        desc: "Drag to select a window and instantly see who can meet."
      },
      %{
        action: :open_avatar2,
        delay_ms: 1800,
        highlight: nil,
        title: "Another teammate",
        desc: "Open a different profile to compare working hours."
      }
    ]
  end

  defp perform_demo_step(socket) do
    step_index = socket.assigns.demo_step_index || 0

    case Enum.at(demo_steps(), step_index) do
      nil ->
        socket
        |> assign(:demo_on?, false)
        |> push_event("demo_highlight", %{selector: "__end__"})

      %{action: :open_day_tz, delay_ms: delay} = step ->
        socket
        |> assign(:demo_ui, Map.take(step, [:title, :desc]))
        |> push_event("demo_highlight", %{selector: step.highlight})
        |> push_event("open_tz_popup", %{tzid: "Europe/Berlin", lat: 52.52, lng: 13.405})
        |> next_demo_step(delay)

      %{action: :open_night_tz, delay_ms: delay} = step ->
        socket
        |> assign(:demo_ui, Map.take(step, [:title, :desc]))
        |> push_event("demo_highlight", %{selector: step.highlight})
        # Place popup over open ocean to avoid covering avatar markers
        |> push_event("open_tz_popup", %{tzid: "Pacific/Honolulu", lat: 10.0, lng: -170.0})
        |> next_demo_step(delay)

      %{action: :open_avatar, delay_ms: delay} = step ->
        # Choose a demo user whose marker is far from the previous popup areas to avoid overlap
        user =
          pick_demo_user(socket.assigns.users) ||
            (socket.assigns.users |> Enum.find(&(&1.latitude && &1.longitude)) ||
               List.first(socket.assigns.users))

        socket
        |> assign(:demo_ui, Map.take(step, [:title, :desc]))
        |> push_event("demo_highlight", %{selector: step.highlight})
        |> assign(:selected_user, user)
        |> next_demo_step(delay)

      %{action: :pronounce_name, delay_ms: delay} = step ->
        user = socket.assigns.selected_user || socket.assigns.users |> Enum.at(0)

        socket =
          socket
          |> assign(:demo_ui, Map.take(step, [:title, :desc]))
          |> push_event("demo_highlight", %{selector: step.highlight})
          |> assign(
            :loading_pronunciation,
            Map.put(socket.assigns.loading_pronunciation, user.id, "native")
          )

        send(self(), {:process_pronunciation, :native, user})
        next_demo_step(socket, delay)

      %{action: :select_overlap, delay_ms: delay} = step ->
        a = 10 / 24
        b = 14 / 24

        socket
        |> assign(:demo_ui, Map.take(step, [:title, :desc]))
        |> push_event("demo_highlight", %{selector: step.highlight})
        |> push_event("time_selection_set", %{a_frac: a, b_frac: b})
        |> schedule_drag_sequence([{11 / 24, 13 / 24}, {15 / 24, 18 / 24}], 1800)
        |> next_demo_step(delay)

      %{action: :open_avatar2, delay_ms: delay} = step ->
        alt_user =
          pick_another_user(socket.assigns.users, socket.assigns.selected_user) ||
            pick_demo_user(socket.assigns.users) || socket.assigns.selected_user

        socket
        |> assign(:demo_ui, Map.take(step, [:title, :desc]))
        |> push_event("demo_highlight", %{selector: step.highlight})
        |> assign(:selected_user, alt_user)
        |> next_demo_step(delay)
    end
  end

  # Drag sequence to showcase changing availability states
  defp schedule_drag_sequence(socket, ranges, interval_ms) do
    Enum.with_index(ranges)
    |> Enum.reduce(socket, fn {{a, b}, idx}, s ->
      Process.send_after(self(), {:demo_drag, a, b}, interval_ms * (idx + 1))
      s
    end)
  end

  # Heuristic: pick user farthest from both Berlin and Honolulu to avoid popup overlap
  defp pick_demo_user(users) do
    berlin = {52.52, 13.405}
    honolulu = {21.3069, -157.8583}

    users
    |> Enum.filter(&(&1.latitude && &1.longitude))
    |> Enum.map(fn u ->
      lat = to_float(u.latitude)
      lng = to_float(u.longitude)
      d = approx_distance({lat, lng}, berlin) + approx_distance({lat, lng}, honolulu)
      {d, u}
    end)
    |> Enum.max_by(fn {d, _u} -> d end, fn -> nil end)
    |> case do
      {_, u} -> u
      _ -> nil
    end
  end

  defp pick_another_user(users, current) do
    users
    |> Enum.filter(fn u -> u.id != (current && current.id) && u.latitude && u.longitude end)
    |> Enum.random()
  rescue
    _ -> nil
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(v) when is_number(v), do: v
  defp to_float(_), do: 0.0

  # Equirectangular approximation is fine for demo selection
  defp approx_distance({lat1, lon1}, {lat2, lon2}) do
    rlat1 = :math.pi() * lat1 / 180
    rlat2 = :math.pi() * lat2 / 180
    rlon1 = :math.pi() * lon1 / 180
    rlon2 = :math.pi() * lon2 / 180
    x = (rlon2 - rlon1) * :math.cos((rlat1 + rlat2) / 2)
    y = rlat2 - rlat1
    :math.sqrt(x * x + y * y)
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

  # Onboarding hint helpers
  defp schedule_inactivity_hint(socket) do
    cancel_inactivity_timer(socket)
    ref = Process.send_after(self(), :show_inactivity_hint, 30_000)
    onboarding = Map.put(socket.assigns.onboarding, :inactivity_timer, ref)
    assign(socket, :onboarding, onboarding)
  end

  defp cancel_inactivity_timer(socket) do
    if timer_ref = socket.assigns.onboarding.inactivity_timer do
      Process.cancel_timer(timer_ref)
    end

    onboarding = Map.put(socket.assigns.onboarding, :inactivity_timer, nil)
    assign(socket, :onboarding, onboarding)
  end

  defp reset_inactivity_timer(socket) do
    if socket.assigns.hero_dismissed &&
         !socket.assigns.onboarding.inactivity_hint_shown do
      schedule_inactivity_hint(socket)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Audio event hook for handling audio end events -->
    <div phx-hook="AudioHook" id="audio-hook" style="display: none;"></div>

    <!-- Contextual Onboarding Hints -->
    <%= if @onboarding.active_hint do %>
      <%= cond do %>
        <% @onboarding.active_hint == :pronunciation_hint && @selected_user -> %>
          <.contextual_hint hint_type={@onboarding.active_hint} />
        <% @onboarding.active_hint == :timeline_hint -> %>
          <.contextual_hint hint_type={@onboarding.active_hint} />
        <% @onboarding.active_hint == :inactivity_hint && !@selected_user -> %>
          <.contextual_hint hint_type={@onboarding.active_hint} />
        <% true -> %>
          <%!-- Hint not applicable for current context --%>
      <% end %>
    <% end %>

    <!-- Welcome Hero Overlay (shows on first visit) -->
    <div :if={!@demo_on? && !@hero_dismissed && length(@users) > 0} class="fixed inset-0 bg-gradient-to-br from-indigo-50 to-blue-50 z-[1000] flex items-center justify-center animate-fade-in" id="welcome-hero">
      <div class="max-w-3xl mx-auto px-8 py-12 text-center">
        <div class="inline-flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-sm rounded-full shadow-sm mb-6">
          <span class="text-2xl">🌍</span>
          <span class="text-sm font-medium text-gray-700">Welcome to Zonely</span>
        </div>

        <h1 class="text-4xl md:text-5xl font-bold text-gray-900 mb-4 leading-tight">
          Connect Better Across<br/>Time Zones & Cultures
        </h1>

        <p class="text-lg text-gray-600 mb-8 max-w-2xl mx-auto">
          Say names correctly, find the perfect meeting time, and respect your teammates' working hours—all in one beautiful interface.
        </p>

        <div class="flex flex-wrap gap-4 justify-center mb-8">
          <div class="bg-white rounded-xl shadow-md p-6 text-left max-w-xs hover:shadow-lg transition-all duration-300 cursor-default">
            <div class="text-3xl mb-3">🗣️</div>
            <h3 class="font-semibold text-gray-900 mb-2">Name Pronunciation</h3>
            <p class="text-sm text-gray-600">Click avatars to hear how to pronounce names correctly—show respect from day one.</p>
          </div>

          <div class="bg-white rounded-xl shadow-md p-6 text-left max-w-xs hover:shadow-lg transition-all duration-300 cursor-default">
            <div class="text-3xl mb-3">⏰</div>
            <h3 class="font-semibold text-gray-900 mb-2">Working Hours Overlap</h3>
            <p class="text-sm text-gray-600">Drag the timeline to see who's available—find meeting times that work for everyone.</p>
          </div>
        </div>

        <div class="flex gap-4 justify-center">
          <button phx-click="start_demo" class="px-6 py-3 bg-indigo-600 text-white font-medium rounded-lg shadow-md hover:bg-indigo-700 hover:shadow-lg transition-all duration-200 hover:scale-105" data-testid="hero-start-demo">
            Take a Tour
          </button>
          <button phx-click="dismiss_hero" class="px-6 py-3 bg-white text-gray-700 font-medium rounded-lg shadow-md hover:bg-gray-50 hover:shadow-lg transition-all duration-200">
            Explore on My Own
          </button>
        </div>
      </div>
    </div>

    <!-- Demo overlay controls -->
    <div :if={@demo_on?} class="fixed top-4 right-4 z-[2000] w-96 rounded-lg bg-white/95 backdrop-blur-sm shadow-xl border border-indigo-100 p-5 space-y-3 animate-slide-in" data-testid="demo-overlay">
      <div class="flex items-start gap-3">
        <div class="flex-shrink-0 w-10 h-10 bg-indigo-100 rounded-full flex items-center justify-center">
          <span class="text-lg">✨</span>
        </div>
        <div class="flex-1">
          <div class="text-sm font-semibold text-gray-900 mb-1">
            <%= @demo_ui && @demo_ui.title || "Guided Demo" %>
          </div>
          <div class="text-sm text-gray-600 leading-relaxed">
            <%= @demo_ui && @demo_ui.desc || "Walkthrough of the map and overlap features" %>
          </div>
        </div>
      </div>

      <!-- Progress -->
      <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
        <div
          class="h-full bg-gradient-to-r from-indigo-500 to-blue-500 transition-all duration-500 ease-out"
          style={"width: #{Float.round(((min(@demo_step_index || 0, length(demo_steps()) - 1)) / max(length(demo_steps()) - 1, 1)) * 100.0, 1)}%"}
        ></div>
      </div>

      <div class="flex items-center gap-2 pt-1">
        <button phx-click="demo_toggle" class={["px-3 py-1.5 rounded-md text-xs font-medium transition-colors", @demo_paused? && "bg-emerald-600 text-white hover:bg-emerald-700" || "bg-gray-800 text-white hover:bg-gray-900"]} data-testid="demo-toggle">
          <%= @demo_paused? && "▶ Resume" || "⏸ Pause" %>
        </button>
        <button phx-click="demo_skip" class="px-3 py-1.5 rounded-md bg-white border border-gray-200 text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors" data-testid="demo-skip">Skip →</button>
        <button phx-click="demo_replay" class="px-3 py-1.5 rounded-md bg-white border border-gray-200 text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors" data-testid="demo-replay">↺ Replay</button>
      </div>

      <div class="flex items-center gap-2 text-xs text-gray-500 pt-1 border-t border-gray-100">
        <span class="text-blue-500">💡</span>
        <span>You can still interact with the map during the demo</span>
      </div>
    </div>

    <div class="fixed left-0 top-16 w-full h-[calc(100vh-4rem)] z-10">
      <!-- Current User Timezone Display -->
      <div class="absolute top-4 left-4 z-[1500] bg-white/95 backdrop-blur-sm rounded-xl shadow-xl border border-gray-100 p-4 max-w-xs">
        <div class="flex items-center gap-3">
          <div class="flex-shrink-0 w-12 h-12 bg-gradient-to-br from-indigo-500 to-blue-500 rounded-full flex items-center justify-center text-white text-2xl shadow-lg">
            🌍
          </div>
          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-0.5">Your Timezone</div>
            <div class="text-base font-semibold text-gray-900 truncate" id="viewer-timezone-name">
              {@viewer_tz}
            </div>
            <div class="text-lg font-bold text-indigo-600" id="viewer-current-time" phx-hook="LiveClock" data-timezone={@viewer_tz}>
              Loading...
            </div>
          </div>
        </div>
      </div>

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

      <!-- Improved Start Demo button with tooltip (only if users exist) -->
      <div :if={!@demo_on? && length(@users) > 0} id="start-demo-cta" class="absolute top-4 right-4 z-[1500] group">
        <button phx-click="start_demo" class="px-4 py-2.5 rounded-lg bg-gradient-to-r from-indigo-600 to-blue-600 text-white text-sm font-medium shadow-lg hover:shadow-xl transition-all hover:scale-105 flex items-center gap-2" data-testid="start-demo">
          <span class="text-base">✨</span>
          <span>Start Interactive Tour</span>
        </button>
        <div class="absolute top-full right-0 mt-2 w-64 px-3 py-2 bg-gray-900 text-white text-xs rounded-lg shadow-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
          See Zonely in action with a guided walkthrough
        </div>
      </div>

      <!-- Empty State (when no users on map) -->
      <div :if={length(@users) == 0} class="absolute inset-0 flex items-center justify-center z-[1500] pointer-events-none">
        <div class="bg-white rounded-2xl shadow-xl p-8 max-w-md text-center pointer-events-auto">
          <div class="text-6xl mb-4">🗺️</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-3">Your Team Map is Empty</h2>
          <p class="text-gray-600 mb-6">
            Add team members to see them on the map, learn their name pronunciation, and find the best times to collaborate.
          </p>
          <a href="/directory" class="inline-flex items-center gap-2 px-6 py-3 bg-indigo-600 text-white font-medium rounded-lg shadow-md hover:bg-indigo-700 hover:shadow-lg transition-all duration-200 hover:scale-105">
            <span>➕</span>
            <span>Add Team Members</span>
          </a>
          <div class="mt-6 pt-6 border-t border-gray-100">
            <p class="text-sm text-gray-500">
              Team members with locations will appear as pins on this map
            </p>
          </div>
        </div>
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
            loading_pronunciation={Map.get(@loading_pronunciation, @selected_user.id)}
            playing_pronunciation={@playing_pronunciation}
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

  # Contextual hint component
  defp contextual_hint(assigns) do
    hint_config =
      case assigns.hint_type do
        :pronunciation_hint ->
          %{
            position: "profile-card",
            icon: "🗣️",
            title: "Hear How to Say Names",
            message:
              "Click the speaker icons to hear name pronunciation—show respect from day one!",
            pointer_class: "top-24 right-1/2"
          }

        :timeline_hint ->
          %{
            position: "timeline",
            icon: "⏰",
            title: "Find Meeting Times",
            message: "Drag across the timeline below to see who's available during those hours.",
            pointer_class: "bottom-32 left-1/2"
          }

        :inactivity_hint ->
          %{
            position: "center",
            icon: "👋",
            title: "Try Clicking an Avatar",
            message:
              "Click any team member's avatar on the map to view their profile and timezone info.",
            pointer_class: "top-1/2 left-1/2"
          }

        _ ->
          nil
      end

    assigns = Map.put(assigns, :config, hint_config)

    ~H"""
    <%= if @config do %>
      <div
        class="fixed z-[1500] animate-fade-in"
        style={hint_position_style(@config.position)}
        data-testid={"hint-#{@hint_type}"}
      >
        <div class="bg-gradient-to-br from-indigo-600 to-blue-600 text-white rounded-xl shadow-2xl p-5 max-w-sm relative">
          <button
            phx-click="dismiss_hint"
            class="absolute top-2 right-2 text-white/80 hover:text-white transition-colors"
            aria-label="Dismiss hint"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>

          <div class="flex items-start gap-3 pr-6">
            <div class="flex-shrink-0 w-10 h-10 bg-white/20 rounded-full flex items-center justify-center text-2xl">
              {@config.icon}
            </div>
            <div class="flex-1">
              <div class="font-semibold text-lg mb-1">
                {@config.title}
              </div>
              <div class="text-sm text-white/90 leading-relaxed">
                {@config.message}
              </div>
            </div>
          </div>

          <div class="mt-3 pt-3 border-t border-white/20 text-xs text-white/70">
            💡 This hint will auto-dismiss when you try it
          </div>
        </div>

        <!-- Animated pointer/arrow -->
        <div class="absolute w-6 h-6 bg-gradient-to-br from-indigo-600 to-blue-600 rotate-45 shadow-xl animate-bounce" style={@config.pointer_class}>
        </div>
      </div>
    <% end %>
    """
  end

  defp hint_position_style(position) do
    case position do
      "profile-card" -> "top: 8rem; right: 2rem;"
      "timeline" -> "bottom: 12rem; left: 50%; transform: translateX(-50%);"
      "center" -> "top: 50%; left: 50%; transform: translate(-50%, -50%);"
      _ -> "top: 50%; left: 50%; transform: translate(-50%, -50%);"
    end
  end
end

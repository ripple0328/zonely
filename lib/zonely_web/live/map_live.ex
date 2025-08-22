defmodule ZonelyWeb.MapLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.TextToSpeech

  @topic "users:schedule"
  @edge_minutes 60

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
       overlap_panel_expanded: true
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
    {from_utc, to_utc} = frac_to_utc(a, b, socket.assigns.viewer_tz, socket.assigns.base_date)

    statuses =
      socket.assigns.users
      |> Task.async_stream(fn u -> {u.id, classify_user(u, from_utc, to_utc)} end,
           max_concurrency: 8, timeout: 200)
      |> Enum.map(fn {:ok, kv} -> kv end)
      |> Map.new()

    # Convert atoms to tiny ints for payload efficiency
    payload = for {id, st} <- statuses, into: %{}, do: {id, status_int(st)}

    {:noreply, push_event(socket, "overlap_update", %{statuses: payload})}
  end

  @impl true
  def handle_event("commit_range", %{"a_frac" => a, "b_frac" => b}, socket) do
    # For now, just handle the same as hover - could store selected range later
    handle_event("hover_range", %{"a_frac" => a, "b_frac" => b}, socket)
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
        country: country_name(user.country),
        country_code: user.country,
        timezone: user.timezone,
        latitude: Decimal.to_float(user.latitude),
        longitude: Decimal.to_float(user.longitude),
        pronouns: user.pronouns,
        name_native: user.name_native,
        native_language: user.native_language,
        work_start: Calendar.strftime(user.work_start, "%I:%M %p"),
        work_end: Calendar.strftime(user.work_end, "%I:%M %p"),
        profile_picture: fake_profile_picture(user.name)
      }
    end)
    |> Jason.encode!()
  end

  # Generate fake profile pictures using external service
  defp fake_profile_picture(name) do
    # Using DiceBear Avatars API for consistent fake profile pictures
    seed = name |> String.downcase() |> String.replace(" ", "-")

    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{seed}&backgroundColor=b6e3f4,c0aede,d1d4f9&size=64"
  end

  # Time classification helper functions
  defp frac_to_utc(a, b, _viewer_tz, date) do
    {a, b} = if a <= b, do: {a, b}, else: {b, a}
    minutes = fn f -> round(f * 24 * 60) end

    # Use naive datetime for now since timezone data may not be available
    start_naive = NaiveDateTime.new!(date, ~T[00:00:00])

    from_naive = NaiveDateTime.add(start_naive, minutes.(a) * 60, :second)
    to_naive = NaiveDateTime.add(start_naive, minutes.(b) * 60, :second)

    # Convert to UTC DateTime (assuming viewer is in UTC for MVP)
    from_utc = DateTime.from_naive!(from_naive, "Etc/UTC")
    to_utc = DateTime.from_naive!(to_naive, "Etc/UTC")

    {from_utc, to_utc}
  end

  defp classify_user(user, from_utc, to_utc) do
    # For MVP, assume all times are in UTC and compare directly
    # This is a simplified version until timezone data is available

    # Convert UTC times to minutes since midnight
    fmin = from_utc.hour * 60 + from_utc.minute
    tmin = to_utc.hour * 60 + to_utc.minute

    ws = time_to_minutes(user.work_start)
    we = time_to_minutes(user.work_end)

    # Simple overlap check (not timezone-aware for MVP)
    in_work = overlap?(fmin, tmin, ws, we)
    near_edge = within_edge?(fmin, tmin, ws, we, @edge_minutes)

    cond do
      in_work -> :working
      near_edge -> :edge
      true -> :off
    end
  end

  defp overlap?(a1, a2, b1, b2), do: max(a1, b1) < min(a2, b2)

  defp within_edge?(a1, a2, ws, we, edge) do
    # any part of [a1,a2) within edge minutes of ws or we
    near_start = (ws - edge)..(ws + edge)
    near_end = (we - edge)..(we + edge)
    any_in?(a1, a2, near_start) or any_in?(a1, a2, near_end)
  end

  defp any_in?(a1, a2, range) do
    # Handle the case where a2 might be less than a1
    start_range = min(a1, a2 - 1)
    end_range = max(a1, a2 - 1)
    Enum.any?(start_range..end_range, &(&1 in range))
  end

  defp time_to_minutes(%Time{hour: h, minute: m}), do: h * 60 + m

  defp status_int(:working), do: 2
  defp status_int(:edge), do: 1
  defp status_int(:off), do: 0

  # Simple debug function for timezone highlighting
  defp get_debug_timezone_data() do
    [
      %{timezone: "America/New_York", coverage: 0.8, local_start: "09:00:00", local_end: "17:00:00"},
      %{timezone: "Europe/London", coverage: 0.6, local_start: "10:00:00", local_end: "16:00:00"}
    ]
  end



  # Helper function to convert country codes to names
  defp country_name(country_code) do
    case country_code do
      "US" -> "United States"
      "GB" -> "United Kingdom"
      "JP" -> "Japan"
      "IN" -> "India"
      "SE" -> "Sweden"
      "ES" -> "Spain"
      "AU" -> "Australia"
      "EG" -> "Egypt"
      "BR" -> "Brazil"
      "DE" -> "Germany"
      "FR" -> "France"
      "CA" -> "Canada"
      "MX" -> "Mexico"
      "IT" -> "Italy"
      "NL" -> "Netherlands"
      "CH" -> "Switzerland"
      "AT" -> "Austria"
      "BE" -> "Belgium"
      "DK" -> "Denmark"
      "FI" -> "Finland"
      "NO" -> "Norway"
      "PT" -> "Portugal"
      "IE" -> "Ireland"
      "PL" -> "Poland"
      "CZ" -> "Czech Republic"
      "HU" -> "Hungary"
      "GR" -> "Greece"
      "TR" -> "Turkey"
      "RU" -> "Russia"
      "CN" -> "China"
      "KR" -> "South Korea"
      "TH" -> "Thailand"
      "VN" -> "Vietnam"
      "ID" -> "Indonesia"
      "MY" -> "Malaysia"
      "SG" -> "Singapore"
      "PH" -> "Philippines"
      "TW" -> "Taiwan"
      "HK" -> "Hong Kong"
      "NZ" -> "New Zealand"
      "ZA" -> "South Africa"
      "AR" -> "Argentina"
      "CL" -> "Chile"
      "CO" -> "Colombia"
      "PE" -> "Peru"
      "VE" -> "Venezuela"
      _ -> country_code
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed top-0 left-0 w-full h-screen pt-[4rem] z-10">
      <!-- MapLibre GL JS Map Container -->
      <div
        id="map-container"
        class="h-full w-full"
        phx-hook="TeamMap"
        phx-update="ignore"
        data-api-key={@maptiler_api_key}
        data-users={users_to_json(@users)}
      >
      </div>

      <!-- Profile Modal -->
      <div
        :if={@selected_user}
        class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
        phx-click="hide_profile"
      >
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <div class="mt-3">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <h3 class="text-lg font-medium text-gray-900">
                  <%= @selected_user.name %>
                </h3>
                <!-- Pronunciation buttons -->
                <div class="flex items-center gap-1">
                  <!-- English pronunciation button -->
                  <button
                    phx-click="play_english_pronunciation"
                    phx-value-user_id={@selected_user.id}
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
                    :if={@selected_user.name_native && @selected_user.name_native != @selected_user.name}
                    phx-click="play_native_pronunciation"
                    phx-value-user_id={@selected_user.id}
                    class={if TextToSpeech.get_native_language_display_name(@selected_user.country) do
                      "inline-flex items-center justify-center gap-1 px-2 py-1 text-gray-500 hover:text-emerald-600 hover:bg-emerald-50 rounded-full transition-colors text-xs"
                    else
                      "inline-flex items-center justify-center w-6 h-6 text-gray-500 hover:text-emerald-600 hover:bg-emerald-50 rounded-full transition-colors"
                    end}
                    title={"Play #{TextToSpeech.get_native_language_name(@selected_user.country)} pronunciation"}
                  >
                    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"></path>
                    </svg>
                    <span :if={TextToSpeech.get_native_language_display_name(@selected_user.country)} class="font-medium"><%= TextToSpeech.get_native_language_display_name(@selected_user.country) %></span>
                  </button>
                </div>
              </div>
              <button
                phx-click="hide_profile"
                class="text-gray-400 hover:text-gray-600"
              >
                <span class="sr-only">Close</span>
                <.icon name="hero-x-mark" class="h-6 w-6" />
              </button>
            </div>

            <div class="mt-4 space-y-3">
              <!-- Native name display -->
              <div :if={@selected_user.name_native && @selected_user.name_native != @selected_user.name}>
                <label class="block text-sm font-medium text-gray-700">
                  Native Name (<%= TextToSpeech.get_native_language_name(@selected_user.country) %>)
                </label>
                <p class="text-lg text-gray-900 mb-2"><%= @selected_user.name_native %></p>
              </div>

              <div :if={@selected_user.pronouns}>
                <label class="block text-sm font-medium text-gray-700">Pronouns</label>
                <p class="text-sm text-gray-900"><%= @selected_user.pronouns %></p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">Role</label>
                <p class="text-sm text-gray-900"><%= @selected_user.role || "Team Member" %></p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">Location</label>
                <p class="text-sm text-gray-900"><%= @selected_user.country %> • <%= @selected_user.timezone %></p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">Working Hours</label>
                <p class="text-sm text-gray-900">
                  <%= Calendar.strftime(@selected_user.work_start, "%I:%M %p") %> -
                  <%= Calendar.strftime(@selected_user.work_end, "%I:%M %p") %>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Working Hours Overlap Selector (Outside map container) -->
    <div class="fixed bottom-4 left-1/2 transform -translate-x-1/2 z-40 px-4">
      <!-- Toggle Button (always visible) -->
      <div class="flex justify-center mb-2">
        <button
          phx-click="toggle_overlap_panel"
          class={[
            "overlap-panel-toggle bg-white rounded-full shadow-lg border border-gray-200 p-3 hover:shadow-xl",
            "flex items-center gap-2 text-gray-700 hover:text-blue-600"
          ]}
        >
          <svg class={[
            "w-5 h-5 toggle-icon",
            if(@overlap_panel_expanded, do: "rotated", else: "")
          ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
          </svg>
          <span class="text-sm font-medium">
            <%= if @overlap_panel_expanded, do: "Hide Panel", else: "Working Hours Overlap" %>
          </span>
        </button>
      </div>

      <!-- Panel Content -->
      <div class={[
        "bg-white rounded-xl shadow-xl border border-gray-200 max-w-4xl w-full p-6 transition-all duration-300",
        if(@overlap_panel_expanded, do: "opacity-100 scale-100", else: "opacity-0 scale-95 h-0 overflow-hidden p-0")
      ]}>
        <!-- Header -->
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-lg font-semibold text-gray-800">Working Hours Overlap</h3>
            <p class="text-sm text-gray-500">Drag to select a time range and see team availability</p>
          </div>
          <div class="text-right">
            <div class="text-sm font-medium text-gray-700" id="time-display">No selection</div>
            <div class="text-xs text-gray-500" id="duration-display">Drag to select</div>
          </div>
        </div>



        <!-- Time Slider -->
        <div class="relative">
          <!-- Hour labels (top) -->
          <div class="flex justify-between mb-2 text-xs font-medium text-gray-600">
            <%= for hour <- [0, 6, 12, 18] do %>
              <span class="transform -translate-x-1/2">
                <%= if hour == 0, do: "Midnight", else: (if hour == 12, do: "Noon", else: (if hour > 12, do: "#{hour-12}PM", else: "#{hour}AM")) %>
              </span>
            <% end %>
          </div>

          <!-- Main slider area with clear drag target -->
          <div
            id="time-scrubber"
            phx-hook="TimeScrubber"
            class="relative h-16 bg-white rounded-lg border-2 border-dashed border-blue-300 hover:border-blue-500 hover:bg-blue-50/30 transition-all duration-200 cursor-grab active:cursor-grabbing"
          >
            <!-- Hour grid -->
            <div class="absolute inset-2 flex">
              <%= for hour <- 0..23 do %>
                <div class="flex-1 relative">
                  <%= if rem(hour, 6) == 0 do %>
                    <div class="absolute top-0 bottom-0 left-0 w-px bg-blue-300"></div>
                  <% else %>
                    <div class="absolute top-0 bottom-0 left-0 w-px bg-gray-200"></div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Drag instruction -->
            <div class="absolute inset-0 flex items-center justify-center" id="instruction-text">
              <div class="bg-blue-100 text-blue-700 px-4 py-2 rounded-lg border border-blue-200 flex items-center gap-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 15l-2 5L9 9l11 4-5 2zm0 0l5 5M7.188 2.239l.777 2.897M5.136 7.965l-2.898-.777M13.95 4.05l-2.122 2.122m-5.657 5.656l-2.12 2.122"></path>
                </svg>
                <span class="font-medium">Click and drag across hours</span>
              </div>
            </div>

            <!-- Selection highlight -->
            <div id="scrubber-selection" class="absolute inset-y-0 bg-blue-200/60 border-l-2 border-r-2 border-blue-500 hidden">
              <!-- Start handle (draggable) -->
              <div class="absolute left-0 top-1/2 transform -translate-y-1/2 -translate-x-3 w-6 h-10 bg-blue-500 rounded-lg shadow-lg flex items-center justify-center cursor-ew-resize hover:bg-blue-600 transition-colors">
                <div class="w-1 h-4 bg-white rounded"></div>
              </div>
              <!-- End handle (draggable) -->
              <div class="absolute right-0 top-1/2 transform -translate-y-1/2 translate-x-3 w-6 h-10 bg-blue-500 rounded-lg shadow-lg flex items-center justify-center cursor-ew-resize hover:bg-blue-600 transition-colors">
                <div class="w-1 h-4 bg-white rounded"></div>
              </div>
            </div>
          </div>

          <!-- Detailed hour markers -->
          <div class="flex justify-between mt-2 text-xs text-gray-400">
            <%= for hour <- 0..23 do %>
              <%= if rem(hour, 3) == 0 do %>
                <span class="text-center w-0">
                  <%= "#{hour}" %>
                </span>
              <% else %>
                <span class="w-0"></span>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Legend -->
        <div class="mt-4 flex items-center justify-center gap-8 text-sm">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-green-500 rounded-full shadow-sm"></div>
            <span class="text-gray-600">Working</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-yellow-500 rounded-full shadow-sm"></div>
            <span class="text-gray-600">Flexible Hours</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-gray-400 rounded-full shadow-sm"></div>
            <span class="text-gray-600">Off Work</span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

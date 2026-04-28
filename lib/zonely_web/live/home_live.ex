defmodule ZonelyWeb.HomeLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.Audio
  alias Zonely.AvatarService
  alias Zonely.Geography
  alias Zonely.Reachability
  alias Zonely.SayMyNameShareClient

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    live_now = live_now()

    {:ok,
     socket
     |> assign(:page_title, "Map")
     |> assign(:active_tab, :map)
     |> assign(:users, users)
     |> assign(:live_now, live_now)
     |> assign(:preview_at, nil)
     |> assign_effective_time()
     |> assign(:selected_user, nil)
     |> assign(:loading_pronunciation, nil)
     |> assign(:playing_pronunciation, %{})
     |> assign(:name_card_share_urls, %{})
     |> assign(:name_card_share_loading, nil)
     |> assign(:name_card_share_error, nil)
     |> assign(:team_name_list_share_url, nil)
     |> assign(:team_name_list_share_loading, false)
     |> assign(:team_name_list_share_error, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  @impl true
  def handle_event("show_profile", %{"user_id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &("#{&1.id}" == id))

    socket =
      socket
      |> assign(:selected_user, user)
      |> push_event("focus_user", %{user_id: id})

    {:noreply, socket}
  end

  def handle_event("hide_profile", _params, socket) do
    {:noreply, assign(socket, :selected_user, nil)}
  end

  def handle_event("preview_time", params, socket) do
    current_live_now = live_now()

    case parse_preview_at(params, current_live_now) do
      {:ok, preview_at} ->
        {:noreply,
         socket
         |> assign(:live_now, current_live_now)
         |> assign(:preview_at, preview_at)
         |> assign_effective_time()
         |> push_marker_state_update()}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("reset_preview_time", _params, socket) do
    current_live_now = live_now()

    {:noreply,
     socket
     |> assign(:live_now, current_live_now)
     |> assign(:preview_at, nil)
     |> assign_effective_time()
     |> push_marker_state_update()}
  end

  def handle_event("play_english_pronunciation", %{"user_id" => id}, socket) do
    play_pronunciation(socket, id, :english)
  end

  def handle_event("play_native_pronunciation", %{"user_id" => id}, socket) do
    play_pronunciation(socket, id, :native)
  end

  def handle_event("share_name_card", %{"user_id" => id}, socket) do
    case Enum.find(socket.assigns.users, &("#{&1.id}" == id)) do
      nil ->
        {:noreply, assign(socket, :name_card_share_error, "Could not find teammate.")}

      user ->
        socket =
          socket
          |> assign(:name_card_share_loading, id)
          |> assign(:name_card_share_error, nil)

        case SayMyNameShareClient.create_card_share(user) do
          {:ok, %{"share_url" => share_url}} ->
            {:noreply,
             socket
             |> assign(:name_card_share_loading, nil)
             |> assign(
               :name_card_share_urls,
               Map.put(socket.assigns.name_card_share_urls, id, share_url)
             )}

          {:ok, _body} ->
            {:noreply,
             socket
             |> assign(:name_card_share_loading, nil)
             |> assign(:name_card_share_error, "SayMyName did not return a share URL.")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:name_card_share_loading, nil)
             |> assign(:name_card_share_error, share_error_message(reason))}
        end
    end
  end

  def handle_event("share_team_names", _params, socket) do
    socket =
      socket
      |> assign(:team_name_list_share_loading, true)
      |> assign(:team_name_list_share_error, nil)

    case SayMyNameShareClient.create_list_share("Zonely Team", socket.assigns.users) do
      {:ok, %{"share_url" => share_url}} ->
        {:noreply,
         socket
         |> assign(:team_name_list_share_loading, false)
         |> assign(:team_name_list_share_url, share_url)}

      {:ok, _body} ->
        {:noreply,
         socket
         |> assign(:team_name_list_share_loading, false)
         |> assign(:team_name_list_share_error, "SayMyName did not return a team share URL.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:team_name_list_share_loading, false)
         |> assign(:team_name_list_share_error, share_error_message(reason))}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div id="map-page" class="min-h-[100dvh]">
      <section id="global-team-map" class="zonely-map-workspace" aria-label="Global team map">
        <nav class="map-nav-island" aria-label="Map workspace navigation">
          <.link navigate={~p"/"} class="map-nav-brand" aria-current="page">
            <.icon name="hero-globe-alt" class="h-4 w-4" />
            <span>Zonely</span>
          </.link>
          <a href="#team-orbit-panel" class="map-nav-link">
            People
          </a>
        </nav>

        <aside id="now-context-strip" class="now-context-strip" aria-label={strip_aria_label(@preview_at)}>
          <div>
            <p class="context-eyebrow">{strip_mode_label(@preview_at)}</p>
            <p class="context-title">{strip_reachable_label(@reachability.working, @preview_at)}</p>
          </div>
          <div class="context-meta">
            <span>{map_size(@reachability.timezones)} zones</span>
            <span>{Reachability.format_count(@reachability.edge, "near transition")}</span>
            <span>{strip_time_label(@effective_at, @preview_at)}</span>
          </div>
        </aside>

        <aside id="team-orbit-panel" class="team-orbit-panel" aria-label="Team orbit">
          <div class="orbit-header">
            <div>
              <p class="context-eyebrow">Team orbit</p>
              <h2>{length(@users)} teammates</h2>
            </div>
            <div class="orbit-actions">
              <span class="orbit-live-pill">{Reachability.format_count(@reachability.working, orbit_pill_label(@preview_at))}</span>
              <button
                type="button"
                id="share-team-names"
                class="orbit-share-button"
                phx-click="share_team_names"
                disabled={@team_name_list_share_loading}
                data-testid="share-team-names"
              >
                <.icon
                  name={if @team_name_list_share_loading, do: "hero-arrow-path", else: "hero-share"}
                  class={if @team_name_list_share_loading, do: "h-4 w-4 animate-spin", else: "h-4 w-4"}
                />
                <span>{if @team_name_list_share_loading, do: "Sharing", else: "Share"}</span>
              </button>
              <button
                :if={@team_name_list_share_url}
                type="button"
                id="copy-team-name-list-share"
                class="orbit-copy-button"
                phx-hook="Clipboard"
                data-clipboard-text={@team_name_list_share_url}
                data-testid="copy-team-name-list-share"
              >
                <.icon name="hero-clipboard" class="h-4 w-4" />
                <span>Copy</span>
              </button>
            </div>
          </div>

          <p :if={@team_name_list_share_error} class="name-share-error px-4 pb-2">
            {@team_name_list_share_error}
          </p>

          <div :if={@users == []} id="team-orbit-empty" class="orbit-empty">
            Add teammates with location and work hours to place them on the map.
          </div>

          <div id="team-orbit-list" class="orbit-list">
            <button
              :for={user <- @users}
              id={"team-orbit-user-#{user.id}"}
              type="button"
              class="orbit-row"
              phx-click="show_profile"
              phx-value-user_id={user.id}
              data-testid="team-orbit-row"
            >
              <span class={["orbit-status-dot", Reachability.orbit_status_class(user, @effective_at)]}></span>
              <span class="orbit-copy">
                <span class="orbit-name">{user.name}</span>
                <span class="orbit-context">
                  {Reachability.local_time_label(user.timezone, @effective_at)} · {Geography.country_name(user.country)} · {Reachability.status_label(user, @effective_at)}
                </span>
              </span>
              <span class="orbit-offset">{Reachability.offset_label(user.timezone, @effective_at)}</span>
            </button>
          </div>
        </aside>

        <div
          id="map-container"
          class="zonely-map-canvas"
          phx-hook="TeamMap"
          phx-update="ignore"
          data-users={@map_users_json}
          data-testid="team-map"
        >
          <div class="map-loading-state">
            <div class="map-loading-grid"></div>
            <p>Loading live team map</p>
          </div>
        </div>

        <div id="map-time-rail" class="map-time-rail" aria-label="Time preview rail">
          <div class="rail-header">
            <span>Preview range</span>
            <span>{@rail.window_label}</span>
          </div>
          <form
            id="map-time-rail-form"
            phx-change="preview_time"
            phx-throttle="250"
            aria-describedby="map-time-rail-status map-time-rail-ticks"
          >
            <div class="rail-track">
              <div
                id="map-time-rail-context"
                class="rail-context-markers"
                aria-label="Computed teammate daylight and work-window markers"
              >
                <span
                  :for={segment <- @rail.segments}
                  class={["rail-segment", segment.class]}
                  style={segment.style}
                  data-kind={segment.kind}
                  data-user-id={segment.user_id}
                  data-start-at={segment.start_at}
                  data-end-at={segment.end_at}
                  data-left-percent={segment.left_percent}
                  data-width-percent={segment.width_percent}
                  role="img"
                  aria-label={segment.label}
                >
                </span>
              </div>
              <input
                id="map-time-rail-control"
                class="rail-control"
                type="range"
                name="offset_minutes"
                min="0"
                max="1440"
                step="15"
                value={@rail.offset_minutes}
                phx-debounce="250"
                aria-label="Preview teammate reachability time"
                aria-valuetext={@rail.value_text}
              />
            </div>
          </form>
          <div id="map-time-rail-status" class="rail-status" aria-live="polite">
            {@rail.status_text}
          </div>
          <div id="map-time-rail-ticks" class="rail-labels" aria-label={@rail.tick_description}>
            <span :for={tick <- @rail.ticks} data-offset-minutes={tick.offset_minutes}>
              {tick.label}
            </span>
          </div>
          <button
            :if={@preview_at}
            type="button"
            id="map-time-rail-reset"
            class="rail-reset-button"
            phx-click="reset_preview_time"
          >
            Reset to now
          </button>
        </div>
      </section>

      <div
        :if={@selected_user}
        id="profile-panel"
        class="profile-panel-shell"
      >
        <button
          type="button"
          class="profile-panel-backdrop"
          phx-click="hide_profile"
          aria-label="Close teammate context"
        >
        </button>
        <div class="profile-panel-position">
          <.profile_card
            user={@selected_user}
            effective_at={@effective_at}
            loading_pronunciation={@loading_pronunciation}
            playing_pronunciation={@playing_pronunciation}
            name_share_url={Map.get(@name_card_share_urls, "#{@selected_user.id}")}
            name_share_loading={@name_card_share_loading == "#{@selected_user.id}"}
            name_share_error={@name_card_share_error}
          />
        </div>
      </div>
    </div>
    """
  end

  defp apply_action(socket, _action) do
    socket
    |> assign(:page_title, "Map")
    |> assign(:active_tab, :map)
  end

  defp assign_effective_time(socket) do
    effective_at = Reachability.effective_at(socket.assigns.preview_at, socket.assigns.live_now)

    socket
    |> assign(:effective_at, effective_at)
    |> assign(
      :map_users_json,
      marker_payload(socket.assigns.users, effective_at, nil) |> Jason.encode!()
    )
    |> assign(:reachability, Reachability.summary(socket.assigns.users, effective_at))
    |> assign(
      :rail,
      rail_state(
        socket.assigns.live_now,
        socket.assigns.preview_at,
        effective_at,
        socket.assigns.users
      )
    )
  end

  defp push_marker_state_update(socket) do
    push_event(socket, "team_marker_states", marker_state_payload(socket))
  end

  defp marker_state_payload(socket) do
    selected_user_id = selected_user_id(socket.assigns.selected_user)

    %{
      effective_at: DateTime.to_iso8601(socket.assigns.effective_at),
      mode: if(socket.assigns.preview_at, do: "preview", else: "live"),
      selected_user_id: selected_user_id,
      markers:
        marker_payload(
          socket.assigns.users,
          socket.assigns.effective_at,
          selected_user_id
        )
    }
  end

  defp selected_user_id(%{id: id}), do: id
  defp selected_user_id(_selected_user), do: nil

  defp live_now do
    case Application.get_env(:zonely, :home_live_now) do
      %DateTime{} = now -> DateTime.truncate(now, :second)
      fun when is_function(fun, 0) -> fun.() |> DateTime.truncate(:second)
      _other -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp parse_preview_at(%{"offset_minutes" => value}, %DateTime{} = live_now) do
    case Integer.parse(to_string(value)) do
      {minutes, ""} ->
        preview_at =
          live_now
          |> DateTime.add(clamp(minutes, 0, 1440) * 60, :second)
          |> DateTime.truncate(:second)

        {:ok, preview_or_nil(preview_at, live_now)}

      _other ->
        :error
    end
  end

  defp parse_preview_at(%{"preview_at" => value}, %DateTime{} = live_now) when is_binary(value) do
    with {:ok, datetime, _offset} <- DateTime.from_iso8601(value) do
      normalized =
        datetime
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.truncate(:second)

      preview_at =
        clamp_datetime(normalized, live_now, DateTime.add(live_now, 24 * 60 * 60, :second))

      {:ok, preview_or_nil(preview_at, live_now)}
    else
      _error -> :error
    end
  end

  defp parse_preview_at(_params, _live_now), do: :error

  defp clamp_datetime(%DateTime{} = datetime, %DateTime{} = min, %DateTime{} = max) do
    cond do
      DateTime.compare(datetime, min) == :lt -> min
      DateTime.compare(datetime, max) == :gt -> max
      true -> datetime
    end
  end

  defp preview_or_nil(%DateTime{} = preview_at, %DateTime{} = live_now) do
    if DateTime.compare(preview_at, live_now) == :eq, do: nil, else: preview_at
  end

  defp clamp(value, min, _max) when value < min, do: min
  defp clamp(value, _min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value

  defp rail_state(%DateTime{} = live_now, preview_at, %DateTime{} = effective_at, users) do
    offset_minutes =
      effective_at
      |> DateTime.diff(live_now, :second)
      |> div(60)
      |> clamp(0, 1440)

    %{
      offset_minutes: offset_minutes,
      window_label:
        "#{format_rail_time(live_now)} to #{format_rail_time(DateTime.add(live_now, 24 * 60 * 60, :second))} tomorrow",
      value_text: rail_value_text(effective_at, preview_at),
      status_text: rail_status_text(effective_at, preview_at),
      ticks: rail_ticks(live_now),
      tick_description: rail_tick_description(live_now),
      segments: rail_segments(users, live_now)
    }
  end

  defp rail_segments(users, %DateTime{} = live_now) when is_list(users) do
    window_end = DateTime.add(live_now, 24 * 60 * 60, :second)

    users
    |> Enum.flat_map(fn user ->
      daylight_segments(user, live_now, window_end) ++
        work_window_segments(user, live_now, window_end)
    end)
    |> Enum.sort_by(&{&1.start_at, &1.kind, &1.user_id})
  end

  defp work_window_segments(user, %DateTime{} = window_start, %DateTime{} = window_end) do
    build_local_time_segments(
      user,
      window_start,
      window_end,
      user.work_start,
      user.work_end,
      "work-window"
    )
  end

  defp daylight_segments(user, %DateTime{} = window_start, %DateTime{} = window_end) do
    build_local_time_segments(
      user,
      window_start,
      window_end,
      ~T[08:00:00],
      ~T[17:00:00],
      "daylight"
    )
  end

  defp build_local_time_segments(
         user,
         window_start,
         window_end,
         %Time{} = starts_at,
         %Time{} = ends_at,
         kind
       ) do
    user.timezone
    |> candidate_local_dates(window_start, window_end)
    |> Enum.flat_map(fn date ->
      with {:ok, local_start} <- DateTime.new(date, starts_at, user.timezone),
           {:ok, local_end} <- DateTime.new(date, ends_at, user.timezone),
           {:ok, utc_start} <- DateTime.shift_zone(local_start, "Etc/UTC"),
           {:ok, utc_end} <- DateTime.shift_zone(local_end, "Etc/UTC"),
           {:ok, segment} <-
             clipped_rail_segment(user, kind, utc_start, utc_end, window_start, window_end) do
        [segment]
      else
        _error -> []
      end
    end)
  end

  defp build_local_time_segments(_user, _window_start, _window_end, _starts_at, _ends_at, _kind),
    do: []

  defp candidate_local_dates(timezone, %DateTime{} = window_start, %DateTime{} = window_end)
       when is_binary(timezone) do
    with {:ok, local_start} <- DateTime.shift_zone(window_start, timezone),
         {:ok, local_end} <- DateTime.shift_zone(window_end, timezone) do
      Date.range(
        Date.add(DateTime.to_date(local_start), -1),
        Date.add(DateTime.to_date(local_end), 1)
      )
      |> Enum.to_list()
    else
      _error -> []
    end
  end

  defp candidate_local_dates(_timezone, _window_start, _window_end), do: []

  defp clipped_rail_segment(
         user,
         kind,
         %DateTime{} = start_at,
         %DateTime{} = end_at,
         window_start,
         window_end
       ) do
    clipped_start = max_datetime(start_at, window_start)
    clipped_end = min_datetime(end_at, window_end)

    if DateTime.compare(clipped_start, clipped_end) == :lt do
      left_percent = rail_percent(clipped_start, window_start)
      width_percent = rail_width_percent(clipped_start, clipped_end)

      {:ok,
       %{
         kind: kind,
         class: rail_segment_class(kind),
         user_id: user.id,
         start_at: DateTime.to_iso8601(clipped_start),
         end_at: DateTime.to_iso8601(clipped_end),
         left_percent: format_percent(left_percent),
         width_percent: format_percent(width_percent),
         style:
           "left: #{format_percent(left_percent)}%; width: #{format_percent(width_percent)}%;",
         label: rail_segment_label(user, kind, clipped_start, clipped_end)
       }}
    else
      :error
    end
  end

  defp rail_percent(%DateTime{} = datetime, %DateTime{} = window_start) do
    datetime
    |> DateTime.diff(window_start, :second)
    |> Kernel./(24 * 60 * 60)
    |> Kernel.*(100)
  end

  defp rail_width_percent(%DateTime{} = start_at, %DateTime{} = end_at) do
    end_at
    |> DateTime.diff(start_at, :second)
    |> Kernel./(24 * 60 * 60)
    |> Kernel.*(100)
  end

  defp rail_segment_class("daylight"), do: "rail-segment-daylight"
  defp rail_segment_class("work-window"), do: "rail-segment-overlap"

  defp rail_segment_label(user, "daylight", start_at, end_at) do
    "#{user.name} daylight from #{format_rail_time(start_at)} to #{format_rail_time(end_at)} UTC"
  end

  defp rail_segment_label(user, "work-window", start_at, end_at) do
    "#{user.name} work window from #{format_rail_time(start_at)} to #{format_rail_time(end_at)} UTC"
  end

  defp min_datetime(first, second) do
    if DateTime.compare(first, second) == :gt, do: second, else: first
  end

  defp max_datetime(first, second) do
    if DateTime.compare(first, second) == :lt, do: second, else: first
  end

  defp format_percent(value) do
    value
    |> Float.round(4)
    |> :erlang.float_to_binary(decimals: 4)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp rail_ticks(%DateTime{} = live_now) do
    [0, 360, 720, 1080, 1440]
    |> Enum.map(fn offset ->
      tick_at = DateTime.add(live_now, offset * 60, :second)

      label =
        if offset == 0,
          do: format_rail_time(tick_at),
          else: relative_tick_label(tick_at, live_now)

      %{offset_minutes: offset, label: label}
    end)
  end

  defp rail_tick_description(%DateTime{} = live_now) do
    end_at = DateTime.add(live_now, 24 * 60 * 60, :second)

    "Bounded from live now at #{format_rail_time(live_now)} UTC through #{format_rail_time(end_at)} UTC tomorrow"
  end

  defp relative_tick_label(%DateTime{} = tick_at, %DateTime{} = live_now) do
    suffix =
      if Date.compare(DateTime.to_date(tick_at), DateTime.to_date(live_now)) == :gt,
        do: " tomorrow",
        else: ""

    "#{format_rail_time(tick_at)}#{suffix}"
  end

  defp rail_status_text(%DateTime{} = effective_at, nil) do
    "Live now at #{format_rail_time(effective_at)} UTC. Preview range runs through #{format_rail_time(DateTime.add(effective_at, 24 * 60 * 60, :second))} tomorrow."
  end

  defp rail_status_text(%DateTime{} = effective_at, %DateTime{}) do
    "Simulated preview at #{format_utc_datetime(effective_at)}."
  end

  defp rail_value_text(%DateTime{} = effective_at, nil),
    do: "Live now, #{format_rail_time(effective_at)} UTC"

  defp rail_value_text(%DateTime{} = effective_at, %DateTime{}),
    do: "Preview at #{format_utc_datetime(effective_at)}"

  defp strip_aria_label(nil), do: "Current team context"
  defp strip_aria_label(%DateTime{}), do: "Previewed team context"

  defp strip_mode_label(nil), do: "Now"
  defp strip_mode_label(%DateTime{}), do: "Preview"

  defp strip_reachable_label(count, nil), do: Reachability.reachable_label(count)
  defp strip_reachable_label(1, %DateTime{}), do: "1 teammate reachable in preview"
  defp strip_reachable_label(count, %DateTime{}), do: "#{count} teammates reachable in preview"

  defp orbit_pill_label(nil), do: "reachable"
  defp orbit_pill_label(%DateTime{}), do: "preview reachable"

  defp strip_time_label(%DateTime{} = effective_at, nil),
    do: "Live #{format_rail_time(effective_at)} UTC"

  defp strip_time_label(%DateTime{} = effective_at, %DateTime{}),
    do: "Simulated #{format_rail_time(effective_at)} UTC"

  defp format_rail_time(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%H:%M")

  defp format_utc_datetime(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")

  defp play_pronunciation(socket, id, type) do
    case Enum.find(socket.assigns.users, &("#{&1.id}" == id)) do
      nil ->
        {:noreply, socket}

      user ->
        event =
          case type do
            :native -> Audio.play_native_pronunciation(user)
            :english -> Audio.play_english_pronunciation(user)
          end

        source = playback_source(event)

        {:noreply,
         socket
         |> assign(:playing_pronunciation, %{id => %{type: Atom.to_string(type), source: source}})
         |> push_event(elem(event, 0) |> Atom.to_string(), elem(event, 1))}
    end
  end

  defp playback_source({:play_audio, _data}), do: "audio"
  defp playback_source({:play_sequence, _data}), do: "audio"
  defp playback_source({:play_tts_audio, _data}), do: "tts"
  defp playback_source({:play_tts, _data}), do: "tts"

  defp share_error_message(:missing_api_key),
    do: "Missing PRONUNCIATION_API_KEY for SayMyName sharing."

  defp share_error_message(:unauthorized), do: "SayMyName rejected the configured API key."

  defp share_error_message({:validation_failed, _body}),
    do: "SayMyName could not validate this profile."

  defp share_error_message(_reason), do: "Could not create SayMyName share right now."

  defp marker_payload(users, %DateTime{} = effective_at, selected_user_id) do
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
        latitude: coordinate_to_float(user.latitude),
        longitude: coordinate_to_float(user.longitude),
        work_start: format_time(user.work_start),
        work_end: format_time(user.work_end),
        status: Reachability.marker_state(user, effective_at),
        selected: user.id == selected_user_id,
        profile_picture: AvatarService.generate_avatar_url(user.name, 64)
      }
    end)
  end

  defp coordinate_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp coordinate_to_float(value) when is_number(value), do: value

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp format_time(_time), do: nil
end

defmodule ZonelyWeb.HomeLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.Audio
  alias Zonely.AvatarService
  alias Zonely.Geography
  alias Zonely.Reachability

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    {:ok,
     socket
     |> assign(:page_title, "Map")
     |> assign(:active_tab, :map)
     |> assign(:users, users)
     |> assign(:map_users_json, users_to_json(users))
     |> assign(:reachability, Reachability.summary(users))
     |> assign(:selected_user, nil)
     |> assign(:loading_pronunciation, nil)
     |> assign(:playing_pronunciation, %{})}
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

  def handle_event("play_english_pronunciation", %{"user_id" => id}, socket) do
    play_pronunciation(socket, id, :english)
  end

  def handle_event("play_native_pronunciation", %{"user_id" => id}, socket) do
    play_pronunciation(socket, id, :native)
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

        <aside id="now-context-strip" class="now-context-strip" aria-label="Current team context">
          <div>
            <p class="context-eyebrow">Now</p>
            <p class="context-title">{Reachability.reachable_label(@reachability.working)}</p>
          </div>
          <div class="context-meta">
            <span>{map_size(@reachability.timezones)} zones</span>
            <span>{Reachability.format_count(@reachability.edge, "near transition")}</span>
          </div>
        </aside>

        <aside id="team-orbit-panel" class="team-orbit-panel" aria-label="Team orbit">
          <div class="orbit-header">
            <div>
              <p class="context-eyebrow">Team orbit</p>
              <h2>{length(@users)} teammates</h2>
            </div>
            <span class="orbit-live-pill">{Reachability.format_count(@reachability.working, "reachable")}</span>
          </div>

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
              <span class={["orbit-status-dot", Reachability.orbit_status_class(user)]}></span>
              <span class="orbit-copy">
                <span class="orbit-name">{user.name}</span>
                <span class="orbit-context">
                  {Reachability.local_time_label(user.timezone)} · {Geography.country_name(user.country)} · {Reachability.status_label(user)}
                </span>
              </span>
              <span class="orbit-offset">{Reachability.offset_label(user.timezone)}</span>
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

        <div id="map-time-rail" class="map-time-rail" aria-label="Time context rail">
          <div class="rail-header">
            <span>Local day</span>
            <span>Overlap window</span>
          </div>
          <div class="rail-track">
            <span class="rail-night"></span>
            <span class="rail-daylight"></span>
            <span class="rail-overlap"></span>
            <span class="rail-thumb" aria-hidden="true"></span>
          </div>
          <div class="rail-labels">
            <span>06:12</span>
            <span>Now</span>
            <span>18:47</span>
          </div>
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
        <div class="profile-panel-position" phx-click-away="hide_profile">
          <.profile_card
            user={@selected_user}
            loading_pronunciation={@loading_pronunciation}
            playing_pronunciation={@playing_pronunciation}
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
        latitude: coordinate_to_float(user.latitude),
        longitude: coordinate_to_float(user.longitude),
        work_start: format_time(user.work_start),
        work_end: format_time(user.work_end),
        status: Reachability.marker_state(user),
        profile_picture: AvatarService.generate_avatar_url(user.name, 64)
      }
    end)
    |> Jason.encode!()
  end

  defp coordinate_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp coordinate_to_float(value) when is_number(value), do: value

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp format_time(_time), do: nil
end

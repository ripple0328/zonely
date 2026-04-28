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

    {:ok,
     socket
     |> assign(:page_title, "Map")
     |> assign(:active_tab, :map)
     |> assign(:users, users)
     |> assign(:map_users_json, users_to_json(users))
     |> assign(:reachability, Reachability.summary(users))
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
            <div class="orbit-actions">
              <span class="orbit-live-pill">{Reachability.format_count(@reachability.working, "reachable")}</span>
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

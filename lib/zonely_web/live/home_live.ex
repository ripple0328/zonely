defmodule ZonelyWeb.HomeLive do
  use ZonelyWeb, :live_view

  alias Phoenix.LiveView.JS
  alias Zonely.Accounts
  alias Zonely.Accounts.Team
  alias Zonely.Audio
  alias Zonely.AvatarService
  alias Zonely.Drafts
  alias Zonely.Geography
  alias Zonely.NameProfileContract
  alias Zonely.Reachability
  alias Zonely.SayMyNameShareClient

  @impl true
  def mount(_params, _session, socket) do
    live_now = live_now()

    {:ok,
     socket
     |> assign(:page_title, "Map")
     |> assign(:active_tab, :map)
     |> assign(:users, [])
     |> assign(:teams, [])
     |> assign(:active_team, nil)
     |> assign(:team_member_counts, %{})
     |> assign(:team_scope_name, "All teammates")
     |> assign(:team_scope_count, 0)
     |> assign(:live_now, live_now)
     |> assign(:preview_at, nil)
     |> assign(:selected_user_ids, [])
     |> assign(:selected_user, nil)
     |> assign(:team_switcher_open, false)
     |> assign(:team_orbit_open, true)
     |> assign_effective_time()
     |> assign(:loading_pronunciation, nil)
     |> assign(:playing_pronunciation, %{})
     |> assign(:name_card_share_urls, %{})
     |> assign(:name_card_share_loading, nil)
     |> assign(:name_card_share_error, nil)
     |> assign(:team_share_loading, false)
     |> assign(:team_share_error, nil)
     |> assign(:current_origin, ZonelyWeb.Endpoint.url())
     |> assign(:share_preview, nil)
     |> assign(:team_create_modal_open, false)
     |> assign(:team_create_form, team_create_form())
     |> assign(:team_invite_modal_open, false)
     |> assign(:team_invite_target_team, nil)
     |> assign(:team_invite_form, to_form(%{}, as: :packet))}
  end

  @impl true
  def handle_params(params, uri, socket) do
    previous_team_id = active_team_id(socket.assigns.active_team)

    socket =
      socket
      |> assign(:current_origin, current_origin(uri))
      |> assign_team_context(params)
      |> apply_action(socket.assigns.live_action, params)

    team_changed? = team_context_changed?(previous_team_id, socket.assigns.active_team)

    socket =
      if team_changed? do
        socket
        |> assign(:team_switcher_open, false)
        |> assign(:team_orbit_open, true)
      else
        socket
      end

    socket =
      if connected?(socket) and
           team_changed? do
        push_marker_state_update(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_profile", %{"user_id" => id}, socket) do
    selected_user_ids = user_ids_from_param(id, socket.assigns.users) |> Enum.take(1)
    user = selected_user(socket.assigns.users, selected_user_ids)

    socket =
      socket
      |> assign(:selected_user_ids, selected_user_ids)
      |> assign(:selected_user, user)
      |> assign_effective_time()
      |> push_event("focus_user", %{user_id: id})
      |> push_marker_state_update()

    {:noreply, socket}
  end

  def handle_event("hide_profile", _params, socket) do
    {:noreply, clear_selection(socket)}
  end

  def handle_event("toggle_selected_user", %{"user_id" => id}, socket) do
    selected_user_ids =
      toggle_selected_user_id(socket.assigns.selected_user_ids, id, socket.assigns.users)

    {:noreply,
     socket
     |> assign(:selected_user_ids, selected_user_ids)
     |> assign(:selected_user, nil)
     |> assign_effective_time()
     |> push_marker_state_update()}
  end

  def handle_event("remove_selected_user", %{"user_id" => id}, socket) do
    ids_to_remove = user_ids_from_param(id, socket.assigns.users)
    selected_user_ids = socket.assigns.selected_user_ids -- ids_to_remove

    {:noreply,
     socket
     |> assign(:selected_user_ids, selected_user_ids)
     |> assign(:selected_user, nil)
     |> assign_effective_time()
     |> push_marker_state_update()}
  end

  def handle_event("clear_selected_users", _params, socket) do
    {:noreply, clear_selection(socket)}
  end

  def handle_event("toggle_team_switcher", _params, socket) do
    team_switcher_open = !socket.assigns.team_switcher_open

    {:noreply,
     socket
     |> assign(:team_switcher_open, team_switcher_open)
     |> assign(
       :team_orbit_open,
       if(team_switcher_open, do: false, else: socket.assigns.team_orbit_open)
     )}
  end

  def handle_event("select_team_scope", %{"team_id" => team_id}, socket) do
    {:noreply,
     socket
     |> assign(:team_switcher_open, false)
     |> assign(:team_orbit_open, true)
     |> push_patch(to: ~p"/?team=#{team_id}")}
  end

  def handle_event("create_team", %{"team" => team_params}, socket) do
    case Accounts.create_team(team_params) do
      {:ok, team} ->
        {:noreply,
         socket
         |> put_flash(:info, "Team created.")
         |> assign(:team_create_modal_open, false)
         |> push_patch(to: ~p"/?team=#{team.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :team_create_form, to_form(changeset, as: :team))}
    end
  end

  def handle_event("toggle_team_orbit", _params, socket) do
    team_orbit_open = !socket.assigns.team_orbit_open

    socket =
      socket
      |> assign(
        :team_switcher_open,
        if(team_orbit_open, do: false, else: socket.assigns.team_switcher_open)
      )
      |> assign(:team_orbit_open, team_orbit_open)

    if team_orbit_open do
      {:noreply, push_event(socket, "focus_team_orbit", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("preview_time", params, socket) do
    current_live_now = live_now()

    if duplicate_preview_offset?(params, socket) do
      {:noreply, socket}
    else
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
        payload = NameProfileContract.from_person(user)

        socket =
          socket
          |> assign(:name_card_share_loading, id)
          |> assign(:name_card_share_error, nil)

        case SayMyNameShareClient.create_card_share(payload) do
          {:ok, %{"share_url" => share_url} = body} ->
            {:noreply,
             socket
             |> assign(:name_card_share_loading, nil)
             |> assign(:share_preview, share_preview_for_card(payload, share_url, body))
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

  def handle_event("share_team", _params, socket) do
    case socket.assigns.active_team do
      %Team{id: team_id, name: team_name} ->
        socket =
          socket
          |> assign(:team_share_loading, true)
          |> assign(:team_share_error, nil)

        attrs = %{
          name: team_name,
          published_team_id: team_id,
          source_kind: "zonely_team_invite"
        }

        case Drafts.create_team_draft(attrs) do
          {:ok, %{invite_token: invite_token}} ->
            invite_path = ~p"/team-invites/invite/#{invite_token}"
            invite_url = absolute_url(socket.assigns.current_origin, invite_path)

            {:noreply,
             socket
             |> assign(:team_share_loading, false)
             |> assign(:share_preview, share_preview_for_team_invite(team_name, invite_url))}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(:team_share_loading, false)
             |> assign(:team_share_error, "Could not create a Zonely team invite right now.")}
        end

      _no_team ->
        {:noreply, assign(socket, :team_share_error, "Create or select a team before sharing.")}
    end
  end

  def handle_event("close_share_preview", _params, socket) do
    {:noreply, assign(socket, :share_preview, nil)}
  end

  def handle_event("copy_share_preview", _params, socket) do
    {:noreply,
     socket
     |> assign(:share_preview, nil)
     |> put_flash(:info, "Share link copied.")}
  end

  def handle_event("lv:clear-flash", %{"key" => "info"}, socket) do
    {:noreply, clear_flash(socket, :info)}
  end

  def handle_event("lv:clear-flash", %{"key" => "error"}, socket) do
    {:noreply, clear_flash(socket, :error)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div id="map-page" class="min-h-[100dvh]" phx-hook="FocusTeamOrbit">
      <section id="global-team-map" class="zonely-map-workspace" aria-label="Global team map">
        <nav class="map-nav-island" aria-label="Map workspace navigation">
          <div class="map-nav-brand" aria-current="page" aria-label="Zonely">
            <img class="map-nav-logo" src={~p"/images/zonely-logo-transparent.svg"} alt="" aria-hidden="true" />
          </div>
          <div id="team-switcher" class={["map-team-switcher", @team_switcher_open && "is-open"]}>
            <button
              type="button"
              id="toggle-team-switcher"
              class="team-switcher-trigger"
              phx-click="toggle_team_switcher"
              aria-label="Switch team"
              aria-haspopup="menu"
              aria-controls="team-switcher-menu"
              aria-expanded={to_string(@team_switcher_open)}
            >
              <.icon name="hero-building-office-2" class="h-4 w-4" />
              <span class="team-switcher-label">{@team_scope_name}</span>
              <span class="team-switcher-count">{@team_scope_count}</span>
              <.icon name="hero-chevron-down" class="h-3.5 w-3.5" />
            </button>
            <div
              id="team-switcher-menu"
              class="team-switcher-menu"
              role="menu"
              hidden={!@team_switcher_open}
              aria-hidden={to_string(!@team_switcher_open)}
            >
              <button
                :for={team <- @teams}
                type="button"
                id={"team-switcher-option-#{team.id}"}
                phx-click="select_team_scope"
                phx-value-team_id={team.id}
                role="menuitem"
                class={["team-switcher-option", active_team?(team, @active_team) && "is-active"]}
              >
                <span>{team.name}</span>
                <small>{Map.get(@team_member_counts, team.id, 0)}</small>
              </button>
              <.link
                id="create-new-team"
                patch={new_team_path(@active_team)}
                role="menuitem"
                class="team-switcher-option is-create"
              >
                <.icon name="hero-plus" class="h-4 w-4" />
                <span>New team</span>
              </.link>
            </div>
          </div>
          <button
            type="button"
            id="toggle-team-orbit"
            class={["map-nav-link", @team_orbit_open && "is-active"]}
            phx-click="toggle_team_orbit"
            aria-controls="team-orbit-panel"
            aria-expanded={to_string(@team_orbit_open)}
          >
            <.icon name="hero-users" class="h-4 w-4" />
            People
          </button>
        </nav>

        <aside
          id="team-orbit-panel"
          class="team-orbit-panel"
          aria-label="Team orbit"
          hidden={!@team_orbit_open}
          aria-hidden={to_string(!@team_orbit_open)}
          tabindex="-1"
        >
          <div class="orbit-header">
            <div class="orbit-title-block">
              <h2 id="team-scope-title">People</h2>
              <p>
                <span>{team_member_label(@team_scope_count)}</span>
                <span aria-hidden="true">·</span>
                <span>{Reachability.format_count(@reachability.working, orbit_pill_label(@preview_at))}</span>
              </p>
            </div>
            <div class="orbit-header-actions">
              <button
                type="button"
                id="share-team"
                class="orbit-share-button"
                phx-click="share_team"
                disabled={@team_share_loading}
                data-testid="share-team"
                title={if @team_share_loading, do: "Creating team invite link", else: "Share team invite link"}
                aria-label={if @team_share_loading, do: "Creating team invite link", else: "Share team invite link"}
              >
                <.icon
                  name={if @team_share_loading, do: "hero-arrow-path", else: "hero-share"}
                  class={if @team_share_loading, do: "h-4 w-4 animate-spin", else: "h-4 w-4"}
                />
              </button>
            </div>
          </div>

          <p :if={@team_share_error} class="name-share-error px-4 pb-2">
            {@team_share_error}
          </p>

          <section :if={@orbit_users == []} id="team-onboarding-panel" class="orbit-onboarding">
            <p id="team-orbit-empty" class="orbit-empty">{team_empty_message(@active_team)}</p>
            <div class="orbit-onboarding-actions">
              <.link
                :if={@active_team}
                id="invite-team-members"
                patch={team_invite_new_path(@active_team)}
                class="orbit-onboarding-primary"
              >
                <.icon name="hero-user-plus" class="h-4 w-4" />
                <span>Invite people</span>
              </.link>
              <.link
                :if={is_nil(@active_team)}
                id="create-first-team"
                patch={new_team_path(nil)}
                class="orbit-onboarding-primary"
              >
                <.icon name="hero-plus" class="h-4 w-4" />
                <span>Create team</span>
              </.link>
              <form
                id="saymyname-import-form"
                class="onboarding-import-form"
                action={~p"/imports/saymyname"}
                method="get"
              >
                <input :if={@active_team} type="hidden" name="team_id" value={@active_team.id} />
                <input
                  class="onboarding-field"
                  name="url"
                  type="url"
                  placeholder="Import person/team from SayMyName"
                  aria-label="SayMyName person or team URL"
                  required
                />
                <button
                  class="onboarding-submit"
                  type="submit"
                  aria-label="Import person/team from SayMyName"
                  title="Import person/team from SayMyName"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" />
                </button>
              </form>
            </div>
          </section>

          <div id="team-orbit-list" class="orbit-list">
            <div
              :for={user <- @orbit_users}
              id={"team-orbit-item-#{user.id}"}
              class="orbit-list-item"
            >
              <button
                id={"team-orbit-user-#{user.id}"}
                type="button"
                class={["orbit-row", selected_user?(@selected_user_ids, user.id) && "is-selected"]}
                phx-click="toggle_selected_user"
                phx-value-user_id={user.id}
                data-testid="team-orbit-row"
                data-team-orbit-user-id={user.id}
                aria-pressed={selected_user?(@selected_user_ids, user.id)}
                aria-label={select_button_label(@selected_user_ids, user)}
              >
                <span class="orbit-select-box" aria-hidden="true">
                  <.icon
                    :if={selected_user?(@selected_user_ids, user.id)}
                    name="hero-check"
                    class="h-3.5 w-3.5"
                  />
                </span>
                <span class={["orbit-status-dot", Reachability.orbit_status_class(user, @effective_at)]}></span>
                <span class="orbit-copy">
                  <span class="orbit-name">{user.name}</span>
                  <span class="orbit-context">
                    {Reachability.local_time_label(user.timezone, @effective_at)} · {Geography.country_name(user.country)} · {Reachability.status_label(user, @effective_at)}
                  </span>
                </span>
                <span class="orbit-offset">{Reachability.offset_label(user.timezone, @effective_at)}</span>
              </button>
              <button
                id={"team-orbit-view-#{user.id}"}
                type="button"
                class="orbit-view-button"
                phx-click="show_profile"
                phx-value-user_id={user.id}
                title={"Open #{user.name} details"}
                aria-label={"Open #{user.name} details"}
              >
                <.icon name="hero-chevron-right" class="h-4 w-4" />
              </button>
            </div>
          </div>

          <section
            :if={length(@selected_user_ids) >= 2}
            id="selected-group-summary"
            class="selected-group-summary"
            aria-label="Selected teammate group summary"
          >
            <div>
              <p class="context-eyebrow">{strip_mode_label(@preview_at)}</p>
              <h3>{length(@selected_user_ids)} selected teammates</h3>
              <p>{@selected_group_summary.text}</p>
            </div>
          </section>
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

        <div
          id="map-time-rail"
          class="map-time-rail"
          aria-label="Time preview rail"
          phx-hook="RailLocalTime"
          data-window-start-at={@rail.window_start_at}
          data-window-end-at={@rail.window_end_at}
          data-effective-at={@rail.effective_at}
          data-preview-active={if(@preview_at, do: "true", else: "false")}
          data-rail-context-label={@rail.context_label}
        >
          <div class="rail-header">
            <span>{@rail.context_label}</span>
            <span data-rail-local-range>{@rail.window_label}</span>
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
                aria-label={@rail.context_description}
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
                  data-reachable-count={Map.get(segment, :reachable_count)}
                  data-total-count={Map.get(segment, :total_count)}
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
                phx-hook="PreviewRail"
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
          <div id="map-time-rail-status" class="rail-status" aria-live="polite" data-rail-local-status>
            {@rail.status_text}
          </div>
          <div id="map-time-rail-ticks" class="rail-labels" aria-label={@rail.tick_description}>
            <span
              :for={tick <- @rail.ticks}
              data-offset-minutes={tick.offset_minutes}
              data-local-time-at={tick.at}
            >
              {tick.label}
            </span>
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
        <div class="profile-panel-position">
          <.profile_card
            user={@selected_user}
            effective_at={@effective_at}
            loading_pronunciation={@loading_pronunciation}
            playing_pronunciation={@playing_pronunciation}
            name_share_loading={@name_card_share_loading == "#{@selected_user.id}"}
            name_share_error={@name_card_share_error}
          />
        </div>
      </div>

      <div
        :if={length(@selected_user_ids) >= 2}
        id="selected-group-panel"
        class="selected-group-panel-shell"
        data-testid="selected-group-panel-shell"
      >
        <section class="selected-group-panel" aria-label="Selected teammate group panel">
          <div class="selected-group-handle" data-testid="selected-group-sheet-handle" aria-hidden="true">
          </div>

          <header class="selected-group-panel-header">
            <div class="selected-group-verdict">
              <p class="context-eyebrow">{strip_mode_label(@preview_at)} group availability</p>
              <h2 class={"is-#{@selected_group_verdict.tone}"}>{@selected_group_verdict.label}</h2>
              <p class="selected-group-effective-time" data-testid="selected-group-effective-time">
                {length(@selected_user_ids)} selected · {strip_time_label(@effective_at, @preview_at)}
              </p>
            </div>

            <button
              type="button"
              id="selected-group-clear"
              class="decision-close-button"
              phx-click="clear_selected_users"
              aria-label="Clear selected teammate group"
            >
              <.icon name="hero-x-mark" class="h-4 w-4" />
            </button>
          </header>

          <section class="selected-group-decision" data-testid="selected-group-decision">
            <p>{@selected_group_summary.text}</p>
            <div
              :if={@selected_group_attention}
              class={"selected-group-attention is-#{@selected_group_attention.tone}"}
              data-testid="selected-group-attention"
            >
              <span>{@selected_group_attention.label}</span>
              <strong>{@selected_group_attention.name}</strong>
              <p>{@selected_group_attention.detail}</p>
            </div>
            <div
              :if={@selected_group_next_best}
              class="selected-group-next-best"
              data-testid="selected-group-next-best"
            >
              <span>{@selected_group_next_best.label}</span>
              <strong>{@selected_group_next_best.time_label}</strong>
              <p>{@selected_group_next_best.text}</p>
            </div>
          </section>

          <div class="selected-group-rows" role="list" aria-label="Compared teammates">
            <article
              :for={user <- selected_users(@users, @selected_user_ids)}
              id={"selected-group-row-#{user.id}"}
              class={["selected-group-row", decision_state_class(user, @effective_at)]}
              role="listitem"
              data-testid="selected-group-row"
            >
              <div class="selected-group-row-main">
                <span class={["decision-state-dot", decision_state_class(user, @effective_at)]}></span>
                <div class="selected-group-row-copy">
                  <h3>{user.name}</h3>
                  <p>{user.role || "Team Member"} · {Geography.country_name(user.country)}</p>
                </div>
                <time class="selected-group-local-time" data-testid="selected-group-local-time">
                  {Reachability.local_time_label(user.timezone, @effective_at)}
                </time>
              </div>

              <p class="selected-group-row-meta">
                <span data-testid="selected-group-work-window">{format_user_time_range(user)}</span>
                <span aria-hidden="true">·</span>
                <span data-testid="selected-group-daylight">
                  {Reachability.daylight_context_label(user, @effective_at)}
                </span>
                <span aria-hidden="true">·</span>
                <span>{Reachability.next_transition(user, @effective_at).text}</span>
              </p>
            </article>
          </div>
        </section>
      </div>

      <.share_preview_modal preview={@share_preview} />
      <.team_create_modal
        :if={@team_create_modal_open}
        form={@team_create_form}
        return_team={@active_team}
      />
      <.team_invite_modal
        :if={@team_invite_modal_open}
        form={@team_invite_form}
        target_team={@team_invite_target_team}
      />
    </div>
    """
  end

  defp apply_action(socket, :new_team_invite, params) do
    target_team = team_invite_target_team(params, socket.assigns.teams)

    socket
    |> assign(:page_title, "Create team invite")
    |> assign(:active_tab, :map)
    |> assign(:team_switcher_open, false)
    |> assign(:team_create_modal_open, false)
    |> assign(:team_create_form, team_create_form())
    |> assign(:team_invite_modal_open, true)
    |> assign(:team_invite_target_team, target_team)
    |> assign(:team_invite_form, team_invite_form(target_team))
  end

  defp apply_action(socket, :new_team, _params) do
    socket
    |> assign(:page_title, "Create team")
    |> assign(:active_tab, :map)
    |> assign(:team_switcher_open, false)
    |> assign(:team_create_modal_open, true)
    |> assign(:team_create_form, team_create_form())
    |> assign(:team_invite_modal_open, false)
    |> assign(:team_invite_target_team, nil)
    |> assign(:team_invite_form, team_invite_form(nil))
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Map")
    |> assign(:active_tab, :map)
    |> assign(:team_create_modal_open, false)
    |> assign(:team_create_form, team_create_form())
    |> assign(:team_invite_modal_open, false)
    |> assign(:team_invite_target_team, nil)
    |> assign(:team_invite_form, team_invite_form(nil))
  end

  attr(:form, Phoenix.HTML.Form, required: true)
  attr(:return_team, :map, default: nil)

  defp team_create_modal(assigns) do
    ~H"""
    <div
      id="team-create-modal"
      class="team-invite-modal team-create-modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="team-create-modal-title"
      phx-window-keydown={JS.patch(team_create_close_path(@return_team))}
      phx-key="Escape"
      data-testid="team-create-modal"
    >
      <.link
        patch={team_create_close_path(@return_team)}
        class="team-invite-backdrop"
        aria-label="Close team dialog"
      >
      </.link>

      <section class="team-invite-panel">
        <header class="team-invite-header">
          <div>
            <p class="context-eyebrow">Team</p>
            <h2 id="team-create-modal-title">Create a team</h2>
            <p>Name the team first. Then invite or import people from the People panel.</p>
          </div>
          <.link
            patch={team_create_close_path(@return_team)}
            class="decision-close-button"
            aria-label="Close team dialog"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </.link>
        </header>

        <.form for={@form} id="team-create-form" phx-submit="create_team" class="team-invite-modal-form">
          <label for="team-name">Team name</label>
          <input
            id="team-name"
            name={@form[:name].name}
            type="text"
            required
            value={@form[:name].value}
            autocomplete="organization"
          />
          <button id="team-create-submit" type="submit">
            <.icon name="hero-plus" class="h-4 w-4" />
            <span>Create team</span>
          </button>
        </.form>
      </section>
    </div>
    """
  end

  attr(:form, Phoenix.HTML.Form, required: true)
  attr(:target_team, :map, default: nil)

  defp team_invite_modal(assigns) do
    ~H"""
    <div
      id="team-invite-modal"
      class="team-invite-modal"
      role="dialog"
      aria-modal="true"
      aria-labelledby="team-invite-modal-title"
      phx-window-keydown={JS.patch(team_invite_close_path(@target_team))}
      phx-key="Escape"
      data-testid="team-invite-modal"
    >
      <.link
        patch={team_invite_close_path(@target_team)}
        class="team-invite-backdrop"
        aria-label="Close team invite dialog"
      >
      </.link>

      <section class="team-invite-panel">
        <header class="team-invite-header">
          <div>
            <p class="context-eyebrow">Team invite</p>
            <h2 id="team-invite-modal-title">Create a team invite</h2>
            <p>Invite teammates to add their location and work hours before publishing them to the map.</p>
          </div>
          <.link
            patch={team_invite_close_path(@target_team)}
            class="decision-close-button"
            aria-label="Close team invite dialog"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </.link>
        </header>

        <.form for={@form} id="packet-create-form" action={~p"/team-invites"} method="post" class="team-invite-modal-form">
          <input
            :if={@target_team}
            type="hidden"
            name="packet[published_team_id]"
            value={@target_team.id}
          />
          <label for="packet-name">Team name</label>
          <input
            id="packet-name"
            name={@form[:name].name}
            type="text"
            required
            value={@form[:name].value}
            autocomplete="organization"
          />
          <button id="packet-create-submit" type="submit">
            <.icon name="hero-user-plus" class="h-4 w-4" />
            <span>Create invite</span>
          </button>
        </.form>
      </section>
    </div>
    """
  end

  defp assign_team_context(socket, params) do
    teams = Accounts.list_teams()
    team_member_counts = Accounts.team_member_counts()
    active_team = active_team_from_params(params, teams)
    users = users_for_scope(active_team, teams)
    selected_user_ids = valid_selected_user_ids(socket.assigns.selected_user_ids, users)

    socket
    |> assign(:teams, teams)
    |> assign(:active_team, active_team)
    |> assign(:team_member_counts, team_member_counts)
    |> assign(:team_scope_name, team_scope_name(active_team, teams))
    |> assign(:team_scope_count, length(users))
    |> assign(:users, users)
    |> assign(:selected_user_ids, selected_user_ids)
    |> assign(:selected_user, selected_user(users, selected_user_ids))
    |> assign_effective_time()
  end

  defp active_team_from_params(%{"team" => team_id}, teams) when is_binary(team_id) do
    Enum.find(teams, &(&1.id == team_id)) || List.first(teams)
  end

  defp active_team_from_params(%{"team_id" => team_id}, teams) when is_binary(team_id) do
    Enum.find(teams, &(&1.id == team_id)) || List.first(teams)
  end

  defp active_team_from_params(_params, teams), do: List.first(teams)

  defp active_team_id(%{id: id}), do: id
  defp active_team_id(_team), do: nil

  defp team_context_changed?(nil, _active_team), do: false

  defp team_context_changed?(previous_team_id, active_team) do
    previous_team_id != active_team_id(active_team)
  end

  defp users_for_scope(nil, []), do: Accounts.list_people()
  defp users_for_scope(nil, _teams), do: []
  defp users_for_scope(team, _teams), do: Accounts.list_people_for_team(team.id)

  defp team_scope_name(%{name: name}, _teams) when is_binary(name), do: name
  defp team_scope_name(nil, []), do: "All teammates"
  defp team_scope_name(nil, _teams), do: "No team selected"

  defp valid_selected_user_ids(selected_user_ids, users) when is_list(selected_user_ids) do
    user_ids = MapSet.new(users, & &1.id)
    Enum.filter(selected_user_ids, &MapSet.member?(user_ids, &1))
  end

  defp active_team?(team, active_team), do: active_team && team.id == active_team.id

  defp team_member_label(1), do: "1 teammate"
  defp team_member_label(count), do: "#{count} teammates"

  defp team_empty_message(%Team{}),
    do: "No teammates yet. Invite people or import from SayMyName."

  defp team_empty_message(_team),
    do: "No teammates yet. Create a team or import from SayMyName."

  defp new_team_path(%{id: id}) when is_binary(id), do: ~p"/teams/new?team_id=#{id}"
  defp new_team_path(_team), do: ~p"/teams/new"

  defp team_invite_new_path(%{id: id}) when is_binary(id), do: ~p"/team-invites/new?team_id=#{id}"
  defp team_invite_new_path(_team), do: ~p"/teams/new"

  defp team_invite_target_team(%{"team_id" => team_id}, teams) when is_binary(team_id) do
    Enum.find(teams, &(&1.id == team_id))
  end

  defp team_invite_target_team(_params, _teams), do: nil

  defp team_invite_form(%{name: name}) when is_binary(name) do
    to_form(%{"name" => name}, as: :packet)
  end

  defp team_invite_form(_team), do: to_form(%{}, as: :packet)

  defp team_create_form do
    %Team{}
    |> Accounts.change_team()
    |> to_form(as: :team)
  end

  defp team_create_close_path(%{id: id}) when is_binary(id), do: ~p"/?team=#{id}"
  defp team_create_close_path(_team), do: ~p"/"

  defp team_invite_close_path(%{id: id}) when is_binary(id), do: ~p"/?team=#{id}"
  defp team_invite_close_path(_team), do: ~p"/"

  defp current_origin(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: scheme, host: host, port: port} when is_binary(scheme) and is_binary(host) ->
        scheme <> "://" <> host <> origin_port(scheme, port)

      _uri ->
        ZonelyWeb.Endpoint.url()
    end
  end

  defp current_origin(_uri), do: ZonelyWeb.Endpoint.url()

  defp origin_port("http", 80), do: ""
  defp origin_port("https", 443), do: ""
  defp origin_port(_scheme, nil), do: ""
  defp origin_port(_scheme, port), do: ":#{port}"

  defp absolute_url(origin, path) do
    String.trim_trailing(origin, "/") <> path
  end

  defp assign_effective_time(socket) do
    effective_at = Reachability.effective_at(socket.assigns.preview_at, socket.assigns.live_now)
    orbit_users = Reachability.sort_by_availability(socket.assigns.users, effective_at)
    selected_user_ids = Map.get(socket.assigns, :selected_user_ids, [])
    selected_users = selected_users(socket.assigns.users, selected_user_ids)

    socket
    |> assign(:effective_at, effective_at)
    |> assign(:orbit_users, orbit_users)
    |> assign(
      :map_users_json,
      marker_payload(socket.assigns.users, effective_at, selected_user_ids) |> Jason.encode!()
    )
    |> assign(:reachability, Reachability.summary(socket.assigns.users, effective_at))
    |> assign(:selected_group_summary, Reachability.group_summary(selected_users, effective_at))
    |> assign(
      :selected_group_verdict,
      selected_group_verdict(Reachability.group_summary(selected_users, effective_at))
    )
    |> assign(
      :selected_group_next_best,
      selected_group_next_best(selected_users, effective_at)
    )
    |> assign(
      :selected_group_attention,
      selected_group_attention(selected_users, effective_at)
    )
    |> assign(
      :rail,
      rail_state(
        socket.assigns.live_now,
        socket.assigns.preview_at,
        effective_at,
        rail_context(socket.assigns.users, selected_user_ids)
      )
    )
  end

  defp push_marker_state_update(socket) do
    push_event(socket, "team_marker_states", marker_state_payload(socket))
  end

  defp marker_state_payload(socket) do
    selected_user_ids = socket.assigns.selected_user_ids
    selected_user_id = single_selected_user_id(selected_user_ids)

    %{
      effective_at: DateTime.to_iso8601(socket.assigns.effective_at),
      mode: if(socket.assigns.preview_at, do: "preview", else: "live"),
      selected_user_id: selected_user_id,
      selected_user_ids: selected_user_ids,
      markers:
        marker_payload(
          socket.assigns.users,
          socket.assigns.effective_at,
          selected_user_ids
        )
    }
  end

  defp single_selected_user_id([id]), do: id
  defp single_selected_user_id(_selected_user_ids), do: nil

  defp clear_selection(socket) do
    socket
    |> assign(:selected_user_ids, [])
    |> assign(:selected_user, nil)
    |> assign_effective_time()
    |> push_marker_state_update()
  end

  defp selected_user(users, [id]), do: Enum.find(users, &(&1.id == id))
  defp selected_user(_users, _selected_user_ids), do: nil

  defp selected_users(users, selected_user_ids) when is_list(selected_user_ids) do
    selected_user_ids
    |> Enum.map(fn id -> Enum.find(users, &(&1.id == id)) end)
    |> Enum.reject(&is_nil/1)
  end

  defp selected_user?(selected_user_ids, user_id), do: user_id in selected_user_ids

  defp toggle_selected_user_id(selected_user_ids, id, users) do
    case user_ids_from_param(id, users) do
      [user_id] ->
        if user_id in selected_user_ids do
          List.delete(selected_user_ids, user_id)
        else
          selected_user_ids ++ [user_id]
        end

      [] ->
        selected_user_ids
    end
  end

  defp user_ids_from_param(id, users) do
    users
    |> Enum.find(&("#{&1.id}" == to_string(id)))
    |> case do
      %{id: user_id} -> [user_id]
      nil -> []
    end
  end

  defp select_button_label(selected_user_ids, user) do
    if selected_user?(selected_user_ids, user.id),
      do: "Remove #{user.name} from selection",
      else: "Select #{user.name}"
  end

  defp decision_state_class(user, %DateTime{} = effective_at) do
    case Reachability.marker_state(user, effective_at) do
      "working" -> "is-working"
      "edge" -> "is-edge"
      _other -> "is-off"
    end
  end

  defp format_user_time_range(%{work_start: %Time{} = work_start, work_end: %Time{} = work_end}) do
    "#{format_time(work_start)}–#{format_time(work_end)}"
  end

  defp format_user_time_range(_user), do: "Work window unavailable"

  defp selected_group_verdict(%{selected_count: 0}) do
    %{label: "No group selected", tone: "wait"}
  end

  defp selected_group_verdict(%{selected_count: count, working: count, edge: 0, off: 0}) do
    %{label: "Good time now", tone: "good"}
  end

  defp selected_group_verdict(%{working: 0, edge: 0}) do
    %{label: "Wait", tone: "wait"}
  end

  defp selected_group_verdict(_summary) do
    %{label: "Partial overlap", tone: "partial"}
  end

  defp selected_group_next_best([], %DateTime{}), do: nil

  defp selected_group_next_best(users, %DateTime{} = effective_at) do
    current = Reachability.group_summary(users, effective_at)

    15..1440//15
    |> Enum.map(fn minutes ->
      at = DateTime.add(effective_at, minutes * 60, :second)
      summary = Reachability.group_summary(users, at)
      %{at: at, minutes: minutes, summary: summary}
    end)
    |> Enum.max_by(&{&1.summary.working, &1.summary.edge, -&1.minutes}, fn -> nil end)
    |> case do
      nil ->
        nil

      %{summary: %{working: working}} when working <= current.working ->
        nil

      %{at: at, summary: summary} ->
        %{
          label: next_best_label(summary),
          time_label: "#{format_rail_time(at)} UTC",
          text: summary.text
        }
    end
  end

  defp next_best_label(%{selected_count: count, working: count}), do: "Next full overlap"
  defp next_best_label(_summary), do: "Next better overlap"

  defp selected_group_attention(users, %DateTime{} = effective_at) do
    users
    |> Enum.reject(&(Reachability.status(&1, effective_at) == :working))
    |> Enum.sort_by(&group_attention_sort_key(&1, effective_at))
    |> List.first()
    |> case do
      nil ->
        nil

      user ->
        status = Reachability.status(user, effective_at)

        %{
          label: group_attention_label(status),
          tone: group_attention_tone(status),
          name: user.name,
          detail:
            "#{Reachability.status_label(user, effective_at)} · #{Reachability.next_transition(user, effective_at).text}"
        }
    end
  end

  defp group_attention_sort_key(user, %DateTime{} = effective_at) do
    status = Reachability.status(user, effective_at)
    transition = Reachability.next_transition(user, effective_at)
    instant = transition.instant || DateTime.add(effective_at, 24 * 60 * 60, :second)

    {group_attention_priority(status), DateTime.to_unix(instant, :second), user.name}
  end

  defp group_attention_priority(:off), do: 0
  defp group_attention_priority(:edge), do: 1
  defp group_attention_priority(:working), do: 2

  defp group_attention_label(:edge), do: "Boundary"
  defp group_attention_label(_status), do: "Waiting on"

  defp group_attention_tone(:edge), do: "edge"
  defp group_attention_tone(_status), do: "wait"

  defp live_now do
    case Application.get_env(:zonely, :home_live_now) do
      %DateTime{} = now -> DateTime.truncate(now, :second)
      fun when is_function(fun, 0) -> fun.() |> DateTime.truncate(:second)
      _other -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp duplicate_preview_offset?(%{"offset_minutes" => value}, socket) do
    socket.assigns.preview_at &&
      to_string(socket.assigns.rail.offset_minutes) == to_string(value)
  end

  defp duplicate_preview_offset?(_params, _socket), do: false

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

  defp rail_context(users, []), do: %{kind: :team, users: users, label: "Team availability"}

  defp rail_context(users, [selected_user_id]) do
    selected = selected_users(users, [selected_user_id])
    user = List.first(selected)

    %{
      kind: :single,
      users: selected,
      label: if(user, do: "#{user.name} availability", else: "Selected availability")
    }
  end

  defp rail_context(users, selected_user_ids) do
    selected = selected_users(users, selected_user_ids)

    %{
      kind: :group,
      users: selected,
      label: "#{length(selected)}-person overlap"
    }
  end

  defp rail_state(%DateTime{} = live_now, preview_at, %DateTime{} = effective_at, rail_context) do
    offset_minutes =
      effective_at
      |> DateTime.diff(live_now, :second)
      |> div(60)
      |> clamp(0, 1440)

    %{
      offset_minutes: offset_minutes,
      window_start_at: DateTime.to_iso8601(live_now),
      window_end_at: DateTime.add(live_now, 24 * 60 * 60, :second) |> DateTime.to_iso8601(),
      effective_at: DateTime.to_iso8601(effective_at),
      window_label:
        "#{format_rail_time(live_now)} to #{format_rail_time(DateTime.add(live_now, 24 * 60 * 60, :second))} tomorrow",
      context_label: rail_context.label,
      context_description: rail_context_description(rail_context),
      value_text: rail_value_text(effective_at, preview_at, rail_context),
      status_text: rail_status_text(effective_at, preview_at, rail_context),
      ticks: rail_ticks(live_now),
      tick_description: rail_tick_description(live_now),
      segments: rail_segments(rail_context, live_now)
    }
  end

  defp rail_segments(%{kind: :group, users: users}, %DateTime{} = live_now)
       when length(users) >= 2 do
    group_overlap_segments(users, live_now)
  end

  defp rail_segments(%{users: users}, %DateTime{} = live_now) when is_list(users) do
    window_end = DateTime.add(live_now, 24 * 60 * 60, :second)

    users
    |> Enum.flat_map(fn user ->
      daylight_segments(user, live_now, window_end) ++
        work_window_segments(user, live_now, window_end)
    end)
    |> Enum.sort_by(&{&1.start_at, &1.kind, &1.user_id})
  end

  defp group_overlap_segments(users, %DateTime{} = live_now) do
    total = length(users)

    users
    |> group_overlap_buckets(live_now)
    |> Enum.reject(&(&1.reachable_count == 0))
    |> merge_group_overlap_buckets()
    |> Enum.map(&group_overlap_segment(&1, live_now, total))
  end

  defp group_overlap_buckets(users, %DateTime{} = live_now) do
    0..95
    |> Enum.map(fn step ->
      start_at = DateTime.add(live_now, step * 15 * 60, :second)
      end_at = DateTime.add(start_at, 15 * 60, :second)
      reachable_count = Enum.count(users, &(Reachability.status(&1, start_at) == :working))
      kind = group_overlap_kind(reachable_count, length(users))

      %{
        start_at: start_at,
        end_at: end_at,
        kind: kind,
        reachable_count: reachable_count
      }
    end)
  end

  defp merge_group_overlap_buckets([]), do: []

  defp merge_group_overlap_buckets([first | rest]) do
    rest
    |> Enum.reduce([first], fn bucket, [current | merged] ->
      if bucket.kind == current.kind and bucket.reachable_count == current.reachable_count and
           DateTime.compare(bucket.start_at, current.end_at) == :eq do
        [%{current | end_at: bucket.end_at} | merged]
      else
        [bucket, current | merged]
      end
    end)
    |> Enum.reverse()
  end

  defp group_overlap_segment(segment, %DateTime{} = live_now, total) do
    left_percent = rail_percent(segment.start_at, live_now)
    width_percent = rail_width_percent(segment.start_at, segment.end_at)

    %{
      kind: Atom.to_string(segment.kind),
      class: rail_segment_class(Atom.to_string(segment.kind)),
      user_id: "selected-group",
      reachable_count: segment.reachable_count,
      total_count: total,
      start_at: DateTime.to_iso8601(segment.start_at),
      end_at: DateTime.to_iso8601(segment.end_at),
      left_percent: format_percent(left_percent),
      width_percent: format_percent(width_percent),
      style: "left: #{format_percent(left_percent)}%; width: #{format_percent(width_percent)}%;",
      label:
        "#{segment.reachable_count} of #{total} selected teammates reachable from #{format_rail_time(segment.start_at)} to #{format_rail_time(segment.end_at)} UTC"
    }
  end

  defp group_overlap_kind(total, total), do: :group_full
  defp group_overlap_kind(_reachable_count, _total), do: :group_partial

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
  defp rail_segment_class("group_full"), do: "rail-segment-group-full"
  defp rail_segment_class("group_partial"), do: "rail-segment-group-partial"

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

      %{offset_minutes: offset, label: label, at: DateTime.to_iso8601(tick_at)}
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

  defp rail_context_description(%{kind: :team}),
    do: "All teammate daylight and work-window markers"

  defp rail_context_description(%{kind: :single, label: label}),
    do: "#{label} daylight and work-window markers"

  defp rail_context_description(%{kind: :group, label: label}),
    do: "#{label} reachable overlap markers"

  defp rail_status_text(%DateTime{} = effective_at, nil, rail_context) do
    "#{rail_context.label} live at #{format_rail_time(effective_at)} UTC. Explore the next 24 hours."
  end

  defp rail_status_text(%DateTime{} = effective_at, %DateTime{}, rail_context) do
    "#{rail_context.label} preview at #{format_utc_datetime(effective_at)}."
  end

  defp rail_value_text(%DateTime{} = effective_at, nil, rail_context),
    do: "#{rail_context.label} live now, #{format_rail_time(effective_at)} UTC"

  defp rail_value_text(%DateTime{} = effective_at, %DateTime{}, rail_context),
    do: "#{rail_context.label} preview at #{format_utc_datetime(effective_at)}"

  defp strip_mode_label(nil), do: "Now"
  defp strip_mode_label(%DateTime{}), do: "Preview"

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

  defp share_preview_for_card(payload, share_url, response) do
    %{
      kind: :card,
      title: get_in(payload, ["person", "display_name"]),
      subtitle: "Name card",
      url: share_url,
      preview_image_url: share_preview_image_url(response, share_url)
    }
  end

  defp share_preview_for_team_invite(team_name, invite_url) do
    %{
      kind: :team_invite,
      title: team_name,
      subtitle: "Zonely invite link for teammates to add location and work hours.",
      url: invite_url
    }
  end

  defp share_preview_image_url(response, share_url) do
    Map.get(response, "preview_image_url") ||
      SayMyNameShareClient.preview_image_url_from_share_url(share_url)
  end

  defp marker_payload(users, %DateTime{} = effective_at, selected_user_ids) do
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
        selected: user.id in selected_user_ids,
        profile_picture: AvatarService.generate_avatar_url(user.name, 64)
      }
    end)
  end

  defp coordinate_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp coordinate_to_float(value) when is_number(value), do: value

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp format_time(_time), do: nil
end

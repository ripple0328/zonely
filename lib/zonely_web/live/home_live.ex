defmodule ZonelyWeb.HomeLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.Audio
  alias Zonely.AvatarService
  alias Zonely.Geography
  alias Zonely.WorkingHours

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    {:ok,
     socket
     |> assign(:page_title, "Map")
     |> assign(:active_tab, :map)
     |> assign(:users, users)
     |> assign(:map_users_json, users_to_json(users))
     |> assign(:stats, WorkingHours.get_statistics(users))
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
    {:noreply, assign(socket, :selected_user, user)}
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
    <div id={if(@live_action == :directory, do: "directory-page", else: "map-page")} class="space-y-6">
      <%= if @live_action == :directory do %>
        <section class="grid gap-3 sm:grid-cols-3" aria-label="Team availability summary">
          <.stat_tile label="Working now" value={@stats.working} tone="emerald" />
          <.stat_tile label="Near work hours" value={@stats.edge} tone="amber" />
          <.stat_tile label="Off hours" value={@stats.off} tone="slate" />
        </section>

        <section>
          <div>
            <h1 class="text-2xl font-semibold tracking-normal text-gray-950">Team Directory</h1>
            <p class="mt-1 text-sm text-gray-600">
              {length(@users)} teammates across {map_size(@stats.timezones)} time zones.
            </p>
          </div>
        </section>

        <section
          id="team-directory"
          class="grid gap-4 md:grid-cols-2 xl:grid-cols-3"
          aria-label="Team members"
        >
          <div :if={@users == []} class="rounded-lg border border-dashed border-gray-300 bg-white px-6 py-12 text-center text-sm text-gray-600 md:col-span-2 xl:col-span-3">
            No team members have been added yet.
          </div>
          <.user_card
            :for={user <- @users}
            user={user}
            loading_pronunciation={@loading_pronunciation}
            playing_pronunciation={@playing_pronunciation}
          />
        </section>
      <% else %>
        <section id="global-team-map" class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm" aria-label="Global team map">
          <div class="flex flex-col gap-4 border-b border-gray-200 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
            <div>
              <h1 class="text-2xl font-semibold tracking-normal text-gray-950">Global Team Map</h1>
              <p class="mt-1 max-w-2xl text-sm text-gray-600">
                {length(@users)} teammates across {map_size(@stats.timezones)} time zones, with live daylight context.
              </p>
            </div>
            <.link
              navigate={~p"/directory"}
              class="inline-flex items-center justify-center rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50"
            >
              Directory
            </.link>
          </div>

          <div
            id="map-container"
            class="h-[68vh] min-h-[460px] max-h-[720px] w-full bg-slate-100"
            phx-hook="TeamMap"
            phx-update="ignore"
            data-users={@map_users_json}
            data-testid="team-map"
          >
            <div class="flex h-full items-center justify-center text-sm text-gray-500">
              Loading global team map...
            </div>
          </div>
        </section>
      <% end %>

      <div
        :if={@selected_user}
        id="profile-panel"
        class="fixed inset-0 z-50 bg-black/30 p-4 sm:flex sm:items-center sm:justify-center"
      >
        <div class="mx-auto max-w-md" phx-click-away="hide_profile">
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

  defp apply_action(socket, :directory) do
    socket
    |> assign(:page_title, "Directory")
    |> assign(:active_tab, :directory)
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
        status: user |> WorkingHours.classify_status() |> Atom.to_string(),
        profile_picture: AvatarService.generate_avatar_url(user.name, 64)
      }
    end)
    |> Jason.encode!()
  end

  defp coordinate_to_float(%Decimal{} = value), do: Decimal.to_float(value)
  defp coordinate_to_float(value) when is_number(value), do: value

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp format_time(_time), do: nil

  attr(:label, :string, required: true)
  attr(:value, :integer, required: true)
  attr(:tone, :string, required: true)

  defp stat_tile(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border bg-white p-4 shadow-sm",
      @tone == "emerald" && "border-emerald-200",
      @tone == "amber" && "border-amber-200",
      @tone == "slate" && "border-slate-200"
    ]}>
      <div class="text-2xl font-semibold text-gray-950">{@value}</div>
      <div class="text-sm text-gray-600">{@label}</div>
    </div>
    """
  end
end

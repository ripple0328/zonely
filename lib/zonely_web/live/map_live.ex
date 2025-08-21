defmodule ZonelyWeb.MapLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.TextToSpeech

    @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    maptiler_api_key = Application.get_env(:zonely, :maptiler)[:api_key]

    {:ok, assign(socket,
      users: users,
      selected_user: nil,
      maptiler_api_key: maptiler_api_key
    )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Team Map")
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
    text_to_speak = user.phonetic_native || user.name_native || user.name

    {:noreply,
     socket
     |> push_event("speak_text", %{
       text: text_to_speak,
       lang: user.native_language || "en-US"
     })}
  end



  # Convert users to JSON for JavaScript
  defp users_to_json(users) do
    users
    |> Enum.filter(& &1.latitude && &1.longitude)
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
        phonetic: user.phonetic,
        name_native: user.name_native,
        phonetic_native: user.phonetic_native,
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
    <div class="fixed top-0 left-0 w-full h-screen pt-[4rem] z-0">
      <!-- MapLibre GL JS Map Container -->
            <div
        id="map-container"
        class="h-full w-full"
        phx-hook="TeamMap"
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
              <h3 class="text-lg font-medium text-gray-900">
                <%= @selected_user.name %>
              </h3>
              <button
                phx-click="hide_profile"
                class="text-gray-400 hover:text-gray-600"
              >
                <span class="sr-only">Close</span>
                <.icon name="hero-x-mark" class="h-6 w-6" />
              </button>
            </div>

            <div class="mt-4 space-y-3">
              <div :if={@selected_user.phonetic}>
                <label class="block text-sm font-medium text-gray-700">English Pronunciation</label>
                <p class="text-sm text-gray-900 font-mono"><%= @selected_user.phonetic %></p>
                <button
                  :if={@selected_user.pronunciation_audio_url}
                  class="mt-1 inline-flex items-center px-2.5 py-1.5 border border-gray-300 shadow-sm text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50"
                >
                  <.icon name="hero-speaker-wave" class="h-4 w-4 mr-1" />
                  Play Audio
                </button>
              </div>

              <div :if={@selected_user.name_native && @selected_user.name_native != @selected_user.name}>
                <label class="block text-sm font-medium text-gray-700">
                  Native Name (<%= TextToSpeech.get_native_language_name(@selected_user.country) %>)
                </label>
                <p class="text-lg text-gray-900 mb-2"><%= @selected_user.name_native %></p>
                <div :if={@selected_user.phonetic_native} class="mb-2">
                  <p class="text-sm text-gray-600 font-mono"><%= @selected_user.phonetic_native %></p>
                </div>
                <button
                  phx-click="play_native_pronunciation"
                  phx-value-user_id={@selected_user.id}
                  class="inline-flex items-center px-3 py-1.5 border border-blue-300 shadow-sm text-sm font-medium rounded text-blue-700 bg-blue-50 hover:bg-blue-100"
                >
                  <.icon name="hero-speaker-wave" class="h-4 w-4 mr-1" />
                  Play Native Pronunciation
                </button>
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
    """
  end
end

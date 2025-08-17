defmodule ZonelyWeb.DirectoryLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.TextToSpeech

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    {:ok, assign(socket, users: users, selected_user: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Team Directory")
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
    
    # Send JavaScript command to play TTS
    {:noreply, 
     socket
     |> push_event("speak_text", %{
       text: text_to_speak,
       lang: user.native_language || "en-US"
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Team Directory</h1>
        <p class="mt-2 text-gray-600">Connect with your distributed team members</p>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={user <- @users}
          class="relative bg-white overflow-hidden shadow rounded-lg border border-gray-200 hover:shadow-md transition-shadow cursor-pointer"
          phx-click="show_profile"
          phx-value-user_id={user.id}
        >
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                  <span class="text-sm font-medium text-gray-700">
                    <%= String.first(user.name) %>
                  </span>
                </div>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    <%= user.name %>
                  </dt>
                  <dd class="text-sm text-gray-900">
                    <%= user.role || "Team Member" %>
                  </dd>
                </dl>
              </div>
            </div>
            <div class="mt-4">
              <div class="flex items-center justify-between text-sm text-gray-500">
                <span><%= user.timezone %></span>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                  <%= user.country %>
                </span>
              </div>
              <div :if={user.pronouns} class="mt-2 text-sm text-gray-600">
                <%= user.pronouns %>
              </div>
              <div :if={user.name_native && user.name_native != user.name} class="mt-2">
                <div class="text-xs text-gray-500"><%= TextToSpeech.get_native_language_name(user.country) %></div>
                <div class="text-sm font-medium text-gray-800"><%= user.name_native %></div>
              </div>
            </div>
          </div>
        </div>
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
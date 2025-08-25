defmodule ZonelyWeb.WorkHoursLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts
  alias Zonely.DateUtils
  alias Zonely.WorkingHours

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    {:ok, assign(socket, users: users, selected_users: [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Work Hour")
  end

  @impl true
  def handle_event("toggle_user", %{"user_id" => user_id}, socket) do
    selected_users = socket.assigns.selected_users

    updated_users =
      if user_id in selected_users do
        List.delete(selected_users, user_id)
      else
        [user_id | selected_users]
      end

    {:noreply, assign(socket, selected_users: updated_users)}
  end

  defp get_selected_user_data(users, selected_user_ids) do
    Enum.filter(users, fn user -> user.id in selected_user_ids end)
  end

  defp get_overlap_hours(selected_users) do
    WorkingHours.calculate_overlap_hours(selected_users)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Work Hour Overlaps</h1>
        <p class="mt-2 text-gray-600">Find the best times to collaborate across timezones</p>
      </div>

      <!-- User Selection -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Select Team Members</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            <label
              :for={user <- @users}
              class="relative flex items-center py-3 px-3 cursor-pointer hover:bg-gray-50 rounded-lg border border-gray-200 transition-all duration-150 hover:border-indigo-300 hover:shadow-sm"
            >
              <div class="flex items-center h-5">
                <input
                  type="checkbox"
                  checked={user.id in @selected_users}
                  phx-click="toggle_user"
                  phx-value-user_id={user.id}
                  class="focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded"
                />
              </div>
              <div class="ml-3 flex-shrink-0">
                <.user_avatar user={user} size={40} />
              </div>
              <div class="ml-3 text-sm flex-1 min-w-0">
                <div class="font-medium text-gray-700 truncate"><%= user.name %></div>
                <div class="text-gray-500 text-xs truncate">
                  <%= user.timezone %>
                </div>
                <div class="text-gray-400 text-xs">
                  <%= DateUtils.format_working_hours(user.work_start, user.work_end) %>
                </div>
              </div>
            </label>
          </div>
        </div>
      </div>

      <!-- Timeline View -->
      <div :if={length(@selected_users) > 0} class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Timeline View</h3>

          <.work_hours_timeline users={get_selected_user_data(@users, @selected_users)} />

          <!-- Overlap Summary -->
          <div class="mt-6 p-4 bg-blue-50 rounded-lg">
            <h4 class="text-sm font-medium text-blue-900">Overlap Summary</h4>
            <p class="mt-1 text-sm text-blue-700">
              <%= get_overlap_hours(get_selected_user_data(@users, @selected_users)) %>
            </p>
          </div>
        </div>
      </div>

      <!-- Golden Hours Suggestion -->
      <div :if={length(@selected_users) >= 2} class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Suggested Meeting Times</h3>
          <div class="space-y-2">
            <div class="flex justify-between items-center p-3 bg-yellow-50 rounded-lg">
              <div>
                <div class="font-medium text-yellow-900">09:00 - 10:00 UTC</div>
                <div class="text-sm text-yellow-700">Good overlap for <%= length(@selected_users) %> selected members</div>
              </div>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                Golden Hour
              </span>
            </div>
            <div class="flex justify-between items-center p-3 bg-green-50 rounded-lg">
              <div>
                <div class="font-medium text-green-900">14:00 - 15:00 UTC</div>
                <div class="text-sm text-green-700">Optimal overlap for all selected members</div>
              </div>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                Best
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

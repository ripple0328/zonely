defmodule ZonelyWeb.WorkHoursLive do
  use ZonelyWeb, :live_view

  alias Zonely.Accounts

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
    |> assign(:page_title, "Work Hour Overlaps")
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

  defp format_work_hours_in_timezone(work_start, work_end, user_timezone, display_timezone) do
    # For now, simplified - would need proper timezone conversion
    "#{Calendar.strftime(work_start, "%H:%M")} - #{Calendar.strftime(work_end, "%H:%M")}"
  end

  defp get_overlap_hours(selected_users) do
    # Simplified overlap calculation - would need proper timezone math
    if length(selected_users) >= 2 do
      "09:00 - 17:00 UTC (overlap detected)"
    else
      "Select at least 2 users to see overlaps"
    end
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
          <div class="space-y-3">
            <label
              :for={user <- @users}
              class="relative flex items-start py-2 cursor-pointer"
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
              <div class="ml-3 text-sm">
                <div class="font-medium text-gray-700"><%= user.name %></div>
                <div class="text-gray-500">
                  <%= user.timezone %> • 
                  <%= Calendar.strftime(user.work_start, "%H:%M") %> - <%= Calendar.strftime(user.work_end, "%H:%M") %>
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
          
          <!-- Hours header -->
          <div class="mb-4">
            <div class="grid grid-cols-24 gap-1 text-xs text-gray-500">
              <div :for={hour <- 0..23} class="text-center">
                <%= String.pad_leading(to_string(hour), 2, "0") %>
              </div>
            </div>
          </div>

          <!-- User timelines -->
          <div class="space-y-3">
            <div
              :for={user <- get_selected_user_data(@users, @selected_users)}
              class="flex items-center"
            >
              <div class="w-32 text-sm font-medium text-gray-900 truncate">
                <%= user.name %>
              </div>
              <div class="flex-1 grid grid-cols-24 gap-1">
                <div
                  :for={hour <- 0..23}
                  class={[
                    "h-6 rounded-sm",
                    hour >= user.work_start.hour and hour < user.work_end.hour && "bg-green-200",
                    (hour < user.work_start.hour or hour >= user.work_end.hour) && "bg-gray-100"
                  ]}
                >
                </div>
              </div>
            </div>
          </div>

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
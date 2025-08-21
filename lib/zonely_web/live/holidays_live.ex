defmodule ZonelyWeb.HolidaysLive do
  use ZonelyWeb, :live_view

  alias Zonely.{Accounts, Holidays}

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    countries = users |> Enum.map(& &1.country) |> Enum.uniq()
    holidays = load_holidays_for_countries(countries)
    
    {:ok, assign(socket, users: users, countries: countries, holidays: holidays)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Holiday Calendar")
  end

  @impl true
  def handle_event("fetch_holidays", %{"country" => country}, socket) do
    current_year = Date.utc_today().year
    
    case Holidays.fetch_and_store_holidays(country, current_year) do
      {:ok, message} ->
        holidays = load_holidays_for_countries(socket.assigns.countries)
        socket = socket |> assign(holidays: holidays) |> put_flash(:info, message)
        {:noreply, socket}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to fetch holidays: #{error}")}
    end
  end

  defp load_holidays_for_countries(countries) do
    today = Date.utc_today()
    end_date = Date.add(today, 90) # Next 3 months
    
    countries
    |> Enum.flat_map(fn country ->
      Holidays.get_holidays_by_country_and_date_range(country, today, end_date)
    end)
    |> Enum.sort_by(& &1.date)
  end

  defp get_users_for_country(users, country) do
    Enum.filter(users, fn user -> user.country == country end)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp days_until(date) do
    Date.diff(date, Date.utc_today())
  end

  # Generate fake profile pictures using external service
  defp fake_profile_picture(name) do
    # Using DiceBear Avatars API for consistent fake profile pictures
    seed = name |> String.downcase() |> String.replace(" ", "-")
    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{seed}&backgroundColor=b6e3f4,c0aede,d1d4f9&size=32"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Holiday Calendar</h1>
        <p class="mt-2 text-gray-600">Stay aware of holidays across your team's locations</p>
      </div>

      <!-- Country Overview -->
      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={country <- @countries}
          class="bg-white overflow-hidden shadow rounded-lg"
        >
          <div class="p-5">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-lg font-medium text-gray-900"><%= country %></h3>
                <p class="text-sm text-gray-500">
                  <%= length(get_users_for_country(@users, country)) %> team members
                </p>
              </div>
              <button
                phx-click="fetch_holidays"
                phx-value-country={country}
                class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Refresh
              </button>
            </div>
            
            <div class="mt-4">
              <h4 class="text-sm font-medium text-gray-900 mb-2">Team Members</h4>
              <div class="space-y-2">
                <div
                  :for={user <- get_users_for_country(@users, country)}
                  class="flex items-center space-x-2"
                >
                  <!-- Avatar -->
                  <div class="flex-shrink-0">
                    <img 
                      src={fake_profile_picture(user.name)} 
                      alt={user.name} 
                      class="w-6 h-6 rounded-full"
                      onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
                    />
                    <div class="w-6 h-6 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center" style="display: none;">
                      <span class="text-white font-medium text-xs">
                        <%= String.first(user.name) %>
                      </span>
                    </div>
                  </div>
                  <div class="text-sm text-gray-600">
                    <%= user.name %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Upcoming Holidays -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Upcoming Holidays</h3>
          
          <div :if={length(@holidays) == 0} class="text-center py-8">
            <div class="text-gray-500">
              <p>No holidays loaded yet.</p>
              <p class="text-sm mt-1">Click "Refresh" on country cards to fetch holiday data.</p>
            </div>
          </div>

          <div :if={length(@holidays) > 0} class="space-y-4">
            <div
              :for={holiday <- @holidays}
              class={[
                "flex items-center justify-between p-4 rounded-lg border",
                days_until(holiday.date) <= 7 && "bg-red-50 border-red-200",
                days_until(holiday.date) > 7 && days_until(holiday.date) <= 30 && "bg-yellow-50 border-yellow-200",
                days_until(holiday.date) > 30 && "bg-gray-50 border-gray-200"
              ]}
            >
              <div class="flex-1">
                <div class="flex items-center space-x-3">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    <%= holiday.country %>
                  </span>
                  <h4 class="text-sm font-medium text-gray-900"><%= holiday.name %></h4>
                </div>
                <p class="mt-1 text-sm text-gray-600"><%= format_date(holiday.date) %></p>
              </div>
              
              <div class="flex items-center space-x-4">
                <!-- Affected users avatars -->
                <div class="flex -space-x-1">
                  <div
                    :for={user <- get_users_for_country(@users, holiday.country) |> Enum.take(3)}
                    class="flex-shrink-0"
                  >
                    <img 
                      src={fake_profile_picture(user.name)} 
                      alt={user.name} 
                      class="w-6 h-6 rounded-full border-2 border-white"
                      title={user.name}
                      onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
                    />
                    <div class="w-6 h-6 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full border-2 border-white flex items-center justify-center" style="display: none;" title={user.name}>
                      <span class="text-white font-medium text-xs">
                        <%= String.first(user.name) %>
                      </span>
                    </div>
                  </div>
                  <div 
                    :if={length(get_users_for_country(@users, holiday.country)) > 3} 
                    class="w-6 h-6 bg-gray-300 rounded-full border-2 border-white flex items-center justify-center"
                    title={"#{length(get_users_for_country(@users, holiday.country)) - 3} more"}
                  >
                    <span class="text-gray-600 font-medium text-xs">
                      +<%= length(get_users_for_country(@users, holiday.country)) - 3 %>
                    </span>
                  </div>
                </div>
                
                <div class="text-right">
                  <div class={[
                    "text-sm font-medium",
                    days_until(holiday.date) <= 7 && "text-red-700",
                    days_until(holiday.date) > 7 && days_until(holiday.date) <= 30 && "text-yellow-700",
                    days_until(holiday.date) > 30 && "text-gray-700"
                  ]}>
                    <%= cond do %>
                      <% days_until(holiday.date) == 0 -> %>
                        Today
                      <% days_until(holiday.date) == 1 -> %>
                        Tomorrow
                      <% days_until(holiday.date) > 1 -> %>
                        In <%= days_until(holiday.date) %> days
                      <% true -> %>
                        <%= days_until(holiday.date) %> days ago
                    <% end %>
                  </div>
                  <div class="text-xs text-gray-500">
                    <%= length(get_users_for_country(@users, holiday.country)) %> members
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Holiday Dashboard -->
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">This Week's Impact</h3>
          
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div class="text-center">
              <div class="text-2xl font-bold text-red-600">
                <%= @holidays |> Enum.filter(fn h -> days_until(h.date) >= 0 && days_until(h.date) <= 7 end) |> length() %>
              </div>
              <div class="text-sm text-gray-500">Holidays this week</div>
            </div>
            
            <div class="text-center">
              <div class="text-2xl font-bold text-yellow-600">
                <%= @holidays |> Enum.filter(fn h -> days_until(h.date) > 7 && days_until(h.date) <= 30 end) |> length() %>
              </div>
              <div class="text-sm text-gray-500">Next 30 days</div>
            </div>
            
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600">
                <%= @countries |> length() %>
              </div>
              <div class="text-sm text-gray-500">Countries tracked</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
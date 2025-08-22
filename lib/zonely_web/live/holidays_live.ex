defmodule ZonelyWeb.HolidaysLive do
  use ZonelyWeb, :live_view

  alias Zonely.{Accounts, DateUtils, Geography, Holidays}

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    countries = Geography.unique_countries(users)
    holidays = load_holidays_for_countries(countries)

    {:ok, assign(socket, users: users, countries: countries, holidays: holidays)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, action, _params) when action in [:index, nil] do
    socket
    |> assign(:page_title, "Holiday")
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
    # Next 3 months
    end_date = Date.add(today, 90)

    countries
    |> Enum.flat_map(fn country ->
      Holidays.get_holidays_by_country_and_date_range(country, today, end_date)
    end)
    |> Enum.sort_by(& &1.date)
  end

  defp get_users_for_country(users, country) do
    Geography.users_by_country(users, country)
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
                  <div class="flex-shrink-0">
                    <.user_avatar user={user} size={24} />
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
            <.holiday_card
              :for={holiday <- @holidays}
              holiday={holiday}
              users={get_users_for_country(@users, holiday.country)}
            />
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
                <%= @holidays |> DateUtils.filter_within_days(:date, 7) |> length() %>
              </div>
              <div class="text-sm text-gray-500">Holidays this week</div>
            </div>

            <div class="text-center">
              <div class="text-2xl font-bold text-yellow-600">
                <%= @holidays |> DateUtils.filter_within_range(:date, 8, 30) |> length() %>
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

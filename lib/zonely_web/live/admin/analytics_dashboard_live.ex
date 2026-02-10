defmodule ZonelyWeb.Admin.AnalyticsDashboardLive do
  use ZonelyWeb, :live_view

  alias Zonely.Analytics

  @time_ranges %{
    "24h" => {24, :hour},
    "7d" => {7, :day},
    "30d" => {30, :day}
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Refresh every 30 seconds
      :timer.send_interval(30_000, self(), :refresh)
    end

    socket =
      socket
      |> assign(:time_range, "24h")
      |> assign(:loading, true)
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    time_range = Map.get(params, "range", "24h")

    socket =
      socket
      |> assign(:time_range, time_range)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_range", %{"range" => range}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/analytics?range=#{range}")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, load_dashboard_data(socket)}
  end

  defp load_dashboard_data(socket) do
    time_range = socket.assigns.time_range
    {amount, unit} = Map.get(@time_ranges, time_range, {24, :hour})

    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -amount, unit)

    # Load all metrics
    total_pronunciations = Analytics.total_pronunciations(start_date, end_date)
    cache_hit_rate = Analytics.cache_hit_rate(start_date, end_date)
    top_names = Analytics.top_requested_names(start_date, end_date, 10)
    geo_distribution = Analytics.geographic_distribution(start_date, end_date, 10)
    provider_performance = Analytics.tts_provider_performance(start_date, end_date)
    error_stats = Analytics.error_rate(start_date, end_date)
    errors_by_type = Analytics.errors_by_type(start_date, end_date)
    conversion = Analytics.conversion_funnel(start_date, end_date)

    # Time series for chart
    granularity = if amount <= 1, do: "hour", else: "day"
    time_series = Analytics.pronunciations_time_series(start_date, end_date, granularity)

    socket
    |> assign(:loading, false)
    |> assign(:start_date, start_date)
    |> assign(:end_date, end_date)
    |> assign(:total_pronunciations, total_pronunciations)
    |> assign(:cache_hit_rate, cache_hit_rate)
    |> assign(:top_names, top_names)
    |> assign(:geo_distribution, geo_distribution)
    |> assign(:provider_performance, provider_performance)
    |> assign(:error_stats, error_stats)
    |> assign(:errors_by_type, errors_by_type)
    |> assign(:conversion, conversion)
    |> assign(:time_series, time_series)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">SayMyName Analytics</h1>
          <p class="mt-2 text-sm text-gray-600">
            Internal dashboard for usage statistics
          </p>
        </div>

        <!-- Time Range Selector -->
        <div class="mb-6 flex items-center justify-between">
          <div class="flex space-x-2">
            <button
              :for={range <- ["24h", "7d", "30d"]}
              phx-click="change_range"
              phx-value-range={range}
              class={[
                "px-4 py-2 text-sm font-medium rounded-lg transition-colors",
                if(@time_range == range,
                  do: "bg-blue-600 text-white",
                  else: "bg-white text-gray-700 hover:bg-gray-50 border border-gray-300"
                )
              ]}
            >
              <%= range %>
            </button>
          </div>

          <div class="text-sm text-gray-500">
            Last updated: <%= Calendar.strftime(DateTime.utc_now(), "%H:%M:%S UTC") %>
          </div>
        </div>

        <%= if @loading do %>
          <div class="flex items-center justify-center h-64">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        <% else %>
          <!-- Key Metrics Grid -->
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4 mb-8">
            <.metric_card
              title="Total Pronunciations"
              value={@total_pronunciations}
              icon="🎙️"
              color="blue"
            />
            <.metric_card
              title="Cache Hit Rate"
              value={"#{@cache_hit_rate}%"}
              icon="⚡"
              color="green"
            />
            <.metric_card
              title="Error Rate"
              value={"#{@error_stats.error_rate}%"}
              subtitle={"#{@error_stats.errors} errors"}
              icon="⚠️"
              color={if @error_stats.error_rate > 5, do: "red", else: "yellow"}
            />
            <.metric_card
              title="Conversion Rate"
              value={"#{@conversion.conversion_rate}%"}
              subtitle={"#{@conversion.converted}/#{@conversion.landed} sessions"}
              icon="📊"
              color="purple"
            />
          </div>

          <!-- Charts Row -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Pronunciations Over Time -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Pronunciations Over Time
              </h2>
              <.simple_time_chart data={@time_series} />
            </div>

            <!-- Provider Performance -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                TTS Provider Performance
              </h2>
              <.provider_performance_table providers={@provider_performance} />
            </div>
          </div>

          <!-- Tables Row -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Top Names -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Top 10 Requested Names
              </h2>
              <.top_names_table names={@top_names} />
            </div>

            <!-- Geographic Distribution -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Geographic Distribution
              </h2>
              <.geo_distribution_table countries={@geo_distribution} />
            </div>
          </div>

          <!-- Errors Row -->
          <%= if @error_stats.errors > 0 do %>
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Errors by Type
              </h2>
              <.errors_by_type_table errors={@errors_by_type} />
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Components

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :subtitle, :string, default: nil
  attr :icon, :string, required: true
  attr :color, :string, default: "blue"

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-600"><%= @title %></p>
          <p class={[
            "mt-2 text-3xl font-bold",
            "text-#{@color}-600"
          ]}>
            <%= @value %>
          </p>
          <%= if @subtitle do %>
            <p class="mt-1 text-sm text-gray-500"><%= @subtitle %></p>
          <% end %>
        </div>
        <div class="text-4xl"><%= @icon %></div>
      </div>
    </div>
    """
  end

  attr :data, :list, required: true

  defp simple_time_chart(assigns) do
    ~H"""
    <%= if @data == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div class="space-y-2">
        <%= for {timestamp, count} <- @data do %>
          <div class="flex items-center space-x-2">
            <div class="text-xs text-gray-600 w-32">
              <%= format_timestamp(timestamp) %>
            </div>
            <div class="flex-1 bg-gray-200 rounded-full h-4 relative">
              <div
                class="bg-blue-600 h-4 rounded-full"
                style={"width: #{bar_width(@data, count)}%"}
              >
              </div>
            </div>
            <div class="text-sm font-medium text-gray-900 w-12 text-right">
              <%= count %>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :providers, :list, required: true

  defp provider_performance_table(assigns) do
    ~H"""
    <%= if @providers == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div class="overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead>
            <tr>
              <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                Provider
              </th>
              <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                Avg (ms)
              </th>
              <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                P95 (ms)
              </th>
              <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                Requests
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <%= for provider <- @providers do %>
              <tr>
                <td class="px-3 py-2 text-sm font-medium text-gray-900">
                  <%= provider.provider || "Unknown" %>
                </td>
                <td class="px-3 py-2 text-sm text-gray-600 text-right">
                  <%= provider.avg_generation_time_ms %>
                </td>
                <td class="px-3 py-2 text-sm text-gray-600 text-right">
                  <%= provider.p95_generation_time_ms %>
                </td>
                <td class="px-3 py-2 text-sm text-gray-600 text-right">
                  <%= provider.total_requests %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  attr :names, :list, required: true

  defp top_names_table(assigns) do
    ~H"""
    <%= if @names == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div class="space-y-2">
        <%= for {{name_hash, count}, index} <- Enum.with_index(@names, 1) do %>
          <div class="flex items-center justify-between py-2 border-b border-gray-100">
            <div class="flex items-center space-x-3">
              <span class="text-sm font-medium text-gray-500 w-6"><%= index %>.</span>
              <span class="text-sm text-gray-900 font-mono"><%= name_hash %></span>
            </div>
            <span class="text-sm font-semibold text-blue-600"><%= count %></span>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :countries, :list, required: true

  defp geo_distribution_table(assigns) do
    ~H"""
    <%= if @countries == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div class="space-y-2">
        <%= for {{country_code, session_count}, index} <- Enum.with_index(@countries, 1) do %>
          <div class="flex items-center justify-between py-2 border-b border-gray-100">
            <div class="flex items-center space-x-3">
              <span class="text-sm font-medium text-gray-500 w-6"><%= index %>.</span>
              <span class="text-sm text-gray-900">
                <%= country_name(country_code) %> (<%= country_code %>)
              </span>
            </div>
            <span class="text-sm font-semibold text-blue-600"><%= session_count %></span>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :errors, :list, required: true

  defp errors_by_type_table(assigns) do
    ~H"""
    <div class="overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead>
          <tr>
            <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">
              Error Type
            </th>
            <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">
              Count
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <%= for {error_type, count} <- @errors do %>
            <tr>
              <td class="px-4 py-2 text-sm text-gray-900"><%= error_type || "Unknown" %></td>
              <td class="px-4 py-2 text-sm text-gray-600 text-right"><%= count %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # Helper functions

  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} ->
        Calendar.strftime(timestamp, "%b %d %H:%M")

      _ ->
        "N/A"
    end
  end

  defp bar_width(data, count) do
    max_count = data |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
    if max_count > 0, do: Float.round(count / max_count * 100, 1), else: 0
  end

  defp country_name(code) do
    # Simple mapping - could be expanded
    %{
      "US" => "United States",
      "GB" => "United Kingdom",
      "CA" => "Canada",
      "AU" => "Australia",
      "DE" => "Germany",
      "FR" => "France",
      "JP" => "Japan",
      "CN" => "China",
      "IN" => "India",
      "BR" => "Brazil"
    }
    |> Map.get(code, code)
  end
end

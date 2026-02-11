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
    range = if Map.has_key?(@time_ranges, range), do: range, else: "24h"

    socket =
      socket
      |> assign(:time_range, range)
      |> load_dashboard_data()

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
    top_names = Analytics.top_requested_names(start_date, end_date, 5)
    geo_distribution = Analytics.geographic_distribution(start_date, end_date, 100)
    top_languages = Analytics.top_languages(start_date, end_date, 5)
    provider_performance =
      Analytics.provider_usage(start_date, end_date)
      |> with_all_providers()
    error_stats = Analytics.error_rate(start_date, end_date)
    errors_by_type = Analytics.errors_by_type(start_date, end_date)
    conversion = Analytics.conversion_funnel(start_date, end_date)

    # Time series for chart (dynamic bucket sizing)
    span_hours = DateTime.diff(end_date, start_date, :hour)

    {granularity, bucket_label} =
      cond do
        span_hours <= 24 -> {"2h", "2-hour"}
        span_hours <= 72 -> {"6h", "6-hour"}
        span_hours <= 24 * 21 -> {"day", "day"}
        true -> {"week", "week"}
      end

    time_series = Analytics.pronunciations_time_series(start_date, end_date, granularity)

    geo_distribution_map =
      geo_distribution
      |> Enum.reduce(%{}, fn {country, count}, acc -> Map.put(acc, country, count) end)

    maptiler_api_key =
      Application.get_env(:zonely, :maptiler)[:api_key] ||
        "demo_key_get_your_own_at_maptiler_com"

    socket
    |> assign(:loading, false)
    |> assign(:start_date, start_date)
    |> assign(:end_date, end_date)
    |> assign(:total_pronunciations, total_pronunciations)
    |> assign(:cache_hit_rate, cache_hit_rate)
    |> assign(:top_names, top_names)
    |> assign(:geo_distribution, geo_distribution)
    |> assign(:geo_distribution_map, geo_distribution_map)
    |> assign(:maptiler_api_key, maptiler_api_key)
    |> assign(:top_languages, top_languages)
    |> assign(:provider_performance, provider_performance)
    |> assign(:error_stats, error_stats)
    |> assign(:errors_by_type, errors_by_type)
    |> assign(:conversion, conversion)
    |> assign(:time_series, time_series)
    |> assign(:time_bucket_label, bucket_label)
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
              tooltip="Total successful plays (all sources) in the selected range."
            />
            <.metric_card
              title="Cache Hit Rate"
              value={"#{@cache_hit_rate}%"}
              icon="⚡"
              color="green"
              tooltip="% of plays served from any cache (client + server local + remote)."
            />
            <.metric_card
              title="Error Rate"
              value={"#{@error_stats.error_rate}%"}
              subtitle={"#{@error_stats.errors} errors"}
              icon="⚠️"
              color={if @error_stats.error_rate > 5, do: "red", else: "yellow"}
              tooltip="% of events that resulted in pronunciation or system API errors in the selected range."
            />
            <.metric_card
              title="Conversion Rate"
              value={"#{@conversion.conversion_rate}%"}
              subtitle={"#{@conversion.converted}/#{@conversion.landed} sessions"}
              icon="📊"
              color="purple"
              tooltip="% of sessions that landed on the homepage and requested a pronunciation."
            />
          </div>

          <!-- Charts Row -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Pronunciations Over Time -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Pronunciations Over Time (per <%= @time_bucket_label %>)
              </h2>
              <.simple_time_chart data={@time_series} />
            </div>

            <!-- Provider Performance -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Provider Performance
              </h2>
              <.provider_performance_table providers={@provider_performance} />
            </div>
          </div>

          <!-- Tables Row -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <!-- Top Names -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Top 5 Requested Names
              </h2>
              <.top_names_table names={@top_names} />
            </div>

            <!-- Top Languages -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">
                Top Languages (Pronunciations)
              </h2>
              <.top_languages_chart languages={@top_languages} />
            </div>
          </div>

          <!-- Geographic Distribution -->
          <div class="bg-white rounded-lg shadow p-6 mb-8">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">
              Geographic Distribution
            </h2>
            <.geo_distribution_map countries={@geo_distribution} map_data={@geo_distribution_map} api_key={@maptiler_api_key} />
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
  attr :tooltip, :string, default: nil

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6" title={@tooltip || @title}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-600"><%= @title %></p>
          <p class={[
            "mt-2 text-3xl font-bold",
            "text-#{@color}-600"
          ]} data-metric-value>
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
      <div class="w-full overflow-x-auto">
        <svg viewBox="0 0 640 240" class="w-full h-60">
          <line x1="40" y1="20" x2="40" y2="210" stroke="#9ca3af" stroke-width="1" />
          <line x1="40" y1="210" x2="620" y2="210" stroke="#9ca3af" stroke-width="1" />

          <%= for {y, label} <- y_tick_labels(@data) do %>
            <line x1="40" y1={y} x2="620" y2={y} stroke="#e5e7eb" stroke-width="1" />
            <text x="34" y={y + 3} text-anchor="end" class="fill-gray-500 text-[10px]">
              <%= label %>
            </text>
          <% end %>

          <polyline fill="none" stroke="#2563eb" stroke-width="2" points={chart_points(@data)} />

          <%= for {x, y} <- chart_points_xy(@data) do %>
            <circle cx={x} cy={y} r="2.5" fill="#2563eb" />
          <% end %>

          <%= for {x, label} <- x_tick_labels(@data) do %>
            <text x={x} y="232" text-anchor="middle" class="fill-gray-500 text-[10px]">
              <%= label %>
            </text>
          <% end %>
        </svg>
      </div>
    <% end %>
    """
  end

  attr :providers, :list, required: true

  defp provider_performance_table(assigns) do
    ~H"""
    <% providers = if @providers == [], do: with_all_providers([]), else: @providers %>
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
          <%= for provider <- providers do %>
            <tr>
              <td class="px-3 py-2 text-sm font-medium text-gray-900">
                <%= provider_label(provider.provider) %>
              </td>
              <td class="px-3 py-2 text-sm text-gray-600 text-right">
                <%= provider.avg_generation_time_ms || "—" %>
              </td>
              <td class="px-3 py-2 text-sm text-gray-600 text-right">
                <%= provider.p95_generation_time_ms || "—" %>
              </td>
              <td class="px-3 py-2 text-sm text-gray-600 text-right">
                <%= provider.total_requests %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :names, :list, required: true

  defp top_names_table(assigns) do
    ~H"""
    <%= if @names == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div class="overflow-x-auto">
        <table class="table-auto w-auto divide-y divide-gray-200 whitespace-nowrap">
          <thead>
            <tr>
              <th class="px-0.5 py-0.5 text-left text-xs font-semibold text-gray-500 uppercase">#</th>
              <th class="px-0.5 py-0.5 text-left text-xs font-semibold text-gray-500 uppercase">Name</th>
              <th class="px-0.5 py-0.5 text-left text-xs font-semibold text-gray-500 uppercase">Lang</th>
              <th class="px-0.5 py-0.5 text-center text-xs font-semibold text-gray-500 uppercase">Src</th>
              <th class="px-0.5 py-0.5 text-right text-xs font-semibold text-gray-500 uppercase">Count</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <%= for {row, index} <- Enum.with_index(@names, 1) do %>
              <tr>
                <td class="px-0.5 py-0.5 text-sm text-gray-500"><%= index %>.</td>
                <td class="px-0.5 py-0.5 text-sm text-gray-900"><%= row.name %></td>
                <td class="px-0.5 py-0.5 text-sm text-gray-600"><%= language_label(row.lang) %></td>
                <td class="px-0.5 py-0.5 text-center text-sm"><%= provider_icon(row.provider) %></td>
                <td class="px-0.5 py-0.5 text-sm text-gray-600 text-right"><%= row.count %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  attr :countries, :list, required: true
  attr :map_data, :map, required: true
  attr :api_key, :string, required: true

  defp geo_distribution_map(assigns) do
    ~H"""
    <%= if @countries == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div
        id="analytics-geo-map"
        class="w-full h-80 rounded-lg overflow-hidden border"
        phx-hook="AnalyticsGeoMap"
        phx-update="ignore"
        data-api-key={@api_key}
        data-countries={Jason.encode!(@map_data)}
      >
      </div>
      <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-2">
        <%= for {country_code, session_count} <- @countries do %>
          <div class="text-sm text-gray-600">
            <span class="font-medium"><%= country_name(country_code) %> (<%= country_code %>)</span>: <%= session_count %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :languages, :list, required: true

  defp top_languages_chart(assigns) do
    ~H"""
    <%= if @languages == [] do %>
      <p class="text-gray-500 text-center py-8">No data available</p>
    <% else %>
      <div class="space-y-2">
        <%= for {lang, count} <- @languages do %>
          <div class="flex items-center space-x-2">
            <div class="text-xs text-gray-600 w-32"><%= language_label(lang) %></div>
            <div class="flex-1 bg-gray-200 rounded-full h-3 relative">
              <div class="bg-indigo-600 h-3 rounded-full" style={"width: #{language_bar_width(@languages, count)}%"}></div>
            </div>
            <div class="text-sm font-medium text-gray-900 w-10 text-right"><%= count %></div>
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

      %NaiveDateTime{} = naive ->
        naive
        |> DateTime.from_naive!("Etc/UTC")
        |> Calendar.strftime("%b %d %H:%M")

      binary when is_binary(binary) ->
        case DateTime.from_iso8601(binary) do
          {:ok, dt, _} -> Calendar.strftime(dt, "%b %d %H:%M")
          _ ->
            case NaiveDateTime.from_iso8601(binary) do
              {:ok, naive} ->
                naive
                |> DateTime.from_naive!("Etc/UTC")
                |> Calendar.strftime("%b %d %H:%M")

              _ ->
                "N/A"
            end
        end

      _ ->
        "N/A"
    end
  end

  defp chart_dimensions do
    %{
      width: 640,
      height: 240,
      left: 40,
      right: 20,
      top: 20,
      bottom: 30,
      inner_width: 640 - 40 - 20,
      inner_height: 240 - 20 - 30
    }
  end

  defp chart_points_xy(data) do
    dims = chart_dimensions()
    counts = Enum.map(data, &elem(&1, 1))
    max_count = Enum.max(counts ++ [0])
    n = length(data)

    Enum.with_index(data)
    |> Enum.map(fn {{_timestamp, count}, idx} ->
      x =
        if n == 1 do
          dims.left + dims.inner_width / 2
        else
          dims.left + idx * dims.inner_width / (n - 1)
        end

      y =
        if max_count > 0 do
          dims.top + dims.inner_height - count / max_count * dims.inner_height
        else
          dims.top + dims.inner_height
        end

      {Float.round(x, 1), Float.round(y, 1)}
    end)
  end

  defp chart_points(data) do
    data
    |> chart_points_xy()
    |> Enum.map(fn {x, y} -> "#{x},#{y}" end)
    |> Enum.join(" ")
  end

  defp x_tick_labels(data) do
    dims = chart_dimensions()
    n = length(data)

    if n == 0 do
      []
    else
      indexes = [0, div(n - 1, 2), n - 1] |> Enum.uniq() |> Enum.sort()

      Enum.map(indexes, fn idx ->
        {timestamp, _} = Enum.at(data, idx)

        x =
          if n == 1 do
            dims.left + dims.inner_width / 2
          else
            dims.left + idx * dims.inner_width / (n - 1)
          end

        {Float.round(x, 1), format_timestamp(timestamp)}
      end)
    end
  end

  defp y_tick_labels(data) do
    dims = chart_dimensions()
    counts = Enum.map(data, &elem(&1, 1))
    max_count = Enum.max(counts ++ [0])
    ticks = [0, div(max_count, 2), max_count] |> Enum.uniq() |> Enum.sort()

    Enum.map(ticks, fn tick ->
      y =
        if max_count > 0 do
          dims.top + dims.inner_height - tick / max_count * dims.inner_height
        else
          dims.top + dims.inner_height
        end

      {Float.round(y, 1), tick}
    end)
  end

  defp bar_width(data, count) do
    max_count = data |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
    if max_count > 0, do: Float.round(count / max_count * 100, 1), else: 0
  end

  defp language_bar_width(data, count) do
    max_count = data |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
    if max_count > 0, do: Float.round(count / max_count * 100, 1), else: 0
  end

  defp provider_label(provider) do
    case provider do
      "polly" -> "Polly (AI)"
      "forvo" -> "Forvo (Human)"
      "name_shouts" -> "NameShouts (Human)"
      "cache_local" -> "Cache (Server Local)"
      "cache_remote" -> "Cache (Remote)"
      "cache_client" -> "Cache (Client)"
      nil -> "Unknown"
      other ->
        other
        |> to_string()
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  defp with_all_providers(providers) do
    defaults = [
      %{provider: "polly", avg_generation_time_ms: nil, p95_generation_time_ms: nil, total_requests: 0},
      %{provider: "forvo", avg_generation_time_ms: nil, p95_generation_time_ms: nil, total_requests: 0},
      %{provider: "name_shouts", avg_generation_time_ms: nil, p95_generation_time_ms: nil, total_requests: 0},
      %{provider: "cache_client", avg_generation_time_ms: nil, p95_generation_time_ms: nil, total_requests: 0},
      %{provider: "cache_local", avg_generation_time_ms: nil, p95_generation_time_ms: nil, total_requests: 0},
      %{provider: "cache_remote", avg_generation_time_ms: nil, p95_generation_time_ms: nil, total_requests: 0}
    ]

    map =
      providers
      |> Enum.reduce(%{}, fn row, acc ->
        Map.put(acc, to_string(row.provider || ""), row)
      end)

    defaults
    |> Enum.map(fn row -> Map.get(map, row.provider, row) end)
  end

  defp provider_icon(provider) do
    case provider do
      "polly" -> "🤖"
      "external" -> "👤"
      "forvo" -> "👤"
      "name_shouts" -> "👤"
      _ -> "•"
    end
  end

  defp language_label(nil), do: "Unknown"

  defp language_label(lang) when is_binary(lang) do
    Zonely.NameShoutsParser.language_display_name(lang)
  end

  # country_coordinates removed (map uses MapLibre)

  defp country_name(code) do
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
      "BR" => "Brazil",
      "NL" => "Netherlands"
    }
    |> Map.get(code, code)
  end
end

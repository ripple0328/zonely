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
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50/30 to-slate-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%!-- Header with gradient accent --%>
        <header class="mb-10">
          <div class="flex items-center gap-4 mb-2">
            <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center shadow-lg shadow-indigo-500/25">
              <.icon name="hero-chart-bar" class="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 class="text-2xl font-bold text-slate-900 tracking-tight">Analytics Dashboard</h1>
              <p class="text-sm text-slate-500">SayMyName usage insights</p>
            </div>
          </div>
        </header>

        <%!-- Time Range Pills --%>
        <div class="mb-8 flex items-center justify-between">
          <div class="inline-flex p-1 rounded-xl bg-white/80 backdrop-blur-sm shadow-sm border border-slate-200/60">
            <button
              :for={range <- ["24h", "7d", "30d"]}
              phx-click="change_range"
              phx-value-range={range}
              class={[
                "px-5 py-2 text-sm font-semibold rounded-lg transition-all duration-200",
                if(@time_range == range,
                  do: "bg-gradient-to-r from-indigo-500 to-indigo-600 text-white shadow-md shadow-indigo-500/30",
                  else: "text-slate-600 hover:text-slate-900 hover:bg-slate-50"
                )
              ]}
            >
              {range}
            </button>
          </div>

          <div class="flex items-center gap-2 text-xs text-slate-400">
            <div class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span>Live · Updated {Calendar.strftime(DateTime.utc_now(), "%H:%M")}</span>
          </div>
        </div>

        <%= if @loading do %>
          <div class="flex items-center justify-center h-64">
            <div class="animate-spin rounded-full h-10 w-10 border-2 border-indigo-200 border-t-indigo-600"></div>
          </div>
        <% else %>
          <%!-- Metric Cards --%>
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-10">
            <.metric_card
              title="Total Plays"
              value={@total_pronunciations}
              icon="hero-play-circle"
              gradient="from-indigo-500 to-blue-500"
              tooltip="Total successful plays (all sources) in the selected range."
            />
            <.metric_card
              title="Cache Hit Rate"
              value={"#{@cache_hit_rate}%"}
              icon="hero-bolt"
              gradient="from-emerald-500 to-teal-500"
              tooltip="% of plays served from any cache."
            />
            <.metric_card
              title="Error Rate"
              value={"#{@error_stats.error_rate}%"}
              subtitle={"#{@error_stats.errors} errors"}
              icon="hero-exclamation-triangle"
              gradient={if(@error_stats.error_rate > 5, do: "from-red-500 to-rose-500", else: "from-amber-500 to-orange-500")}
              tooltip="% of events that resulted in errors."
            />
            <.metric_card
              title="Conversion"
              value={"#{@conversion.conversion_rate}%"}
              subtitle={"#{@conversion.converted}/#{@conversion.landed}"}
              icon="hero-arrow-trending-up"
              gradient="from-violet-500 to-purple-500"
              tooltip="% of sessions that requested a pronunciation."
            />
          </div>

          <%!-- Charts Row --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-10">
            <.section_card title="Pronunciations Over Time" subtitle={"per #{@time_bucket_label}"}>
              <.simple_time_chart data={@time_series} />
            </.section_card>

            <.section_card title="Provider Performance" subtitle="latency & usage">
              <.provider_performance_table providers={@provider_performance} />
            </.section_card>
          </div>

          <%!-- Names & Languages Row --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-10">
            <.section_card title="Top Requested Names" subtitle="most popular">
              <.top_names_table names={@top_names} />
            </.section_card>

            <.section_card title="Languages" subtitle="by pronunciation count">
              <.top_languages_chart languages={@top_languages} />
            </.section_card>
          </div>

          <%!-- Geographic Distribution --%>
          <.section_card title="Geographic Distribution" subtitle="plays by country" class="mb-10">
            <.geo_distribution_map countries={@geo_distribution} map_data={@geo_distribution_map} api_key={@maptiler_api_key} />
          </.section_card>

          <%!-- Errors --%>
          <%= if @error_stats.errors > 0 do %>
            <.section_card title="Errors by Type" subtitle="breakdown">
              <.errors_by_type_table errors={@errors_by_type} />
            </.section_card>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Section card component for consistent styling
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  defp section_card(assigns) do
    ~H"""
    <div class={[
      "bg-white/80 backdrop-blur-sm rounded-2xl border border-slate-200/60 shadow-sm shadow-slate-200/50 overflow-hidden",
      @class
    ]}>
      <div class="px-6 py-4 border-b border-slate-100">
        <div class="flex items-baseline gap-2">
          <h2 class="text-base font-semibold text-slate-900">{@title}</h2>
          <%= if @subtitle do %>
            <span class="text-xs text-slate-400 font-medium">{@subtitle}</span>
          <% end %>
        </div>
      </div>
      <div class="p-6">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Components

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :subtitle, :string, default: nil
  attr :icon, :string, required: true
  attr :gradient, :string, default: "from-indigo-500 to-blue-500"
  attr :tooltip, :string, default: nil

  defp metric_card(assigns) do
    ~H"""
    <div
      class="group relative bg-white/80 backdrop-blur-sm rounded-2xl border border-slate-200/60 p-5 shadow-sm hover:shadow-md transition-all duration-300 overflow-hidden"
      title={@tooltip || @title}
    >
      <%!-- Gradient accent bar --%>
      <div class={["absolute top-0 left-0 right-0 h-1 bg-gradient-to-r", @gradient]} />

      <div class="flex items-start justify-between">
        <div class="space-y-1">
          <p class="text-xs font-medium text-slate-500 uppercase tracking-wide">{@title}</p>
          <p class="text-3xl font-bold text-slate-900 tabular-nums" data-metric-value>
            {@value}
          </p>
          <%= if @subtitle do %>
            <p class="text-xs text-slate-400 font-medium">{@subtitle}</p>
          <% end %>
        </div>
        <div class={["w-10 h-10 rounded-xl bg-gradient-to-br flex items-center justify-center shadow-lg", @gradient]}>
          <.icon name={@icon} class="w-5 h-5 text-white" />
        </div>
      </div>
    </div>
    """
  end

  attr :data, :list, required: true

  defp simple_time_chart(assigns) do
    ~H"""
    <%= if @data == [] do %>
      <div class="flex flex-col items-center justify-center py-16 text-slate-400">
        <.icon name="hero-chart-bar" class="w-14 h-14 mb-4 opacity-40" />
        <p class="text-base font-medium">No data available</p>
      </div>
    <% else %>
      <div class="w-full overflow-x-auto">
        <svg viewBox="0 0 640 240" class="w-full h-60">
          <%!-- Grid lines --%>
          <%= for {y, label} <- y_tick_labels(@data) do %>
            <line x1="40" y1={y} x2="620" y2={y} stroke="#f1f5f9" stroke-width="1" />
            <text x="34" y={y + 3} text-anchor="end" class="fill-slate-400 text-[10px] font-medium">
              {label}
            </text>
          <% end %>

          <%!-- Area fill --%>
          <defs>
            <linearGradient id="areaGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color:#6366f1;stop-opacity:0.2" />
              <stop offset="100%" style="stop-color:#6366f1;stop-opacity:0.02" />
            </linearGradient>
          </defs>
          <polygon
            fill="url(#areaGradient)"
            points={"40,210 #{chart_points(@data)} 620,210"}
          />

          <%!-- Line --%>
          <polyline
            fill="none"
            stroke="url(#lineGradient)"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            points={chart_points(@data)}
            class="drop-shadow-sm"
          />
          <defs>
            <linearGradient id="lineGradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" style="stop-color:#6366f1" />
              <stop offset="100%" style="stop-color:#8b5cf6" />
            </linearGradient>
          </defs>

          <%!-- Data points --%>
          <%= for {x, y} <- chart_points_xy(@data) do %>
            <circle cx={x} cy={y} r="3" fill="#6366f1" class="drop-shadow-sm" />
            <circle cx={x} cy={y} r="6" fill="#6366f1" fill-opacity="0.15" />
          <% end %>

          <%!-- X axis labels --%>
          <%= for {x, label} <- x_tick_labels(@data) do %>
            <text x={x} y="232" text-anchor="middle" class="fill-slate-400 text-[10px] font-medium">
              {label}
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
    <div class="overflow-hidden rounded-lg">
      <table class="min-w-full">
        <thead>
          <tr class="border-b border-slate-100">
            <th class="px-3 py-3 text-left text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
              Provider
            </th>
            <th class="px-3 py-3 text-right text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
              Avg
            </th>
            <th class="px-3 py-3 text-right text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
              P95
            </th>
            <th class="px-3 py-3 text-right text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
              Reqs
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
          <%= for provider <- providers do %>
            <tr class="hover:bg-slate-50/50 transition-colors">
              <td class="px-3 py-2.5 text-sm font-medium text-slate-800">
                {provider_label(provider.provider)}
              </td>
              <td class="px-3 py-2.5 text-sm text-slate-500 text-right tabular-nums">
                {provider.avg_generation_time_ms || "—"}
              </td>
              <td class="px-3 py-2.5 text-sm text-slate-500 text-right tabular-nums">
                {provider.p95_generation_time_ms || "—"}
              </td>
              <td class="px-3 py-2.5 text-sm font-medium text-slate-700 text-right tabular-nums">
                {provider.total_requests}
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
    max_count = assigns.names |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <%= if @names == [] do %>
      <div class="flex flex-col items-center justify-center py-16 text-slate-400">
        <.icon name="hero-microphone" class="w-14 h-14 mb-4 opacity-40" />
        <p class="text-base font-medium">No requests yet</p>
      </div>
    <% else %>
      <div class="space-y-2">
        <%= for {row, index} <- Enum.with_index(@names, 1) do %>
          <div class={[
            "group relative flex items-center gap-4 rounded-xl p-4 transition-all duration-200",
            name_rank_styles(index)
          ]}>
            <%!-- Rank indicator --%>
            <div class={["flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center font-bold text-sm", name_badge_styles(index)]}>
              {index}
            </div>

            <%!-- Content --%>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="font-semibold text-slate-900 truncate">{row.name}</span>
                <span class="text-lg opacity-70" title={provider_label(row.provider)}>{provider_icon(row.provider)}</span>
              </div>
              <div class="flex items-center gap-3 mt-2">
                <div class="flex-1 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    class={["h-full rounded-full transition-all duration-500 ease-out", name_bar_styles(index)]}
                    style={"width: #{Float.round(row.count / @max_count * 100, 1)}%"}
                  />
                </div>
                <span class="text-xs font-medium text-slate-400 tabular-nums w-8 text-right">
                  {row.count}
                </span>
              </div>
            </div>

            <%!-- Language pill --%>
            <div class="hidden sm:block">
              <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-slate-100 text-slate-600">
                {language_label(row.lang)}
              </span>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  # Gold #1
  defp name_rank_styles(1), do: "bg-gradient-to-r from-amber-50 via-yellow-50/80 to-amber-50/50 border border-amber-200/60 hover:border-amber-300 hover:shadow-amber-100"
  # Silver #2
  defp name_rank_styles(2), do: "bg-gradient-to-r from-slate-50 via-slate-50/80 to-white border border-slate-200/60 hover:border-slate-300 hover:shadow-slate-100"
  # Bronze #3
  defp name_rank_styles(3), do: "bg-gradient-to-r from-orange-50 via-amber-50/80 to-orange-50/50 border border-orange-200/60 hover:border-orange-300 hover:shadow-orange-100"
  defp name_rank_styles(_), do: "bg-white border border-slate-100 hover:border-slate-200 hover:shadow-sm"

  defp name_badge_styles(1), do: "bg-gradient-to-br from-amber-400 to-yellow-500 text-white shadow-md shadow-amber-200"
  defp name_badge_styles(2), do: "bg-gradient-to-br from-slate-400 to-slate-500 text-white shadow-md shadow-slate-200"
  defp name_badge_styles(3), do: "bg-gradient-to-br from-orange-400 to-amber-500 text-white shadow-md shadow-orange-200"
  defp name_badge_styles(_), do: "bg-slate-100 text-slate-500"

  defp name_bar_styles(1), do: "bg-gradient-to-r from-amber-400 to-yellow-400"
  defp name_bar_styles(2), do: "bg-gradient-to-r from-slate-400 to-slate-500"
  defp name_bar_styles(3), do: "bg-gradient-to-r from-orange-400 to-amber-400"
  defp name_bar_styles(_), do: "bg-indigo-400"

  attr :countries, :list, required: true
  attr :map_data, :map, required: true
  attr :api_key, :string, required: true

  defp geo_distribution_map(assigns) do
    counts = assigns.countries |> Enum.map(&elem(&1, 1))
    max_count = Enum.max(counts ++ [0])
    total_plays = Enum.sum(counts)
    sorted_countries = Enum.sort_by(assigns.countries, &elem(&1, 1), :desc)

    assigns =
      assigns
      |> assign(:max_count, max_count)
      |> assign(:total_plays, total_plays)
      |> assign(:sorted_countries, sorted_countries)
      |> assign(:legend_stops, heatmap_legend_stops(max_count))

    ~H"""
    <%= if @countries == [] do %>
      <div class="flex flex-col items-center justify-center py-20 text-slate-400">
        <.icon name="hero-globe-alt" class="w-16 h-16 mb-4 opacity-40" />
        <p class="text-base font-medium">No geographic data yet</p>
        <p class="text-sm mt-1 text-slate-300">Plays will appear once users start listening</p>
      </div>
    <% else %>
      <div class="space-y-5">
        <%!-- Map container --%>
        <div class="relative rounded-xl overflow-hidden">
          <div
            id="analytics-geo-map"
            class="w-full h-80 lg:h-96"
            phx-hook="AnalyticsGeoMap"
            phx-update="ignore"
            data-api-key={@api_key}
            data-countries={Jason.encode!(@map_data)}
          />

          <%!-- Stats overlay --%>
          <div class="absolute top-3 left-3 bg-white/90 backdrop-blur-md rounded-xl shadow-lg px-4 py-3 border border-white/50">
            <div class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Total Plays</div>
            <div class="text-xl font-bold text-slate-900 tabular-nums">{format_number(@total_plays)}</div>
          </div>

          <%!-- Legend --%>
          <div class="absolute bottom-3 right-3 bg-white/90 backdrop-blur-md rounded-xl shadow-lg px-4 py-3 border border-white/50 min-w-[160px]">
            <div class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider mb-2">Intensity</div>
            <div class="h-2 rounded-full overflow-hidden bg-gradient-to-r from-indigo-100 via-indigo-400 to-indigo-700" />
            <div class="flex justify-between mt-1.5">
              <span class="text-[10px] text-slate-400 font-medium">0</span>
              <%= for stop <- @legend_stops do %>
                <span class="text-[10px] text-slate-400 font-medium tabular-nums">{stop}</span>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Country grid --%>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2">
          <%= for {{country_code, play_count}, index} <- Enum.with_index(@sorted_countries, 1) do %>
            <div class={[
              "flex items-center gap-2.5 p-2.5 rounded-lg transition-all duration-200",
              geo_rank_styles(index)
            ]}>
              <div class={["flex-shrink-0 w-6 h-6 rounded-md flex items-center justify-center text-xs font-bold", geo_badge_styles(index)]}>
                {index}
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-slate-800 truncate">{country_name(country_code)}</div>
                <div class="text-xs text-slate-400 tabular-nums">{format_number(play_count)}</div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp geo_rank_styles(1), do: "bg-gradient-to-r from-amber-50 to-yellow-50/50 border border-amber-200/50"
  defp geo_rank_styles(2), do: "bg-gradient-to-r from-slate-50 to-white border border-slate-200/50"
  defp geo_rank_styles(3), do: "bg-gradient-to-r from-orange-50 to-amber-50/50 border border-orange-200/50"
  defp geo_rank_styles(_), do: "bg-white border border-slate-100 hover:border-slate-200"

  defp geo_badge_styles(1), do: "bg-gradient-to-br from-amber-400 to-yellow-500 text-white shadow-sm"
  defp geo_badge_styles(2), do: "bg-gradient-to-br from-slate-400 to-slate-500 text-white shadow-sm"
  defp geo_badge_styles(3), do: "bg-gradient-to-br from-orange-400 to-amber-500 text-white shadow-sm"
  defp geo_badge_styles(_), do: "bg-slate-100 text-slate-500"

  defp heatmap_legend_stops(max_count) when max_count <= 0, do: []

  defp heatmap_legend_stops(max_count) do
    [div(max_count, 4), div(max_count, 2), max_count]
    |> Enum.uniq()
    |> Enum.filter(&(&1 > 0))
    |> Enum.map(&format_number/1)
  end

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

  attr :languages, :list, required: true

  defp top_languages_chart(assigns) do
    max_count = assigns.languages |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <%= if @languages == [] do %>
      <div class="flex flex-col items-center justify-center py-16 text-slate-400">
        <.icon name="hero-language" class="w-14 h-14 mb-4 opacity-40" />
        <p class="text-base font-medium">No language data</p>
      </div>
    <% else %>
      <div class="space-y-2">
        <%= for {{lang, count}, index} <- Enum.with_index(@languages, 1) do %>
          <div class={[
            "flex items-center gap-3 p-3 rounded-lg transition-all duration-200",
            lang_rank_styles(index)
          ]}>
            <div class={["flex-shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold", lang_badge_styles(index)]}>
              {index}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between mb-1.5">
                <span class="text-sm font-medium text-slate-800">{language_label(lang)}</span>
                <span class="text-xs font-semibold text-slate-500 tabular-nums">{count}</span>
              </div>
              <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  class={["h-full rounded-full transition-all duration-500 ease-out", lang_bar_styles(index)]}
                  style={"width: #{Float.round(count / @max_count * 100, 1)}%"}
                />
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp lang_rank_styles(1), do: "bg-gradient-to-r from-amber-50 to-yellow-50/50 border border-amber-200/50"
  defp lang_rank_styles(2), do: "bg-gradient-to-r from-slate-50 to-white border border-slate-200/50"
  defp lang_rank_styles(3), do: "bg-gradient-to-r from-orange-50 to-amber-50/50 border border-orange-200/50"
  defp lang_rank_styles(_), do: "bg-white border border-slate-100 hover:border-slate-200"

  defp lang_badge_styles(1), do: "bg-gradient-to-br from-amber-400 to-yellow-500 text-white shadow-sm"
  defp lang_badge_styles(2), do: "bg-gradient-to-br from-slate-400 to-slate-500 text-white shadow-sm"
  defp lang_badge_styles(3), do: "bg-gradient-to-br from-orange-400 to-amber-500 text-white shadow-sm"
  defp lang_badge_styles(_), do: "bg-slate-100 text-slate-500"

  defp lang_bar_styles(1), do: "bg-gradient-to-r from-amber-400 to-yellow-400"
  defp lang_bar_styles(2), do: "bg-gradient-to-r from-slate-400 to-slate-500"
  defp lang_bar_styles(3), do: "bg-gradient-to-r from-orange-400 to-amber-400"
  defp lang_bar_styles(_), do: "bg-indigo-400"

  attr :errors, :list, required: true

  defp errors_by_type_table(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-lg">
      <table class="min-w-full">
        <thead>
          <tr class="border-b border-slate-100">
            <th class="px-4 py-3 text-left text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
              Error Type
            </th>
            <th class="px-4 py-3 text-right text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
              Count
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50">
          <%= for {error_type, count} <- @errors do %>
            <tr class="hover:bg-slate-50/50 transition-colors">
              <td class="px-4 py-3 text-sm text-slate-700">{error_type || "Unknown"}</td>
              <td class="px-4 py-3 text-sm font-medium text-slate-900 text-right tabular-nums">{count}</td>
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

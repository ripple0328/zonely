defmodule ZonelyWeb.Admin.AnalyticsDashboardLive do
  use Phoenix.LiveView, layout: {ZonelyWeb.Layouts, :admin}

  import Phoenix.HTML
  import Phoenix.LiveView.Helpers
  import ZonelyWeb.CoreComponents
  use Gettext, backend: ZonelyWeb.Gettext
  alias ZonelyWeb.Layouts
  use Phoenix.VerifiedRoutes, endpoint: ZonelyWeb.Endpoint, router: ZonelyWeb.Router, statics: ZonelyWeb.static_paths()

  alias Zonely.Analytics

  @time_ranges %{
    "24h" => {24, :hour},
    "7d" => {7, :day},
    "30d" => {30, :day}
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time analytics events
      Zonely.Analytics.subscribe()
    end

    socket =
      socket
      |> assign(:page_title, "Analytics · SayMyName")
      |> assign(:time_range, "24h")
      |> assign(:loading, true)
      |> assign(:updated_at, DateTime.utc_now())
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    time_range = Map.get(params, "range", "24h")

    socket =
      socket
      |> assign(:time_range, time_range)
      |> assign(:updated_at, DateTime.utc_now())
      |> load_dashboard_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_range", %{"range" => range}, socket) do
    range = if Map.has_key?(@time_ranges, range), do: range, else: "24h"

    socket =
      socket
      |> assign(:time_range, range)
      |> assign(:updated_at, DateTime.utc_now())
      |> load_dashboard_data()

    {:noreply, push_patch(socket, to: ~p"/admin/analytics?range=#{range}")}
  end

  @impl true
  def handle_info({:analytics_event, _event}, socket) do
    # Real-time update when any analytics event occurs
    {:noreply, socket |> assign(:updated_at, DateTime.utc_now()) |> load_dashboard_data()}
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
              <div class="flex items-center gap-3">
                <h1 class="text-2xl font-bold text-slate-900 tracking-tight">Analytics Dashboard</h1>
                <span class="live-indicator px-2 py-0.5 rounded-full bg-emerald-50 border border-emerald-200 text-xs font-medium text-emerald-700">
                  <span class="live-indicator-dot"></span>
                  Live
                </span>
              </div>
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
            <span>Live · Updated <span id="updated-at-time" phx-hook="LocalTime" data-utc={DateTime.to_iso8601(@updated_at)}>--:--</span></span>
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

            <.section_card title="Provider Performance" subtitle="plays by TTS provider">
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
      data-metric-card
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
            <p class="text-xs text-slate-400 font-medium" data-metric-value>{@subtitle}</p>
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

  # ==========================================================================
  # Unified Ranking Components
  # ==========================================================================
  # All ranking UIs use consistent styling:
  # - space-y-3 for vertical spacing
  # - p-3, gap-3 for card padding
  # - w-7 h-7 rounded badges
  # - Gold/Silver/Bronze gradients for top 3
  # - Optional progress bars
  # ==========================================================================

  # Unified rank card styles (used by all ranking components)
  # Uses indigo gradient theme - top 3 get progressively lighter indigo backgrounds
  defp rank_card_styles(1), do: "bg-gradient-to-r from-indigo-100 to-indigo-50 border border-indigo-200/60"
  defp rank_card_styles(2), do: "bg-gradient-to-r from-indigo-50 to-slate-50 border border-indigo-100/50"
  defp rank_card_styles(3), do: "bg-gradient-to-r from-slate-50 to-white border border-slate-200/50"
  defp rank_card_styles(_), do: "bg-white border border-slate-100 hover:border-slate-200"

  defp rank_badge_styles(1), do: "bg-gradient-to-br from-indigo-500 to-indigo-600 text-white shadow-sm"
  defp rank_badge_styles(2), do: "bg-gradient-to-br from-indigo-400 to-indigo-500 text-white shadow-sm"
  defp rank_badge_styles(3), do: "bg-gradient-to-br from-slate-400 to-slate-500 text-white shadow-sm"
  defp rank_badge_styles(_), do: "bg-slate-100 text-slate-500"

  defp rank_bar_styles(1), do: "bg-gradient-to-r from-indigo-500 to-indigo-400"
  defp rank_bar_styles(2), do: "bg-gradient-to-r from-indigo-400 to-indigo-300"
  defp rank_bar_styles(3), do: "bg-gradient-to-r from-slate-400 to-slate-300"
  defp rank_bar_styles(_), do: "bg-slate-300"

  attr :providers, :list, required: true

  defp provider_performance_table(assigns) do
    providers = if assigns.providers == [], do: with_all_providers([]), else: assigns.providers
    providers_sorted = Enum.sort_by(providers, & &1.total_requests, :desc)
    max_requests = providers_sorted |> Enum.map(& &1.total_requests) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, providers: providers_sorted, max_requests: max_requests)

    ~H"""
    <div class="space-y-3">
      <%= for {provider, index} <- Enum.with_index(@providers, 1) do %>
        <div
          class={[
            "flex items-center gap-3 p-3 rounded-lg transition-all duration-200",
            rank_card_styles(index)
          ]}
          data-rank-item
        >
          <div class={["flex-shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold", rank_badge_styles(index)]}>
            {index}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between mb-1.5">
              <span class="text-sm font-medium text-slate-800 truncate">{provider_label(provider.provider)}</span>
              <span class="text-xs font-semibold text-indigo-600 tabular-nums" data-metric-value>{provider.total_requests} plays</span>
            </div>
            <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
              <div
                class={["h-full rounded-full transition-all duration-500 ease-out", rank_bar_styles(index)]}
                style={"width: #{if @max_requests > 0, do: Float.round(provider.total_requests / @max_requests * 100, 1), else: 0}%"}
              />
            </div>
          </div>
          <%= if provider.avg_generation_time_ms do %>
            <div class="hidden sm:flex items-center gap-1 text-xs text-slate-400 tabular-nums">
              <span class="text-slate-600 font-medium">{provider.avg_generation_time_ms}ms</span>
              <%= if provider.p95_generation_time_ms do %>
                <span class="text-slate-300">·</span>
                <span class="text-slate-400">p95: {provider.p95_generation_time_ms}ms</span>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
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
      <div class="space-y-3">
        <%= for {row, index} <- Enum.with_index(@names, 1) do %>
          <div
            class={[
              "flex items-center gap-3 p-3 rounded-lg transition-all duration-200",
              rank_card_styles(index)
            ]}
            data-rank-item
          >
            <div class={["flex-shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold", rank_badge_styles(index)]}>
              {index}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between mb-1.5">
                <div class="flex items-center gap-2 min-w-0">
                  <span class="text-sm font-medium text-slate-800 truncate">{row.name}</span>
                  <span class="text-sm opacity-60" title={provider_label(row.provider)}>{provider_icon(row.provider)}</span>
                </div>
                <span class="text-xs font-semibold text-slate-500 tabular-nums" data-metric-value>{row.count}</span>
              </div>
              <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  class={["h-full rounded-full transition-all duration-500 ease-out", rank_bar_styles(index)]}
                  style={"width: #{Float.round(row.count / @max_count * 100, 1)}%"}
                />
              </div>
            </div>
            <div class="hidden sm:block">
              <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-500">
                {language_label(row.lang)}
              </span>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

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

        <%!-- Country list - unified ranking style --%>
        <div class="space-y-3">
          <%= for {{country_code, play_count}, index} <- Enum.with_index(@sorted_countries, 1) do %>
            <div
              class={[
                "flex items-center gap-3 p-3 rounded-lg transition-all duration-200",
                rank_card_styles(index)
              ]}
              data-rank-item
            >
              <div class={["flex-shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold", rank_badge_styles(index)]}>
                {index}
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between mb-1.5">
                  <span class="text-sm font-medium text-slate-800 truncate">{country_name(country_code)}</span>
                  <span class="text-xs font-semibold text-slate-500 tabular-nums" data-metric-value>{format_number(play_count)}</span>
                </div>
                <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    class={["h-full rounded-full transition-all duration-500 ease-out", rank_bar_styles(index)]}
                    style={"width: #{if @max_count > 0, do: Float.round(play_count / @max_count * 100, 1), else: 0}%"}
                  />
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

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
      <div class="space-y-3">
        <%= for {{lang, count}, index} <- Enum.with_index(@languages, 1) do %>
          <div
            class={[
              "flex items-center gap-3 p-3 rounded-lg transition-all duration-200",
              rank_card_styles(index)
            ]}
            data-rank-item
          >
            <div class={["flex-shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold", rank_badge_styles(index)]}>
              {index}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between mb-1.5">
                <span class="text-sm font-medium text-slate-800">{language_label(lang)}</span>
                <span class="text-xs font-semibold text-slate-500 tabular-nums" data-metric-value>{count}</span>
              </div>
              <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  class={["h-full rounded-full transition-all duration-500 ease-out", rank_bar_styles(index)]}
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

  attr :errors, :list, required: true

  defp errors_by_type_table(assigns) do
    errors_sorted = Enum.sort_by(assigns.errors, fn {_type, count} -> count end, :desc)
    max_count = errors_sorted |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, errors: errors_sorted, max_count: max_count)

    ~H"""
    <%= if @errors == [] do %>
      <div class="flex flex-col items-center justify-center py-16 text-slate-400">
        <.icon name="hero-check-circle" class="w-14 h-14 mb-4 opacity-40" />
        <p class="text-base font-medium">No errors</p>
      </div>
    <% else %>
      <div class="space-y-3">
        <%= for {{error_type, count}, index} <- Enum.with_index(@errors, 1) do %>
          <div class={[
            "flex items-center gap-3 p-3 rounded-lg transition-all duration-200",
            rank_card_styles(index)
          ]}>
            <div class={["flex-shrink-0 w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold", rank_badge_styles(index)]}>
              {index}
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between mb-1.5">
                <span class="text-sm font-medium text-slate-800 truncate">{error_type || "Unknown"}</span>
                <span class="text-xs font-semibold text-slate-500 tabular-nums">{count}</span>
              </div>
              <div class="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                <div
                  class={["h-full rounded-full transition-all duration-500 ease-out", rank_bar_styles(index)]}
                  style={"width: #{if @max_count > 0, do: Float.round(count / @max_count * 100, 1), else: 0}%"}
                />
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
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

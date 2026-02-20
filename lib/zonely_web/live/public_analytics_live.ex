defmodule ZonelyWeb.PublicAnalyticsLive do
  use Phoenix.LiveView, layout: false

  import Phoenix.HTML
  use Gettext, backend: ZonelyWeb.Gettext
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
      Analytics.subscribe()
      Analytics.track_async("page_view_analytics", %{})
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

    {:noreply, push_patch(socket, to: ~p"/analytics?range=#{range}")}
  end

  @impl true
  def handle_info({:analytics_event, _event}, socket) do
    {:noreply, socket |> assign(:updated_at, DateTime.utc_now()) |> load_dashboard_data()}
  end

  defp load_dashboard_data(socket) do
    time_range = socket.assigns.time_range
    {amount, unit} = Map.get(@time_ranges, time_range, {24, :hour})

    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -amount, unit)

    total_pronunciations = Analytics.total_pronunciations(start_date, end_date)
    top_names = Analytics.top_requested_names(start_date, end_date, 5)
    geo_distribution = Analytics.geographic_distribution(start_date, end_date, 100)
    top_languages = Analytics.top_languages(start_date, end_date, 5)

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
    |> assign(:total_pronunciations, total_pronunciations)
    |> assign(:top_names, top_names)
    |> assign(:geo_distribution, geo_distribution)
    |> assign(:geo_distribution_map, geo_distribution_map)
    |> assign(:maptiler_api_key, maptiler_api_key)
    |> assign(:top_languages, top_languages)
    |> assign(:time_series, time_series)
    |> assign(:time_bucket_label, bucket_label)
  end

  # ── Render ──────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
      <title>{@page_title}</title>
      <meta name="color-scheme" content="light dark" />
      <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
      <link rel="icon" type="image/svg+xml" href={~p"/favicon.svg?v=3"} />
      <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
      <style>
        <%= raw(page_styles()) %>
      </style>
    </head>
    <body class="pa-body">
      <div class="pa-wrap">
        <.page_header time_range={@time_range} updated_at={@updated_at} />

        <%= if @loading do %>
          <div class="pa-loading">
            <div class="pa-spinner"></div>
          </div>
        <% else %>
          <.metric_hero total={@total_pronunciations} />

          <div class="pa-grid-2">
            <.section_card title="Pronunciations Over Time" subtitle={"per #{@time_bucket_label}"}>
              <.time_chart data={@time_series} />
            </.section_card>
            <.section_card title="Top Languages" subtitle="by pronunciation count">
              <.languages_chart languages={@top_languages} />
            </.section_card>
          </div>

          <.section_card title="Geographic Distribution" subtitle="plays by country" class="pa-mb">
            <.geo_map countries={@geo_distribution} map_data={@geo_distribution_map} api_key={@maptiler_api_key} />
          </.section_card>

          <.section_card title="Top Requested Names" subtitle="most popular">
            <.names_table names={@top_names} />
          </.section_card>
        <% end %>

        <footer class="pa-footer">
          <a href="/" class="pa-back">← Back to SayMyName</a>
        </footer>
      </div>
    </body>
    </html>
    """
  end

  # ── Page Header Component ──────────────────────────────────────────

  attr :time_range, :string, required: true
  attr :updated_at, :any, required: true

  defp page_header(assigns) do
    ~H"""
    <header class="pa-header">
      <div class="pa-header-top">
        <a href="/" class="pa-brand">
          <img src={~p"/favicon-32x32.png?v=3"} alt="SayMyName" class="pa-logo" />
          <span class="pa-brand-text">SayMyName</span>
        </a>
        <div class="pa-live-badge">
          <span class="pa-live-dot"></span>
          <span>Live</span>
        </div>
      </div>
      <h1 class="pa-title">Analytics</h1>
      <p class="pa-subtitle">See how people are using SayMyName around the world</p>
      <div class="pa-controls">
        <div class="pa-range-pills">
          <button
            :for={range <- ["24h", "7d", "30d"]}
            phx-click="change_range"
            phx-value-range={range}
            class={["pa-pill", @time_range == range && "pa-pill-active"]}
          >
            {range}
          </button>
        </div>
        <div class="pa-updated">
          Updated <span id="updated-at-time" phx-hook="LocalTime" data-utc={DateTime.to_iso8601(@updated_at)}>--:--</span>
        </div>
      </div>
    </header>
    """
  end

  # ── Metric Hero (Total Plays) ──────────────────────────────────────

  attr :total, :integer, required: true

  defp metric_hero(assigns) do
    ~H"""
    <div class="pa-hero" data-metric-card>
      <div class="pa-hero-icon">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="currentColor"><path fill-rule="evenodd" d="M4.5 5.653c0-1.426 1.529-2.33 2.779-1.643l11.54 6.348c1.295.712 1.295 2.573 0 3.285L7.28 19.991c-1.25.687-2.779-.217-2.779-1.643V5.653z" clip-rule="evenodd"/></svg>
      </div>
      <div class="pa-hero-label">Total Plays</div>
      <div class="pa-hero-value" data-metric-value>{format_number(@total)}</div>
    </div>
    """
  end

  # ── Section Card ────────────────────────────────────────────────────

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  defp section_card(assigns) do
    ~H"""
    <div class={["pa-card", @class]}>
      <div class="pa-card-header">
        <h2 class="pa-card-title">{@title}</h2>
        <%= if @subtitle do %>
          <span class="pa-card-subtitle">{@subtitle}</span>
        <% end %>
      </div>
      <div class="pa-card-body">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ── Time Chart ──────────────────────────────────────────────────────

  attr :data, :list, required: true

  defp time_chart(assigns) do
    ~H"""
    <%= if @data == [] do %>
      <div class="pa-empty">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 13h4v8H3zm7-5h4v13h-4zm7-4h4v17h-4z"/></svg>
        <p>No data available</p>
      </div>
    <% else %>
      <div class="pa-chart-wrap">
        <svg viewBox="0 0 640 240" class="pa-chart-svg">
          <%= for {y, label} <- y_tick_labels(@data) do %>
            <line x1="40" y1={y} x2="620" y2={y} stroke="currentColor" stroke-opacity="0.1" stroke-width="1" />
            <text x="34" y={y + 3} text-anchor="end" class="pa-chart-label">{label}</text>
          <% end %>
          <defs>
            <linearGradient id="pub-area-grad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" style="stop-color:#6366f1;stop-opacity:0.25" />
              <stop offset="100%" style="stop-color:#6366f1;stop-opacity:0.02" />
            </linearGradient>
            <linearGradient id="pub-line-grad" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" style="stop-color:#6366f1" />
              <stop offset="100%" style="stop-color:#a78bfa" />
            </linearGradient>
          </defs>
          <polygon fill="url(#pub-area-grad)" points={"40,210 #{chart_points(@data)} 620,210"} />
          <polyline fill="none" stroke="url(#pub-line-grad)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" points={chart_points(@data)} />
          <%= for {x, y} <- chart_points_xy(@data) do %>
            <circle cx={x} cy={y} r="3" fill="#6366f1" />
            <circle cx={x} cy={y} r="6" fill="#6366f1" fill-opacity="0.15" />
          <% end %>
          <%= for {x, label} <- x_tick_labels(@data) do %>
            <text x={x} y="232" text-anchor="middle" class="pa-chart-label">{label}</text>
          <% end %>
        </svg>
      </div>
    <% end %>
    """
  end

  # ── Languages Chart ─────────────────────────────────────────────────

  attr :languages, :list, required: true

  defp languages_chart(assigns) do
    max_count = assigns.languages |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <%= if @languages == [] do %>
      <div class="pa-empty">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M10.5 21l5.25-11.25L21 21m-9-3h7.5M3 5.621a48.474 48.474 0 016-.371m0 0c1.12 0 2.233.038 3.334.114M9 5.25V3m3.334 2.364V3"/></svg>
        <p>No language data</p>
      </div>
    <% else %>
      <div class="pa-rank-list">
        <%= for {{lang, count}, index} <- Enum.with_index(@languages, 1) do %>
          <div class={["pa-rank-item", rank_class(index)]} data-rank-item>
            <div class={["pa-rank-badge", badge_class(index)]}>{index}</div>
            <div class="pa-rank-content">
              <div class="pa-rank-row">
                <span class="pa-rank-name">{language_label(lang)}</span>
                <span class="pa-rank-count" data-metric-value>{count}</span>
              </div>
              <div class="pa-rank-bar-bg">
                <div class={["pa-rank-bar", bar_class(index)]} style={"width: #{Float.round(count / @max_count * 100, 1)}%"}></div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  # ── Geographic Distribution Map ─────────────────────────────────────

  attr :countries, :list, required: true
  attr :map_data, :map, required: true
  attr :api_key, :string, required: true

  defp geo_map(assigns) do
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
      <div class="pa-empty pa-empty-lg">
        <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 014 10 15.3 15.3 0 01-4 10 15.3 15.3 0 01-4-10 15.3 15.3 0 014-10z"/></svg>
        <p>No geographic data yet</p>
        <span class="pa-empty-sub">Plays will appear once users start listening</span>
      </div>
    <% else %>
      <div class="pa-geo-section">
        <div class="pa-map-container">
          <div
            id="analytics-geo-map"
            class="pa-map"
            phx-hook="AnalyticsGeoMap"
            phx-update="ignore"
            data-api-key={@api_key}
            data-countries={Jason.encode!(@map_data)}
          />
          <div class="pa-map-overlay pa-map-overlay-tl">
            <div class="pa-map-stat-label">Total Plays</div>
            <div class="pa-map-stat-value">{format_number(@total_plays)}</div>
          </div>
          <div class="pa-map-overlay pa-map-overlay-br">
            <div class="pa-map-stat-label">Intensity</div>
            <div class="pa-map-legend-bar"></div>
            <div class="pa-map-legend-labels">
              <span>0</span>
              <%= for stop <- @legend_stops do %>
                <span>{stop}</span>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end



  # ── Names Table ─────────────────────────────────────────────────────

  attr :names, :list, required: true

  defp names_table(assigns) do
    max_count = assigns.names |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)
    assigns = assign(assigns, :max_count, max_count)

    ~H"""
    <%= if @names == [] do %>
      <div class="pa-empty">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 18.75a6 6 0 006-6v-1.5m-6 7.5a6 6 0 01-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 01-3-3V4.5a3 3 0 116 0v8.25a3 3 0 01-3 3z"/></svg>
        <p>No requests yet</p>
      </div>
    <% else %>
      <div class="pa-rank-list">
        <%= for {row, index} <- Enum.with_index(@names, 1) do %>
          <div class={["pa-rank-item", rank_class(index)]} data-rank-item>
            <div class={["pa-rank-badge", badge_class(index)]}>{index}</div>
            <div class="pa-rank-content">
              <div class="pa-rank-row">
                <div class="pa-rank-name-group">
                  <span class="pa-rank-name">{row.name}</span>
                  <span class="pa-rank-provider">{provider_icon(row.provider)}</span>
                </div>
                <div class="pa-rank-meta">
                  <span class="pa-rank-lang-tag">{language_label(row.lang)}</span>
                  <span class="pa-rank-count" data-metric-value>{row.count}</span>
                </div>
              </div>
              <div class="pa-rank-bar-bg">
                <div class={["pa-rank-bar", bar_class(index)]} style={"width: #{Float.round(row.count / @max_count * 100, 1)}%"}></div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  # ── Ranking Style Helpers ───────────────────────────────────────────

  defp rank_class(1), do: "pa-rank-1"
  defp rank_class(2), do: "pa-rank-2"
  defp rank_class(3), do: "pa-rank-3"
  defp rank_class(_), do: "pa-rank-n"

  defp badge_class(1), do: "pa-badge-1"
  defp badge_class(2), do: "pa-badge-2"
  defp badge_class(3), do: "pa-badge-3"
  defp badge_class(_), do: "pa-badge-n"

  defp bar_class(1), do: "pa-bar-1"
  defp bar_class(2), do: "pa-bar-2"
  defp bar_class(3), do: "pa-bar-3"
  defp bar_class(_), do: "pa-bar-n"

  # ── Chart Helpers ───────────────────────────────────────────────────

  defp chart_dimensions do
    %{width: 640, height: 240, left: 40, right: 20, top: 20, bottom: 30,
      inner_width: 640 - 40 - 20, inner_height: 240 - 20 - 30}
  end

  defp chart_points_xy(data) do
    dims = chart_dimensions()
    counts = Enum.map(data, &elem(&1, 1))
    max_count = Enum.max(counts ++ [0])
    n = length(data)

    Enum.with_index(data)
    |> Enum.map(fn {{_ts, count}, idx} ->
      x = if n == 1, do: dims.left + dims.inner_width / 2, else: dims.left + idx * dims.inner_width / (n - 1)
      y = if max_count > 0, do: dims.top + dims.inner_height - count / max_count * dims.inner_height, else: dims.top + dims.inner_height
      {Float.round(x, 1), Float.round(y, 1)}
    end)
  end

  defp chart_points(data) do
    data |> chart_points_xy() |> Enum.map(fn {x, y} -> "#{x},#{y}" end) |> Enum.join(" ")
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
        x = if n == 1, do: dims.left + dims.inner_width / 2, else: dims.left + idx * dims.inner_width / (n - 1)
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
      y = if max_count > 0, do: dims.top + dims.inner_height - tick / max_count * dims.inner_height, else: dims.top + dims.inner_height
      {Float.round(y, 1), tick}
    end)
  end

  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} -> Calendar.strftime(timestamp, "%b %d %H:%M")
      %NaiveDateTime{} = naive -> naive |> DateTime.from_naive!("Etc/UTC") |> Calendar.strftime("%b %d %H:%M")
      binary when is_binary(binary) ->
        case DateTime.from_iso8601(binary) do
          {:ok, dt, _} -> Calendar.strftime(dt, "%b %d %H:%M")
          _ ->
            case NaiveDateTime.from_iso8601(binary) do
              {:ok, naive} -> naive |> DateTime.from_naive!("Etc/UTC") |> Calendar.strftime("%b %d %H:%M")
              _ -> "N/A"
            end
        end
      _ -> "N/A"
    end
  end

  # ── Format Helpers ──────────────────────────────────────────────────

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

  defp heatmap_legend_stops(max_count) when max_count <= 0, do: []
  defp heatmap_legend_stops(max_count) do
    [div(max_count, 4), div(max_count, 2), max_count]
    |> Enum.uniq()
    |> Enum.filter(&(&1 > 0))
    |> Enum.map(&format_number/1)
  end

  defp language_label(nil), do: "Unknown"
  defp language_label(lang) when is_binary(lang), do: Zonely.NameShoutsParser.language_display_name(lang)

  defp provider_icon(provider) do
    case provider do
      "polly" -> "🤖"
      "forvo" -> "👤"
      "name_shouts" -> "👤"
      _ -> "•"
    end
  end



  # ── Page Styles ──────────────────────────────────────────────────────

  defp page_styles do
    """
    :root{--bg:#fafafa;--fg:#18181b;--muted:#71717a;--ring:#e4e4e7;--accent:#6366f1;--card:rgba(255,255,255,.72);--card-border:rgba(0,0,0,.06);--hero-bg:linear-gradient(135deg,#eef2ff,#ede9fe);--badge-1:#eef2ff;--badge-1-fg:#4f46e5;--badge-2:#fef3c7;--badge-2-fg:#b45309;--badge-3:#fce7f3;--badge-3-fg:#be185d;--badge-n:#f4f4f5;--badge-n-fg:#52525b;--bar-1:#6366f1;--bar-2:#f59e0b;--bar-3:#ec4899;--bar-n:#a1a1aa;--legend-low:#eef2ff;--legend-high:#4338ca}
    @media(prefers-color-scheme:dark){:root{--bg:#09090b;--fg:#fafafa;--muted:#a1a1aa;--ring:#27272a;--accent:#818cf8;--card:rgba(24,24,27,.6);--card-border:rgba(255,255,255,.06);--hero-bg:linear-gradient(135deg,#1e1b4b,#312e81);--badge-1:#312e81;--badge-1-fg:#a5b4fc;--badge-2:#78350f;--badge-2-fg:#fde68a;--badge-3:#831843;--badge-3-fg:#fbcfe8;--badge-n:#27272a;--badge-n-fg:#a1a1aa;--bar-1:#818cf8;--bar-2:#fbbf24;--bar-3:#f472b6;--bar-n:#71717a;--legend-low:#1e1b4b;--legend-high:#a5b4fc}}
    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
    .pa-body{background:var(--bg);color:var(--fg);font-family:system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;-webkit-font-smoothing:antialiased;min-height:100vh}
    .pa-wrap{max-width:960px;margin:0 auto;padding:24px 16px 48px}
    @media(min-width:640px){.pa-wrap{padding:32px 24px 64px}}

    /* Header */
    .pa-header{margin-bottom:32px}
    .pa-header-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}
    .pa-brand{display:inline-flex;align-items:center;gap:8px;text-decoration:none;color:var(--fg);font-weight:700;font-size:15px;transition:opacity .2s}
    .pa-brand:hover{opacity:.7}
    .pa-logo{width:24px;height:24px;border-radius:6px}
    .pa-brand-text{letter-spacing:-.02em}
    .pa-live-badge{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:600;color:var(--accent);background:var(--badge-1);padding:4px 10px;border-radius:999px}
    .pa-live-dot{width:8px;height:8px;border-radius:50%;background:var(--accent);animation:pa-pulse 2s ease-in-out infinite}
    @keyframes pa-pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.4;transform:scale(.8)}}
    .pa-title{font-size:clamp(28px,5vw,42px);font-weight:800;letter-spacing:-.03em;line-height:1.1;margin-bottom:6px}
    .pa-subtitle{color:var(--muted);font-size:15px;margin-bottom:20px}
    .pa-controls{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px}
    .pa-range-pills{display:flex;gap:4px}
    .pa-pill{background:transparent;border:1px solid var(--ring);color:var(--muted);font-size:13px;font-weight:600;padding:6px 14px;border-radius:999px;cursor:pointer;transition:all .2s}
    .pa-pill:hover{border-color:var(--accent);color:var(--accent)}
    .pa-pill-active{background:var(--accent);border-color:var(--accent);color:#fff}
    .pa-updated{font-size:12px;color:var(--muted)}

    /* Loading */
    .pa-loading{display:flex;align-items:center;justify-content:center;min-height:320px}
    .pa-spinner{width:36px;height:36px;border:3px solid var(--ring);border-top-color:var(--accent);border-radius:50%;animation:pa-spin .7s linear infinite}
    @keyframes pa-spin{to{transform:rotate(360deg)}}

    /* Hero metric */
    .pa-hero{background:var(--hero-bg);border-radius:16px;padding:28px;text-align:center;margin-bottom:24px;position:relative;overflow:hidden}
    .pa-hero::after{content:'';position:absolute;inset:0;border-radius:16px;border:1px solid var(--card-border);pointer-events:none}
    .pa-hero-icon{color:var(--accent);margin-bottom:8px;opacity:.8}
    .pa-hero-label{font-size:13px;font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:.05em;margin-bottom:4px}
    .pa-hero-value{font-size:clamp(36px,7vw,56px);font-weight:800;letter-spacing:-.04em;line-height:1}

    /* Cards */
    .pa-card{background:var(--card);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);border:1px solid var(--card-border);border-radius:14px;margin-bottom:20px;overflow:hidden}
    .pa-card-header{padding:18px 20px 0}
    .pa-card-title{font-size:16px;font-weight:700;letter-spacing:-.01em}
    .pa-card-subtitle{font-size:12px;color:var(--muted);margin-top:2px;display:block}
    .pa-card-body{padding:16px 20px 20px}
    .pa-grid-2{display:grid;grid-template-columns:1fr;gap:20px}
    @media(min-width:640px){.pa-grid-2{grid-template-columns:1fr 1fr}}
    .pa-mb{margin-bottom:20px}

    /* Chart */
    .pa-chart-wrap{overflow-x:auto}
    .pa-chart-svg{width:100%;height:auto;color:var(--fg)}
    .pa-chart-label{font-size:10px;fill:var(--muted)}

    /* Rank list */
    .pa-rank-list{display:flex;flex-direction:column;gap:8px}
    .pa-rank-item{display:flex;align-items:flex-start;gap:10px;padding:10px 12px;border-radius:10px;transition:background .15s}
    .pa-rank-1,.pa-rank-2,.pa-rank-3{background:color-mix(in srgb,var(--card) 80%,transparent)}
    .pa-rank-item:hover{background:color-mix(in srgb,var(--accent) 5%,var(--card))}
    .pa-rank-badge{width:26px;height:26px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;flex-shrink:0}
    .pa-badge-1{background:var(--badge-1);color:var(--badge-1-fg)}
    .pa-badge-2{background:var(--badge-2);color:var(--badge-2-fg)}
    .pa-badge-3{background:var(--badge-3);color:var(--badge-3-fg)}
    .pa-badge-n{background:var(--badge-n);color:var(--badge-n-fg)}
    .pa-rank-content{flex:1;min-width:0}
    .pa-rank-row{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:6px}
    .pa-rank-name{font-weight:600;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .pa-rank-count{font-weight:700;font-size:14px;font-variant-numeric:tabular-nums;flex-shrink:0}
    .pa-rank-bar-bg{height:4px;border-radius:2px;background:var(--ring);overflow:hidden}
    .pa-rank-bar{height:100%;border-radius:2px;transition:width .6s cubic-bezier(.22,1,.36,1)}
    .pa-bar-1{background:var(--bar-1)}.pa-bar-2{background:var(--bar-2)}.pa-bar-3{background:var(--bar-3)}.pa-bar-n{background:var(--bar-n)}
    .pa-rank-name-group{display:flex;align-items:center;gap:6px;min-width:0}
    .pa-rank-provider{font-size:14px;flex-shrink:0}
    .pa-rank-meta{display:flex;align-items:center;gap:8px;flex-shrink:0}
    .pa-rank-lang-tag{font-size:11px;color:var(--muted);background:var(--badge-n);padding:2px 7px;border-radius:4px;font-weight:500}

    /* Empty states */
    .pa-empty{display:flex;flex-direction:column;align-items:center;justify-content:center;padding:32px 16px;color:var(--muted);text-align:center;gap:8px}
    .pa-empty p{font-size:14px;font-weight:500}
    .pa-empty-lg{padding:48px 16px}
    .pa-empty-sub{font-size:12px;opacity:.7}

    /* Geo map */
    .pa-geo-section{display:flex;flex-direction:column;gap:16px}
    .pa-map-container{position:relative;border-radius:10px;overflow:hidden;height:360px}
    @media(min-width:640px){.pa-map-container{height:420px}}
    .pa-map{width:100%;height:100%}
    .pa-map-overlay{position:absolute;background:var(--card);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border:1px solid var(--card-border);border-radius:8px;padding:8px 12px;font-size:12px;z-index:2}
    .pa-map-overlay-tl{top:12px;left:12px}
    .pa-map-overlay-br{bottom:12px;right:12px}
    .pa-map-stat-label{color:var(--muted);font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:.04em}
    .pa-map-stat-value{font-size:20px;font-weight:800;letter-spacing:-.02em}
    .pa-map-legend-bar{height:6px;width:120px;border-radius:3px;background:linear-gradient(90deg,var(--legend-low),var(--legend-high));margin:4px 0 2px}
    .pa-map-legend-labels{display:flex;justify-content:space-between;font-size:9px;color:var(--muted)}

    /* Footer */
    .pa-footer{text-align:center;margin-top:48px;padding-top:24px;border-top:1px solid var(--ring)}
    .pa-back{color:var(--muted);text-decoration:none;font-size:14px;font-weight:500;transition:color .2s}
    .pa-back:hover{color:var(--accent)}
    """
  end

end
defmodule ZonelyWeb.Router do
  use ZonelyWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ZonelyWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :map_layout do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ZonelyWeb.Layouts, :root})
    plug(:put_layout, html: {ZonelyWeb.Layouts, :map})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :no_cache do
    plug(:no_cache_headers)
  end

  # Minimal, layout-free pipeline for standalone host
  pipeline :bare do
    plug(:accepts, ["html"])
    plug(:put_root_layout, false)
    plug(:put_layout, false)
    plug(:put_secure_browser_headers)
  end

  pipeline :health do
    plug(:put_root_layout, false)
    plug(:put_layout, false)
    plug(:put_secure_browser_headers)
  end

  # Standalone minimal site served on saymyname.qingbo.us (host-specific must be before generic "/" scopes)

  # Health endpoints (used by uptime checks)
  scope "/", ZonelyWeb, host: "saymyname.qingbo.us" do
    pipe_through(:health)

    get("/healthz", HealthController, :healthz)
    get("/readyz", HealthController, :readyz)
  end

  scope "/", ZonelyWeb, host: "saymyname.qingbo.us" do
    pipe_through(:api)

    post("/api/analytics/play", AnalyticsController, :play)
    get("/api/analytics/dashboard", AnalyticsController, :dashboard)
  end

  scope "/", ZonelyWeb, host: "saymyname.qingbo.us" do
    pipe_through(:bare)

    get("/", NameSiteController, :index)
    get("/privacy", NameSiteController, :privacy)
    # Apple App Site Association for Universal Links
    get("/.well-known/apple-app-site-association", NameSiteController, :aasa)
    # Ensure audio-cache is reachable from the standalone host
    get("/audio-cache/:filename", AudioCacheController, :show)
    get("/api/pronounce", NameSiteController, :pronounce)
    get("/about", NameSiteController, :about)
    live("/native", NativePronounceLive)
    live("/analytics", PublicAnalyticsLive)
  end

  scope "/", ZonelyWeb do
    pipe_through(:map_layout)

    live("/", MapLive)
  end

  scope "/", ZonelyWeb do
    pipe_through(:browser)

    # Serve runtime audio files safely
    get("/audio-cache/:filename", AudioCacheController, :show)

    live("/demo", DemoLive)
    live("/directory", DirectoryLive)
    live("/work-hours", WorkHoursLive)
    live("/holidays", HolidaysLive)
  end

  # Public API fallback for local development (so native app can call /api/pronounce at root)
  scope "/", ZonelyWeb do
    pipe_through(:api)
    get("/api/pronounce", NameSiteController, :pronounce)
    post("/api/analytics/play", AnalyticsController, :play)
    get("/api/analytics/dashboard", AnalyticsController, :dashboard)
  end

  # Local development access at /name
  scope "/name", ZonelyWeb do
    pipe_through(:bare)

    get("/", NameSiteController, :index)
    get("/privacy", NameSiteController, :privacy)
    get("/about", NameSiteController, :about)
    # Ensure audio-cache works under /name scope as well
    get("/audio-cache/:filename", AudioCacheController, :show)
    get("/api/pronounce", NameSiteController, :pronounce)
    live("/native", NativePronounceLive)
  end

  # Admin routes (protected, internal only)
  # TODO: Add authentication plug for production
  scope "/admin", ZonelyWeb.Admin do
    pipe_through([:browser, :no_cache])

    live("/analytics", AnalyticsDashboardLive)
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZonelyWeb do
  #   pipe_through :api
  # end

  defp no_cache_headers(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate, proxy-revalidate")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:zonely, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ZonelyWeb.Telemetry)
    end
  end
end

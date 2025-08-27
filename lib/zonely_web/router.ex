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

  # Minimal, layout-free pipeline for standalone host
  pipeline :bare do
    plug(:accepts, ["html"])
    plug(:put_root_layout, false)
    plug(:put_layout, false)
    plug(:put_secure_browser_headers)
  end

  # Standalone minimal site served on saymyname.qingbo.us (host-specific must be before generic "/" scopes)
  scope "/", ZonelyWeb, host: "saymyname.qingbo.us" do
    pipe_through(:bare)

    get("/", NameSiteController, :index)
    # Ensure audio-cache is reachable from the standalone host
    get("/audio-cache/:filename", AudioCacheController, :show)
    get("/api/pronounce", NameSiteController, :pronounce)
    live("/native", NativePronounceLive)
  end

  scope "/", ZonelyWeb do
    pipe_through(:map_layout)

    live("/", MapLive)
  end

  scope "/", ZonelyWeb do
    pipe_through(:browser)

    # Serve runtime-cached audio safely
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
  end

  # Local development access at /name
  scope "/name", ZonelyWeb do
    pipe_through(:bare)

    get("/", NameSiteController, :index)
    # Ensure audio-cache works under /name scope as well
    get("/audio-cache/:filename", AudioCacheController, :show)
    get("/api/pronounce", NameSiteController, :pronounce)
    live("/native", NativePronounceLive)
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZonelyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:zonely, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ZonelyWeb.Telemetry)
    end
  end
end

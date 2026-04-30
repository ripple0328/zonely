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

  pipeline :health do
    plug(:put_root_layout, false)
    plug(:put_layout, false)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ZonelyWeb, host: "zonely.qingbo.us" do
    pipe_through(:health)

    get("/healthz", HealthController, :healthz)
    get("/readyz", HealthController, :readyz)
  end

  scope "/", ZonelyWeb do
    pipe_through(:health)

    get("/healthz", HealthController, :healthz)
    get("/readyz", HealthController, :readyz)
  end

  scope "/", ZonelyWeb do
    pipe_through(:browser)

    live("/", HomeLive, :map)
  end

  scope "/api/v1", ZonelyWeb.Api.V1 do
    pipe_through(:api)

    get("/countries/:country/holidays", PublicHolidaysController, :index)
  end

  if Application.compile_env(:zonely, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ZonelyWeb.Telemetry)
    end
  end
end

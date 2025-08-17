defmodule ZonelyWeb.Router do
  use ZonelyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZonelyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ZonelyWeb do
    pipe_through :browser

    live "/", DirectoryLive
    live "/directory", DirectoryLive
    live "/work-hours", WorkHoursLive
    live "/holidays", HolidaysLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ZonelyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:zonely, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ZonelyWeb.Telemetry
    end
  end
end
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
    live("/teams/new", HomeLive, :new_team)
    get("/imports/saymyname", ImportController, :say_my_name)
    get("/imports/saymyname/card", ImportController, :say_my_name_card)
    get("/imports/saymyname/list", ImportController, :say_my_name_list)
    live("/imports/:id", ImportLive, :show)
    live("/team-invites/new", HomeLive, :new_team_invite)
    post("/team-invites", PacketController, :create)
    get("/team-invites/created", PacketController, :created)
    get("/team-invites/review/:invite_token", PacketController, :review)
    post("/team-invites/review/:invite_token/publish", PacketController, :publish)
    post("/team-invites/review/:invite_token/:member_id", PacketController, :review_member)
    get("/team-invites/invite/:invite_token", PacketController, :invite)
    post("/team-invites/invite/:invite_token/submission", PacketController, :submit)
    get("/packets/new", PacketController, :new)
    post("/packets", PacketController, :create)
    get("/packets/created", PacketController, :created)
    get("/packets/review/:invite_token", PacketController, :review)
    post("/packets/review/:invite_token/publish", PacketController, :publish)
    post("/packets/review/:invite_token/:member_id", PacketController, :review_member)
    get("/packets/invite/:invite_token", PacketController, :invite)
    post("/packets/invite/:invite_token/submission", PacketController, :submit)
  end

  scope "/api/v1", ZonelyWeb.Api.V1 do
    pipe_through(:api)

    get("/countries/:country/holidays", PublicHolidaysController, :index)
    get("/local-time", LocalTimeController, :show)
  end

  if Application.compile_env(:zonely, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ZonelyWeb.Telemetry)
    end
  end
end

defmodule ZonelyWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :zonely

  @session_options [
    store: :cookie,
    key: "_zonely_key",
    signing_salt: "zonely",
    same_site: "Lax"
  ]

  socket("/socket", ZonelyWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(:healthcheck)

  # Tidewave should be placed after code reloading but before static assets
  if Code.ensure_loaded?(Tidewave) do
    plug(Tidewave)
  end

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Static,
    at: "/",
    from: :zonely,
    gzip: false,
    only: ZonelyWeb.static_paths()
  )

  if code_reloading? do
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :zonely)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)

  if Application.compile_env(:zonely, :sql_sandbox) do
    plug(Phoenix.Ecto.SQL.Sandbox)
  end

  plug(ZonelyWeb.Router)

  defp healthcheck(%{request_path: "/healthz"} = conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "ok")
    |> Plug.Conn.halt()
  end

  defp healthcheck(%{request_path: "/readyz"} = conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "ready")
    |> Plug.Conn.halt()
  end

  defp healthcheck(conn, _opts), do: conn
end

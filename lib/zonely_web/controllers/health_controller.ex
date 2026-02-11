defmodule ZonelyWeb.HealthController do
  use ZonelyWeb, :controller
  require Logger

  # Liveness: process is up and responding.
  def healthz(conn, _params) do
    Logger.info("healthz hit")

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  # Readiness: keep lightweight; expand to include deps (DB/cache) if/when present.
  def readyz(conn, _params) do
    Logger.info("readyz hit")

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ready")
  end
end

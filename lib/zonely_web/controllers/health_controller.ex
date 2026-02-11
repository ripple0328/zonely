defmodule ZonelyWeb.HealthController do
  use ZonelyWeb, :controller

  # Liveness: process is up and responding.
  def healthz(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  # Readiness: keep lightweight; expand to include deps (DB/cache) if/when present.
  def readyz(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ready")
  end
end

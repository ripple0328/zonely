defmodule ZonelyWeb.HealthController do
  use ZonelyWeb, :controller

  # Liveness: process is up and responding.
  def healthz(conn, _params) do
    json(conn, %{status: "ok"})
  end

  # Readiness: keep lightweight; expand to include deps (DB/cache) if/when present.
  def readyz(conn, _params) do
    json(conn, %{status: "ready"})
  end
end

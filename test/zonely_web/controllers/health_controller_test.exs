defmodule ZonelyWeb.HealthControllerTest do
  use ZonelyWeb.ConnCase, async: true

  @host "zonely.qingbo.us"

  test "GET /healthz returns ok", %{conn: conn} do
    conn =
      conn
      |> Map.put(:host, @host)
      |> get("/healthz")

    assert response(conn, 200) == "ok"
  end

  test "GET /readyz returns ready", %{conn: conn} do
    conn =
      conn
      |> Map.put(:host, @host)
      |> get("/readyz")

    assert response(conn, 200) == "ready"
  end
end

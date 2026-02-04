defmodule ZonelyWeb.HealthControllerTest do
  use ZonelyWeb.ConnCase, async: true

  @host "saymyname.qingbo.us"

  test "GET /healthz returns ok", %{conn: conn} do
    conn =
      conn
      |> put_req_header("host", @host)
      |> get("/healthz")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end

  test "GET /readyz returns ready", %{conn: conn} do
    conn =
      conn
      |> put_req_header("host", @host)
      |> get("/readyz")

    assert json_response(conn, 200) == %{"status" => "ready"}
  end
end

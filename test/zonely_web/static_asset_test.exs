defmodule ZonelyWeb.StaticAssetTest do
  use ZonelyWeb.ConnCase, async: true

  test "serves digested root favicon assets", %{conn: conn} do
    favicon_path =
      "priv/static/cache_manifest.json"
      |> File.read!()
      |> Jason.decode!()
      |> get_in(["latest", "favicon.svg"])

    assert is_binary(favicon_path)

    conn = get(conn, "/" <> favicon_path)

    assert response(conn, 200) =~ "<svg"
    assert get_resp_header(conn, "content-type") == ["image/svg+xml"]
  end
end

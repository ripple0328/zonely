defmodule ZonelyWeb.StaticAssetTest do
  use ZonelyWeb.ConnCase, async: false

  test "serves digested root favicon assets", %{conn: conn} do
    favicon_path = "favicon-test-digest.svg"
    file_path = Path.join(["priv", "static", favicon_path])

    File.write!(
      file_path,
      ~s(<svg xmlns="http://www.w3.org/2000/svg"><title>Zonely</title></svg>)
    )

    on_exit(fn -> File.rm(file_path) end)

    conn = get(conn, "/" <> favicon_path)
    assert response(conn, 200) =~ "<svg"
    assert get_resp_header(conn, "content-type") == ["image/svg+xml"]
  end
end

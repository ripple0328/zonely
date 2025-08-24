defmodule ZonelyWeb.AudioCacheController do
  use ZonelyWeb, :controller

  alias Zonely.AudioCache

  def show(conn, %{"filename" => filename}) do
    path = AudioCache.path_for(filename)

    if File.exists?(path) do
      content_type = MIME.from_path(path) || "application/octet-stream"

      conn
      |> put_resp_header("content-type", content_type)
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_file(200, path)
    else
      send_resp(conn, 404, "Not found")
    end
  end
end

defmodule ZonelyWeb.AnalyticsController do
  use ZonelyWeb, :controller

  alias Zonely.Analytics

  def play(conn, params) do
    properties =
      params
      |> Map.take(["provider", "cache_source", "original_provider", "name_text", "lang", "platform"])
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Enum.into(%{})

    Analytics.track_async(
      "interaction_play_audio",
      properties,
      user_context: Analytics.user_context_from_headers(conn.req_headers)
    )

    json(conn, %{ok: true})
  end
end

defmodule ZonelyWeb.Api.V1.LocalTimeController do
  use ZonelyWeb, :controller

  alias Zonely.LocalTime

  def show(conn, params) do
    with {:ok, payload} <- LocalTime.to_api(Map.get(params, "timezone"), Map.get(params, "at")) do
      json(conn, payload)
    else
      {:error, %{code: code, message: message}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: Atom.to_string(code), message: message}})
    end
  end
end

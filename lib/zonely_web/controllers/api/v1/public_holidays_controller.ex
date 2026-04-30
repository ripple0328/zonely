defmodule ZonelyWeb.Api.V1.PublicHolidaysController do
  use ZonelyWeb, :controller

  alias Zonely.Calendar.PublicHolidays

  def index(conn, %{"country" => country} = params) do
    with {:ok, year} <- parse_year(Map.get(params, "year")),
         {:ok, payload} <- PublicHolidays.to_api(country, year) do
      json(conn, payload)
    else
      {:error, %{code: code, message: message}} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: Atom.to_string(code), message: message}})
    end
  end

  defp parse_year(year) when is_binary(year) do
    case Integer.parse(year) do
      {year, ""} -> {:ok, year}
      _other -> invalid_year()
    end
  end

  defp parse_year(_year), do: invalid_year()

  defp invalid_year do
    {:error,
     %{
       code: :invalid_year,
       message: "year is required and must be an integer from 1900 through 2100"
     }}
  end
end

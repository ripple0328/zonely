defmodule Zonely.Holidays do
  @moduledoc """
  The Holidays context.
  """

  import Ecto.Query, warn: false
  alias Zonely.Repo
  alias Zonely.Holidays.Holiday

  @doc """
  Returns the list of holidays.
  """
  def list_holidays do
    Repo.all(Holiday)
  end

  @doc """
  Gets holidays for a specific country.
  """
  def get_holidays_by_country(country) do
    Holiday
    |> where([h], h.country == ^country)
    |> order_by([h], h.date)
    |> Repo.all()
  end

  @doc """
  Gets holidays for a specific country and date range.
  """
  def get_holidays_by_country_and_date_range(country, start_date, end_date) do
    Holiday
    |> where([h], h.country == ^country)
    |> where([h], h.date >= ^start_date and h.date <= ^end_date)
    |> order_by([h], h.date)
    |> Repo.all()
  end

  @doc """
  Gets upcoming holidays for a country.
  """
  def get_upcoming_holidays(country, days \\ 30) do
    today = Date.utc_today()
    end_date = Date.add(today, days)
    
    get_holidays_by_country_and_date_range(country, today, end_date)
  end

  @doc """
  Creates a holiday.
  """
  def create_holiday(attrs \\ %{}) do
    %Holiday{}
    |> Holiday.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Fetches holidays from Nager.Date API and stores them.
  """
  def fetch_and_store_holidays(country, year) do
    url = "https://date.nager.at/api/v3/publicholidays/#{year}/#{country}"
    
    case Req.get(url) do
      {:ok, %{status: 200, body: holidays}} ->
        holidays
        |> Enum.map(fn holiday ->
          %{
            country: country,
            date: Date.from_iso8601!(holiday["date"]),
            name: holiday["name"]
          }
        end)
        |> Enum.each(&create_holiday_if_not_exists/1)
        
        {:ok, "Holidays fetched and stored for #{country} #{year}"}
      
      {:ok, %{status: status}} ->
        {:error, "Failed to fetch holidays: HTTP #{status}"}
      
      {:error, reason} ->
        {:error, "Failed to fetch holidays: #{inspect(reason)}"}
    end
  end

  defp create_holiday_if_not_exists(attrs) do
    case Repo.get_by(Holiday, country: attrs.country, date: attrs.date, name: attrs.name) do
      nil -> create_holiday(attrs)
      _holiday -> {:ok, :already_exists}
    end
  end
end
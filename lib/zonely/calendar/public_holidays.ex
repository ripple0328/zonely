defmodule Zonely.Calendar.PublicHolidays do
  @moduledoc """
  DB-backed, UI-independent public holiday primitive.

  This module intentionally reads only the existing `Zonely.Holidays` persisted
  rows. It does not fetch external holiday data or add regional behavior beyond
  explicitly reporting that V1 is country-level only.
  """

  alias Zonely.Holidays

  @version "zonely.holidays.v1"
  @supported_years 1900..2100

  @type validation_error :: %{code: atom(), message: String.t()}

  @doc """
  Lists persisted country-level public holidays for a required year.
  """
  @spec list(term(), term()) :: {:ok, map()} | {:error, validation_error()}
  def list(country, year) do
    with {:ok, country} <- normalize_country(country),
         {:ok, year} <- validate_year(year) do
      start_date = Date.new!(year, 1, 1)
      end_date = Date.new!(year, 12, 31)

      holidays =
        country
        |> Holidays.get_holidays_by_country_and_date_range(start_date, end_date)
        |> Enum.sort_by(&{&1.date, &1.name})
        |> Enum.map(&project_holiday/1)

      {:ok,
       %{
         country: country,
         year: year,
         region: nil,
         region_supported: false,
         data_status: data_status(holidays),
         holidays: holidays
       }}
    end
  end

  @doc """
  Projects the persisted holidays into the V1 JSON-ready API shape.
  """
  @spec to_api(term(), term()) :: {:ok, map()} | {:error, validation_error()}
  def to_api(country, year) do
    with {:ok, result} <- list(country, year) do
      {:ok,
       %{
         version: @version,
         country: result.country,
         year: result.year,
         region: result.region,
         region_supported: result.region_supported,
         data_status: Atom.to_string(result.data_status),
         holidays: Enum.map(result.holidays, &holiday_to_api/1)
       }}
    end
  end

  @doc """
  Returns evidence records for a specific valid country/date pair.
  """
  @spec evidence(term(), term()) :: {:ok, map()} | {:error, validation_error()}
  def evidence(country, %Date{} = date) do
    with {:ok, country} <- normalize_country(country) do
      holidays =
        country
        |> Holidays.get_holidays_by_country_and_date_range(date, date)
        |> Enum.sort_by(&{&1.date, &1.name})
        |> Enum.map(&project_holiday/1)

      {:ok,
       %{
         country: country,
         date: date,
         evidence: Enum.map(holidays, &holiday_to_evidence(&1, country))
       }}
    end
  end

  def evidence(country, _date) do
    with {:ok, _country} <- normalize_country(country) do
      {:error, invalid_date_error()}
    end
  end

  defp normalize_country(country) when is_binary(country) do
    country = String.trim(country)

    if Regex.match?(~r/\A[A-Za-z]{2}\z/, country) do
      {:ok, String.upcase(country)}
    else
      {:error, invalid_country_error()}
    end
  end

  defp normalize_country(_country), do: {:error, invalid_country_error()}

  defp validate_year(year) when is_integer(year) and year in @supported_years, do: {:ok, year}
  defp validate_year(_year), do: {:error, invalid_year_error()}

  defp project_holiday(holiday) do
    %{
      date: holiday.date,
      name: holiday.name,
      observed: true,
      scope: "national",
      impact: "blocks_scheduling",
      source: "public_holiday_calendar",
      evidence_type: "public_holiday"
    }
  end

  defp holiday_to_api(holiday) do
    Map.update!(holiday, :date, &Date.to_iso8601/1)
  end

  defp holiday_to_evidence(holiday, country) do
    %{
      type: holiday.evidence_type,
      impact: holiday.impact,
      source: holiday.source,
      confidence: "high",
      label: holiday.name,
      observed_on: Date.to_iso8601(holiday.date),
      metadata: %{
        country: country,
        region: nil,
        region_supported: false,
        scope: holiday.scope,
        observed: holiday.observed
      }
    }
  end

  defp data_status([]), do: :no_local_data
  defp data_status(_holidays), do: :available

  defp invalid_country_error do
    %{
      code: :invalid_country,
      message: "country must be a two-letter ISO 3166-1 alpha-2 code"
    }
  end

  defp invalid_year_error do
    %{
      code: :invalid_year,
      message: "year is required and must be an integer from 1900 through 2100"
    }
  end

  defp invalid_date_error do
    %{
      code: :invalid_date,
      message: "date must be a Date struct"
    }
  end
end

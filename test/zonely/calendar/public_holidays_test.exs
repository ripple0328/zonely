defmodule Zonely.Calendar.PublicHolidaysTest do
  use Zonely.DataCase, async: true

  alias Zonely.Calendar.PublicHolidays
  alias Zonely.Holidays

  describe "list/2 validation" do
    test "normalizes valid two-letter countries to uppercase" do
      assert {:ok, result} = PublicHolidays.list(" jp ", 2026)

      assert result.country == "JP"
      assert result.year == 2026
      assert result.region == nil
      assert result.region_supported == false
      assert result.data_status == :no_local_data
      assert result.holidays == []
    end

    test "rejects invalid country inputs with controlled errors" do
      for country <- [nil, "", " ", "J", "JPN", "J1", "日本"] do
        assert {:error, %{code: :invalid_country, message: message}} =
                 PublicHolidays.list(country, 2026)

        assert is_binary(message)
      end
    end

    test "requires an integer year in the supported range" do
      for year <- [nil, "", "2026", 1899, 2101, 2026.0] do
        assert {:error, %{code: :invalid_year, message: message}} =
                 PublicHolidays.list("JP", year)

        assert is_binary(message)
      end
    end
  end

  describe "list/2 persisted rows" do
    test "filters by requested year and country, then sorts deterministically" do
      insert_holiday!(%{country: "JP", date: ~D[2026-01-01], name: "New Year's Day"})
      insert_holiday!(%{country: "JP", date: ~D[2025-12-31], name: "Previous Year"})
      insert_holiday!(%{country: "US", date: ~D[2026-01-01], name: "Other Country"})
      insert_holiday!(%{country: "JP", date: ~D[2026-05-04], name: "Greenery Day"})
      insert_holiday!(%{country: "JP", date: ~D[2026-05-04], name: "Observed Greenery Day"})

      assert {:ok, result} = PublicHolidays.list("jp", 2026)

      assert result.data_status == :available

      assert Enum.map(result.holidays, &{&1.date, &1.name}) == [
               {~D[2026-01-01], "New Year's Day"},
               {~D[2026-05-04], "Greenery Day"},
               {~D[2026-05-04], "Observed Greenery Day"}
             ]
    end

    test "returns an explicit no-local-data state for valid empty lookups" do
      assert {:ok, result} = PublicHolidays.list("CA", 2026)

      assert result.country == "CA"
      assert result.year == 2026
      assert result.data_status == :no_local_data
      assert result.holidays == []
    end
  end

  describe "to_api/2" do
    test "projects V1 country-level metadata and evidence-ready holiday rows" do
      insert_holiday!(%{country: "JP", date: ~D[2026-05-04], name: "Greenery Day"})

      assert {:ok, payload} = PublicHolidays.to_api("jp", 2026)

      assert payload == %{
               version: "zonely.holidays.v1",
               country: "JP",
               year: 2026,
               region: nil,
               region_supported: false,
               data_status: "available",
               holidays: [
                 %{
                   date: "2026-05-04",
                   name: "Greenery Day",
                   observed: true,
                   scope: "national",
                   impact: "blocks_scheduling",
                   source: "public_holiday_calendar",
                   evidence_type: "public_holiday"
                 }
               ]
             }

      refute Map.has_key?(hd(payload.holidays), :id)
      refute Map.has_key?(hd(payload.holidays), :inserted_at)
      refute Map.has_key?(hd(payload.holidays), :updated_at)
      refute Map.has_key?(hd(payload.holidays), :__meta__)
    end
  end

  describe "evidence/2" do
    test "returns holiday evidence for matching dates and no evidence for non-holiday dates" do
      insert_holiday!(%{country: "JP", date: ~D[2026-05-04], name: "Greenery Day"})

      assert {:ok, %{evidence: [evidence]}} = PublicHolidays.evidence("jp", ~D[2026-05-04])

      assert evidence == %{
               type: "public_holiday",
               impact: "blocks_scheduling",
               source: "public_holiday_calendar",
               confidence: "high",
               label: "Greenery Day",
               observed_on: "2026-05-04",
               metadata: %{
                 country: "JP",
                 region: nil,
                 region_supported: false,
                 scope: "national",
                 observed: true
               }
             }

      assert {:ok, %{country: "JP", date: ~D[2026-05-05], evidence: []}} =
               PublicHolidays.evidence("JP", ~D[2026-05-05])
    end

    test "validates country and date inputs" do
      assert {:error, %{code: :invalid_country}} = PublicHolidays.evidence("JPN", ~D[2026-05-04])

      for date <- [nil, "2026-05-04", %{year: 2026, month: 5, day: 4}] do
        assert {:error, %{code: :invalid_date}} = PublicHolidays.evidence("JP", date)
      end
    end
  end

  defp insert_holiday!(attrs) do
    attrs =
      Map.merge(
        %{country: "JP", date: ~D[2026-01-01], name: "New Year's Day"},
        attrs
      )

    {:ok, holiday} = Holidays.create_holiday(attrs)
    holiday
  end
end

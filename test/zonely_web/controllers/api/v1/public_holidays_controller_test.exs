defmodule ZonelyWeb.Api.V1.PublicHolidaysControllerTest do
  use ZonelyWeb.ConnCase, async: true

  alias Zonely.Holidays
  alias Zonely.Holidays.Holiday
  alias Zonely.Repo

  describe "GET /api/v1/countries/:country/holidays" do
    test "returns populated versioned holiday JSON with normalized country and stable rows", %{
      conn: conn
    } do
      insert_holiday!(%{country: "JP", date: ~D[2026-05-04], name: "Greenery Day"})
      insert_holiday!(%{country: "JP", date: ~D[2026-01-01], name: "New Year's Day"})
      insert_holiday!(%{country: "JP", date: ~D[2025-12-31], name: "Previous Year"})

      conn = get(conn, "/api/v1/countries/jp/holidays?year=2026")

      assert %{
               "version" => "zonely.holidays.v1",
               "country" => "JP",
               "year" => 2026,
               "region" => nil,
               "region_supported" => false,
               "data_status" => "available",
               "holidays" => [
                 %{
                   "date" => "2026-01-01",
                   "name" => "New Year's Day",
                   "observed" => true,
                   "scope" => "national",
                   "impact" => "blocks_scheduling",
                   "source" => "public_holiday_calendar",
                   "evidence_type" => "public_holiday"
                 },
                 %{
                   "date" => "2026-05-04",
                   "name" => "Greenery Day",
                   "observed" => true,
                   "scope" => "national",
                   "impact" => "blocks_scheduling",
                   "source" => "public_holiday_calendar",
                   "evidence_type" => "public_holiday"
                 }
               ]
             } = json_response(conn, 200)

      refute hd(json_response(conn, 200)["holidays"])["id"]
      refute hd(json_response(conn, 200)["holidays"])["inserted_at"]
      refute hd(json_response(conn, 200)["holidays"])["updated_at"]
      refute hd(json_response(conn, 200)["holidays"])["__meta__"]
    end

    test "returns empty country-level results as explicit no-local-data JSON", %{conn: conn} do
      conn = get(conn, "/api/v1/countries/ca/holidays?year=2026&region=QC")

      assert json_response(conn, 200) == %{
               "version" => "zonely.holidays.v1",
               "country" => "CA",
               "year" => 2026,
               "region" => nil,
               "region_supported" => false,
               "data_status" => "no_local_data",
               "holidays" => []
             }
    end

    test "returns stable invalid country errors as JSON", %{conn: conn} do
      for country <- ["J", "JPN", "J1"] do
        conn = get(conn, "/api/v1/countries/#{country}/holidays?year=2026")

        assert json_response(conn, 400) == %{
                 "error" => %{
                   "code" => "invalid_country",
                   "message" => "country must be a two-letter ISO 3166-1 alpha-2 code"
                 }
               }
      end
    end

    test "returns stable invalid year errors as JSON", %{conn: conn} do
      for path <- [
            "/api/v1/countries/JP/holidays",
            "/api/v1/countries/JP/holidays?year=not-a-year",
            "/api/v1/countries/JP/holidays?year=1899",
            "/api/v1/countries/JP/holidays?year=2101"
          ] do
        conn = get(conn, path)

        assert json_response(conn, 400) == %{
                 "error" => %{
                   "code" => "invalid_year",
                   "message" => "year is required and must be an integer from 1900 through 2100"
                 }
               }
      end
    end

    test "does not create update or delete holidays for populated and empty GET requests", %{
      conn: conn
    } do
      insert_holiday!(%{country: "JP", date: ~D[2026-05-04], name: "Greenery Day"})
      count_before = Repo.aggregate(Holiday, :count)

      conn = get(conn, "/api/v1/countries/JP/holidays?year=2026")
      assert json_response(conn, 200)["data_status"] == "available"

      conn = get(recycle(conn), "/api/v1/countries/CA/holidays?year=2026")
      assert json_response(conn, 200)["data_status"] == "no_local_data"

      assert Repo.aggregate(Holiday, :count) == count_before
    end

    test "is only mounted under the versioned API path", %{conn: conn} do
      conn = get(conn, "/countries/JP/holidays?year=2026")
      assert response(conn, 404) == "Not Found"

      conn = get(recycle(conn), "/api/countries/JP/holidays?year=2026")
      assert response(conn, 404) == "Not Found"
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

defmodule ZonelyWeb.Api.V1.LocalTimeControllerTest do
  use ZonelyWeb.ConnCase, async: true

  describe "GET /api/v1/local-time" do
    test "returns versioned deterministic local-time JSON", %{conn: conn} do
      conn = get(conn, "/api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30T16:00:00Z")

      assert %{
               "version" => "zonely.local_time.v1",
               "timezone" => "Asia/Tokyo",
               "effective_at" => "2026-04-30T16:00:00Z",
               "local_date" => "2026-05-01",
               "local_time" => "01:00:00",
               "utc_offset" => "UTC+09:00",
               "evidence" => %{
                 "type" => "local_time",
                 "impact" => "informational",
                 "source" => "iana_timezone_database",
                 "confidence" => "high",
                 "label" => "Local time in Asia/Tokyo",
                 "observed_on" => "2026-05-01",
                 "metadata" => %{
                   "timezone" => "Asia/Tokyo",
                   "effective_at" => "2026-04-30T16:00:00Z",
                   "local_date" => "2026-05-01",
                   "local_time" => "01:00:00",
                   "utc_offset" => "UTC+09:00"
                 }
               }
             } = response = json_response(conn, 200)

      conn = get(recycle(conn), "/api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30T16:00:00Z")
      assert json_response(conn, 200) == response
    end

    test "rejects missing unknown and fixed-offset timezone values with JSON errors", %{
      conn: conn
    } do
      for path <- [
            "/api/v1/local-time?at=2026-04-30T16:00:00Z",
            "/api/v1/local-time?timezone=Mars/Base&at=2026-04-30T16:00:00Z",
            "/api/v1/local-time?timezone=%2B09%3A00&at=2026-04-30T16:00:00Z"
          ] do
        conn = get(conn, path)

        assert json_response(conn, 400) == %{
                 "error" => %{
                   "code" => "invalid_timezone",
                   "message" => "timezone must be an IANA timezone name"
                 }
               }
      end
    end

    test "rejects missing and malformed timestamps with JSON errors", %{conn: conn} do
      for path <- [
            "/api/v1/local-time?timezone=Asia/Tokyo",
            "/api/v1/local-time?timezone=Asia/Tokyo&at=not-a-time",
            "/api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30"
          ] do
        conn = get(conn, path)

        assert json_response(conn, 400) == %{
                 "error" => %{
                   "code" => "invalid_timestamp",
                   "message" => "at is required and must be an ISO8601 datetime"
                 }
               }
      end
    end

    test "returns local-time facts only without person team schedule or reachability fields", %{
      conn: conn
    } do
      conn = get(conn, "/api/v1/local-time?timezone=Asia/Tokyo&at=2026-04-30T16:00:00Z")
      response = json_response(conn, 200)

      refute Map.has_key?(response, "person")
      refute Map.has_key?(response, "team")
      refute Map.has_key?(response, "schedule")
      refute Map.has_key?(response, "reachability")
      refute Map.has_key?(response, "state")
      refute Map.has_key?(response, "score")
      refute Map.has_key?(response, "reason_codes")
      refute Map.has_key?(response, "next_better_time")
    end
  end
end

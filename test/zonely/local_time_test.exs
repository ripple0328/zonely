defmodule Zonely.LocalTimeTest do
  use ExUnit.Case, async: true

  alias Zonely.Availability.Evidence
  alias Zonely.LocalTime

  describe "evaluate/2" do
    test "converts an explicit UTC instant with IANA rules and Tokyo date rollover" do
      assert {:ok, result} = LocalTime.evaluate("Asia/Tokyo", ~U[2026-04-30 16:00:00Z])

      assert result.timezone == "Asia/Tokyo"
      assert result.effective_at == "2026-04-30T16:00:00Z"
      assert result.local_date == "2026-05-01"
      assert result.local_time == "01:00:00"
      assert result.utc_offset == "UTC+09:00"

      assert result.evidence.type == "local_time"
      assert result.evidence.impact == "informational"
      assert result.evidence.source == "iana_timezone_database"
      assert result.evidence.confidence == "high"
      assert result.evidence.observed_on == "2026-05-01"
      assert result.evidence.metadata.timezone == "Asia/Tokyo"
      assert result.evidence.metadata.effective_at == "2026-04-30T16:00:00Z"
      assert result.evidence.metadata.local_date == "2026-05-01"
      assert result.evidence.metadata.local_time == "01:00:00"
      assert result.evidence.metadata.utc_offset == "UTC+09:00"

      assert {:ok, ^result} = LocalTime.evaluate("Asia/Tokyo", ~U[2026-04-30 16:00:00Z])
    end

    test "rejects unknown timezones and fixed offsets without raising" do
      for timezone <- ["Mars/Base", "+09:00", "UTC+09:00", "", nil] do
        assert {:error, %{code: :invalid_timezone, message: message}} =
                 LocalTime.evaluate(timezone, ~U[2026-04-30 16:00:00Z])

        assert is_binary(message)
      end
    end

    test "requires an explicit effective timestamp and never falls back to the system clock" do
      for effective_at <- [nil, "not-a-time", "2026-04-30"] do
        assert {:error, %{code: :invalid_timestamp, message: message}} =
                 LocalTime.evaluate("Asia/Tokyo", effective_at)

        assert is_binary(message)
      end
    end

    test "normalizes ISO8601 timestamp strings to deterministic UTC second precision" do
      assert {:ok, result} =
               LocalTime.evaluate("Asia/Tokyo", "2026-05-01T01:00:00.999999+09:00")

      assert result.effective_at == "2026-04-30T16:00:00Z"
      assert result.local_date == "2026-05-01"
      assert result.local_time == "01:00:00"
    end

    test "uses DST-aware IANA rules rather than fixed offset shortcuts" do
      assert {:ok, winter} =
               LocalTime.evaluate("America/New_York", ~U[2026-01-15 17:00:00Z])

      assert {:ok, summer} =
               LocalTime.evaluate("America/New_York", ~U[2026-07-15 17:00:00Z])

      assert winter.timezone == "America/New_York"
      assert summer.timezone == "America/New_York"
      assert winter.local_time == "12:00:00"
      assert summer.local_time == "13:00:00"
      assert winter.utc_offset == "UTC-05:00"
      assert summer.utc_offset == "UTC-04:00"
    end

    test "returns only local-time facts and evidence without reachability decisions" do
      assert {:ok, result} = LocalTime.evaluate("Asia/Tokyo", ~U[2026-04-30 16:00:00Z])

      refute Map.has_key?(result, :person)
      refute Map.has_key?(result, :team)
      refute Map.has_key?(result, :schedule)
      refute Map.has_key?(result, :reachability)
      refute Map.has_key?(result, :state)
      refute Map.has_key?(result, :score)
      refute Map.has_key?(result, :reason_codes)
      refute Map.has_key?(result, :next_better_time)
    end

    test "emits evidence compatible with the shared availability evidence normalizer" do
      assert {:ok, result} = LocalTime.evaluate("Asia/Tokyo", ~U[2026-04-30 16:00:00Z])
      evidence = result.evidence
      assert {:ok, ^evidence} = Evidence.normalize(evidence)
    end
  end
end

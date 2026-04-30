defmodule Zonely.Availability.EvidenceTest do
  use ExUnit.Case, async: true

  alias Zonely.Availability.Evidence

  describe "normalize/1 point evidence" do
    test "normalizes atom and string fields with an observed_on date" do
      assert {:ok, evidence} =
               Evidence.normalize(%{
                 type: :public_holiday,
                 impact: :blocks_scheduling,
                 source: :public_holiday_calendar,
                 confidence: :high,
                 label: "Greenery Day",
                 observed_on: ~D[2026-05-04],
                 metadata: %{"country" => "JP", region: nil}
               })

      assert evidence == %{
               type: "public_holiday",
               impact: "blocks_scheduling",
               source: "public_holiday_calendar",
               confidence: "high",
               label: "Greenery Day",
               observed_on: "2026-05-04",
               metadata: %{"country" => "JP", region: nil}
             }
    end

    test "defaults metadata to an empty map" do
      assert {:ok, evidence} =
               Evidence.new(%{
                 "type" => "local_time",
                 "impact" => "informational",
                 "source" => "iana_timezone_database",
                 "confidence" => "high",
                 "label" => "Local time in Asia/Tokyo",
                 "observed_on" => "2026-05-01"
               })

      assert evidence.metadata == %{}
    end
  end

  describe "normalize/1 interval evidence" do
    test "normalizes starts_at and ends_at to UTC ISO8601 second precision" do
      assert {:ok, evidence} =
               Evidence.normalize(%{
                 type: "calendar_busy",
                 impact: "blocks_scheduling",
                 source: :calendar,
                 confidence: "medium",
                 label: "Focus block",
                 starts_at: ~U[2026-04-30 16:00:00Z],
                 ends_at: ~U[2026-04-30 17:30:00Z],
                 metadata: %{calendar_id: "primary"}
               })

      assert evidence == %{
               type: "calendar_busy",
               impact: "blocks_scheduling",
               source: "calendar",
               confidence: "medium",
               label: "Focus block",
               starts_at: "2026-04-30T16:00:00Z",
               ends_at: "2026-04-30T17:30:00Z",
               metadata: %{calendar_id: "primary"}
             }
    end
  end

  describe "normalize/1 validation" do
    test "returns controlled errors for missing required fields" do
      base = %{
        type: "public_holiday",
        impact: "blocks_scheduling",
        source: "public_holiday_calendar",
        confidence: "high",
        label: "Greenery Day",
        observed_on: "2026-05-04"
      }

      for field <- [:type, :impact, :source, :confidence, :label] do
        assert {:error, %{code: :missing_required_field, field: ^field, message: message}} =
                 base
                 |> Map.delete(field)
                 |> Evidence.normalize()

        assert is_binary(message)
      end
    end

    test "returns controlled errors for missing or invalid temporal anchors" do
      base = %{
        type: "public_holiday",
        impact: "blocks_scheduling",
        source: "public_holiday_calendar",
        confidence: "high",
        label: "Greenery Day"
      }

      assert {:error, %{code: :missing_temporal_anchor}} = Evidence.normalize(base)

      assert {:error, %{code: :invalid_temporal_anchor, field: :observed_on}} =
               Evidence.normalize(Map.put(base, :observed_on, "not-a-date"))

      assert {:error, %{code: :invalid_temporal_anchor, field: :ends_at}} =
               Evidence.normalize(Map.put(base, :starts_at, ~U[2026-04-30 16:00:00Z]))

      assert {:error, %{code: :invalid_interval}} =
               Evidence.normalize(
                 base
                 |> Map.put(:starts_at, ~U[2026-04-30 17:00:00Z])
                 |> Map.put(:ends_at, ~U[2026-04-30 16:00:00Z])
               )
    end

    test "returns controlled errors for unknown enum values and invalid metadata" do
      base = %{
        type: "public_holiday",
        impact: "blocks_scheduling",
        source: "public_holiday_calendar",
        confidence: "high",
        label: "Greenery Day",
        observed_on: "2026-05-04"
      }

      assert {:error, %{code: :invalid_type, value: "mystery"}} =
               Evidence.normalize(%{base | type: "mystery"})

      assert {:error, %{code: :invalid_impact, value: "maybe"}} =
               Evidence.normalize(%{base | impact: "maybe"})

      assert {:error, %{code: :invalid_source, value: "unknown_source"}} =
               Evidence.normalize(%{base | source: "unknown_source"})

      assert {:error, %{code: :invalid_confidence, value: "certain"}} =
               Evidence.normalize(%{base | confidence: "certain"})

      assert {:error, %{code: :invalid_metadata}} =
               Evidence.normalize(Map.put(base, :metadata, country: "JP"))
    end
  end

  describe "idempotence" do
    test "normalizing canonical evidence returns the same shape" do
      input = %{
        type: :public_holiday,
        impact: :blocks_scheduling,
        source: :public_holiday_calendar,
        confidence: :high,
        label: "Greenery Day",
        observed_on: ~D[2026-05-04],
        metadata: %{country: "JP"}
      }

      assert {:ok, normalized} = Evidence.normalize(input)
      assert {:ok, ^normalized} = Evidence.normalize(normalized)
    end
  end

  describe "merge/1" do
    test "normalizes, deduplicates by canonical equality, and sorts deterministically" do
      holiday = %{
        type: :public_holiday,
        impact: :blocks_scheduling,
        source: :public_holiday_calendar,
        confidence: :high,
        label: "Greenery Day",
        observed_on: ~D[2026-05-04],
        metadata: %{country: "JP"}
      }

      local_time = %{
        type: "local_time",
        impact: "informational",
        source: "iana_timezone_database",
        confidence: "high",
        label: "Local time in Asia/Tokyo",
        observed_on: "2026-05-01",
        metadata: %{timezone: "Asia/Tokyo", utc_offset: "UTC+09:00"}
      }

      assert {:ok, merged} = Evidence.merge([local_time, holiday, holiday])

      assert Enum.map(merged, & &1.type) == ["local_time", "public_holiday"]
      assert length(merged) == 2

      for evidence <- merged do
        refute Map.has_key?(evidence, :state)
        refute Map.has_key?(evidence, :score)
        refute Map.has_key?(evidence, :reason_codes)
        refute Map.has_key?(evidence, :next_better_time)
      end
    end

    test "returns a controlled error when any record is invalid" do
      assert {:error,
              %{code: :invalid_evidence, index: 0, reason: %{code: :missing_temporal_anchor}}} =
               Evidence.merge([
                 %{
                   type: "local_time",
                   impact: "informational",
                   source: "iana_timezone_database",
                   confidence: "high",
                   label: "Local time"
                 }
               ])
    end
  end
end

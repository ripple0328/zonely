defmodule Zonely.SchedulesTest do
  use ExUnit.Case, async: true

  alias Zonely.Availability.Evidence
  alias Zonely.Schedules

  @weekday_schedule %{
    working_days: [:monday, :tuesday, :wednesday, :thursday, :friday],
    windows: [%{start: ~T[09:00:00], end: ~T[17:00:00]}]
  }

  describe "evaluate/3" do
    test "is deterministic and pure for identical in-memory inputs" do
      assert {:ok, first} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 10:30:00Z], "Etc/UTC")

      assert {:ok, second} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 10:30:00Z], "Etc/UTC")

      assert first == second
      refute Map.has_key?(first, :repo)
      refute Map.has_key?(first, :person)
      refute Map.has_key?(first, :team)
      refute Map.has_key?(first, :meeting_suggestion)
      refute Map.has_key?(first, :ui_copy)
    end

    test "uses provided timezone local date and time including UTC date rollover" do
      assert {:ok, result} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-03 23:30:00Z], "Asia/Tokyo")

      assert result.state == "near_work_boundary"
      assert result.timezone == "Asia/Tokyo"
      assert result.effective_at == "2026-05-03T23:30:00Z"
      assert result.local_date == "2026-05-04"
      assert result.local_time == "08:30:00"
      assert result.utc_offset == "UTC+09:00"
      assert "before_work_window_start" in result.reason_codes
    end

    test "classifies working-day states with start-inclusive and end-exclusive semantics" do
      assert {:ok, at_start} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 09:00:00Z], "Etc/UTC")

      assert at_start.state == "near_work_boundary"
      assert "inside_work_window" in at_start.reason_codes
      assert "near_work_window_start" in at_start.reason_codes

      assert {:ok, inside} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 10:30:00Z], "Etc/UTC")

      assert inside.state == "inside_work_window"
      assert inside.reason_codes == ["inside_work_window"]

      assert {:ok, at_end} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 17:00:00Z], "Etc/UTC")

      assert at_end.state == "near_work_boundary"
      assert "outside_work_window" in at_end.reason_codes
      assert "after_work_window_end" in at_end.reason_codes

      assert {:ok, outside} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 21:00:00Z], "Etc/UTC")

      assert outside.state == "outside_work_window"
      assert outside.reason_codes == ["outside_work_window"]
    end

    test "after the final work window, next transition points to a future work start" do
      assert {:ok, result} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 21:00:00Z], "Etc/UTC")

      assert result.state == "outside_work_window"
      assert result.next_transition.type == "work_window_start"
      assert result.next_transition.at == "2026-05-05T09:00:00Z"
      assert DateTime.compare(~U[2026-05-05 09:00:00Z], ~U[2026-05-04 21:00:00Z]) == :gt
    end

    test "after-end near-boundary next transition does not report the past work end" do
      assert {:ok, result} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 17:10:00Z], "Etc/UTC")

      assert result.state == "near_work_boundary"
      assert "after_work_window_end" in result.reason_codes
      assert result.next_transition.type == "work_window_start"
      assert result.next_transition.at == "2026-05-05T09:00:00Z"
      refute result.next_transition.at == "2026-05-04T17:00:00Z"
      assert DateTime.compare(~U[2026-05-05 09:00:00Z], ~U[2026-05-04 17:10:00Z]) == :gt
    end

    test "classifies configured non-working days without inventing default hours" do
      assert {:ok, result} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-09 10:30:00Z], "Etc/UTC")

      assert result.state == "non_working_day"
      assert result.reason_codes == ["non_working_day"]
      assert result.work_window == nil
      assert result.next_transition != nil

      assert Enum.any?(result.evidence, &(&1.type == "weekend_or_non_working_day"))
    end

    test "returns evidence and reason codes without UI prose" do
      assert {:ok, result} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 10:30:00Z], "Etc/UTC")

      assert is_list(result.reason_codes)
      assert Enum.all?(result.reason_codes, &is_binary/1)
      assert Enum.any?(result.evidence, &(&1.type == "local_time"))
      assert Enum.any?(result.evidence, &(&1.type == "work_window"))
      assert result.next_transition.type == "work_window_end"
      assert result.next_transition.evidence.type == "work_window"

      for evidence <- result.evidence do
        assert {:ok, ^evidence} = Evidence.normalize(evidence)
      end

      refute Map.has_key?(result, :html)
      refute Map.has_key?(result, :css_class)
      refute Map.has_key?(result, :description)
    end

    test "validates invalid inputs explicitly" do
      assert {:error, %{code: :invalid_timezone}} =
               Schedules.evaluate(@weekday_schedule, ~U[2026-05-04 10:30:00Z], "Mars/Base")

      assert {:error, %{code: :invalid_timestamp}} =
               Schedules.evaluate(@weekday_schedule, nil, "Etc/UTC")

      assert {:error, %{code: :invalid_schedule}} =
               Schedules.evaluate(%{}, ~U[2026-05-04 10:30:00Z], "Etc/UTC")

      assert {:error, %{code: :invalid_schedule}} =
               Schedules.evaluate(
                 %{working_days: [:monday], windows: []},
                 ~U[2026-05-04 10:30:00Z],
                 "Etc/UTC"
               )

      assert {:error, %{code: :invalid_schedule}} =
               Schedules.evaluate(
                 %{working_days: [:monday], windows: [%{start: ~T[17:00:00], end: ~T[09:00:00]}]},
                 ~U[2026-05-04 10:30:00Z],
                 "Etc/UTC"
               )
    end
  end
end

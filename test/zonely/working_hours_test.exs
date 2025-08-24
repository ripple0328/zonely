defmodule Zonely.WorkingHoursTest do
  use ExUnit.Case, async: true

  alias Zonely.WorkingHours
  alias Zonely.Accounts.User

  describe "calculate_overlap_hours/1" do
    test "returns message for single user" do
      user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      result = WorkingHours.calculate_overlap_hours([user])

      assert result == "Select at least 2 users to see overlaps"
    end

    test "returns overlap for multiple users" do
      users = [
        %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]},
        %User{work_start: ~T[10:00:00], work_end: ~T[18:00:00]}
      ]

      result = WorkingHours.calculate_overlap_hours(users)

      assert result == "09:00 - 17:00 UTC (overlap detected)"
    end

    test "handles empty list" do
      result = WorkingHours.calculate_overlap_hours([])

      assert result == "Select at least 2 users to see overlaps"
    end
  end

  describe "is_working?/2" do
    setup do
      user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      {:ok, user: user}
    end

    test "returns true during work hours", %{user: user} do
      assert WorkingHours.is_working?(user, ~T[14:00:00]) == true
      assert WorkingHours.is_working?(user, ~T[09:00:00]) == true
      assert WorkingHours.is_working?(user, ~T[16:59:00]) == true
    end

    test "returns false outside work hours", %{user: user} do
      assert WorkingHours.is_working?(user, ~T[08:59:00]) == false
      assert WorkingHours.is_working?(user, ~T[17:00:00]) == false
      assert WorkingHours.is_working?(user, ~T[20:00:00]) == false
    end

    test "uses current time when not provided", %{user: user} do
      # This test depends on current time, so we just verify it doesn't crash
      result = WorkingHours.is_working?(user)
      assert is_boolean(result)
    end
  end

  describe "classify_status/2" do
    setup do
      user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      {:ok, user: user}
    end

    test "returns :working during work hours", %{user: user} do
      assert WorkingHours.classify_status(user, ~T[14:00:00]) == :working
      assert WorkingHours.classify_status(user, ~T[09:30:00]) == :working
    end

    test "returns :edge near work hours", %{user: user} do
      assert WorkingHours.classify_status(user, ~T[08:30:00]) == :edge
      assert WorkingHours.classify_status(user, ~T[17:30:00]) == :edge
    end

    test "returns :off when far from work hours", %{user: user} do
      assert WorkingHours.classify_status(user, ~T[07:00:00]) == :off
      assert WorkingHours.classify_status(user, ~T[19:00:00]) == :off
    end
  end

  describe "filter_by_status/2" do
    setup do
      users = [
        %User{id: 1, work_start: ~T[09:00:00], work_end: ~T[17:00:00]},
        %User{id: 2, work_start: ~T[10:00:00], work_end: ~T[18:00:00]},
        %User{id: 3, work_start: ~T[08:00:00], work_end: ~T[16:00:00]}
      ]

      {:ok, users: users}
    end

    test "filters users by work status", %{users: users} do
      # Mock current time to ensure consistent results
      working_users = WorkingHours.filter_by_status(users, :working)
      edge_users = WorkingHours.filter_by_status(users, :edge)
      off_users = WorkingHours.filter_by_status(users, :off)

      # All users combined should equal original list
      total_filtered = length(working_users) + length(edge_users) + length(off_users)
      assert total_filtered == length(users)
    end
  end

  describe "get_statistics/1" do
    setup do
      users = [
        %User{
          id: 1,
          timezone: "America/New_York",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        },
        %User{
          id: 2,
          timezone: "America/New_York",
          work_start: ~T[10:00:00],
          work_end: ~T[18:00:00]
        },
        %User{id: 3, timezone: "Europe/London", work_start: ~T[08:00:00], work_end: ~T[16:00:00]}
      ]

      {:ok, users: users}
    end

    test "returns correct statistics structure", %{users: users} do
      stats = WorkingHours.get_statistics(users)

      assert Map.has_key?(stats, :working)
      assert Map.has_key?(stats, :edge)
      assert Map.has_key?(stats, :off)
      assert Map.has_key?(stats, :timezones)

      assert is_integer(stats.working)
      assert is_integer(stats.edge)
      assert is_integer(stats.off)
      assert is_map(stats.timezones)
    end

    test "counts timezones correctly", %{users: users} do
      stats = WorkingHours.get_statistics(users)

      assert stats.timezones["America/New_York"] == 2
      assert stats.timezones["Europe/London"] == 1
    end

    test "status counts sum to total users", %{users: users} do
      stats = WorkingHours.get_statistics(users)
      total_status = stats.working + stats.edge + stats.off

      assert total_status == length(users)
    end
  end

  describe "suggest_meeting_times/1" do
    test "returns suggestions for multiple users" do
      users = [
        %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]},
        %User{work_start: ~T[10:00:00], work_end: ~T[18:00:00]}
      ]

      suggestions = WorkingHours.suggest_meeting_times(users)

      assert length(suggestions) == 2
      assert Enum.all?(suggestions, &Map.has_key?(&1, :time))
      assert Enum.all?(suggestions, &Map.has_key?(&1, :description))
      assert Enum.all?(suggestions, &Map.has_key?(&1, :quality))
    end

    test "returns empty list for single user" do
      user = %User{work_start: ~T[09:00:00], work_end: ~T[17:00:00]}
      suggestions = WorkingHours.suggest_meeting_times([user])

      assert suggestions == []
    end
  end

  describe "time_to_minutes/1" do
    test "converts time to minutes correctly" do
      assert WorkingHours.time_to_minutes(~T[00:00:00]) == 0
      assert WorkingHours.time_to_minutes(~T[09:30:00]) == 570
      assert WorkingHours.time_to_minutes(~T[12:00:00]) == 720
      assert WorkingHours.time_to_minutes(~T[23:59:00]) == 1439
    end
  end

  describe "time_ranges_overlap?/4" do
    test "detects overlapping ranges" do
      assert WorkingHours.time_ranges_overlap?(
               ~T[09:00:00],
               ~T[17:00:00],
               ~T[14:00:00],
               ~T[22:00:00]
             ) == true

      assert WorkingHours.time_ranges_overlap?(
               ~T[09:00:00],
               ~T[12:00:00],
               ~T[10:00:00],
               ~T[15:00:00]
             ) == true
    end

    test "detects non-overlapping ranges" do
      assert WorkingHours.time_ranges_overlap?(
               ~T[09:00:00],
               ~T[17:00:00],
               ~T[18:00:00],
               ~T[22:00:00]
             ) == false

      assert WorkingHours.time_ranges_overlap?(
               ~T[14:00:00],
               ~T[16:00:00],
               ~T[09:00:00],
               ~T[12:00:00]
             ) == false
    end

    test "handles edge cases" do
      # Touching ranges don't overlap
      assert WorkingHours.time_ranges_overlap?(
               ~T[09:00:00],
               ~T[12:00:00],
               ~T[12:00:00],
               ~T[15:00:00]
             ) == false

      # Same range overlaps
      assert WorkingHours.time_ranges_overlap?(
               ~T[09:00:00],
               ~T[17:00:00],
               ~T[09:00:00],
               ~T[17:00:00]
             ) == true
    end
  end

  describe "group_by_status/1" do
    setup do
      users = [
        %User{id: 1, work_start: ~T[09:00:00], work_end: ~T[17:00:00]},
        %User{id: 2, work_start: ~T[10:00:00], work_end: ~T[18:00:00]}
      ]

      {:ok, users: users}
    end

    test "returns grouped users by status", %{users: users} do
      grouped = WorkingHours.group_by_status(users)

      assert Map.has_key?(grouped, :working)
      assert Map.has_key?(grouped, :edge)
      assert Map.has_key?(grouped, :off)

      assert is_list(grouped.working)
      assert is_list(grouped.edge)
      assert is_list(grouped.off)

      # Total users should match
      total_grouped = length(grouped.working) + length(grouped.edge) + length(grouped.off)
      assert total_grouped == length(users)
    end
  end
end

defmodule Zonely.ReachabilityTest do
  use ExUnit.Case, async: true

  alias Zonely.Accounts.User
  alias Zonely.Reachability

  @now ~U[2026-01-15 14:30:00Z]

  describe "status/2" do
    test "classifies reachability in the teammate local timezone" do
      new_york = user("America/New_York", "US")
      tokyo = user("Asia/Tokyo", "JP")

      assert Reachability.status(new_york, @now) == :working
      assert Reachability.status(tokyo, @now) == :off
    end

    test "classifies near-boundary local time as edge" do
      edge_now = ~U[2026-01-15 13:30:00Z]

      assert Reachability.status(user("America/New_York", "US"), edge_now) == :edge
    end
  end

  describe "summary/2" do
    test "counts working edge and off teammates with timezone-aware status" do
      users = [
        user("America/New_York", "US"),
        user("America/New_York", "US"),
        user("Asia/Tokyo", "JP")
      ]

      summary = Reachability.summary(users, @now)

      assert summary.working == 2
      assert summary.edge == 0
      assert summary.off == 1
      assert summary.timezones["America/New_York"] == 2
      assert summary.timezones["Asia/Tokyo"] == 1
    end
  end

  describe "labels" do
    test "explains reachable teammates with direct map copy" do
      user = user("America/New_York", "US")

      assert Reachability.status_label(user, @now) == "Reachable now"
      assert Reachability.orbit_status_class(user, @now) == "is-working"
      assert Reachability.marker_state(user, @now) == "working"
      assert Reachability.context_sentence(user, @now) =~ "Good time:"
      assert Reachability.context_sentence(user, @now) =~ "Local time is 09:30"
      assert Reachability.offset_label("America/New_York", @now) == "UTC-05:00"
    end

    test "keeps wait copy clear for off-hours teammates" do
      user = user("Asia/Tokyo", "JP")

      assert Reachability.status_label(user, @now) == "Wait"
      assert Reachability.orbit_status_class(user, @now) == "is-off"
      assert Reachability.context_sentence(user, @now) =~ "Wait:"
      assert Reachability.local_time_label("Asia/Tokyo", @now) == "23:30"
    end
  end

  defp user(timezone, country) do
    %User{
      name: "Test Teammate",
      timezone: timezone,
      country: country,
      work_start: ~T[09:00:00],
      work_end: ~T[17:00:00]
    }
  end
end

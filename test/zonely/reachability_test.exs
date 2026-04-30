defmodule Zonely.ReachabilityTest do
  use ExUnit.Case, async: true

  alias Zonely.Accounts.Person
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

  describe "sort_by_availability/2" do
    test "puts reachable teammates first then orders by next available time" do
      available = user("America/New_York", "US", "Available")
      sooner = user("America/Los_Angeles", "US", "Sooner")
      later = user("Asia/Tokyo", "JP", "Later")

      assert Enum.map(
               Reachability.sort_by_availability([later, sooner, available], @now),
               & &1.name
             ) == ["Available", "Sooner", "Later"]
    end

    test "keeps ask-carefully teammates ahead of wait teammates" do
      wait_but_sooner = user("America/Los_Angeles", "US", "Alice")
      ask_carefully_but_later = user("Australia/Sydney", "AU", "David")
      now = ~U[2026-04-30 07:10:00Z]

      assert Reachability.status(wait_but_sooner, now) == :off
      assert Reachability.status(ask_carefully_but_later, now) == :edge

      assert Enum.map(
               Reachability.sort_by_availability([wait_but_sooner, ask_carefully_but_later], now),
               & &1.name
             ) == ["David", "Alice"]
    end
  end

  describe "group_summary/2" do
    test "summarizes selected teammates deterministically from the effective time" do
      users = [
        user("America/New_York", "US"),
        user("Europe/Lisbon", "PT"),
        user("Asia/Tokyo", "JP")
      ]

      live_summary = Reachability.group_summary(users, @now)
      preview_summary = Reachability.group_summary(users, ~U[2026-01-16 00:30:00Z])

      assert live_summary == Reachability.group_summary(users, @now)
      assert live_summary.selected_count == 3
      assert live_summary.working == 2
      assert live_summary.edge == 0
      assert live_summary.off == 1
      assert live_summary.text == "2 of 3 teammates are reachable now; 1 should wait."

      assert preview_summary.working == 1
      assert preview_summary.text == "1 of 3 teammates is reachable now; 2 should wait."
    end

    test "handles empty selected groups without hidden clock calls" do
      assert Reachability.group_summary([], @now) == %{
               selected_count: 0,
               working: 0,
               edge: 0,
               off: 0,
               text: "No teammates selected."
             }
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

  describe "effective time helpers" do
    test "single-sources preview time ahead of live time" do
      live_now = ~U[2026-01-15 14:30:00Z]
      preview_at = ~U[2026-01-15 22:30:00Z]

      assert Reachability.effective_at(preview_at, live_now) == preview_at
      assert Reachability.effective_at(nil, live_now) == live_now
    end

    test "decision context changes deterministically at preview time" do
      teammate = user("America/New_York", "US")
      live_now = ~U[2026-01-15 14:30:00Z]
      preview_at = ~U[2026-01-15 22:30:00Z]

      assert Reachability.status(teammate, live_now) == :working
      assert Reachability.status(teammate, preview_at) == :edge
      assert Reachability.local_time_label(teammate.timezone, preview_at) == "17:30"
      assert Reachability.daylight_context_label(teammate, preview_at) == "dusk"
      assert Reachability.decision_sentence(teammate, live_now) =~ "good moment"
      assert Reachability.decision_sentence(teammate, preview_at) =~ "near a work-hour boundary"
    end
  end

  describe "next_transition/2" do
    test "returns stable transition data for repeated deterministic calls" do
      teammate = user("America/New_York", "US")
      now = ~U[2026-01-15 14:30:00Z]

      transition = Reachability.next_transition(teammate, now)

      assert transition == Reachability.next_transition(teammate, now)
      assert transition.type == :workday_end
      assert transition.instant == ~U[2026-01-15 22:00:00Z]
      assert transition.local_time_label == "17:00"
      assert transition.text == "Workday ends at 17:00"
    end

    test "points before-hours and edge-before cases to today's local work start" do
      teammate = user("America/New_York", "US")

      assert %{
               type: :workday_start,
               instant: ~U[2026-01-15 14:00:00Z],
               local_time_label: "09:00",
               text: "Workday starts at 09:00"
             } = Reachability.next_transition(teammate, ~U[2026-01-15 12:30:00Z])
    end

    test "points after-hours cases to tomorrow's local work start" do
      teammate = user("America/New_York", "US")

      assert %{
               type: :back_tomorrow,
               instant: ~U[2026-01-16 14:00:00Z],
               local_time_label: "09:00",
               text: "Back tomorrow at 09:00"
             } = Reachability.next_transition(teammate, ~U[2026-01-15 23:30:00Z])

      assert Reachability.decision_sentence(teammate, ~U[2026-01-15 23:30:00Z]) =~
               "back tomorrow at 09:00"
    end

    test "uses teammate timezone for local labels and UTC instants" do
      new_york = user("America/New_York", "US")
      tokyo = user("Asia/Tokyo", "JP")
      now = ~U[2026-01-15 14:30:00Z]

      assert Reachability.local_time_label(new_york.timezone, now) == "09:30"
      assert Reachability.local_time_label(tokyo.timezone, now) == "23:30"

      assert Reachability.next_transition(new_york, now).instant == ~U[2026-01-15 22:00:00Z]
      assert Reachability.next_transition(tokyo, now).instant == ~U[2026-01-16 00:00:00Z]
      assert Reachability.next_transition(tokyo, now).text == "Back tomorrow at 09:00"
    end

    test "handles date rollover across teammate timezone boundaries" do
      los_angeles = user("America/Los_Angeles", "US")
      tokyo = user("Asia/Tokyo", "JP")
      now = ~U[2026-01-01 01:30:00Z]

      assert Reachability.local_date_label(los_angeles, now) == "2025-12-31"
      assert Reachability.local_time_label(los_angeles.timezone, now) == "17:30"
      assert Reachability.status(los_angeles, now) == :edge
      assert Reachability.next_transition(los_angeles, now).instant == ~U[2026-01-01 17:00:00Z]

      assert Reachability.local_date_label(tokyo, now) == "2026-01-01"
      assert Reachability.local_time_label(tokyo.timezone, now) == "10:30"
      assert Reachability.status(tokyo, now) == :working
      assert Reachability.next_transition(tokyo, now).instant == ~U[2026-01-01 08:00:00Z]
    end
  end

  describe "work-hour boundary behavior" do
    test "classifies explicit start and end boundaries consistently" do
      teammate = user("America/New_York", "US")

      cases = [
        {~U[2026-01-15 13:59:00Z], :edge},
        {~U[2026-01-15 14:00:00Z], :working},
        {~U[2026-01-15 22:00:00Z], :edge},
        {~U[2026-01-15 22:01:00Z], :edge},
        {~U[2026-01-15 23:01:00Z], :off}
      ]

      for {now, status} <- cases do
        assert Reachability.status(teammate, now) == status
      end
    end
  end

  defp user(timezone, country, name \\ "Test Teammate") do
    %Person{
      name: name,
      timezone: timezone,
      country: country,
      work_start: ~T[09:00:00],
      work_end: ~T[17:00:00]
    }
  end
end

defmodule Zonely.AnalyticsTest do
  use Zonely.DataCase, async: true

  alias Zonely.Analytics

  describe "track/3" do
    test "creates event successfully" do
      assert {:ok, event} =
               Analytics.track("page_view_landing", %{
                 utm_source: "twitter",
                 entry_point: "social"
               })

      assert event.event_name == "page_view_landing"
      assert event.properties["utm_source"] == "twitter"
      assert event.session_id != nil
    end

    test "validates event name" do
      assert {:error, changeset} = Analytics.track("invalid_event", %{})
      assert "is invalid" in errors_on(changeset).event_name
    end
  end

  describe "total_pronunciations/2" do
    test "counts pronunciation events in date range" do
      start_date = ~U[2026-02-01 00:00:00Z]
      mid_date = ~U[2026-02-05 00:00:00Z]
      end_date = ~U[2026-02-10 00:00:00Z]

      # Create events at different times
      Analytics.track(
        "pronunciation_generated",
        %{name_hash: "abc123", language: "en"},
        timestamp: start_date
      )

      Analytics.track(
        "pronunciation_generated",
        %{name_hash: "def456", language: "en"},
        timestamp: mid_date
      )

      Analytics.track(
        "pronunciation_generated",
        %{name_hash: "ghi789", language: "fr"},
        timestamp: DateTime.add(end_date, 1, :day)
      )

      # Should only count events within range
      count = Analytics.total_pronunciations(start_date, end_date)
      assert count == 2
    end
  end

  describe "cache_hit_rate/2" do
    setup do
      start_date = ~U[2026-02-01 00:00:00Z]
      end_date = ~U[2026-02-02 00:00:00Z]

      # 1 cache hit + 2 generated = 33.33% hit rate
      Analytics.track("pronunciation_cache_hit", %{name_hash: "abc"}, timestamp: start_date)
      Analytics.track("pronunciation_generated", %{name_hash: "def"}, timestamp: start_date)
      Analytics.track("pronunciation_generated", %{name_hash: "ghi"}, timestamp: start_date)

      %{start_date: start_date, end_date: end_date}
    end

    test "calculates correct rate", %{start_date: start_date, end_date: end_date} do
      rate = Analytics.cache_hit_rate(start_date, end_date)
      assert rate == 33.33
    end

    test "returns 0 when no events", %{start_date: _start_date, end_date: _end_date} do
      future_start = ~U[2027-01-01 00:00:00Z]
      future_end = ~U[2027-01-02 00:00:00Z]
      rate = Analytics.cache_hit_rate(future_start, future_end)
      assert rate == 0.0
    end
  end

  describe "top_requested_names/3" do
    test "returns top names ordered by count" do
      start_date = ~U[2026-02-01 00:00:00Z]
      end_date = ~U[2026-02-02 00:00:00Z]

      # Create events with different name hashes
      for _ <- 1..5,
          do:
            Analytics.track("pronunciation_generated", %{name_hash: "popular"},
              timestamp: start_date
            )

      for _ <- 1..3,
          do:
            Analytics.track("pronunciation_generated", %{name_hash: "medium"},
              timestamp: start_date
            )

      for _ <- 1..1,
          do:
            Analytics.track("pronunciation_generated", %{name_hash: "rare"},
              timestamp: start_date
            )

      top_names = Analytics.top_requested_names(start_date, end_date, 3)

      assert [{"popular", 5}, {"medium", 3}, {"rare", 1}] = top_names
    end
  end

  describe "error_rate/2" do
    test "calculates error rate correctly" do
      start_date = ~U[2026-02-01 00:00:00Z]
      end_date = ~U[2026-02-02 00:00:00Z]

      # 2 errors out of 10 total events = 20%
      for _ <- 1..2,
          do:
            Analytics.track("pronunciation_error", %{error_type: "timeout"},
              timestamp: start_date
            )

      for _ <- 1..8,
          do:
            Analytics.track("pronunciation_generated", %{name_hash: "ok"}, timestamp: start_date)

      result = Analytics.error_rate(start_date, end_date)

      assert result.errors == 2
      assert result.total == 10
      assert result.error_rate == 20.0
    end
  end
end

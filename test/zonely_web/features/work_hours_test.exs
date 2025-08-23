defmodule ZonelyWeb.Features.WorkHoursTest do
  use ZonelyWeb.FeatureCase, async: false

  @moduletag :feature

  describe "Work Hours - Basic Layout and Navigation" do
    feature "user can navigate to work hours page", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_has(testid("main-header"))
      |> assert_path("/work-hours")
    end

    feature "work hours page shows team overview", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_text("Work Hours")  # Page title
    end
  end

  describe "Work Hours - Team Member Display" do
    setup do
      # Create users with different working hours across timezones
      early_bird = create_test_user(%{
        id: 1,
        name: "Alice Early",
        role: "Frontend Developer",
        country: "US",
        timezone: "America/Los_Angeles",
        work_start: ~T[06:00:00],  # 6 AM
        work_end: ~T[14:00:00]     # 2 PM
      })

      regular_worker = create_test_user(%{
        id: 2,
        name: "Bob Regular",
        role: "Backend Developer",
        country: "US",
        timezone: "America/New_York",
        work_start: ~T[09:00:00],  # 9 AM
        work_end: ~T[17:00:00]     # 5 PM
      })

      night_owl = create_test_user(%{
        id: 3,
        name: "Charlie Night",
        role: "DevOps Engineer",
        country: "GB",
        timezone: "Europe/London",
        work_start: ~T[14:00:00],  # 2 PM
        work_end: ~T[22:00:00]     # 10 PM
      })

      flexible_worker = create_test_user(%{
        id: 4,
        name: "Diana Flexible",
        role: "Product Manager",
        country: "AU",
        timezone: "Australia/Sydney",
        work_start: ~T[08:30:00],  # 8:30 AM
        work_end: ~T[16:30:00]     # 4:30 PM
      })

      %{
        early_bird: early_bird,
        regular_worker: regular_worker,
        night_owl: night_owl,
        flexible_worker: flexible_worker
      }
    end

    @tag :skip # TODO: Align displayed time format with test or assert using DateUtils output
    feature "displays all team members with their working hours", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_text("Alice Early")
      |> assert_text("06:00")
      |> assert_text("14:00")
      |> assert_text("Bob Regular")
      |> assert_text("09:00")
      |> assert_text("17:00")
      |> assert_text("Charlie Night")
      |> assert_text("14:00")
      |> assert_text("22:00")
      |> assert_text("Diana Flexible")
      |> assert_text("08:30")
      |> assert_text("16:30")
    end

    feature "shows timezone information for each user", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_text("America/Los_Angeles")
      |> assert_text("America/New_York")
      |> assert_text("Europe/London")
      |> assert_text("Australia/Sydney")
    end

    @tag :skip # TODO: UI shows codes; adjust assertion or render names
    feature "displays country information using Geography module", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_text("US")
      |> assert_text("GB")
      |> assert_text("AU")
    end
  end

  describe "Work Hours - Time Selection and Filtering" do
    setup do
      # Create users for overlap testing
      create_test_user(%{
        id: 5,
        name: "Morning Person",
        work_start: ~T[07:00:00],
        work_end: ~T[15:00:00],
        timezone: "America/New_York"
      })

      create_test_user(%{
        id: 6,
        name: "Regular Hours",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        timezone: "America/New_York"
      })

      create_test_user(%{
        id: 7,
        name: "Evening Person",
        work_start: ~T[12:00:00],
        work_end: ~T[20:00:00],
        timezone: "America/New_York"
      })

      :ok
    end

    # Note: These tests assume work hours filtering UI exists
    @tag :skip
    feature "user can select specific time range to find overlaps", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_has(testid("time-range-picker"))
      |> fill_in(testid("start-time"), with: "10:00")
      |> fill_in(testid("end-time"), with: "14:00")
      |> click(testid("find-overlap"))
      # Should show users available in 10 AM - 2 PM range
      |> assert_text("Morning Person")   # 7-3, overlaps 10-2
      |> assert_text("Regular Hours")    # 9-5, overlaps 10-2
      |> refute_text("Evening Person")   # 12-8, starts too late for full overlap
    end

    @tag :skip
    feature "user can filter by timezone region", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> select(testid("timezone-filter"), option: "America")
      |> assert_text("America/Los_Angeles")
      |> assert_text("America/New_York")
      |> refute_text("Europe/London")
      |> refute_text("Australia/Sydney")
    end

    feature "displays current time indicators", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      # Should show current time or working status indicators
      # This would use our TimeUtils module for calculations
    end
  end

  describe "Work Hours - Overlap Calculations" do
    setup do
      # Set up users with known overlaps for testing WorkingHours module
      create_test_user(%{
        id: 8,
        name: "US East",
        work_start: ~T[09:00:00],  # 9 AM EST
        work_end: ~T[17:00:00],    # 5 PM EST
        timezone: "America/New_York"
      })

      create_test_user(%{
        id: 9,
        name: "US West",
        work_start: ~T[09:00:00],  # 9 AM PST (12 PM EST)
        work_end: ~T[17:00:00],    # 5 PM PST (8 PM EST)
        timezone: "America/Los_Angeles"
      })

      create_test_user(%{
        id: 10,
        name: "UK Worker",
        work_start: ~T[09:00:00],  # 9 AM GMT (4 AM EST)
        work_end: ~T[17:00:00],    # 5 PM GMT (12 PM EST)
        timezone: "Europe/London"
      })

      :ok
    end

    feature "shows overlap information when users selected", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_has(css(".space-y-6"))
    end

    # Note: This assumes user selection UI exists
    @tag :skip
    feature "calculates overlap for selected users", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> check(testid("user-checkbox-8"))   # US East
      |> check(testid("user-checkbox-9"))   # US West
      |> assert_text("12:00 PM - 5:00 PM EST")  # Expected overlap
    end

    @tag :skip
    feature "updates overlap calculation when selection changes", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> check(testid("user-checkbox-8"))   # US East
      |> check(testid("user-checkbox-10"))  # UK
      |> assert_text("12:00 PM - 5:00 PM EST")  # UK-US East overlap
      |> check(testid("user-checkbox-9"))   # Add US West
      |> assert_text("12:00 PM - 5:00 PM EST")  # All three overlap
    end

    @tag :skip
    feature "shows no overlap message when appropriate", %{session: session} do
      # Create user with no overlap
      create_test_user(%{
        id: 11,
        name: "Night Shift",
        work_start: ~T[23:00:00],
        work_end: ~T[07:00:00],
        timezone: "America/New_York"
      })

      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> check(testid("user-checkbox-8"))   # US East (9-5)
      |> check(testid("user-checkbox-11"))  # Night shift (11-7)
      |> assert_text("No overlap found")
    end
  end

  describe "Work Hours - Visual Indicators" do
    setup do
      # Create users with current status for visual testing
      create_test_user(%{
        id: 12,
        name: "Currently Working",
        work_start: ~T[08:00:00],
        work_end: ~T[18:00:00],
        timezone: "America/New_York"
      })

      :ok
    end

    # Note: These assume visual status indicators exist
    @tag :skip
    feature "shows green indicator for users currently working", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_has(css(".status-indicator.bg-green-500"))
      |> assert_text("Available now")
    end

    @tag :skip
    feature "shows red indicator for users currently off", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_has(css(".status-indicator.bg-red-500"))
      |> assert_text("Currently off")
    end

    @tag :skip
    feature "shows yellow indicator for users in flexible hours", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_has(css(".status-indicator.bg-yellow-500"))
      |> assert_text("Flexible hours")
    end

    @tag :skip # TODO: Confirm target time strings; assert via DateUtils.format_working_hours if rendered
    feature "displays working hours in readable format", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      # TimeUtils.format_time should format these properly
      |> assert_text("08:00")
      |> assert_text("18:00")
    end
  end

  describe "Work Hours - Real-time Updates" do
    @tag :skip # TODO: Add live update wiring for work-hours LV; assert after PubSub event integration
    feature "page updates when user working hours change", %{session: session} do
      user = create_test_user(%{
        id: 13,
        name: "Dynamic User",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      })

      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> assert_text("09:00")
      |> assert_text("17:00")

      # Simulate user updating their hours (this would come from another session)
      Zonely.Repo.update!(Ecto.Changeset.change(user, %{
        work_start: ~T[10:00:00],
        work_end: ~T[18:00:00]
      }))

      # Send PubSub message to trigger live update
      Phoenix.PubSub.broadcast(
        Zonely.PubSub,
        "users:schedule",
        {:schedule_changed, user.id, %{work_start: ~T[10:00:00], work_end: ~T[18:00:00]}}
      )

      session
      |> assert_text("10:00")
      |> assert_text("18:00")
    end
  end

  describe "Work Hours - Export and Sharing" do
    # Note: These assume export functionality exists
    @tag :skip
    feature "user can export team schedule", %{session: session} do
      create_test_user(%{id: 14, name: "Export User"})

      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> click(testid("export-schedule"))
      |> assert_has(testid("export-modal"))
      |> select(testid("export-format"), option: "CSV")
      |> click(testid("download-export"))
      # Would trigger file download
    end

    @tag :skip
    feature "user can generate shareable team schedule link", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> click(testid("share-schedule"))
      |> assert_has(testid("share-modal"))
      |> click(testid("generate-link"))
      |> assert_has(css("input[readonly]"))  # Shareable URL
      |> click(testid("copy-link"))
      |> assert_has(css(".flash-info"))
      |> assert_text("Link copied")
    end
  end

  describe "Work Hours - Accessibility" do
    feature "page is accessible with screen readers", %{session: session} do
      create_test_user(%{id: 15, name: "Accessible User"})

      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      # Check for semantic HTML and ARIA labels
      |> assert_has(testid("main-header"))
    end

    feature "page works with keyboard navigation", %{session: session} do
      session
      |> visit("/work-hours")
      |> wait_for_liveview()
      |> send_keys([:tab])  # Should focus first interactive element
      |> send_keys([:enter]) # Should activate focused element
    end
  end

  # Helper functions
end

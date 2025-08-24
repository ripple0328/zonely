defmodule ZonelyWeb.CoreComponentsTest do
  use ZonelyWeb.ComponentCase

  import ZonelyWeb.CoreComponents

  alias Zonely.Accounts.User

  describe "user_avatar/1" do
    test "renders avatar with proper attributes" do
      user = %User{name: "John Doe"}

      html =
        render_component_test(&user_avatar/1, %{user: user, size: 48})

      assert html =~ "John Doe&#39;s avatar"
      assert html =~ "rounded-full"
      assert html =~ "seed=john-doe"
      assert html =~ "size=48"
    end

    test "applies custom CSS classes" do
      user = %User{name: "Test User"}

      html = render_component_test(&user_avatar/1, %{user: user, class: "custom-class"})

      assert html =~ "custom-class"
    end
  end

  describe "pronunciation_buttons/1" do
    test "renders English pronunciation button" do
      user = %User{id: 1, name: "John Doe", country: "US"}

      html = render_component_test(&pronunciation_buttons/1, %{user: user})

      assert html =~ "play_english_pronunciation"
      assert html =~ "phx-value-user_id=\"1\""
      assert html =~ "EN"
    end

    test "renders native pronunciation button when name differs" do
      user = %User{
        id: 2,
        name: "Jose Garcia",
        name_native: "José García",
        country: "ES"
      }

      html = render_component_test(&pronunciation_buttons/1, %{user: user})

      assert html =~ "play_native_pronunciation"
      # Spanish abbreviation
      assert html =~ "SP"
    end

    test "does not render native button when names are the same" do
      user = %User{
        id: 3,
        name: "John Doe",
        name_native: "John Doe",
        country: "US"
      }

      html = render_component_test(&pronunciation_buttons/1, %{user: user})

      assert html =~ "play_english_pronunciation"
      refute html =~ "play_native_pronunciation"
    end

    test "applies different sizes correctly" do
      user = %User{id: 1, name: "Test", country: "US"}

      small_html = render_component_test(&pronunciation_buttons/1, %{user: user, size: :small})
      large_html = render_component_test(&pronunciation_buttons/1, %{user: user, size: :large})

      assert small_html =~ "w-3 h-3"
      assert large_html =~ "w-4 h-4"
    end

    test "can hide labels" do
      user = %User{id: 1, name: "Test", country: "US"}

      html = render_component_test(&pronunciation_buttons/1, %{user: user, show_labels: false})

      refute html =~ "EN"
    end
  end

  describe "timezone_display/1" do
    test "renders timezone and country information" do
      user = %User{timezone: "America/New_York", country: "US"}

      html = render_component_test(&timezone_display/1, %{user: user})

      assert html =~ "America/New_York"
      assert html =~ "US"
    end

    test "shows local time when requested" do
      user = %User{timezone: "Europe/London", country: "GB"}

      html = render_component_test(&timezone_display/1, %{user: user, show_local_time: true})

      assert html =~ "Local:"
    end

    test "applies vertical layout" do
      user = %User{timezone: "Asia/Tokyo", country: "JP"}

      html = render_component_test(&timezone_display/1, %{user: user, layout: :vertical})

      assert html =~ "space-y-1"
      refute html =~ "justify-between"
    end
  end

  describe "working_hours/1" do
    test "renders working hours correctly" do
      user = %User{
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      html = render_component_test(&working_hours/1, %{user: user})

      assert html =~ "Working Hours:"
      assert html =~ "09:00 AM"
      assert html =~ "05:00 PM"
    end

    test "shows status indicator when requested" do
      user = %User{
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      html = render_component_test(&working_hours/1, %{user: user, show_status: true})

      assert html =~ "bg-green-400 rounded-full"
      assert html =~ "Available now"
    end

    test "applies compact styling" do
      user = %User{
        work_start: ~T[10:00:00],
        work_end: ~T[18:00:00]
      }

      html = render_component_test(&working_hours/1, %{user: user, compact: true})

      assert html =~ "text-xs"
    end
  end

  describe "profile_card/1" do
    test "renders comprehensive user profile" do
      user = %User{
        id: 1,
        name: "Alice Johnson",
        role: "Software Engineer",
        country: "CA",
        timezone: "America/Toronto",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      html = render_component_test(&profile_card/1, %{user: user})

      assert html =~ "Alice Johnson"
      assert html =~ "Software Engineer"
      assert html =~ "America/Toronto"
      assert html =~ "CA"
      assert html =~ "09:00 AM"
    end

    test "shows action buttons when requested" do
      user = %User{
        id: 2,
        name: "Bob Smith",
        work_start: ~T[08:00:00],
        work_end: ~T[16:00:00]
      }

      html = render_component_test(&profile_card/1, %{user: user, show_actions: true})

      assert html =~ "Message"
      assert html =~ "Meeting"
      assert html =~ "send_message"
      assert html =~ "propose_meeting"
    end

    test "shows native name when different from regular name" do
      user = %User{
        id: 3,
        name: "Maria Garcia",
        name_native: "María García",
        country: "ES",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      html = render_component_test(&profile_card/1, %{user: user})

      assert html =~ "Native Name"
      assert html =~ "María García"
      assert html =~ "Spanish"
    end

    test "applies custom CSS classes" do
      user = %User{
        id: 4,
        name: "Test User",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      }

      html = render_component_test(&profile_card/1, %{user: user, class: "custom-profile"})

      assert html =~ "custom-profile"
    end
  end

  describe "user_card/1" do
    test "renders compact user card for directory" do
      user = %User{
        id: 5,
        name: "Charlie Brown",
        role: "Designer",
        timezone: "America/Los_Angeles",
        country: "US"
      }

      html = render_component_test(&user_card/1, %{user: user})

      assert html =~ "Charlie Brown"
      assert html =~ "Designer"
      assert html =~ "America/Los_Angeles"
      assert html =~ "US"
    end

    test "makes card clickable by default" do
      user = %User{id: 6, name: "David Wilson"}

      html = render_component_test(&user_card/1, %{user: user})

      assert html =~ "cursor-pointer"
      assert html =~ "show_profile"
      assert html =~ "phx-value-user_id=\"6\""
    end

    test "can disable clickable behavior" do
      user = %User{id: 7, name: "Eve Adams"}

      html = render_component_test(&user_card/1, %{user: user, clickable: false})

      refute html =~ "cursor-pointer"
      refute html =~ "show_profile"
    end

    test "shows native name information when available" do
      user = %User{
        id: 8,
        name: "Hiroshi Tanaka",
        name_native: "田中 寛",
        country: "JP",
        timezone: "Asia/Tokyo"
      }

      html = render_component_test(&user_card/1, %{user: user})

      assert html =~ "Japanese"
      assert html =~ "田中 寛"
    end
  end

  describe "flash/1" do
    test "renders info flash message" do
      flash = %{"info" => "Success message"}

      html = render_component_test(&flash/1, %{kind: :info, flash: flash})

      assert html =~ "Success message"
      assert html =~ "bg-emerald-50"
      assert html =~ "text-emerald-800"
    end

    test "renders error flash message" do
      flash = %{"error" => "Error occurred"}

      html = render_component_test(&flash/1, %{kind: :error, flash: flash})

      assert html =~ "Error occurred"
      assert html =~ "bg-rose-50"
      assert html =~ "text-rose-900"
    end

    test "includes custom title when provided" do
      flash = %{"info" => "Test message"}

      html = render_component_test(&flash/1, %{kind: :info, flash: flash, title: "Custom Title"})

      assert html =~ "Custom Title"
    end
  end

  describe "navbar/1" do
    test "renders navigation with logo and links" do
      html = render_component_test(&navbar/1, %{current_page: "map", page_title: "Team Map"})

      assert html =~ "Zonely"
      assert html =~ "Team Map"
      assert html =~ "Map"
      assert html =~ "Directory"
      assert html =~ "Work Hours"
      assert html =~ "Holidays"
    end

    test "marks current page as active" do
      html = render_component_test(&navbar/1, %{current_page: "directory"})

      # Should contain active styling for directory link
      assert html =~ "text-blue-700 bg-blue-50"
    end

    test "includes mobile menu button" do
      html = render_component_test(&navbar/1, %{current_page: "map"})

      assert html =~ "mobile-menu-button"
      assert html =~ "lg:hidden"
    end
  end

  describe "map_legend/1" do
    test "renders map legend with overlays" do
      html = render_component_test(&map_legend/1, %{})

      assert html =~ "Map Overlays"
      assert html =~ "Night Region"
      assert html =~ "Timezone Regions"
      assert html =~ "Pacific Time"
      assert html =~ "Eastern Time"
    end

    test "includes proper positioning and styling" do
      html = render_component_test(&map_legend/1, %{})

      assert html =~ "fixed top-20 right-4"
      assert html =~ "bg-white/90 backdrop-blur-sm"
      assert html =~ "rounded-lg shadow-lg"
    end
  end

  describe "logo/1" do
    test "renders Zonely logo with clock design" do
      html = render_component_test(&logo/1, %{})

      assert html =~ "Zonely"
      # Clock face
      assert html =~ "rounded-full"
      assert html =~ "Hour hand"
      assert html =~ "Minute hand"
    end

    test "applies custom CSS classes" do
      html = render_component_test(&logo/1, %{class: "custom-logo"})

      assert html =~ "custom-logo"
    end
  end

  describe "quick_actions_bar/1" do
    test "renders quick actions for user" do
      user = %User{id: 1, name: "John Doe"}

      html = render_component_test(&quick_actions_bar/1, %{user: user})

      assert html =~ "Quick Actions"
      assert html =~ "for John Doe"
      assert html =~ "phx-click=\"quick_message\""
      assert html =~ "phx-click=\"quick_meeting\""
      assert html =~ "phx-click=\"quick_pin\""
      assert html =~ "phx-value-user_id=\"1\""
    end

    test "applies custom CSS classes" do
      user = %User{id: 1, name: "Test User"}

      html = render_component_test(&quick_actions_bar/1, %{user: user, class: "custom-actions"})

      assert html =~ "custom-actions"
    end

    test "includes action icons and labels" do
      user = %User{id: 1, name: "Test User"}

      html = render_component_test(&quick_actions_bar/1, %{user: user})

      assert html =~ "hero-chat-bubble-left-ellipsis"
      assert html =~ "hero-calendar-days"
      assert html =~ "hero-map-pin"
      assert html =~ "Message"
      assert html =~ "Meeting"
      assert html =~ "Pin TZ"
    end
  end

  describe "time_range_selector/1" do
    test "renders expanded time range selector" do
      html = render_component_test(&time_range_selector/1, %{expanded: true})

      assert html =~ "Working Hours Overlap"
      assert html =~ "Drag to select a time range"
      assert html =~ "time-scrubber"
      assert html =~ "phx-hook=\"TimeScrubber\""
      assert html =~ "opacity-100 scale-100"
    end

    test "renders collapsed time range selector" do
      html = render_component_test(&time_range_selector/1, %{expanded: false})

      assert html =~ "opacity-0 scale-95 h-0 overflow-hidden p-0"
    end

    test "includes hour labels and markers" do
      html = render_component_test(&time_range_selector/1, %{expanded: true})

      assert html =~ "Midnight"
      assert html =~ "Noon"
      assert html =~ "6AM"
      assert html =~ "6PM"
    end

    test "includes status legend" do
      html = render_component_test(&time_range_selector/1, %{expanded: true})

      assert html =~ "Working"
      assert html =~ "Flexible Hours"
      assert html =~ "Off Work"
      assert html =~ "bg-green-500"
      assert html =~ "bg-yellow-500"
      assert html =~ "bg-gray-400"
    end

    test "applies custom CSS classes" do
      html =
        render_component_test(&time_range_selector/1, %{expanded: true, class: "custom-selector"})

      assert html =~ "custom-selector"
    end
  end

  describe "panel_toggle/1" do
    test "renders expanded panel toggle" do
      html =
        render_component_test(&panel_toggle/1, %{
          expanded: true,
          label: "Hide Panel",
          click_event: "toggle_panel"
        })

      assert html =~ "Hide Panel"
      assert html =~ "phx-click=\"toggle_panel\""
      assert html =~ "rotate-180"
    end

    test "renders collapsed panel toggle" do
      html =
        render_component_test(&panel_toggle/1, %{
          expanded: false,
          label: "Show Panel",
          collapsed_label: "Working Hours",
          click_event: "toggle_panel"
        })

      assert html =~ "Working Hours"
      refute html =~ "Show Panel"
      refute html =~ "rotate-180"
    end

    test "uses label when no collapsed_label provided" do
      html =
        render_component_test(&panel_toggle/1, %{
          expanded: false,
          label: "Panel Label",
          click_event: "toggle_panel"
        })

      assert html =~ "Panel Label"
    end

    test "applies custom CSS classes" do
      html =
        render_component_test(&panel_toggle/1, %{
          expanded: true,
          label: "Toggle",
          click_event: "toggle",
          class: "custom-toggle"
        })

      assert html =~ "custom-toggle"
    end

    test "includes chevron icon" do
      html =
        render_component_test(&panel_toggle/1, %{
          expanded: true,
          label: "Toggle",
          click_event: "toggle"
        })

      assert html =~ "hero-chevron-down"
    end
  end
end

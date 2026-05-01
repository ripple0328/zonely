defmodule ZonelyWeb.HomeLiveTest do
  use ZonelyWeb.ConnCase, async: false

  alias Zonely.Accounts

  setup do
    previous_request_fun = Application.get_env(:zonely, :say_my_name_share_request_fun)
    previous_home_live_now = Application.get_env(:zonely, :home_live_now)
    previous_api_key = System.get_env("PRONUNCIATION_API_KEY")

    on_exit(fn ->
      if previous_request_fun do
        Application.put_env(:zonely, :say_my_name_share_request_fun, previous_request_fun)
      else
        Application.delete_env(:zonely, :say_my_name_share_request_fun)
      end

      if previous_home_live_now do
        Application.put_env(:zonely, :home_live_now, previous_home_live_now)
      else
        Application.delete_env(:zonely, :home_live_now)
      end

      if previous_api_key do
        System.put_env("PRONUNCIATION_API_KEY", previous_api_key)
      else
        System.delete_env("PRONUNCIATION_API_KEY")
      end
    end)

    Application.put_env(:zonely, :home_live_now, ~U[2026-01-15 14:30:00Z])

    :ok
  end

  test "home page loads MapLibre assets", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "maplibre-gl@5.7.1/dist/maplibre-gl.css"
    assert html =~ "maplibre-gl@5.7.1/dist/maplibre-gl.js"
    assert html =~ ~s(rel="icon" href="/favicon.ico")
    assert html =~ ~s(type="image/svg+xml" href="/favicon.svg")
  end

  test "renders global map with teammate location payload", %{conn: conn} do
    {:ok, _user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#global-team-map")
    assert has_element?(view, "#map-container[phx-hook='TeamMap'][data-testid='team-map']")
    assert has_element?(view, "#team-orbit-panel")
    assert has_element?(view, "#team-orbit-list [data-testid='team-orbit-row']")
    refute has_element?(view, "#now-context-strip")
    refute has_element?(view, "#team-directory")

    html = render(view)
    assert html =~ "map-time-rail"
    assert html =~ "Team orbit"

    assert has_element?(
             view,
             ".map-nav-brand[aria-label='Zonely'] img.map-nav-logo[src='/favicon.svg']"
           )

    refute has_element?(view, "a.map-nav-brand")
    refute html =~ ~s(href="/directory")
    assert html =~ "&quot;name&quot;:&quot;Alice Remote&quot;"
    assert html =~ "&quot;timezone&quot;:&quot;America/New_York&quot;"
    assert html =~ "&quot;latitude&quot;:40.7128"
    assert html =~ "&quot;longitude&quot;:-74.006"
    assert html =~ "&quot;status&quot;:&quot;"
  end

  test "map payload omits coordinate-less published people instead of inventing markers", %{
    conn: conn
  } do
    {:ok, _coordinate_user} =
      Accounts.create_person(%{
        name: "Mara Published",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, _private_location_user} =
      Accounts.create_person(%{
        name: "Private Location",
        role: "Engineering",
        timezone: "Europe/London",
        country: "GB",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00]
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#team-orbit-list", "Private Location")

    html = render(view)
    assert html =~ "&quot;name&quot;:&quot;Mara Published&quot;"
    assert html =~ "&quot;latitude&quot;:38.7223"

    refute html =~
             "&quot;name&quot;:&quot;Private Location&quot;,&quot;role&quot;:&quot;Engineering&quot;"

    refute html =~ "&quot;latitude&quot;:null"
    refute html =~ "&quot;longitude&quot;:null"
  end

  test "people control toggles the team orbit panel", %{conn: conn} do
    {:ok, _user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#toggle-team-orbit[aria-expanded='true']")
    assert has_element?(view, "#team-orbit-panel:not([hidden])")

    view |> element("#toggle-team-orbit") |> render_click()

    assert has_element?(view, "#toggle-team-orbit[aria-expanded='false']")
    assert has_element?(view, "#team-orbit-panel[hidden]")
    refute has_element?(view, "#now-context-strip")

    view |> element("#toggle-team-orbit") |> render_click()

    assert_push_event(view, "focus_team_orbit", %{})
    assert has_element?(view, "#toggle-team-orbit[aria-expanded='true']")
    assert has_element?(view, "#team-orbit-panel:not([hidden])")
    refute has_element?(view, "#now-context-strip")
  end

  test "team orbit sorts reachable people first then by next reachable time", %{conn: conn} do
    {:ok, available} =
      Accounts.create_person(%{
        name: "Available Person",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, soon} =
      Accounts.create_person(%{
        name: "Soon Person",
        role: "Product Manager",
        timezone: "America/Los_Angeles",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194")
      })

    {:ok, later} =
      Accounts.create_person(%{
        name: "Later Person",
        role: "UX Designer",
        timezone: "Asia/Tokyo",
        country: "JP",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("35.6762"),
        longitude: Decimal.new("139.6503")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "#team-orbit-item-#{available.id} + #team-orbit-item-#{soon.id}"
           )

    assert has_element?(
             view,
             "#team-orbit-item-#{soon.id} + #team-orbit-item-#{later.id}"
           )
  end

  test "preview rail exposes accessible bounded topology and live labels", %{conn: conn} do
    {:ok, _user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#map-time-rail")
    assert has_element?(view, "#map-time-rail-status")

    assert has_element?(
             view,
             "#map-time-rail-control[phx-hook='PreviewRail'][type='range'][min='0'][max='1440'][step='15']"
           )

    assert has_element?(view, "#map-time-rail-ticks")
    refute has_element?(view, "#map-time-rail-reset")

    html = render(view)
    assert html =~ "Team availability"
    assert html =~ "Team availability live at 14:30 UTC"
    assert html =~ "14:30"
    assert html =~ "14:30 tomorrow"
    refute html =~ "06:12"
    refute html =~ "18:47"
  end

  test "preview rail renders computed context segments from teammate windows", %{conn: conn} do
    {:ok, new_york_user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, tokyo_user} =
      Accounts.create_person(%{
        name: "Yuki Tanaka",
        role: "Engineering Manager",
        timezone: "Asia/Tokyo",
        country: "JP",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("35.6762"),
        longitude: Decimal.new("139.6503")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#map-time-rail-context")

    assert has_element?(
             view,
             "#map-time-rail-context [data-kind='work-window'][data-user-id='#{new_york_user.id}']"
           )

    assert has_element?(
             view,
             "#map-time-rail-context [data-kind='work-window'][data-user-id='#{tokyo_user.id}']"
           )

    assert has_element?(
             view,
             "#map-time-rail-context [data-kind='daylight'][data-user-id='#{new_york_user.id}']"
           )

    html = render(view)
    refute html =~ ~s(class="rail-night")
    refute html =~ ~s(class="rail-daylight"></span>)
    refute html =~ ~s(class="rail-overlap"></span>)

    work_segments = Regex.scan(~r/<span[^>]+data-kind="work-window"[^>]*>/, html)

    assert Enum.any?(work_segments, fn [segment] ->
             segment =~ "data-user-id=\"#{new_york_user.id}\"" and
               segment =~ "style=\"left: 0%; width: 31.25%;\""
           end)

    assert Enum.any?(work_segments, fn [segment] ->
             segment =~ "data-user-id=\"#{tokyo_user.id}\"" and
               segment =~ ~r/style="left: (3|4)\d\.\d+%; width: 33\.3333%;"/
           end)

    assert work_segments
           |> Enum.map(fn [segment] -> Regex.run(~r/style="([^"]+)"/, segment) end)
           |> Enum.uniq()
           |> length() > 1

    assert html =~ "Alice Remote work window"
    assert html =~ "Yuki Tanaka work window"
  end

  test "preview rail follows people selection from team rhythm to person to group overlap", %{
    conn: conn
  } do
    {:ok, alice} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, mara} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#map-time-rail[data-rail-context-label='Team availability']")
    assert has_element?(view, "#map-time-rail-context [data-user-id='#{alice.id}']")
    assert has_element?(view, "#map-time-rail-context [data-user-id='#{mara.id}']")

    view |> element("#team-orbit-user-#{alice.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: [alice_id]})
    assert alice_id == alice.id

    assert has_element?(
             view,
             "#map-time-rail[data-rail-context-label='Alice Remote availability']"
           )

    assert has_element?(
             view,
             "#map-time-rail-context [data-kind='work-window'][data-user-id='#{alice.id}']"
           )

    refute has_element?(view, "#map-time-rail-context [data-user-id='#{mara.id}']")

    view |> element("#team-orbit-user-#{mara.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: selected_ids})
    assert selected_ids == [alice.id, mara.id]

    assert has_element?(view, "#map-time-rail[data-rail-context-label='2-person overlap']")

    assert has_element?(
             view,
             "#map-time-rail-context [data-kind='group_full'][data-user-id='selected-group'][data-reachable-count='2'][data-total-count='2']"
           )

    refute has_element?(view, "#map-time-rail-context [data-kind='work-window']")
  end

  test "preview rail stores server preview state, updates strip and orbit, and resets", %{
    conn: conn
  } do
    {:ok, user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "09:30")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "Reachable now")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "480"})

    refute has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#map-time-rail-status", "Team availability preview")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "17:30")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "Ask carefully")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "0"})

    refute has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "09:30")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "Reachable now")
  end

  test "preview bounds and reset use refreshed live_now source after mount", %{conn: conn} do
    now_agent = start_supervised!({Agent, fn -> ~U[2026-01-15 14:30:00Z] end})
    Application.put_env(:zonely, :home_live_now, fn -> Agent.get(now_agent, & &1) end)

    {:ok, user} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "14:30")

    Agent.update(now_agent, fn _old_now -> ~U[2026-01-15 15:45:00Z] end)

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "60"})

    assert has_element?(view, "#map-time-rail-status", "2026-01-15 16:45 UTC")
    assert has_element?(view, "#map-time-rail-control[value='60']")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "16:45")
    assert has_element?(view, "#map-time-rail-ticks [data-offset-minutes='0']", "15:45")

    Agent.update(now_agent, fn _old_now -> ~U[2026-01-15 16:15:00Z] end)

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "0"})

    assert_push_event(view, "team_marker_states", %{
      effective_at: "2026-01-15T16:15:00Z",
      mode: "live"
    })

    refute has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#map-time-rail-status", "Team availability live at 16:15 UTC")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "16:15")
    assert has_element?(view, "#map-time-rail-ticks [data-offset-minutes='0']", "16:15")
  end

  test "preview timestamps are parsed normalized clamped and malformed input is ignored", %{
    conn: conn
  } do
    {:ok, _user} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    render_change(view, "preview_time", %{"preview_at" => "2026-01-15T22:30:00-05:00"})

    refute has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#map-time-rail-status", "2026-01-16 03:30 UTC")
    assert has_element?(view, "#map-time-rail-control[value='780']")

    render_change(view, "preview_time", %{"preview_at" => "not-a-timestamp"})

    assert has_element?(view, "#map-time-rail-status", "2026-01-16 03:30 UTC")

    render_change(view, "preview_time", %{"preview_at" => "2026-01-20T00:00:00Z"})

    assert has_element?(view, "#map-time-rail-status", "2026-01-16 14:30 UTC")
    assert has_element?(view, "#map-time-rail-control[value='1440']")
  end

  test "preview and reset push structured marker payloads while preserving selected teammate", %{
    conn: conn
  } do
    {:ok, new_york_user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, lisbon_user} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")
    lisbon_user_id = lisbon_user.id
    lisbon_user_id_string = to_string(lisbon_user_id)

    view
    |> element("#team-orbit-view-#{lisbon_user.id}")
    |> render_click()

    assert_push_event(view, "focus_user", %{user_id: ^lisbon_user_id_string})

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "480"})

    assert_push_event(view, "team_marker_states", %{
      effective_at: "2026-01-15T22:30:00Z",
      mode: "preview",
      selected_user_id: lisbon_user_id,
      markers: preview_markers
    })

    assert Enum.find(preview_markers, &(&1.id == new_york_user.id)).status == "edge"

    assert %{id: ^lisbon_user_id, status: "off", selected: true} =
             Enum.find(preview_markers, &(&1.id == lisbon_user_id))

    assert has_element?(view, "#profile-panel", "Mara Okafor")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "0"})

    assert_push_event(view, "team_marker_states", %{
      effective_at: "2026-01-15T14:30:00Z",
      mode: "live",
      selected_user_id: lisbon_user_id,
      markers: live_markers
    })

    assert Enum.find(live_markers, &(&1.id == new_york_user.id)).status == "working"

    assert %{id: ^lisbon_user_id, status: "working", selected: true} =
             Enum.find(live_markers, &(&1.id == lisbon_user_id))

    assert has_element?(view, "#profile-panel", "Mara Okafor")
  end

  test "multi-select state is canonical accessible uncapped and reset preserves group", %{
    conn: conn
  } do
    users =
      [
        {"Alice Remote", "Frontend Developer", "America/New_York", "US", "40.7128", "-74.0060"},
        {"Mara Okafor", "Product Lead", "Europe/Lisbon", "PT", "38.7223", "-9.1393"},
        {"Yuki Tanaka", "Engineering Manager", "Asia/Tokyo", "JP", "35.6762", "139.6503"},
        {"Diego Silva", "Designer", "America/Sao_Paulo", "BR", "-23.5505", "-46.6333"}
      ]
      |> Enum.map(fn {name, role, timezone, country, latitude, longitude} ->
        {:ok, user} =
          Accounts.create_person(%{
            name: name,
            role: role,
            timezone: timezone,
            country: country,
            work_start: ~T[09:00:00],
            work_end: ~T[17:00:00],
            latitude: Decimal.new(latitude),
            longitude: Decimal.new(longitude)
          })

        user
      end)

    [alice, mara, yuki, diego] = users
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#team-orbit-user-#{alice.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [alice_id],
      selected_user_id: selected_user_id,
      markers: markers
    })

    assert alice_id == alice.id
    assert selected_user_id == alice.id
    assert Enum.find(markers, &(&1.id == alice.id)).selected == true

    refute has_element?(view, "#profile-panel [data-testid='selected-decision-sheet']")

    view |> element("#team-orbit-user-#{mara.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: selected_ids,
      selected_user_id: nil,
      markers: markers
    })

    assert selected_ids == [alice.id, mara.id]
    assert Enum.filter(markers, & &1.selected) |> Enum.map(& &1.id) == [alice.id, mara.id]
    refute has_element?(view, "#profile-panel [data-testid='selected-decision-sheet']")
    assert has_element?(view, "#selected-group-summary", "2 of 2 teammates are reachable now")
    assert has_element?(view, "#selected-group-panel", "Good time now")
    assert has_element?(view, "#selected-group-panel", "2 selected · Live 14:30 UTC")
    refute has_element?(view, "#selected-group-panel .selected-group-panel-backdrop")
    assert has_element?(view, "#selected-group-row-#{alice.id}", "Alice Remote")
    refute has_element?(view, "#selected-group-row-#{alice.id}", "Reachable now")
    assert has_element?(view, "#selected-group-row-#{alice.id}", "09:00–17:00")
    assert has_element?(view, "#selected-group-row-#{mara.id}", "daylight")
    refute has_element?(view, "#selected-group-panel [id^='selected-group-focus-']")
    refute has_element?(view, "#selected-group-panel [id^='selected-group-remove-']")

    view |> element("#team-orbit-user-#{yuki.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: three_ids})
    assert three_ids == [alice.id, mara.id, yuki.id]

    view |> element("#team-orbit-user-#{diego.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: four_ids,
      markers: four_markers
    })

    assert four_ids == [alice.id, mara.id, yuki.id, diego.id]
    assert Enum.filter(four_markers, & &1.selected) |> Enum.map(& &1.id) == four_ids
    refute has_element?(view, "#selected-group-feedback")
    assert has_element?(view, "#selected-group-summary", "4 selected teammates")
    assert has_element?(view, "#selected-group-row-#{diego.id}", "Diego Silva")

    view |> element("#map-time-rail-form") |> render_change(%{"offset_minutes" => "600"})

    assert_push_event(view, "team_marker_states", %{
      mode: "preview",
      selected_user_ids: preview_selected_ids,
      markers: preview_markers
    })

    assert preview_selected_ids == [alice.id, mara.id, yuki.id, diego.id]

    assert Enum.filter(preview_markers, & &1.selected) |> Enum.map(& &1.id) ==
             preview_selected_ids

    assert has_element?(view, "#selected-group-summary", "Preview")

    assert has_element?(
             view,
             "#selected-group-panel",
             "4 selected · Simulated 00:30 UTC"
           )

    assert has_element?(view, "#selected-group-row-#{yuki.id}", "09:30")

    view |> element("#map-time-rail-form") |> render_change(%{"offset_minutes" => "0"})

    assert_push_event(view, "team_marker_states", %{
      mode: "live",
      selected_user_ids: reset_selected_ids,
      markers: reset_markers
    })

    assert reset_selected_ids == [alice.id, mara.id, yuki.id, diego.id]
    assert Enum.filter(reset_markers, & &1.selected) |> Enum.map(& &1.id) == reset_selected_ids
    assert has_element?(view, "#selected-group-summary", "4 selected teammates")
    assert has_element?(view, "#selected-group-panel", "4 selected · Live 14:30 UTC")
    refute has_element?(view, "#map-time-rail-reset")

    view |> element("#team-orbit-user-#{mara.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [^alice_id, yuki_id, diego_id]
    })

    assert yuki_id == yuki.id
    assert diego_id == diego.id
    assert has_element?(view, "#selected-group-summary", "3 selected teammates")

    view |> element("#team-orbit-user-#{yuki.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [^alice_id, ^diego_id],
      selected_user_id: nil
    })

    assert has_element?(view, "#selected-group-summary", "2 selected teammates")
    assert has_element?(view, "#selected-group-panel")

    view |> element("#team-orbit-user-#{diego.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [^alice_id],
      selected_user_id: ^alice_id,
      markers: single_markers
    })

    assert Enum.find(single_markers, &(&1.id == alice.id)).selected == true
    refute has_element?(view, "#selected-group-summary")
    refute has_element?(view, "#selected-group-panel")

    refute has_element?(view, "#profile-panel [data-testid='selected-decision-sheet']")

    view |> element("#team-orbit-user-#{alice.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: []})
    refute has_element?(view, "#selected-group-summary")
    refute has_element?(view, "#selected-group-panel")
    refute has_element?(view, "#profile-panel [data-testid='selected-decision-sheet']")

    view |> element("#team-orbit-user-#{alice.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: [^alice_id]})

    view |> element("#team-orbit-user-#{mara.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [^alice_id, rebuilt_mara_id]
    })

    assert rebuilt_mara_id == mara.id
    assert has_element?(view, "#selected-group-panel")

    view |> element("#selected-group-clear") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: []})
    refute has_element?(view, "#selected-group-summary")
    refute has_element?(view, "#selected-group-panel")
  end

  test "selected group leaves membership management to people panel", %{conn: conn} do
    {:ok, alice} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, mara} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#team-orbit-user-#{alice.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: [alice_id]})
    assert alice_id == alice.id

    view |> element("#team-orbit-user-#{mara.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: [^alice_id, mara_id]})
    assert mara_id == mara.id
    assert has_element?(view, "#selected-group-panel")

    refute has_element?(view, "#selected-group-focus-#{mara.id}")
    refute has_element?(view, "#selected-group-remove-#{mara.id}")

    view |> element("#team-orbit-user-#{alice.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [^mara_id],
      selected_user_id: ^mara_id
    })

    refute has_element?(view, "#selected-group-panel")
    refute has_element?(view, "#selected-group-summary")
  end

  test "single decision sheet leaves multi-select to the people panel",
       %{conn: conn} do
    {:ok, alice} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, mara} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#team-orbit-view-#{alice.id}") |> render_click()
    assert_push_event(view, "team_marker_states", %{selected_user_ids: [alice_id]})
    assert alice_id == alice.id

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-decision-sheet']",
             "Alice Remote"
           )

    refute has_element?(view, "#profile-compare-actions")
    refute has_element?(view, "#profile-compare-add-#{mara.id}")

    view |> element("#team-orbit-user-#{mara.id}") |> render_click()

    assert_push_event(view, "team_marker_states", %{
      selected_user_ids: [alice_id, mara_id],
      selected_user_id: nil,
      markers: markers
    })

    assert alice_id == alice.id
    assert mara_id == mara.id
    assert Enum.filter(markers, & &1.selected) |> Enum.map(& &1.id) == [alice.id, mara.id]

    refute has_element?(view, "#profile-panel [data-testid='selected-decision-sheet']")
    assert has_element?(view, "#selected-group-panel", "Good time now")
    assert has_element?(view, "#selected-group-row-#{alice.id}", "Alice Remote")
    assert has_element?(view, "#selected-group-row-#{mara.id}", "Mara Okafor")
  end

  test "boundary/off teammate preview journey synchronizes rail map orbit strip sheet and reset",
       %{
         conn: conn
       } do
    {:ok, tokyo_user} =
      Accounts.create_person(%{
        name: "Yuki Tanaka",
        role: "Engineering Manager",
        timezone: "Asia/Tokyo",
        country: "JP",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("35.6762"),
        longitude: Decimal.new("139.6503")
      })

    {:ok, _lisbon_user} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#global-team-map")
    assert has_element?(view, "#team-orbit-user-#{tokyo_user.id} .orbit-context", "23:30")
    assert has_element?(view, "#team-orbit-user-#{tokyo_user.id} .orbit-context", "Wait")
    refute has_element?(view, "#map-time-rail-reset")

    live_html = render(view)
    assert live_html =~ "&quot;id&quot;:&quot;#{tokyo_user.id}&quot;"
    assert live_html =~ "&quot;status&quot;:&quot;off&quot;"
    refute live_html =~ "dashboard"
    refute live_html =~ "metric"
    refute live_html =~ ~s(id="team-directory")

    view
    |> element("#team-orbit-view-#{tokyo_user.id}")
    |> render_click()

    tokyo_user_id_string = to_string(tokyo_user.id)
    assert_push_event(view, "focus_user", %{user_id: ^tokyo_user_id_string})
    assert has_element?(view, "#profile-panel", "Yuki Tanaka")
    assert has_element?(view, "#profile-panel [data-testid='selected-local-time']", "23:30")
    assert has_element?(view, "#profile-panel [data-testid='selected-reachability']", "Wait")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "600"})

    assert_push_event(view, "team_marker_states", %{
      effective_at: "2026-01-16T00:30:00Z",
      mode: "preview",
      selected_user_id: selected_user_id,
      markers: preview_markers
    })

    assert selected_user_id == tokyo_user.id

    assert %{id: tokyo_user_id, status: "working", selected: true} =
             Enum.find(preview_markers, &(&1.id == tokyo_user.id))

    assert tokyo_user_id == tokyo_user.id

    assert has_element?(
             view,
             "#map-time-rail-status",
             "Yuki Tanaka availability preview at 2026-01-16 00:30 UTC"
           )

    assert has_element?(view, "#map-time-rail-control[value='600']")
    assert has_element?(view, "#team-orbit-user-#{tokyo_user.id} .orbit-context", "09:30")
    assert has_element?(view, "#team-orbit-user-#{tokyo_user.id} .orbit-context", "Reachable now")
    assert has_element?(view, "#profile-panel [data-testid='selected-local-time']", "09:30")

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-reachability']",
             "Reachable now"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-decision-copy']",
             "good moment"
           )

    preview_html = render(view)
    refute preview_html =~ ~s(id="map-time-rail-reset")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "0"})

    assert_push_event(view, "team_marker_states", %{
      effective_at: "2026-01-15T14:30:00Z",
      mode: "live",
      selected_user_id: reset_selected_user_id,
      markers: reset_markers
    })

    assert reset_selected_user_id == tokyo_user.id

    assert %{id: ^tokyo_user_id, status: "off", selected: true} =
             Enum.find(reset_markers, &(&1.id == tokyo_user.id))

    refute has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#team-orbit-user-#{tokyo_user.id} .orbit-context", "23:30")
    assert has_element?(view, "#team-orbit-user-#{tokyo_user.id} .orbit-context", "Wait")
    assert has_element?(view, "#profile-panel [data-testid='selected-local-time']", "23:30")
    assert has_element?(view, "#profile-panel [data-testid='selected-reachability']", "Wait")
  end

  test "team orbit opens selected teammate context on the map", %{conn: conn} do
    {:ok, user} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#team-orbit-view-#{user.id}")
    |> render_click()

    assert has_element?(view, "#profile-panel")
    assert has_element?(view, "#profile-panel .profile-panel-position")
    assert has_element?(view, "#profile-panel [data-testid='selected-sheet-handle']")
    assert has_element?(view, "#profile-panel button[aria-label='Close teammate context']")
    assert has_element?(view, "#profile-panel [data-testid='pronunciation-english']")

    html = render(view)
    assert html =~ "Mara Okafor"
    assert html =~ "Europe/Lisbon"
    refute html =~ "Teammate context"
  end

  test "selected teammate decision sheet follows preview effective time and reset", %{conn: conn} do
    {:ok, user} =
      Accounts.create_person(%{
        name: "Mara Okafor",
        role: "Product Lead",
        timezone: "Europe/Lisbon",
        country: "PT",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("38.7223"),
        longitude: Decimal.new("-9.1393")
      })

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#team-orbit-view-#{user.id}")
    |> render_click()

    assert has_element?(view, "#profile-panel [data-testid='selected-decision-sheet']")
    assert has_element?(view, "#profile-panel [data-testid='selected-location']", "Portugal")
    assert has_element?(view, "#profile-panel [data-testid='selected-role']", "Product Lead")
    assert has_element?(view, "#profile-panel [data-testid='selected-local-time']", "14:30")

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-work-window']",
             "09:00 AM - 05:00 PM"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-timezone-offset']",
             "UTC+00:00"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-reachability']",
             "Reachable now"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-decision-copy']",
             "good moment"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-next-transition']",
             "Workday ends at 17:00"
           )

    assert has_element?(view, "#profile-panel [data-testid='selected-daylight']", "daylight")
    assert has_element?(view, "#profile-panel [data-testid='selected-pronunciation-actions']")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "480"})

    assert has_element?(view, "#profile-panel [data-testid='selected-local-time']", "22:30")
    assert has_element?(view, "#profile-panel [data-testid='selected-reachability']", "Wait")

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-decision-copy']",
             "Wait for a better moment"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-next-transition']",
             "Back tomorrow at 09:00"
           )

    assert has_element?(view, "#profile-panel [data-testid='selected-daylight']", "night")

    view
    |> element("#map-time-rail-form")
    |> render_change(%{"offset_minutes" => "0"})

    assert has_element?(view, "#profile-panel [data-testid='selected-local-time']", "14:30")

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-reachability']",
             "Reachable now"
           )

    assert has_element?(
             view,
             "#profile-panel [data-testid='selected-decision-copy']",
             "good moment"
           )
  end

  test "selected teammate profile can create a SayMyName name-card share", %{conn: conn} do
    System.put_env("PRONUNCIATION_API_KEY", "test-share-key")

    {:ok, user} =
      Accounts.create_person(%{
        name: "Qingbo",
        role: "Founder",
        timezone: "America/Los_Angeles",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("37.7749"),
        longitude: Decimal.new("-122.4194")
      })

    Application.put_env(:zonely, :say_my_name_share_request_fun, fn opts ->
      assert opts[:method] == :post
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/name-card-shares"
      assert opts[:headers] == [{"authorization", "Bearer test-share-key"}]
      assert opts[:json]["version"] == "shared_profile_v1"
      assert opts[:json]["person"]["id"] == user.id
      assert opts[:json]["person"]["display_name"] == "Qingbo"
      assert opts[:json]["person"]["name_variants"] == [%{"lang" => "en-US", "text" => "Qingbo"}]

      {:ok,
       %{
         status: 201,
         body: %{
           "share_token" => "card-token",
           "share_url" => "https://saymyname.qingbo.us/card/card-token",
           "preview_image_url" => "https://saymyname.qingbo.us/og/card/card-token?smn_pv=1"
         }
       }}
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#team-orbit-view-#{user.id}")
    |> render_click()

    view
    |> element("#share-name-card-#{user.id}")
    |> render_click()

    assert has_element?(view, "#share-preview-modal")
    assert has_element?(view, "#share-preview-modal", "Name card preview")
    assert has_element?(view, "#share-preview-modal", "Qingbo")

    assert has_element?(
             view,
             ~s|img[src="https://saymyname.qingbo.us/og/card/card-token?smn_pv=1"]|
           )

    assert has_element?(view, "#share-preview-copy")

    html = render(view)
    assert html =~ "https://saymyname.qingbo.us/card/card-token"
    assert html =~ "data-clipboard-text=\"https://saymyname.qingbo.us/card/card-token\""

    view
    |> element("#share-preview-copy")
    |> render_click()

    refute has_element?(view, "#share-preview-modal")
    assert render(view) =~ "Share link copied."
  end

  test "team orbit can create a SayMyName name-list share", %{conn: conn} do
    System.put_env("PRONUNCIATION_API_KEY", "test-share-key")

    {:ok, _user} =
      Accounts.create_person(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    {:ok, _ahmed} =
      Accounts.create_person(%{
        name: "Ahmed Hassan",
        name_native: "أحمد حسن",
        native_language: "ar-EG",
        role: "Security Engineer",
        timezone: "Africa/Cairo",
        country: "EG",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("30.0444"),
        longitude: Decimal.new("31.2357")
      })

    Application.put_env(:zonely, :say_my_name_share_request_fun, fn opts ->
      assert opts[:method] == :post
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/name-list-shares"
      assert opts[:headers] == [{"authorization", "Bearer test-share-key"}]
      assert opts[:json]["version"] == "shared_profile_v1"
      assert opts[:json]["team"] == %{"name" => "Zonely Team"}

      assert [
               %{"person" => %{"display_name" => "Alice Remote"}},
               %{
                 "person" => %{
                   "display_name" => "Ahmed Hassan",
                   "name_variants" => [
                     %{"lang" => "en-US", "text" => "Ahmed Hassan"},
                     %{"lang" => "ar-SA", "text" => "أحمد حسن"}
                   ]
                 }
               }
             ] = opts[:json]["memberships"]

      {:ok,
       %{
         status: 201,
         body: %{
           "share_token" => "list-token",
           "share_url" => "https://saymyname.qingbo.us/list/list-token",
           "preview_image_url" => "https://saymyname.qingbo.us/og/list/list-token?smn_pv=1"
         }
       }}
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#share-team-names")
    |> render_click()

    assert has_element?(view, "#share-preview-modal")
    assert has_element?(view, "#share-preview-modal", "Name list preview")
    assert has_element?(view, "#share-preview-modal", "2 people")

    assert has_element?(
             view,
             ~s|img[src="https://saymyname.qingbo.us/og/list/list-token?smn_pv=1"]|
           )

    assert has_element?(view, "#share-preview-copy")

    html = render(view)
    assert html =~ "https://saymyname.qingbo.us/list/list-token"
    assert html =~ "data-clipboard-text=\"https://saymyname.qingbo.us/list/list-token\""

    view
    |> element("#share-preview-copy")
    |> render_click()

    refute has_element?(view, "#share-preview-modal")
    assert render(view) =~ "Share link copied."
  end

  test "directory route is removed", %{conn: conn} do
    conn = get(conn, "/directory")
    assert response(conn, 404)
  end
end

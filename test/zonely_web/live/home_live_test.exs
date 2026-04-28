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
  end

  test "renders global map with teammate location payload", %{conn: conn} do
    {:ok, _user} =
      Accounts.create_user(%{
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
    refute has_element?(view, "#team-directory")

    html = render(view)
    assert html =~ "now-context-strip"
    assert html =~ "map-time-rail"
    assert html =~ "Team orbit"
    assert html =~ "Zonely"
    refute html =~ ~s(href="/directory")
    assert html =~ "&quot;name&quot;:&quot;Alice Remote&quot;"
    assert html =~ "&quot;timezone&quot;:&quot;America/New_York&quot;"
    assert html =~ "&quot;latitude&quot;:40.7128"
    assert html =~ "&quot;longitude&quot;:-74.006"
    assert html =~ "&quot;status&quot;:&quot;"
  end

  test "preview rail exposes accessible bounded topology and live labels", %{conn: conn} do
    {:ok, _user} =
      Accounts.create_user(%{
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
             "#map-time-rail-control[type='range'][min='0'][max='1440'][step='15']"
           )

    assert has_element?(view, "#map-time-rail-ticks")
    refute has_element?(view, "#map-time-rail-reset")

    html = render(view)
    assert html =~ "Live now"
    assert html =~ "Preview range"
    assert html =~ "14:30"
    assert html =~ "14:30 tomorrow"
    refute html =~ "06:12"
    refute html =~ "18:47"
  end

  test "preview rail stores server preview state, updates strip and orbit, and resets", %{
    conn: conn
  } do
    {:ok, user} =
      Accounts.create_user(%{
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

    assert has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#now-context-strip", "Preview")
    assert has_element?(view, "#map-time-rail-status", "Simulated")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "17:30")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "Ask carefully")

    view
    |> element("#map-time-rail-reset")
    |> render_click()

    refute has_element?(view, "#map-time-rail-reset")
    assert has_element?(view, "#now-context-strip", "Now")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "09:30")
    assert has_element?(view, "#team-orbit-user-#{user.id} .orbit-context", "Reachable now")
  end

  test "preview timestamps are parsed normalized clamped and malformed input is ignored", %{
    conn: conn
  } do
    {:ok, _user} =
      Accounts.create_user(%{
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

    assert has_element?(view, "#map-time-rail-reset")
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
      Accounts.create_user(%{
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
      Accounts.create_user(%{
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
    |> element("#team-orbit-user-#{lisbon_user.id}")
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
    |> element("#map-time-rail-reset")
    |> render_click()

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

  test "team orbit opens selected teammate context on the map", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
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
    |> element("#team-orbit-user-#{user.id}")
    |> render_click()

    assert has_element?(view, "#profile-panel")
    assert has_element?(view, "#profile-panel [data-testid='pronunciation-english']")

    html = render(view)
    assert html =~ "Mara Okafor"
    assert html =~ "Europe/Lisbon"
    assert html =~ "Teammate context"
  end

  test "selected teammate profile can create a SayMyName name-card share", %{conn: conn} do
    System.put_env("PRONUNCIATION_API_KEY", "test-share-key")

    {:ok, user} =
      Accounts.create_user(%{
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
      assert opts[:json]["id"] == user.id
      assert opts[:json]["display_name"] == "Qingbo"
      assert opts[:json]["variants"] == [%{"lang" => "en-US", "text" => "Qingbo"}]

      {:ok,
       %{
         status: 201,
         body: %{
           "share_token" => "card-token",
           "share_url" => "https://saymyname.qingbo.us/card/card-token"
         }
       }}
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#team-orbit-user-#{user.id}")
    |> render_click()

    view
    |> element("#share-name-card-#{user.id}")
    |> render_click()

    assert has_element?(view, "#copy-name-card-share-#{user.id}")

    html = render(view)
    assert html =~ "https://saymyname.qingbo.us/card/card-token"
    assert html =~ "data-clipboard-text=\"https://saymyname.qingbo.us/card/card-token\""
  end

  test "team orbit can create a SayMyName name-list share", %{conn: conn} do
    System.put_env("PRONUNCIATION_API_KEY", "test-share-key")

    {:ok, _user} =
      Accounts.create_user(%{
        name: "Alice Remote",
        role: "Frontend Developer",
        timezone: "America/New_York",
        country: "US",
        work_start: ~T[09:00:00],
        work_end: ~T[17:00:00],
        latitude: Decimal.new("40.7128"),
        longitude: Decimal.new("-74.0060")
      })

    Application.put_env(:zonely, :say_my_name_share_request_fun, fn opts ->
      assert opts[:method] == :post
      assert opts[:url] == "https://saymyname.qingbo.us/api/v1/name-list-shares"
      assert opts[:headers] == [{"authorization", "Bearer test-share-key"}]
      assert opts[:json]["name"] == "Zonely Team"
      assert [%{"display_name" => "Alice Remote"}] = opts[:json]["entries"]

      {:ok,
       %{
         status: 201,
         body: %{
           "share_token" => "list-token",
           "share_url" => "https://saymyname.qingbo.us/list/list-token"
         }
       }}
    end)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#share-team-names")
    |> render_click()

    assert has_element?(view, "#copy-team-name-list-share")

    html = render(view)
    assert html =~ "https://saymyname.qingbo.us/list/list-token"
    assert html =~ "data-clipboard-text=\"https://saymyname.qingbo.us/list/list-token\""
  end

  test "directory route is removed", %{conn: conn} do
    conn = get(conn, "/directory")
    assert response(conn, 404)
  end
end

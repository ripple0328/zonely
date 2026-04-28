defmodule ZonelyWeb.HomeLiveTest do
  use ZonelyWeb.ConnCase, async: false

  alias Zonely.Accounts

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
    refute has_element?(view, "#team-directory")

    html = render(view)
    assert html =~ "Global Team Map"
    assert html =~ "&quot;name&quot;:&quot;Alice Remote&quot;"
    assert html =~ "&quot;timezone&quot;:&quot;America/New_York&quot;"
    assert html =~ "&quot;latitude&quot;:40.7128"
    assert html =~ "&quot;longitude&quot;:-74.006"
    assert html =~ "&quot;status&quot;:&quot;"
  end

  test "directory page owns the teammate card list", %{conn: conn} do
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

    {:ok, view, _html} = live(conn, ~p"/directory")

    assert has_element?(view, "#team-directory")
    assert has_element?(view, "#team-directory [phx-click='show_profile']")
    refute has_element?(view, "#map-container")

    html = render(view)
    assert html =~ "Team Directory"
    assert html =~ "Alice Remote"
  end
end

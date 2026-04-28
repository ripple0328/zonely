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

  test "directory route is removed", %{conn: conn} do
    conn = get(conn, "/directory")
    assert response(conn, 404)
  end
end

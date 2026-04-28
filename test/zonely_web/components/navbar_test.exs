defmodule ZonelyWeb.NavbarComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import ZonelyWeb.CoreComponents

  test "renders navbar with default values" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.navbar />
      """)

    assert html =~ "Zonely Map"
    assert html =~ "Map"
    assert html =~ "Work Hours"
    assert html =~ "Holidays"
  end

  test "renders navbar with custom page title" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.navbar page_title="Custom Title" />
      """)

    assert html =~ "Custom Title"
  end

  test "highlights current page correctly" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.navbar current_page="map" />
      """)

    assert html =~ "text-blue-700 bg-blue-50"
    assert html =~ "Map"
  end

  test "renders mobile menu structure" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.navbar />
      """)

    assert html =~ "mobile-menu"
    assert html =~ "mobile-menu-button"
  end
end

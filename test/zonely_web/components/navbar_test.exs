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

    assert html =~ "Global Team Map"
    assert html =~ "Map"
    assert html =~ "Directory"
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
      <.navbar current_page="directory" />
      """)

    # Directory should be highlighted (has blue colors)
    assert html =~ "text-blue-700 bg-blue-50"
    assert html =~ "Directory"
    # Map should not be highlighted (has gray colors)
    assert html =~ "text-gray-700 hover:bg-gray-100"
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

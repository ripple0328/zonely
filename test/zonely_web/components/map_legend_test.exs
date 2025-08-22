defmodule ZonelyWeb.MapLegendComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  import ZonelyWeb.CoreComponents

  test "renders legend title and sections" do
    assigns = %{}
    html = rendered_to_string(~H"""
    <.map_legend />
    """)

    assert html =~ "Map Overlays"
    assert html =~ "Timezone Regions"
    assert html =~ "Night Region"
  end
end


defmodule ZonelyWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered around the page that contains
  common elements, like the HTML head, navigation bar, footer, etc.
  The "app" layout is rendered inside the "root" layout and contains all
  the content for a specific page.
  """
  use ZonelyWeb, :html

  embed_templates "layouts/*"
end
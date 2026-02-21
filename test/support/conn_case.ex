defmodule ZonelyWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ZonelyWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      import ZonelyWeb.ConnCase

      use Phoenix.VerifiedRoutes,
        endpoint: ZonelyWeb.Endpoint,
        router: ZonelyWeb.Router,
        statics: ZonelyWeb.static_paths()
    end
  end

  setup tags do
    Zonely.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

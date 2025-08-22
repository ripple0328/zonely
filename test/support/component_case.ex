defmodule ZonelyWeb.ComponentCase do
  @moduledoc """
  This module defines the test case to be used by tests for Phoenix components.
  
  Such tests rely on `Phoenix.LiveViewTest` and also import other functionality 
  to make it easier to build common data structures and query the DOM.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with components
      import Phoenix.Component
      import Phoenix.LiveViewTest
      import ZonelyWeb.CoreComponents

      # The default endpoint for testing
      @endpoint ZonelyWeb.Endpoint
      
      # Helper function to render a component
      defp render_component(component, assigns) do
        component
        |> Phoenix.LiveViewTest.render_component(assigns)
      end
    end
  end

  setup _tags do
    # Component tests typically don't need database access
    # If a specific test needs the database, it can import Zonely.DataCase
    :ok
  end
end
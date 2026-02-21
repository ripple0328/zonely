defmodule ZonelyWeb.ExploreLive do
  use ZonelyWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: "/admin/analytics")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    """
  end
end

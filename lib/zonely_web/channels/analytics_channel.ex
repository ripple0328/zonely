defmodule ZonelyWeb.AnalyticsChannel do
  use Phoenix.Channel

  @impl true
  def join("analytics:events", _payload, socket) do
    # Subscribe to analytics events from PubSub
    Zonely.Analytics.subscribe()
    {:ok, socket}
  end

  @impl true
  def handle_info({:analytics_event, event}, socket) do
    push(socket, "analytics_event", %{
      type: event.event_name,
      timestamp: DateTime.to_unix(event.timestamp)
    })

    {:noreply, socket}
  end
end

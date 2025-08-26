defmodule ZonelyWeb.DemoLive do
  use ZonelyWeb, :live_view

  @moduledoc """
  Autoplay demo that highlights key features through timed steps.
  Server-driven using LiveView timers; no client JS required.
  """

  defp steps do
    [
      %{
        id: "nav-dashboard",
        title: "Team Map",
        desc: "Visualize your distributed team",
        duration_ms: 1600
      },
      %{
        id: "btn-directory",
        title: "Directory",
        desc: "Find teammates and hear names",
        duration_ms: 1600
      },
      %{
        id: "panel-hours",
        title: "Work Hours",
        desc: "Discover overlap time windows",
        duration_ms: 1600
      }
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:step_index, 0)
      |> assign(:highlight_id, nil)
      |> assign(:playing?, true)
      |> assign(:steps, steps())

    {:ok, schedule_and_apply_step(socket)}
  end

  @impl true
  def handle_event("pause", _params, socket) do
    {:noreply, assign(socket, :playing?, false)}
  end

  @impl true
  def handle_event("resume", _params, socket) do
    socket = assign(socket, :playing?, true)
    {:noreply, schedule_and_apply_step(socket)}
  end

  @impl true
  def handle_event("replay", _params, socket) do
    socket = socket |> assign(step_index: 0, playing?: true)
    {:noreply, schedule_and_apply_step(socket)}
  end

  @impl true
  def handle_event("skip", _params, socket) do
    {:noreply, next_step(socket)}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, next_step(socket)}
  end

  defp next_step(socket) do
    step_index = socket.assigns.step_index + 1

    case Enum.at(socket.assigns.steps, step_index) do
      nil ->
        assign(socket, :playing?, false)

      step ->
        socket
        |> assign(:step_index, step_index)
        |> assign(:highlight_id, step.id)
        |> schedule_tick(step.duration_ms)
    end
  end

  defp schedule_and_apply_step(socket) do
    step = Enum.at(socket.assigns.steps, socket.assigns.step_index)

    socket
    |> assign(:highlight_id, step.id)
    |> schedule_tick(step.duration_ms)
  end

  defp schedule_tick(socket, ms) do
    if socket.assigns.playing? do
      Process.send_after(self(), :tick, ms)
      socket
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed top-4 right-4 z-50 w-80 rounded-lg bg-white/90 shadow p-4 space-y-2">
      <div class="text-sm font-semibold">
        <%= Enum.at(@steps, @step_index).title %>
      </div>
      <div class="text-sm text-zinc-600">
        <%= Enum.at(@steps, @step_index).desc %>
      </div>
      <div class="flex gap-2 pt-1">
        <button phx-click={@playing? && "pause" || "resume"} class="px-2 py-1 rounded bg-zinc-800 text-white text-xs">
          <%= @playing? && "Pause" || "Resume" %>
        </button>
        <button phx-click="skip" class="px-2 py-1 rounded bg-zinc-200 text-xs">Skip</button>
        <button phx-click="replay" class="px-2 py-1 rounded bg-zinc-200 text-xs">Replay</button>
      </div>
    </div>

    <div class="p-6 space-y-6">
      <!-- These are demo placeholders. Ensure real pages include matching IDs to highlight. -->
      <nav id="nav-dashboard" class={["p-3 rounded border", @highlight_id == "nav-dashboard" && "ring-4 ring-indigo-500"]}>
        Team Map
      </nav>

      <button id="btn-directory" class={["px-3 py-2 rounded bg-indigo-600 text-white", @highlight_id == "btn-directory" && "ring-4 ring-indigo-500"]}>
        Directory
      </button>

      <div id="panel-hours" class={["mt-4 rounded border p-3", @highlight_id == "panel-hours" && "ring-4 ring-indigo-500"]}>
        Work Hours
      </div>
    </div>
    """
  end
end

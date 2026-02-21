defmodule ZonelyWeb.MeLive do
  use ZonelyWeb, :live_view

  alias Zonely.NameCards

  @impl true
  def mount(_params, _session, socket) do
    card = NameCards.get_name_card()

    {:ok,
     socket
     |> assign(:page_title, "Me")
     |> assign(:card, card)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- My Name Card Section --%>
      <section aria-labelledby="card-heading">
        <h2 id="card-heading" class="text-sm font-semibold uppercase tracking-wider text-[var(--muted)] mb-3">
          My Name Card
        </h2>
        <%= if @card do %>
          <div class="rounded-xl border border-[var(--ring)] bg-[var(--card)] p-5 shadow-sm">
            <.name_card_preview card={@card}>
              <:actions>
                <.link
                  navigate={~p"/name/me/card"}
                  class="inline-flex items-center gap-1.5 rounded-lg bg-[var(--bg)] px-4 py-2 text-sm font-medium text-[var(--fg)] transition-colors hover:bg-[var(--bg)] focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  <.icon name="hero-pencil-square" class="h-4 w-4" /> Edit
                </.link>
                <.link
                  navigate={~p"/name/me/card"}
                  class="inline-flex items-center gap-1.5 rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                >
                  <.icon name="hero-share" class="h-4 w-4" /> Share
                </.link>
              </:actions>
            </.name_card_preview>
          </div>
        <% else %>
          <div class="rounded-xl border-2 border-dashed border-[var(--ring)] bg-[var(--card)] p-6 text-center">
            <div class="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-[var(--bg)]">
              <.icon name="hero-identification" class="h-6 w-6 text-[var(--muted)]" />
            </div>
            <p class="text-sm font-medium text-[var(--fg)]">You haven't set up your card yet.</p>
            <p class="mt-1 text-xs text-[var(--muted)]">Let others learn how to say your name</p>
            <.link
              navigate={~p"/name/me/card"}
              class="mt-4 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            >
              Set Up Now →
            </.link>
          </div>
        <% end %>
      </section>

      <%!-- App Section --%>
      <section aria-labelledby="app-heading">
        <h2 id="app-heading" class="text-sm font-semibold uppercase tracking-wider text-[var(--muted)] mb-3">
          App
        </h2>
        <div class="rounded-xl border border-[var(--ring)] bg-[var(--card)] shadow-sm overflow-hidden divide-y divide-[var(--ring)]">
          <a
            href={~p"/name/about"}
            class="flex items-center justify-between px-4 py-3.5 text-sm text-[var(--fg)] hover:bg-[var(--bg)] transition-colors focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          >
            <span>How It Works</span>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-[var(--muted)]" />
          </a>
          <a
            href={~p"/name/privacy"}
            class="flex items-center justify-between px-4 py-3.5 text-sm text-[var(--fg)] hover:bg-[var(--bg)] transition-colors focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          >
            <span>Privacy</span>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-[var(--muted)]" />
          </a>
          <a
            href="mailto:feedback@saymyname.qingbo.us"
            class="flex items-center justify-between px-4 py-3.5 text-sm text-[var(--fg)] hover:bg-[var(--bg)] transition-colors focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          >
            <span>Send Feedback</span>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-[var(--muted)]" />
          </a>
        </div>
      </section>

      <%!-- Version footer --%>
      <p class="text-center text-xs text-[var(--muted)] pt-4">
        v2.0 · Made with ♥
      </p>
    </div>
    """
  end
end

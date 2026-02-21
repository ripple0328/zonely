defmodule ZonelyWeb.MeLive do
  use ZonelyWeb, :live_view

  alias Zonely.NameCards
  alias Zonely.NameCards.NameCard

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
        <h2 id="card-heading" class="text-sm font-semibold uppercase tracking-wider text-gray-500 mb-3">
          My Name Card
        </h2>
        <%= if @card do %>
          <div class="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
            <div class="flex items-start gap-4">
              <%!-- Initials avatar --%>
              <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-blue-100 text-lg font-bold text-blue-700">
                {initials(@card.display_name)}
              </div>
              <div class="flex-1 min-w-0">
                <h3 class="text-lg font-bold text-gray-900 truncate">{@card.display_name}</h3>
                <%= if @card.pronouns && @card.pronouns != "" do %>
                  <p class="text-sm text-gray-500">{@card.pronouns}</p>
                <% end %>
                <%!-- Language flags --%>
                <%= if @card.language_variants && @card.language_variants != [] do %>
                  <div class="mt-2 flex flex-wrap gap-1">
                    <%= for variant <- @card.language_variants do %>
                      <span class="text-lg" title={variant["language"]}>
                        {NameCard.language_flag(variant["language"])}
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="mt-4 flex gap-2">
              <.link
                navigate={~p"/name/me/card"}
                class="inline-flex items-center gap-1.5 rounded-lg bg-gray-100 px-4 py-2 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                <.icon name="hero-pencil-square" class="h-4 w-4" />
                Edit
              </.link>
              <.link
                navigate={~p"/name/me/card"}
                class="inline-flex items-center gap-1.5 rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
              >
                <.icon name="hero-share" class="h-4 w-4" />
                Share
              </.link>
            </div>
          </div>
        <% else %>
          <div class="rounded-xl border-2 border-dashed border-gray-300 bg-white p-6 text-center">
            <div class="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-gray-100">
              <.icon name="hero-identification" class="h-6 w-6 text-gray-400" />
            </div>
            <p class="text-sm font-medium text-gray-900">You haven't set up your card yet.</p>
            <p class="mt-1 text-xs text-gray-500">Let others learn how to say your name</p>
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
        <h2 id="app-heading" class="text-sm font-semibold uppercase tracking-wider text-gray-500 mb-3">
          App
        </h2>
        <div class="rounded-xl border border-gray-200 bg-white shadow-sm overflow-hidden divide-y divide-gray-100">
          <a
            href={~p"/name/about"}
            class="flex items-center justify-between px-4 py-3.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          >
            <span>How It Works</span>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-gray-400" />
          </a>
          <a
            href={~p"/name/privacy"}
            class="flex items-center justify-between px-4 py-3.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          >
            <span>Privacy</span>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-gray-400" />
          </a>
          <a
            href="mailto:feedback@saymyname.qingbo.us"
            class="flex items-center justify-between px-4 py-3.5 text-sm text-gray-700 hover:bg-gray-50 transition-colors focus:outline-none focus:ring-2 focus:ring-inset focus:ring-blue-500"
          >
            <span>Send Feedback</span>
            <.icon name="hero-chevron-right" class="h-4 w-4 text-gray-400" />
          </a>
        </div>
      </section>

      <%!-- Version footer --%>
      <p class="text-center text-xs text-gray-400 pt-4">
        v2.0 · Made with ♥
      </p>
    </div>
    """
  end

  defp initials(nil), do: "?"

  defp initials(name) when is_binary(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
end

defmodule ZonelyWeb.ImportNameCardLive do
  use ZonelyWeb, :live_view

  alias Zonely.NameCards
  alias Zonely.Collections

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case NameCards.get_name_card_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:card, nil)
         |> assign(:not_found, true)
         |> assign(:collections, [])
         |> assign(:selected_collection, nil)
         |> assign(:new_collection_name, "")
         |> assign(:imported, false)}

      card ->
        collections = Collections.list_collections()

        {:ok,
         socket
         |> assign(:card, card)
         |> assign(:not_found, false)
         |> assign(:collections, collections)
         |> assign(:selected_collection, "new")
         |> assign(:new_collection_name, "")
         |> assign(:imported, false)}
    end
  end

  @impl true
  def handle_event("select_collection", %{"collection" => id}, socket) do
    {:noreply, assign(socket, selected_collection: id)}
  end

  def handle_event("import_card", %{"new_collection_name" => name}, socket) do
    card = socket.assigns.card

    # Build an entry from the name card
    entry = %{
      "name" => card.display_name,
      "pronouns" => card.pronouns,
      "role" => card.role,
      "language_variants" => card.language_variants,
      "imported_from" => card.share_token,
      "imported_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    result =
      case socket.assigns.selected_collection do
        "new" ->
          collection_name =
            if String.trim(name) == "",
              do: "#{card.display_name}'s Card",
              else: String.trim(name)

          Collections.create_collection(%{
            name: collection_name,
            entries: [entry]
          })

        id ->
          collection = Collections.get_collection!(id)
          existing = collection.entries || []

          entries =
            if is_list(existing), do: existing ++ [entry], else: [entry]

          Collections.update_collection(collection, %{entries: entries})
      end

    case result do
      {:ok, _collection} ->
        {:noreply,
         socket
         |> assign(:imported, true)
         |> put_flash(:info, "Name card imported successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to import. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-lg px-4 py-8 sm:px-6">
        <%= if @not_found do %>
          <div class="rounded-xl border border-[var(--ring)] bg-[var(--card)] p-8 text-center shadow-sm">
            <div class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-red-100">
              <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-600" />
            </div>
            <h1 class="text-xl font-bold text-[var(--fg)]">Name Card Not Found</h1>
            <p class="mt-2 text-sm text-[var(--muted)]">
              This name card link may have expired or been removed.
            </p>
            <a
              href={~p"/name/my-name-card"}
              class="mt-6 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            >
              Create Your Own Card
            </a>
          </div>
        <% else %>
          <%= if @imported do %>
            <%!-- Success state --%>
            <div class="rounded-xl border border-green-200 bg-green-50 p-8 text-center shadow-sm">
              <div class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-green-100">
                <.icon name="hero-check" class="h-6 w-6 text-green-600" />
              </div>
              <h1 class="text-xl font-bold text-[var(--fg)]">Imported!</h1>
              <p class="mt-2 text-sm text-[var(--muted)]">
                {@card.display_name}'s name card has been added to your collection.
              </p>
              <div class="mt-6 flex justify-center gap-3">
                <a
                  href={~p"/name/collections"}
                  class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  View Collections
                </a>
                <a
                  href={~p"/name/my-name-card"}
                  class="inline-flex items-center gap-2 rounded-lg border border-[var(--ring)] px-4 py-2 text-sm font-semibold text-[var(--fg)] hover:bg-[var(--bg)] focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-offset-2"
                >
                  My Name Card
                </a>
              </div>
            </div>
          <% else %>
            <%!-- Card preview + import --%>
            <div class="space-y-6">
              <div class="text-center">
                <h1 class="text-2xl font-bold text-[var(--fg)]">
                  {@card.display_name} shared their name card
                </h1>
                <p class="mt-1 text-sm text-[var(--muted)]">
                  Import to your collections to remember how to say their name
                </p>
              </div>

              <%!-- Card preview --%>
              <div class="rounded-xl border border-[var(--ring)] bg-[var(--card)] p-6 shadow-sm">
                <.name_card_preview card={@card} />
              </div>

              <%!-- Import form --%>
              <form id="import-form" phx-submit="import_card" class="rounded-xl border border-[var(--ring)] bg-[var(--card)] p-6 shadow-sm">
                <h3 class="text-sm font-semibold text-[var(--fg)]">Add to collection</h3>

                <div class="mt-3 space-y-2">
                  <%= for collection <- @collections do %>
                    <label class={[
                      "flex cursor-pointer items-center gap-3 rounded-lg border px-4 py-3 transition-colors",
                      if(@selected_collection == collection.id,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-[var(--ring)] hover:border-[var(--muted)]"
                      )
                    ]}>
                      <input
                        type="radio"
                        name="collection"
                        value={collection.id}
                        checked={@selected_collection == collection.id}
                        phx-click="select_collection"
                        phx-value-collection={collection.id}
                        class="text-blue-600 focus:ring-blue-500"
                      />
                      <span class="text-sm font-medium text-[var(--fg)]">{collection.name}</span>
                    </label>
                  <% end %>

                  <label class={[
                    "flex cursor-pointer items-center gap-3 rounded-lg border px-4 py-3 transition-colors",
                    if(@selected_collection == "new",
                      do: "border-blue-500 bg-blue-50",
                      else: "border-[var(--ring)] hover:border-[var(--muted)]"
                    )
                  ]}>
                    <input
                      type="radio"
                      name="collection"
                      value="new"
                      checked={@selected_collection == "new"}
                      phx-click="select_collection"
                      phx-value-collection="new"
                      class="text-blue-600 focus:ring-blue-500"
                    />
                    <span class="text-sm font-medium text-blue-700">
                      + Create new collection
                    </span>
                  </label>

                  <%= if @selected_collection == "new" do %>
                    <div class="ml-8">
                      <input
                        type="text"
                        name="new_collection_name"
                        value={@new_collection_name}
                        placeholder={"#{@card.display_name}'s Card"}
                        class="mt-1 block w-full rounded-lg border border-zinc-300 text-sm text-zinc-900 focus:border-blue-400 focus:ring-0"
                      />
                    </div>
                  <% else %>
                    <input type="hidden" name="new_collection_name" value="" />
                  <% end %>
                </div>

                <button
                  id="import-btn"
                  type="submit"
                  class="mt-4 w-full rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  Import Name Card
                </button>
              </form>
            </div>
          <% end %>
        <% end %>
    </div>
    """
  end
end

defmodule ZonelyWeb.CollectionsLive do
  use ZonelyWeb, :live_view

  alias Zonely.Collections
  alias Zonely.Collections.ShareUrl

  @impl true
  def mount(_params, _session, socket) do
    collections = Collections.list_collections()

    {:ok,
     socket
     |> assign(:collections, collections)
     |> assign(:show_form, false)
     |> assign(:form_mode, :create)
     |> assign(:selected_collection, nil)
     |> assign(:share_url, nil)
     |> assign(:copied, false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case Collections.get_collection(id) do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/name/collections")}

      collection ->
        {:noreply, assign(socket, selected_collection: collection)}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("new_collection", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_mode, :create)
     |> assign(:selected_collection, nil)}
  end

  def handle_event("edit_collection", %{"id" => id}, socket) do
    collection = Collections.get_collection!(id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:form_mode, :edit)
     |> assign(:selected_collection, collection)}
  end

  def handle_event("delete_collection", %{"id" => id}, socket) do
    collection = Collections.get_collection!(id)
    {:ok, _} = Collections.delete_collection(collection)

    collections = Collections.list_collections()

    {:noreply,
     socket
     |> assign(:collections, collections)
     |> assign(:selected_collection, nil)
     |> put_flash(:info, "Collection deleted successfully")}
  end

  def handle_event("share_collection", %{"id" => id}, socket) do
    collection = Collections.get_collection!(id)
    entries = collection.entries

    share_url =
      if is_list(entries) do
        ShareUrl.generate_url(entries)
      else
        ShareUrl.generate_url([])
      end

    {:noreply, assign(socket, share_url: share_url)}
  end

  def handle_event("copy_url", _params, socket) do
    {:noreply, assign(socket, copied: true)}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="space-y-8">
        <!-- Header Section -->
        <div class="flex flex-col gap-8 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-4xl font-bold text-gray-900">Name Collections</h1>
            <p class="mt-2 text-gray-600">Create and share collections of names with others</p>
          </div>
          <button
            phx-click="new_collection"
            aria-label="Create a new collection"
            class="inline-flex items-center justify-center gap-2 rounded-lg bg-blue-600 px-6 py-3 text-base font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-4 focus:ring-blue-500 focus:ring-offset-2 active:bg-blue-800"
          >
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            New Collection
          </button>
        </div>

        <!-- Collections Grid -->
        <div class="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
          <%= if Enum.empty?(@collections) do %>
            <div class="col-span-full flex flex-col items-center justify-center rounded-lg border-2 border-dashed border-gray-300 bg-gray-50 px-8 py-16 text-center">
              <svg class="mb-4 h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V7M3 7l9-4 9 4" />
              </svg>
              <h3 class="text-lg font-semibold text-gray-900">No collections yet</h3>
              <p class="mt-2 text-gray-600">Create your first collection to get started</p>
            </div>
          <% else %>
            <%= for collection <- @collections do %>
              <article class="flex flex-col rounded-lg border border-gray-200 bg-white p-8 shadow-sm transition-shadow hover:shadow-md">
                <div class="mb-4 flex-1">
                  <h2 class="text-xl font-bold text-gray-900"><%= collection.name %></h2>
                  <%= if collection.description do %>
                    <p class="mt-2 text-gray-600"><%= collection.description %></p>
                  <% end %>
                  <p class="mt-4 text-sm text-gray-500">
                    <span class="font-semibold"><%= length(collection.entries || []) %></span>
                    <%= if length(collection.entries || []) == 1, do: "name", else: "names" %>
                  </p>
                </div>

                <!-- Action Buttons -->
                <div class="mt-6 grid grid-cols-3 gap-2">
                  <button
                    phx-click="share_collection"
                    phx-value-id={collection.id}
                    aria-label={"Share #{collection.name}"}
                    class="inline-flex items-center justify-center gap-1 rounded-lg bg-green-50 px-3 py-2 text-sm font-semibold text-green-700 transition-colors hover:bg-green-100 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 active:bg-green-200"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C9.589 12.938 10 12.502 10 12c0-.502-.411-.938-1.316-1.342m0 2.684a3 3 0 110-2.684m9.108-3.342C15.411 5.938 15 5.502 15 5c0-.502.411-.938 1.316-1.342m0 2.684a3 3 0 11-6 0m6 0a3 3 0 01-6 0m0-2.684a3 3 0 000 2.684m0-2.684l9.108-3.342" />
                    </svg>
                    Share
                  </button>
                  <button
                    phx-click="edit_collection"
                    phx-value-id={collection.id}
                    aria-label={"Edit #{collection.name}"}
                    class="inline-flex items-center justify-center gap-1 rounded-lg bg-blue-50 px-3 py-2 text-sm font-semibold text-blue-700 transition-colors hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 active:bg-blue-200"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                    Edit
                  </button>
                  <button
                    phx-click="delete_collection"
                    phx-value-id={collection.id}
                    aria-label={"Delete #{collection.name}"}
                    class="inline-flex items-center justify-center gap-1 rounded-lg bg-red-50 px-3 py-2 text-sm font-semibold text-red-700 transition-colors hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 active:bg-red-200"
                  >
                    <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Delete
                  </button>
                </div>
              </article>
            <% end %>
          <% end %>
        </div>

        <!-- Share Modal -->
        <%= if @share_url do %>
          <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4" role="dialog" aria-modal="true" aria-labelledby="share-modal-title">
            <div class="w-full max-w-md rounded-lg bg-white p-8 shadow-lg">
              <h2 id="share-modal-title" class="text-2xl font-bold text-gray-900">Share Collection</h2>
              <p class="mt-4 text-gray-600">
                Share this URL with others to let them import this collection:
              </p>
              <div class="mt-6 rounded-lg bg-gray-100 p-4 font-mono text-sm text-gray-700 break-all">
                <%= @share_url %>
              </div>
              <div class="mt-6 flex gap-3">
                <button
                  phx-click="copy_url"
                  class="flex-1 inline-flex items-center justify-center gap-2 rounded-lg bg-blue-600 px-4 py-3 font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-4 focus:ring-blue-500 focus:ring-offset-2 active:bg-blue-800"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                  <%= if @copied, do: "✓ Copied!", else: "Copy URL" %>
                </button>
                <button
                  phx-click="close_form"
                  class="flex-1 inline-flex items-center justify-center rounded-lg border-2 border-gray-300 px-4 py-3 font-semibold text-gray-700 transition-colors hover:bg-gray-50 focus:outline-none focus:ring-4 focus:ring-gray-500 focus:ring-offset-2"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    """
  end
end

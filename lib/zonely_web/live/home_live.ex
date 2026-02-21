defmodule ZonelyWeb.HomeLive do
  use ZonelyWeb, :live_view

  alias Zonely.Collections
  alias Zonely.NameCards

  @supported_langs [
    {"English", "en-US"},
    {"中文", "zh-CN"},
    {"Español", "es-ES"},
    {"हिन्दी", "hi-IN"},
    {"العربية", "ar-SA"},
    {"বাংলা", "bn-IN"},
    {"Français", "fr-FR"},
    {"Português", "pt-BR"},
    {"日本語", "ja-JP"},
    {"Deutsch", "de-DE"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    collections = Collections.list_collections()
    card = NameCards.get_name_card()

    # Pick the most recent collection (or nil)
    active_collection =
      case collections do
        [first | _] -> first
        [] -> nil
      end

    {:ok,
     socket
     |> assign(:page_title, "Lists")
     |> assign(:collections, collections)
     |> assign(:active_collection, active_collection)
     |> assign(:has_card, card != nil)
     |> assign(:show_switcher, false)
     |> assign(:expanded_entry, nil)
     |> assign(:supported_langs, @supported_langs)
     |> assign(
       :input_form,
       to_form(%{"name" => "", "lang" => "en-US", "pron_text" => ""}, as: :entry)
     )
     |> assign(:show_pron_override, false)}
  end

  @impl true
  def handle_event("switch_list", %{"id" => id}, socket) do
    collection = Collections.get_collection(id)

    {:noreply,
     socket
     |> assign(:active_collection, collection)
     |> assign(:show_switcher, false)
     |> assign(:expanded_entry, nil)}
  end

  def handle_event("toggle_switcher", _params, socket) do
    {:noreply, assign(socket, :show_switcher, !socket.assigns.show_switcher)}
  end

  def handle_event("close_switcher", _params, socket) do
    {:noreply, assign(socket, :show_switcher, false)}
  end

  def handle_event("toggle_entry", %{"index" => index}, socket) do
    index = String.to_integer(index)

    new_expanded =
      if socket.assigns.expanded_entry == index, do: nil, else: index

    {:noreply, assign(socket, :expanded_entry, new_expanded)}
  end

  def handle_event("validate_input", %{"entry" => params}, socket) do
    {:noreply, assign(socket, :input_form, to_form(params, as: :entry))}
  end

  def handle_event("toggle_pron_override", _params, socket) do
    {:noreply, assign(socket, :show_pron_override, !socket.assigns.show_pron_override)}
  end

  def handle_event("add_entry", %{"entry" => params}, socket) do
    name = String.trim(params["name"] || "")
    lang = params["lang"] || "en-US"
    pron_text = String.trim(params["pron_text"] || "")

    if name == "" do
      {:noreply, socket}
    else
      text =
        if pron_text != "" and socket.assigns.show_pron_override,
          do: pron_text,
          else: name

      entry = %{"name" => name, "entries" => [%{"lang" => lang, "text" => text}]}
      collection = socket.assigns.active_collection
      existing = collection.entries || []
      entries = existing ++ [entry]

      case Collections.update_collection(collection, %{entries: entries}) do
        {:ok, updated} ->
          collections = Collections.list_collections()

          {:noreply,
           socket
           |> assign(:active_collection, updated)
           |> assign(:collections, collections)
           |> assign(
             :input_form,
             to_form(%{"name" => "", "lang" => lang, "pron_text" => ""}, as: :entry)
           )
           |> assign(:show_pron_override, false)
           |> assign(:expanded_entry, nil)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not add entry")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @active_collection do %>
      <%!-- Returning user: show active list --%>
      <div class="space-y-4">
        <%!-- List header with switcher --%>
        <div class="flex items-center justify-between">
          <button
            id="list-switcher-btn"
            phx-click="toggle_switcher"
            class="flex items-center gap-2 text-xl font-bold text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded-lg px-2 py-1 -ml-2 hover:bg-gray-100 transition-colors"
            aria-haspopup="listbox"
            aria-expanded={if(@show_switcher, do: "true", else: "false")}
          >
            {@active_collection.name}
            <.icon name="hero-chevron-down" class="h-5 w-5 text-gray-400" />
          </button>
          <span class="text-sm text-gray-500">
            {length(@active_collection.entries || [])}
            <%= if length(@active_collection.entries || []) == 1, do: "name", else: "names" %>
          </span>
        </div>

        <%!-- List switcher dropdown --%>
        <%= if @show_switcher do %>
          <div
            id="list-switcher"
            class="rounded-xl border border-gray-200 bg-white p-4 shadow-lg"
            role="listbox"
            aria-label="Switch list"
            phx-click-away="close_switcher"
          >
            <div class="mb-3 flex items-center justify-between">
              <h3 class="text-sm font-semibold text-gray-900">Switch List</h3>
              <.link
                navigate={~p"/collections"}
                class="text-xs text-blue-600 hover:text-blue-700 font-medium focus:outline-none focus:underline"
              >
                Manage Lists...
              </.link>
            </div>
            <div class="space-y-1">
              <%= for collection <- @collections do %>
                <button
                  phx-click="switch_list"
                  phx-value-id={collection.id}
                  role="option"
                  aria-selected={if(@active_collection.id == collection.id, do: "true", else: "false")}
                  class={[
                    "flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-left text-sm transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500",
                    if(@active_collection.id == collection.id,
                      do: "bg-blue-50 text-blue-700 font-medium",
                      else: "text-gray-700 hover:bg-gray-50"
                    )
                  ]}
                >
                  <span>{collection.name}</span>
                  <span class="text-xs text-gray-400">
                    {length(collection.entries || [])} names
                  </span>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Add name input card --%>
        <div id="add-name-card" class="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <.form for={@input_form} id="add-name-form" phx-change="validate_input" phx-submit="add_entry">
            <div class="flex items-end gap-2">
              <div class="flex-1">
                <.input
                  field={@input_form[:name]}
                  type="text"
                  label="Name"
                  placeholder="e.g. Zhang Wei"
                  autocomplete="off"
                />
              </div>
              <div class="w-36">
                <.input
                  field={@input_form[:lang]}
                  type="select"
                  label="Language"
                  options={@supported_langs}
                />
              </div>
              <button
                type="submit"
                disabled={String.trim(@input_form[:name].value || "") == ""}
                class={[
                  "mb-0.5 inline-flex items-center justify-center rounded-lg px-4 py-2 text-sm font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
                  if(String.trim(@input_form[:name].value || "") == "",
                    do: "bg-gray-200 text-gray-400 cursor-not-allowed",
                    else: "bg-blue-600 text-white hover:bg-blue-700"
                  )
                ]}
              >
                Add
              </button>
            </div>
            <div class="mt-3 flex items-center gap-2">
              <button
                type="button"
                phx-click="toggle_pron_override"
                class="flex items-center gap-1.5 text-xs text-gray-500 hover:text-gray-700 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 rounded"
                aria-pressed={if(@show_pron_override, do: "true", else: "false")}
              >
                <.icon
                  name={if(@show_pron_override, do: "hero-chevron-up-mini", else: "hero-chevron-down-mini")}
                  class="h-3.5 w-3.5"
                />
                Custom pronunciation
              </button>
            </div>
            <%= if @show_pron_override do %>
              <div class="mt-2">
                <.input
                  field={@input_form[:pron_text]}
                  type="text"
                  label="Pronunciation text"
                  placeholder="How it's pronounced in the selected language"
                  autocomplete="off"
                />
              </div>
            <% end %>
          </.form>
        </div>

        <%!-- Name entries --%>
        <div id="name-list" class="space-y-2">
          <%= if Enum.empty?(@active_collection.entries || []) do %>
            <div class="rounded-xl border-2 border-dashed border-gray-300 bg-white px-6 py-12 text-center">
              <.icon name="hero-user-plus" class="mx-auto h-10 w-10 text-gray-400" />
              <p class="mt-3 text-sm font-medium text-gray-900">No names in this list yet</p>
              <p class="mt-1 text-xs text-gray-500">Share your name card or add names manually</p>
            </div>
          <% else %>
            <%= for {entry, idx} <- Enum.with_index(@active_collection.entries || []) do %>
              <div class="rounded-xl border border-gray-200 bg-white shadow-sm overflow-hidden">
                <div
                  class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors"
                  phx-click="toggle_entry"
                  phx-value-index={idx}
                  role="button"
                  aria-expanded={if(@expanded_entry == idx, do: "true", else: "false")}
                >
                  <span class="text-base font-medium text-gray-900 flex-1">
                    {entry["name"] || entry["display_name"] || "Unknown"}
                  </span>
                  <.icon
                    name={if(@expanded_entry == idx, do: "hero-chevron-up", else: "hero-chevron-down")}
                    class="h-4 w-4 text-gray-400"
                  />
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% else %>
      <%!-- New user or no lists: onboarding --%>
      <div class="flex flex-col items-center justify-center px-4 py-16 text-center">
        <span class="text-5xl mb-6">👋</span>
        <h1 class="text-2xl font-bold text-gray-900">
          Learn to pronounce anyone's name correctly, in any language.
        </h1>
        <div class="mt-8 w-full max-w-sm space-y-3 text-left">
          <div class="flex items-start gap-3 rounded-lg bg-white p-4 border border-gray-200">
            <span class="text-lg">1.</span>
            <div>
              <p class="font-medium text-gray-900">Set up your name card</p>
              <p class="text-sm text-gray-500">so others can learn to say your name</p>
            </div>
          </div>
          <div class="flex items-start gap-3 rounded-lg bg-white p-4 border border-gray-200">
            <span class="text-lg">2.</span>
            <div>
              <p class="font-medium text-gray-900">Share it with your team</p>
              <p class="text-sm text-gray-500">or community</p>
            </div>
          </div>
          <div class="flex items-start gap-3 rounded-lg bg-white p-4 border border-gray-200">
            <span class="text-lg">3.</span>
            <div>
              <p class="font-medium text-gray-900">Import their cards</p>
              <p class="text-sm text-gray-500">and practice together</p>
            </div>
          </div>
        </div>
        <div class="mt-8 flex flex-col gap-3 w-full max-w-xs">
          <.link
            navigate={~p"/me/card"}
            class="inline-flex items-center justify-center rounded-lg bg-blue-600 px-6 py-3 text-base font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            Set Up My Name Card
          </.link>
          <.link
            navigate={~p"/collections"}
            class="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-6 py-3 text-base font-semibold text-gray-700 transition-colors hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            Create a List Instead
          </.link>
        </div>
      </div>
    <% end %>
    """
  end
end

defmodule ZonelyWeb.MyNameCardLive do
  use ZonelyWeb, :live_view

  alias Zonely.NameCards
  alias Zonely.NameCards.NameCard

  @impl true
  def mount(_params, _session, socket) do
    card = NameCards.get_name_card() || %NameCard{}

    {:ok,
     socket
     |> assign(:card, card)
     |> assign(:form, to_form(NameCard.changeset(card, %{})))
     |> assign(:language_variants, card.language_variants || [])
     |> assign(:show_add_lang, false)
     |> assign(:new_lang, "zh-CN")
     |> assign(:new_lang_name, "")
     |> assign(:show_share, false)
     |> assign(:copied, false)
     |> assign(:saved, false)}
  end

  @impl true
  def handle_event("validate", %{"name_card" => params}, socket) do
    changeset =
      socket.assigns.card
      |> NameCard.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"name_card" => params}, socket) do
    params = Map.put(params, "language_variants", socket.assigns.language_variants)

    case NameCards.save_name_card(params) do
      {:ok, card} ->
        {:noreply,
         socket
         |> assign(:card, card)
         |> assign(:language_variants, card.language_variants)
         |> assign(:form, to_form(NameCard.changeset(card, %{})))
         |> assign(:saved, true)
         |> put_flash(:info, "Name card saved!")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("show_add_lang", _params, socket) do
    # Pick a language that isn't already added
    used = Enum.map(socket.assigns.language_variants, & &1["language"])
    available = Enum.reject(NameCard.supported_languages(), fn {code, _, _} -> code in used end)

    default_lang =
      case available do
        [{code, _, _} | _] -> code
        [] -> "en"
      end

    {:noreply,
     socket
     |> assign(:show_add_lang, true)
     |> assign(:new_lang, default_lang)
     |> assign(:new_lang_name, "")}
  end

  def handle_event("cancel_add_lang", _params, socket) do
    {:noreply, assign(socket, show_add_lang: false)}
  end

  def handle_event("change_new_lang", %{"language" => lang}, socket) do
    {:noreply, assign(socket, new_lang: lang)}
  end

  def handle_event("add_language", %{"name" => name}, socket) do
    lang = socket.assigns.new_lang

    if String.trim(name) == "" do
      {:noreply, put_flash(socket, :error, "Name is required")}
    else
      variant = %{
        "language" => lang,
        "name" => String.trim(name)
      }

      variants = socket.assigns.language_variants ++ [variant]

      {:noreply,
       socket
       |> assign(:language_variants, variants)
       |> assign(:show_add_lang, false)
       |> assign(:saved, false)}
    end
  end

  def handle_event("remove_language", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    variants = List.delete_at(socket.assigns.language_variants, index)

    {:noreply,
     socket
     |> assign(:language_variants, variants)
     |> assign(:saved, false)}
  end

  def handle_event("show_share", _params, socket) do
    {:noreply, assign(socket, show_share: true, copied: false)}
  end

  def handle_event("close_share", _params, socket) do
    {:noreply, assign(socket, show_share: false)}
  end

  def handle_event("copy_link", _params, socket) do
    {:noreply, assign(socket, copied: true)}
  end

  def handle_event("delete_card", _params, socket) do
    case socket.assigns.card do
      %NameCard{id: id} when not is_nil(id) ->
        {:ok, _} = NameCards.delete_name_card(socket.assigns.card)
        card = %NameCard{}

        {:noreply,
         socket
         |> assign(:card, card)
         |> assign(:form, to_form(NameCard.changeset(card, %{})))
         |> assign(:language_variants, [])
         |> assign(:saved, false)
         |> assign(:show_share, false)
         |> put_flash(:info, "Name card deleted")}

      _ ->
        {:noreply, socket}
    end
  end

  defp share_url(card) do
    ZonelyWeb.Endpoint.url() <> "/card/#{card.share_token}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-8 px-4 py-8 sm:px-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">My Name Card</h1>
            <p class="mt-1 text-sm text-gray-600">
              Share how you want to be known across languages
            </p>
          </div>
          <div class="flex items-center gap-2">
            <%= if @card.id do %>
              <button
                id="share-btn"
                phx-click="show_share"
                aria-label="Share your name card"
                class="inline-flex items-center gap-2 rounded-lg bg-green-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
              >
                <.icon name="hero-share" class="h-4 w-4" />
                Share
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Main form --%>
        <.form for={@form} id="name-card-form" phx-change="validate" phx-submit="save">
          <div class="space-y-6 rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <%!-- Display name --%>
            <.input
              field={@form[:display_name]}
              type="text"
              label="Your Name"
              placeholder="e.g. Sarah Chen"
              required
            />

            <%!-- Pronouns & Role row --%>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.input
                field={@form[:pronouns]}
                type="text"
                label="Pronouns (optional)"
                placeholder="e.g. she/her"
              />
              <.input
                field={@form[:role]}
                type="text"
                label="Role (optional)"
                placeholder="e.g. Product Designer"
              />
            </div>

            <%!-- Language variants section --%>
            <div class="space-y-3">
              <div class="flex items-center justify-between">
                <label class="block text-sm font-semibold text-zinc-800">
                  Name in Other Languages
                </label>
                <button
                  id="add-language-btn"
                  type="button"
                  phx-click="show_add_lang"
                  aria-label="Add a language variant"
                  class="inline-flex items-center gap-1 rounded-lg bg-blue-50 px-3 py-1.5 text-sm font-semibold text-blue-700 transition-colors hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  <.icon name="hero-plus" class="h-4 w-4" />
                  Add Language
                </button>
              </div>

              <%= if @language_variants == [] do %>
                <div class="rounded-lg border-2 border-dashed border-gray-200 px-4 py-8 text-center">
                  <p class="text-sm text-gray-500">
                    No language variants yet. Add your name in Chinese, Japanese, or other languages.
                  </p>
                </div>
              <% else %>
                <div id="language-variants" class="space-y-2">
                  <%= for {variant, index} <- Enum.with_index(@language_variants) do %>
                    <div
                      id={"lang-#{index}"}
                      class="flex items-center justify-between rounded-lg border border-gray-200 bg-gray-50 px-4 py-3"
                    >
                      <div class="flex items-center gap-3">
                        <span class="text-lg" aria-hidden="true">
                          {NameCard.language_flag(variant["language"])}
                        </span>
                        <div>
                          <span class="font-medium text-gray-900">
                            {variant["name"]}
                          </span>
                          <span class="ml-2 text-xs text-gray-400">
                            {NameCard.language_label(variant["language"])}
                          </span>
                        </div>
                      </div>
                      <button
                        type="button"
                        phx-click="remove_language"
                        phx-value-index={index}
                        aria-label={"Remove #{NameCard.language_label(variant["language"])} variant"}
                        class="rounded p-1 text-gray-400 transition-colors hover:bg-red-50 hover:text-red-600 focus:outline-none focus:ring-2 focus:ring-red-500"
                      >
                        <.icon name="hero-x-mark" class="h-4 w-4" />
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%!-- Save button --%>
            <div class="flex items-center justify-between border-t border-gray-100 pt-4">
              <div>
                <%= if @card.id do %>
                  <button
                    id="delete-card-btn"
                    type="button"
                    phx-click="delete_card"
                    data-confirm="Are you sure you want to delete your name card?"
                    aria-label="Delete your name card"
                    class="text-sm text-red-600 hover:text-red-700 focus:outline-none focus:underline"
                  >
                    Delete card
                  </button>
                <% end %>
              </div>
              <button
                id="save-card-btn"
                type="submit"
                class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                <.icon name="hero-check" class="h-4 w-4" />
                Save Name Card
              </button>
            </div>
          </div>
        </.form>

        <%!-- Add language modal --%>
        <%= if @show_add_lang do %>
          <div
            id="add-lang-modal"
            class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
            role="dialog"
            aria-modal="true"
            aria-labelledby="add-lang-title"
            phx-window-keydown="cancel_add_lang"
            phx-key="Escape"
          >
            <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl">
              <div class="flex items-center justify-between">
                <h2 id="add-lang-title" class="text-lg font-bold text-gray-900">
                  Add Language Variant
                </h2>
                <button
                  type="button"
                  phx-click="cancel_add_lang"
                  aria-label="Close"
                  class="rounded p-1 text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>

              <form id="add-lang-form" phx-submit="add_language" class="mt-4 space-y-4">
                <div>
                  <label for="new-lang-select" class="block text-sm font-semibold text-zinc-800">
                    Language
                  </label>
                  <select
                    id="new-lang-select"
                    name="language"
                    phx-change="change_new_lang"
                    class="mt-1 block w-full rounded-md border border-gray-300 bg-white px-3 py-2 shadow-sm focus:border-blue-400 focus:ring-0 sm:text-sm"
                  >
                    <%= for {code, label, flag} <- NameCard.supported_languages() do %>
                      <% used = Enum.map(@language_variants, & &1["language"]) %>
                      <option value={code} selected={code == @new_lang} disabled={code in used}>
                        {flag} {label} {if code in used, do: "(already added)", else: ""}
                      </option>
                    <% end %>
                  </select>
                </div>

                <div>
                  <label for="new-lang-name" class="block text-sm font-semibold text-zinc-800">
                    Your Name in This Language
                  </label>
                  <input
                    id="new-lang-name"
                    type="text"
                    name="name"
                    value={@new_lang_name}
                    placeholder="Enter your name in native script"
                    required
                    class="mt-1 block w-full rounded-lg border border-zinc-300 text-zinc-900 focus:border-blue-400 focus:ring-0 sm:text-sm"
                  />
                  <p class="mt-1 text-xs text-gray-500">
                    Write in native script (e.g. 陈莎拉 for Chinese)
                  </p>
                </div>

                <div class="flex justify-end gap-3 pt-2">
                  <button
                    type="button"
                    phx-click="cancel_add_lang"
                    class="rounded-lg border border-gray-300 px-4 py-2 text-sm font-semibold text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-offset-2"
                  >
                    Cancel
                  </button>
                  <button
                    id="confirm-add-lang-btn"
                    type="submit"
                    class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                  >
                    Add Language
                  </button>
                </div>
              </form>
            </div>
          </div>
        <% end %>

        <%!-- Share modal --%>
        <%= if @show_share and @card.id do %>
          <div
            id="share-modal"
            class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
            role="dialog"
            aria-modal="true"
            aria-labelledby="share-title"
            phx-window-keydown="close_share"
            phx-key="Escape"
          >
            <div class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl">
              <div class="flex items-center justify-between">
                <h2 id="share-title" class="text-lg font-bold text-gray-900">
                  Share Your Name Card
                </h2>
                <button
                  type="button"
                  phx-click="close_share"
                  aria-label="Close share dialog"
                  class="rounded p-1 text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>

              <p class="mt-2 text-sm text-gray-600">
                Share this link so others can see and import your name card.
              </p>

              <div class="mt-4 rounded-lg bg-gray-50 p-3">
                <code
                  id="share-url-text"
                  class="block break-all text-sm text-gray-700"
                >
                  {share_url(@card)}
                </code>
              </div>

              <div class="mt-4 flex gap-3">
                <button
                  id="copy-link-btn"
                  phx-click="copy_link"
                  phx-hook="Clipboard"
                  data-clipboard-text={share_url(@card)}
                  aria-label="Copy share link"
                  class={[
                    "flex-1 inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2",
                    if(@copied,
                      do:
                        "bg-green-600 text-white focus:ring-green-500",
                      else:
                        "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500"
                    )
                  ]}
                >
                  <%= if @copied do %>
                    <.icon name="hero-check" class="h-4 w-4" />
                    Copied!
                  <% else %>
                    <.icon name="hero-clipboard-document" class="h-4 w-4" />
                    Copy Link
                  <% end %>
                </button>
                <button
                  type="button"
                  phx-click="close_share"
                  class="flex-1 rounded-lg border border-gray-300 px-4 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-400 focus:ring-offset-2"
                >
                  Done
                </button>
              </div>
            </div>
          </div>
        <% end %>
    </div>
    """
  end
end

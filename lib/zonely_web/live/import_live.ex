defmodule ZonelyWeb.ImportLive do
  use Phoenix.LiveView, layout: false

  import Ecto.Query
  import ZonelyWeb.CoreComponents

  use Gettext, backend: ZonelyWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: ZonelyWeb.Endpoint,
    router: ZonelyWeb.Router,
    statics: ZonelyWeb.static_paths()

  alias Zonely.Accounts.Person
  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Repo
  alias ZonelyWeb.Layouts

  @owner_session_key "zonely_import_owner_token"

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    owner_token = Map.get(params, "owner_token") || Map.get(session, @owner_session_key)

    case load_authorized_import(id, owner_token) do
      {:ok, draft, member} ->
        {:ok,
         socket
         |> assign(:page_title, "Complete imported card")
         |> assign(:authorized?, true)
         |> assign(:draft, draft)
         |> assign(:member, member)
         |> assign(:conflicts, duplicate_conflicts(member))
         |> assign_form(member)}

      :error ->
        {:ok,
         socket
         |> assign(:page_title, "Import unavailable")
         |> assign(:authorized?, false)
         |> assign(:draft, nil)
         |> assign(:member, nil)
         |> assign(:conflicts, [])
         |> assign(:form, to_form(%{}, as: :import))}
    end
  end

  @impl true
  def handle_event("save", %{"import" => params}, %{assigns: %{authorized?: true}} = socket) do
    case Drafts.update_draft_member_completion(socket.assigns.member, params) do
      {:ok, member} ->
        {:noreply,
         socket
         |> put_flash(:info, "Zonely-ready profile saved.")
         |> assign(:member, member)
         |> assign(:conflicts, duplicate_conflicts(member))
         |> assign_form(member)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :import))}
    end
  end

  def handle_event("save", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} inner_content={import_content(assigns)} />
    """
  end

  defp import_content(assigns) do
    ~H"""
      <main class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
        <div class="mx-auto max-w-4xl">
          <%= if @authorized? do %>
            <section
              id="card-import-review"
              class="rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]"
            >
              <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">
                SayMyName card import
              </p>
              <div class="mt-3 flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
                <div>
                  <h1 class="text-3xl font-semibold tracking-tight">{@member.display_name}</h1>
                  <p :if={present?(@member.pronouns)} class="mt-1 text-sm text-[#5F6B73]">
                    Pronouns: {@member.pronouns}
                  </p>
                </div>
                <p
                  :if={@member.completion_status == :complete}
                  id="complete-status"
                  class="rounded-full border border-[#1F8A70]/25 bg-[#1F8A70]/10 px-3 py-1 text-sm font-medium text-[#1F8A70]"
                >
                  Zonely-ready profile
                </p>
              </div>

              <div
                :if={@conflicts != []}
                id="duplicate-conflict"
                class="mt-5 rounded-2xl border border-[#B9822E]/30 bg-[#B9822E]/10 p-4 text-sm text-[#5F3D13]"
              >
                <p class="font-semibold">Possible duplicate</p>
                <p>
                  A Zonely profile already uses this display name. Review before publishing; existing
                  location, timezone, and work-hour fields were not overwritten.
                </p>
              </div>

              <div class="mt-6 grid gap-6 md:grid-cols-[1fr_1.1fr]">
                <section aria-labelledby="imported-card-heading">
                  <h2 id="imported-card-heading" class="text-lg font-semibold">Imported card context</h2>
                  <div class="mt-4 space-y-4 text-sm">
                    <div :if={present?(@member.role)} id="role-candidate">
                      <p class="text-[#5F6B73]">Role candidate</p>
                      <p class="font-medium">{@member.role}</p>
                    </div>

                    <div>
                      <p class="text-[#5F6B73]">Name variants</p>
                      <div class="mt-2 space-y-2">
                        <div
                          :for={{variant, index} <- Enum.with_index(@member.name_variants || [])}
                          id={"name-variant-#{index}"}
                          class="rounded-xl border border-[rgba(22,26,29,0.10)] px-3 py-2"
                        >
                          <p class="font-medium">{variant["text"] || variant[:text]}</p>
                          <p class="font-mono text-xs text-[#5F6B73]">
                            {variant["lang"] || variant[:lang]}
                            <span :if={variant["script"] || variant[:script]}>
                              · {variant["script"] || variant[:script]}
                            </span>
                          </p>
                          <p
                            :if={variant["pronunciation"] || variant[:pronunciation]}
                            class="mt-1 text-xs text-[#5F6B73]"
                          >
                            Pronunciation metadata attached to this variant
                          </p>
                        </div>
                      </div>
                    </div>

                    <div
                      :if={map_size(@member.pronunciation || %{}) > 0}
                      id="pronunciation-context"
                      class="rounded-xl border border-[rgba(22,26,29,0.10)] px-3 py-2"
                    >
                      <p class="font-medium">Pronunciation available</p>
                      <p class="text-xs text-[#5F6B73]">
                        Kept as secondary SayMyName profile context.
                      </p>
                    </div>

                    <div
                      :if={not is_nil(@member.latitude) and not is_nil(@member.longitude)}
                      id="explicit-coordinates"
                      class="rounded-xl border border-[rgba(22,26,29,0.10)] px-3 py-2"
                    >
                      <p class="font-medium">Explicit coordinates preserved</p>
                      <p class="font-mono text-xs text-[#5F6B73]">
                        {@member.latitude}, {@member.longitude}
                      </p>
                    </div>
                  </div>
                </section>

                <section aria-labelledby="completion-heading">
                  <h2 id="completion-heading" class="text-lg font-semibold">Complete Zonely fields</h2>
                  <p class="mt-1 text-sm text-[#5F6B73]">
                    Only missing location, timezone, and work-window fields are required here.
                  </p>

                  <div
                    :if={@member.completion_status == :incomplete}
                    id="missing-zonely-fields"
                    class="mt-4 flex flex-wrap gap-2 text-xs font-medium text-[#5F6B73]"
                  >
                    <span :if={!present?(@member.location_country)} id="incomplete-location-country">
                      Missing country
                    </span>
                    <span :if={!present?(@member.location_label)} id="incomplete-location-label">
                      Missing city/location label
                    </span>
                    <span :if={!present?(@member.timezone)} id="incomplete-timezone">
                      Missing timezone
                    </span>
                    <span :if={is_nil(@member.work_start)} id="incomplete-work-start">
                      Missing work start
                    </span>
                    <span :if={is_nil(@member.work_end)} id="incomplete-work-end">
                      Missing work end
                    </span>
                  </div>

                  <.form for={@form} id="card-import-completion-form" phx-submit="save" class="mt-5 space-y-4">
                    <.input field={@form[:location_country]} type="text" label="Country code" />
                    <.input field={@form[:location_label]} type="text" label="City or location label" />
                    <.input field={@form[:timezone]} type="text" label="IANA timezone" />
                    <div class="grid gap-4 sm:grid-cols-2">
                      <.input field={@form[:work_start]} type="time" label="Work start" />
                      <.input field={@form[:work_end]} type="time" label="Work end" />
                    </div>
                    <button
                      id="save-card-import"
                      type="submit"
                      class="min-h-11 rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white transition active:translate-y-px"
                    >
                      Save completion
                    </button>
                  </.form>
                </section>
              </div>
            </section>
          <% else %>
            <section
              id="card-import-forbidden"
              class="rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white p-6"
            >
              <h1 class="text-2xl font-semibold">This import link is not available in this session</h1>
              <p class="mt-2 text-[#5F6B73]">
                Return to the original SayMyName card link from the same browser session to resume.
              </p>
            </section>
          <% end %>
        </div>
      </main>
    """
  end

  defp load_authorized_import(id, owner_token) when is_binary(owner_token) do
    with %TeamDraft{} = draft <- Repo.get(TeamDraft, id),
         true <- Drafts.owner_token_matches?(draft, owner_token),
         [%TeamDraftMember{} = member] <- Drafts.list_draft_members(draft) do
      {:ok, draft, member}
    else
      _other -> :error
    end
  end

  defp load_authorized_import(_id, _owner_token), do: :error

  defp assign_form(socket, %TeamDraftMember{} = member) do
    assign(socket, :form, to_form(Drafts.change_draft_member_completion(member), as: :import))
  end

  defp duplicate_conflicts(%TeamDraftMember{display_name: display_name})
       when is_binary(display_name) do
    normalized = String.downcase(String.trim(display_name))

    Person
    |> where([person], fragment("lower(?)", person.name) == ^normalized)
    |> Repo.all()
  end

  defp duplicate_conflicts(_member), do: []

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end

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

  @owner_session_key "zonely_import_owner_tokens_by_draft"

  @impl true
  def mount(%{"id" => id}, session, socket) do
    owner_token = get_import_owner_token(session, id)

    case load_authorized_import(id, owner_token) do
      {:ok, draft, member} ->
        members = Drafts.list_draft_members(draft)

        {:ok,
         socket
         |> assign(:page_title, import_page_title(draft))
         |> assign(:authorized?, true)
         |> assign(:owner_token, owner_token)
         |> assign(:draft, draft)
         |> assign(:member, member)
         |> assign(:members, members)
         |> assign(:conflicts, duplicate_conflicts(member))
         |> assign(:member_conflicts, duplicate_conflicts_by_member(members))
         |> assign(:invalid_memberships, invalid_memberships(draft))
         |> assign_form(member)}

      :error ->
        {:ok,
         socket
         |> assign(:page_title, "Import unavailable")
         |> assign(:authorized?, false)
         |> assign(:owner_token, nil)
         |> assign(:draft, nil)
         |> assign(:member, nil)
         |> assign(:members, [])
         |> assign(:conflicts, [])
         |> assign(:member_conflicts, %{})
         |> assign(:invalid_memberships, [])
         |> assign(:form, to_form(%{}, as: :import))}
    end
  end

  @impl true
  def handle_event("save", %{"import" => params}, %{assigns: %{authorized?: true}} = socket) do
    case Drafts.update_draft_member_completion(socket.assigns.member, params) do
      {:ok, member} ->
        members = Drafts.list_draft_members(socket.assigns.draft)

        {:noreply,
         socket
         |> put_flash(:info, "Zonely-ready profile saved.")
         |> assign(:member, member)
         |> assign(:members, members)
         |> assign(:conflicts, duplicate_conflicts(member))
         |> assign(:member_conflicts, duplicate_conflicts_by_member(members))
         |> assign_form(member)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :import))}
    end
  end

  def handle_event("publish_import", _params, %{assigns: %{authorized?: true}} = socket) do
    case Drafts.publish_import(socket.assigns.draft, socket.assigns.owner_token) do
      {:ok, %{team: team}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Import published to the team map.")
         |> push_navigate(to: ~p"/?team=#{team.id}")}

      {:error, :no_complete_members} ->
        {:noreply,
         put_flash(socket, :error, "Complete at least one imported profile before publishing.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not publish this import.")}
    end
  end

  def handle_event("publish_import", _params, socket), do: {:noreply, socket}

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
            <%= if team_import?(@draft, @members) do %>
              <.team_import_review
                draft={@draft}
                members={@members}
                member_conflicts={@member_conflicts}
                invalid_memberships={@invalid_memberships}
              />
            <% else %>
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

                    <div
                      :if={has_zonely_review_context?(@member)}
                      id="imported-zonely-review-context"
                      class="rounded-xl border border-[rgba(22,26,29,0.10)] px-3 py-2"
                    >
                      <p class="font-medium">Imported Zonely context</p>
                      <dl class="mt-2 grid gap-2 text-xs text-[#5F6B73]">
                        <div :if={present?(@member.location_country)}>
                          <dt>Country</dt>
                          <dd id="review-location-country" class="font-mono text-[#161A1D]">
                            {@member.location_country}
                          </dd>
                        </div>
                        <div :if={present?(@member.location_label)}>
                          <dt>Location</dt>
                          <dd id="review-location-label" class="font-medium text-[#161A1D]">
                            {@member.location_label}
                          </dd>
                        </div>
                        <div :if={present?(@member.timezone)}>
                          <dt>Timezone</dt>
                          <dd id="review-timezone" class="font-mono text-[#161A1D]">
                            {@member.timezone}
                          </dd>
                        </div>
                        <div :if={not is_nil(@member.work_start)}>
                          <dt>Work start</dt>
                          <dd id="review-work-start" class="font-mono text-[#161A1D]">
                            {time_value(@member.work_start)}
                          </dd>
                        </div>
                        <div :if={not is_nil(@member.work_end)}>
                          <dt>Work end</dt>
                          <dd id="review-work-end" class="font-mono text-[#161A1D]">
                            {time_value(@member.work_end)}
                          </dd>
                        </div>
                      </dl>
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
                    <.input
                      :if={!present?(@member.location_country)}
                      field={@form[:location_country]}
                      id="card-import-completion-form_location_country"
                      type="text"
                      label="Country code"
                    />
                    <.input
                      :if={!present?(@member.location_label)}
                      field={@form[:location_label]}
                      id="card-import-completion-form_location_label"
                      type="text"
                      label="City or location label"
                    />
                    <.input
                      :if={!present?(@member.timezone)}
                      field={@form[:timezone]}
                      id="card-import-completion-form_timezone"
                      type="text"
                      label="IANA timezone"
                    />
                    <div class="grid gap-4 sm:grid-cols-2">
                      <.input
                        :if={is_nil(@member.work_start)}
                        field={@form[:work_start]}
                        id="card-import-completion-form_work_start"
                        type="time"
                        label="Work start"
                      />
                      <.input
                        :if={is_nil(@member.work_end)}
                        field={@form[:work_end]}
                        id="card-import-completion-form_work_end"
                        type="time"
                        label="Work end"
                      />
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
            <% end %>
            <.import_publish_panel draft={@draft} members={@members} />
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

  attr(:draft, TeamDraft, required: true)
  attr(:members, :list, required: true)
  attr(:member_conflicts, :map, required: true)
  attr(:invalid_memberships, :list, required: true)

  defp team_import_review(assigns) do
    ~H"""
    <section
      id="team-import-review"
      class="rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]"
    >
      <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">
        SayMyName list import
      </p>
      <div class="mt-3 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 class="text-3xl font-semibold tracking-tight">{@draft.name}</h1>
          <p class="mt-1 text-sm text-[#5F6B73]">
            Review imported team members before any publish step. Draft members are not visible on
            the normal map yet.
          </p>
        </div>
        <p
          id="team-draft-status"
          class="rounded-full border border-[rgba(22,26,29,0.10)] px-3 py-1 text-sm font-medium text-[#5F6B73]"
        >
          Draft roster
        </p>
      </div>

      <div class="mt-6 space-y-4">
        <article
          :for={member <- @members}
          id={"draft-member-#{member.id}"}
          class="rounded-2xl border border-[rgba(22,26,29,0.10)] p-4"
        >
          <div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
            <div>
              <h2 class="text-lg font-semibold">{member.display_name}</h2>
              <p :if={present?(member.role)} class="mt-1 text-sm text-[#5F6B73]">
                Role candidate: {member.role}
              </p>
              <p :if={present?(member.pronouns)} class="mt-1 text-sm text-[#5F6B73]">
                Pronouns: {member.pronouns}
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <span
                :if={member.completion_status == :complete}
                id={"draft-member-#{member.id}-complete"}
                class="rounded-full border border-[#1F8A70]/25 bg-[#1F8A70]/10 px-3 py-1 text-xs font-medium text-[#1F8A70]"
              >
                Complete
              </span>
              <span
                :if={member.completion_status == :incomplete}
                id={"draft-member-#{member.id}-incomplete"}
                class="rounded-full border border-[#B9822E]/30 bg-[#B9822E]/10 px-3 py-1 text-xs font-medium text-[#5F3D13]"
              >
                Incomplete
              </span>
            </div>
          </div>

          <div
            :if={Map.get(@member_conflicts, member.id, []) != []}
            id={"draft-member-#{member.id}-conflict"}
            class="mt-4 rounded-xl border border-[#B9822E]/30 bg-[#B9822E]/10 px-3 py-2 text-sm text-[#5F3D13]"
          >
            Possible duplicate. Existing Zonely-owned fields were not overwritten.
          </div>

          <div
            :if={member.completion_status == :incomplete}
            class="mt-4 flex flex-wrap gap-2 text-xs font-medium text-[#5F6B73]"
          >
            <span
              :if={!present?(member.location_country)}
              id={"draft-member-#{member.id}-missing-location-country"}
            >
              Missing country
            </span>
            <span
              :if={!present?(member.location_label)}
              id={"draft-member-#{member.id}-missing-location-label"}
            >
              Missing city/location label
            </span>
            <span :if={!present?(member.timezone)} id={"draft-member-#{member.id}-missing-timezone"}>
              Missing timezone
            </span>
            <span :if={is_nil(member.work_start)} id={"draft-member-#{member.id}-missing-work-start"}>
              Missing work start
            </span>
            <span :if={is_nil(member.work_end)} id={"draft-member-#{member.id}-missing-work-end"}>
              Missing work end
            </span>
          </div>

          <div class="mt-4 grid gap-3 text-sm md:grid-cols-2">
            <div>
              <p class="text-[#5F6B73]">Location</p>
              <p class="font-medium">{location_summary(member)}</p>
            </div>
            <div>
              <p class="text-[#5F6B73]">Availability</p>
              <p class="font-mono text-xs">{availability_summary(member)}</p>
            </div>
          </div>

          <div :if={(member.name_variants || []) != []} class="mt-4">
            <p class="text-sm text-[#5F6B73]">Name variants</p>
            <div class="mt-2 space-y-2">
              <div
                :for={{variant, index} <- Enum.with_index(member.name_variants || [])}
                id={"draft-member-#{member.id}-variant-#{index}"}
                class="rounded-xl border border-[rgba(22,26,29,0.10)] px-3 py-2 text-sm"
              >
                <p class="font-medium">{variant["text"] || variant[:text]}</p>
                <p class="font-mono text-xs text-[#5F6B73]">
                  {variant["lang"] || variant[:lang]}
                  <span :if={variant["script"] || variant[:script]}>
                    · {variant["script"] || variant[:script]}
                  </span>
                </p>
              </div>
            </div>
          </div>
        </article>

        <article
          :for={invalid <- @invalid_memberships}
          id={"invalid-import-member-#{invalid_index(invalid)}"}
          class="rounded-2xl border border-[#B9822E]/30 bg-[#B9822E]/10 p-4 text-sm text-[#5F3D13]"
        >
          <p class="font-semibold">Invalid list member was skipped</p>
          <p id={"invalid-import-member-#{invalid_index(invalid)}-reason"}>
            Member #{invalid_index(invalid) + 1}: {invalid_reason(invalid)}
          </p>
          <p class="mt-1 text-xs">
            Zonely did not create a guessed person for this malformed row.
          </p>
        </article>
      </div>
    </section>
    """
  end

  attr(:draft, TeamDraft, required: true)
  attr(:members, :list, required: true)

  defp import_publish_panel(assigns) do
    assigns =
      assigns
      |> assign(:ready_count, complete_member_count(assigns.members))
      |> assign(:ready_label, ready_people_label(complete_member_count(assigns.members)))

    ~H"""
    <section
      id="import-publish-panel"
      class="mt-4 rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-5 shadow-[0_18px_50px_rgba(22,26,29,0.10)]"
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 class="text-lg font-semibold">Publish to map</h2>
          <p class="mt-1 text-sm text-[#5F6B73]">{@draft.name}</p>
        </div>
        <form id="import-publish-form" phx-submit="publish_import">
          <button
            id="publish-import"
            type="submit"
            disabled={@ready_count == 0}
            class="min-h-11 rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white transition disabled:cursor-not-allowed disabled:bg-[#A8B0B4] active:translate-y-px"
          >
            Publish {@ready_label}
          </button>
        </form>
      </div>
    </section>
    """
  end

  defp load_authorized_import(id, owner_token) when is_binary(owner_token) do
    with %TeamDraft{} = draft <- Repo.get(TeamDraft, id),
         true <- Drafts.owner_token_matches?(draft, owner_token),
         [%TeamDraftMember{} = member | _members] <- Drafts.list_draft_members(draft) do
      {:ok, draft, member}
    else
      _other -> :error
    end
  end

  defp load_authorized_import(_id, _owner_token), do: :error

  defp get_import_owner_token(session, draft_id) do
    session
    |> Map.get(@owner_session_key, %{})
    |> normalize_owner_tokens()
    |> Map.get(to_string(draft_id))
  end

  defp normalize_owner_tokens(tokens) when is_map(tokens) do
    Map.new(tokens, fn {draft_id, token} -> {to_string(draft_id), token} end)
  end

  defp normalize_owner_tokens(_tokens), do: %{}

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

  defp duplicate_conflicts_by_member(members) do
    Map.new(members, fn member -> {member.id, duplicate_conflicts(member)} end)
  end

  defp team_import?(%TeamDraft{source_kind: "saymyname_list"}, _members), do: true
  defp team_import?(_draft, members), do: length(members) > 1

  defp import_page_title(%TeamDraft{source_kind: "saymyname_list"}), do: "Review imported team"
  defp import_page_title(_draft), do: "Complete imported card"

  defp complete_member_count(members) do
    Enum.count(members, &(&1.completion_status == :complete))
  end

  defp ready_people_label(1), do: "1 ready person"
  defp ready_people_label(count), do: "#{count} ready people"

  defp invalid_memberships(%TeamDraft{source_payload: payload}) when is_map(payload) do
    Map.get(payload, :invalid_memberships) || Map.get(payload, "invalid_memberships") || []
  end

  defp invalid_memberships(_draft), do: []

  defp invalid_index(%{"index" => index}), do: index
  defp invalid_index(%{index: index}), do: index
  defp invalid_index(_invalid), do: 0

  defp invalid_reason(%{"reason" => reason}), do: reason
  defp invalid_reason(%{reason: reason}), do: reason
  defp invalid_reason(_invalid), do: "invalid member"

  defp location_summary(member) do
    [member.location_label, member.location_country]
    |> Enum.filter(&present?/1)
    |> case do
      [] -> "Missing location"
      parts -> Enum.join(parts, ", ")
    end
  end

  defp availability_summary(member) do
    [member.timezone, time_value(member.work_start), time_value(member.work_end)]
    |> Enum.filter(&present?/1)
    |> case do
      [] -> "Missing availability"
      parts -> Enum.join(parts, " · ")
    end
  end

  defp time_value(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
  defp time_value(value) when is_binary(value), do: value
  defp time_value(_value), do: nil

  defp has_zonely_review_context?(member) do
    present?(member.location_country) or present?(member.location_label) or
      present?(member.timezone) or not is_nil(member.work_start) or not is_nil(member.work_end)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end

defmodule ZonelyWeb.PacketController do
  use ZonelyWeb, :controller

  alias Zonely.Accounts
  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Geography

  @created_owner_session_key "zonely_packet_created_owner_token"
  @created_invite_session_key "zonely_packet_created_invite_token"
  @owner_session_key "zonely_packet_owner_tokens_by_invite"
  @submission_session_key "zonely_packet_submission_tokens_by_invite"

  def new(%{request_path: "/packets/new"} = conn, _params) do
    redirect(conn, to: legacy_team_invite_path(conn))
  end

  def new(conn, params) do
    html(conn, new_packet_html(nil, target_team_from_params(params)))
  end

  def create(conn, %{"packet" => packet_params}) do
    case Drafts.create_team_draft(packet_attrs(packet_params)) do
      {:ok, %{owner_token: owner_token, invite_token: invite_token}} ->
        conn
        |> put_packet_owner_token(invite_token, owner_token)
        |> put_latest_packet_tokens(owner_token, invite_token)
        |> redirect(to: ~p"/team-invites/created")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> html(
          new_packet_html(
            "Team invite name is required.",
            target_team_from_packet_params(packet_params)
          )
        )
    end
  end

  def created(%{request_path: "/packets/created"} = conn, _params) do
    redirect(conn, to: legacy_team_invite_path(conn))
  end

  def created(conn, _params) do
    with owner_token when is_binary(owner_token) <- get_latest_packet_owner_token(conn),
         invite_token when is_binary(invite_token) <- get_latest_packet_invite_token(conn),
         %TeamDraft{} = draft <- Drafts.get_draft_by_owner_token(owner_token),
         true <- Drafts.owner_token_matches?(draft, owner_token),
         true <- Drafts.get_draft_by_invite_token(invite_token) == draft do
      invite_path = ~p"/team-invites/invite/#{invite_token}"
      invite_url = packet_invite_url(conn, invite_path)

      html(conn, created_packet_html(draft, invite_token, invite_path, invite_url))
    else
      _error -> packet_unavailable(conn)
    end
  end

  def review(%{request_path: "/packets/review/" <> _token} = conn, _params) do
    redirect(conn, to: legacy_team_invite_path(conn))
  end

  def review(conn, %{"invite_token" => invite_token}) do
    with %TeamDraft{} = draft <- Drafts.get_draft_by_invite_token(invite_token),
         owner_token when is_binary(owner_token) <- get_packet_owner_token(conn, invite_token),
         true <- Drafts.owner_token_matches?(draft, owner_token) do
      case draft.status do
        :draft ->
          html(conn, owner_review_html(draft, invite_token, Drafts.packet_review_summary(draft)))

        :published ->
          html(
            conn,
            published_review_html(draft, invite_token, Drafts.packet_review_summary(draft))
          )

        _status ->
          review_unavailable(conn)
      end
    else
      _error -> review_unavailable(conn)
    end
  end

  def review_member(conn, %{
        "invite_token" => invite_token,
        "member_id" => member_id,
        "review" => review_params
      }) do
    with %TeamDraft{} = draft <- Drafts.get_open_packet_by_invite_token(invite_token),
         owner_token when is_binary(owner_token) <- get_packet_owner_token(conn, invite_token),
         {:ok, review_status} <- review_status(Map.get(review_params, "status")),
         {:ok, _member} <-
           Drafts.review_packet_member(draft, owner_token, member_id, review_status) do
      conn
      |> put_flash(:info, review_flash(review_status))
      |> redirect(to: ~p"/team-invites/review/#{invite_token}")
    else
      _error -> review_unavailable(conn)
    end
  end

  def review_member(conn, _params), do: review_unavailable(conn)

  def publish(conn, %{"invite_token" => invite_token}) do
    with %TeamDraft{} = draft <- Drafts.get_draft_by_invite_token(invite_token),
         owner_token when is_binary(owner_token) <- get_packet_owner_token(conn, invite_token),
         true <- Drafts.owner_token_matches?(draft, owner_token) do
      case Drafts.publish_packet(draft, owner_token) do
        {:ok, result} ->
          conn
          |> put_flash(:info, "Team invite published to the map.")
          |> redirect(to: team_map_path(result.team))

        {:error, {:incomplete_members, _members}} ->
          conn
          |> put_status(:unprocessable_entity)
          |> html(
            owner_review_html(
              draft,
              invite_token,
              Drafts.packet_review_summary(draft),
              "Complete or exclude incomplete accepted entries before publishing."
            )
          )

        {:error, _reason} ->
          review_unavailable(conn)
      end
    else
      _error -> review_unavailable(conn)
    end
  end

  def invite(%{request_path: "/packets/invite/" <> _token} = conn, _params) do
    redirect(conn, to: legacy_team_invite_path(conn))
  end

  def invite(conn, %{"invite_token" => invite_token}) do
    case Drafts.get_draft_by_invite_token(invite_token) do
      %TeamDraft{status: :draft} = draft ->
        submission = own_submission(conn, draft, invite_token)
        html(conn, invite_html(draft, invite_token, submission))

      %TeamDraft{status: :published} = draft ->
        html(conn, published_invite_html(draft, Drafts.packet_review_summary(draft)))

      nil ->
        packet_unavailable(conn)

      %TeamDraft{} ->
        packet_unavailable(conn)
    end
  end

  def submit(conn, %{"invite_token" => invite_token, "submission" => submission_params}) do
    case get_or_create_submission(conn, invite_token, submission_params) do
      {:ok, conn, _member} ->
        conn
        |> put_flash(:info, "Your invite submission was saved.")
        |> redirect(to: ~p"/team-invites/invite/#{invite_token}")

      {:error, :invalid_invite_token} ->
        packet_unavailable(conn)

      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> html(packet_submission_error_html(invite_token))
    end
  end

  def submit(conn, %{"invite_token" => invite_token}) do
    conn
    |> put_status(:unprocessable_entity)
    |> html(packet_submission_error_html(invite_token))
  end

  defp get_or_create_submission(conn, invite_token, submission_params) do
    submission_token = get_submission_token(conn, invite_token)

    case submission_token do
      token when is_binary(token) ->
        case Drafts.update_packet_submission(invite_token, token, submission_params) do
          {:ok, member} -> {:ok, conn, member}
          {:error, :not_found} -> create_submission(conn, invite_token, submission_params)
          error -> error
        end

      _token ->
        create_submission(conn, invite_token, submission_params)
    end
  end

  defp create_submission(conn, invite_token, submission_params) do
    case Drafts.create_packet_submission(invite_token, submission_params) do
      {:ok, %{member: member, submission_token: submission_token}} ->
        {:ok, put_submission_token(conn, invite_token, submission_token), member}

      error ->
        error
    end
  end

  defp own_submission(conn, %TeamDraft{} = draft, invite_token) do
    case get_submission_token(conn, invite_token) do
      token when is_binary(token) -> Drafts.get_member_by_submission_token(draft, token)
      _token -> nil
    end
  end

  defp put_latest_packet_tokens(conn, owner_token, invite_token) do
    conn
    |> put_session(@created_owner_session_key, owner_token)
    |> put_session(@created_invite_session_key, invite_token)
  end

  defp get_latest_packet_owner_token(conn) do
    get_session(conn, @created_owner_session_key)
  end

  defp get_latest_packet_invite_token(conn) do
    get_session(conn, @created_invite_session_key)
  end

  defp put_packet_owner_token(conn, invite_token, owner_token) do
    tokens =
      conn
      |> get_session(@owner_session_key, %{})
      |> normalize_tokens()
      |> Map.put(invite_token, owner_token)

    put_session(conn, @owner_session_key, tokens)
  end

  defp get_packet_owner_token(conn, invite_token) do
    conn
    |> get_session(@owner_session_key, %{})
    |> normalize_tokens()
    |> Map.get(invite_token)
  end

  defp put_submission_token(conn, invite_token, submission_token) do
    tokens =
      conn
      |> get_session(@submission_session_key, %{})
      |> normalize_tokens()
      |> Map.put(invite_token, submission_token)

    put_session(conn, @submission_session_key, tokens)
  end

  defp get_submission_token(conn, invite_token) do
    conn
    |> get_session(@submission_session_key, %{})
    |> normalize_tokens()
    |> Map.get(invite_token)
  end

  defp normalize_tokens(tokens) when is_map(tokens) do
    Map.new(tokens, fn {key, token} -> {to_string(key), token} end)
  end

  defp normalize_tokens(_tokens), do: %{}

  defp packet_attrs(packet_params) do
    attrs = %{
      name: Map.get(packet_params, "name"),
      source_kind: "zonely_packet"
    }

    case target_team_from_packet_params(packet_params) do
      nil -> attrs
      team -> Map.put(attrs, :published_team_id, team.id)
    end
  end

  defp target_team_from_params(%{"team_id" => team_id}), do: target_team_from_id(team_id)
  defp target_team_from_params(_params), do: nil

  defp target_team_from_packet_params(%{"published_team_id" => team_id}) do
    target_team_from_id(team_id)
  end

  defp target_team_from_packet_params(_params), do: nil

  defp target_team_from_id(team_id) when is_binary(team_id), do: Accounts.get_team(team_id)
  defp target_team_from_id(_team_id), do: nil

  defp legacy_team_invite_path(conn) do
    path = String.replace_prefix(conn.request_path, "/packets", "/team-invites")

    case conn.query_string do
      "" -> path
      query_string -> path <> "?" <> query_string
    end
  end

  defp packet_unavailable(conn) do
    conn
    |> put_status(:not_found)
    |> html(
      page_html(
        "Team invite unavailable",
        """
        <main id="packet-unavailable" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
          <section class="mx-auto max-w-xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
            <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team invite</p>
            <h1 class="mt-3 text-3xl font-semibold tracking-tight">Team invite unavailable</h1>
            <p class="mt-3 text-[#5F6B73]">The link may be invalid, expired, or no longer accepting submissions.</p>
          </section>
        </main>
        """
      )
    )
  end

  defp review_unavailable(conn) do
    conn
    |> put_status(:not_found)
    |> html(
      page_html(
        "Team invite review unavailable",
        """
        <main id="packet-review-unavailable" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
          <section class="mx-auto max-w-xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
            <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team invite review</p>
            <h1 class="mt-3 text-3xl font-semibold tracking-tight">Team invite review unavailable</h1>
            <p class="mt-3 text-[#5F6B73]">The owner review link is unavailable from this browser session.</p>
          </section>
        </main>
        """
      )
    )
  end

  defp new_packet_html(error, target_team) do
    page_html(
      "Create team invite",
      """
      <main id="packet-create" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team invite</p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">Create a team invite</h1>
        <p class="mt-2 text-sm text-[#5F6B73]">Invite teammates to add their location and work hours before you publish the roster to the map.</p>
        #{error_html(error)}
        <form id="packet-create-form" action="/team-invites" method="post" class="mt-6 space-y-4">
          <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
          #{target_team_input_html(target_team)}
          <label for="packet-name" class="block text-sm font-semibold text-[#364148]">Team name</label>
          <input id="packet-name" class="min-h-12 w-full rounded-xl border border-[rgba(22,26,29,0.14)] bg-white px-3 text-base outline-none transition focus:border-[#1F8A70] focus:ring-4 focus:ring-[#1F8A70]/10" name="packet[name]" type="text" required value="#{packet_name_value(target_team)}" />
          <button id="packet-create-submit" class="inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white transition hover:bg-[#176f5c] active:translate-y-px" type="submit">Create invite</button>
        </form>
      </section>
      </main>
      """
    )
  end

  defp created_packet_html(%TeamDraft{} = draft, invite_token, invite_path, invite_url) do
    page_html(
      "Team invite ready",
      """
      <main id="packet-created" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-2xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Invite ready</p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">#{escape(draft.name)}</h1>
        <p class="mt-3 text-[#5F6B73]">Share this team invite link with teammates. Each teammate can add their own map profile for owner review.</p>
        <div class="mt-5 flex flex-col gap-2 sm:flex-row">
          <a id="packet-invite-link" class="min-w-0 flex-1 overflow-x-auto rounded-xl border border-[rgba(22,26,29,0.10)] bg-[#EEF2EF] px-3 py-2 font-mono text-sm text-[#161A1D] no-underline transition hover:border-[#1F8A70]/50 hover:bg-[#E2ECE7]" href="#{escape(invite_url)}" data-invite-path="#{escape(invite_path)}">#{escape(invite_url)}</a>
          <button id="packet-invite-copy" class="inline-flex min-h-11 items-center justify-center gap-2 rounded-full border border-[rgba(31,138,112,0.22)] bg-white/80 px-4 py-2 text-sm font-semibold text-[#1F8A70] transition hover:border-[#1F8A70]/40 hover:bg-white" type="button" data-clipboard-text="#{escape(invite_url)}" data-copy-success-text="Copied">
            <span class="hero-clipboard h-4 w-4" aria-hidden="true"></span>
            <span data-copy-label>Copy</span>
          </button>
        </div>
        <p class="mt-5"><a id="packet-owner-review-link" class="inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white no-underline transition hover:bg-[#176f5c]" href="/team-invites/review/#{escape(invite_token)}">Review submissions</a></p>
      </section>
      </main>
      """
    )
  end

  defp owner_review_html(%TeamDraft{} = draft, invite_token, summary, publish_error \\ nil) do
    page_html(
      "Team invite review",
      """
      <main id="packet-owner-review" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-4xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team invite review</p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">#{escape(draft.name)}</h1>
        <p id="packet-owner-review-context" class="mt-3 text-[#5F6B73]">Review each teammate submission before publishing. Accepted entries stay in the roster; pending, rejected, and excluded entries are visibly separate.</p>
        #{publish_error_html(publish_error)}
        #{publish_action_html(invite_token, summary)}
        #{review_section_html(invite_token, "owner-review-pending", "Pending submissions", Map.fetch!(summary, :pending))}
        #{review_section_html(invite_token, "owner-review-accepted", "Accepted draft roster", Map.fetch!(summary, :accepted))}
        #{review_section_html(invite_token, "owner-review-rejected", "Rejected submissions", Map.fetch!(summary, :rejected))}
        #{review_section_html(invite_token, "owner-review-excluded", "Excluded before publish", Map.fetch!(summary, :excluded))}
        #{review_section_html(invite_token, "owner-review-published", "Published roster", Map.fetch!(summary, :published))}
      </section>
      </main>
      """
    )
  end

  defp published_review_html(%TeamDraft{} = draft, invite_token, summary) do
    page_html(
      "Published team invite",
      """
      <main id="packet-published-review" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-4xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Published team invite</p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">#{escape(draft.name)}</h1>
        <p id="packet-published-context" class="mt-3 text-[#5F6B73]">Team invite already published. Reopening this owner review link resumes the existing published roster without creating another team, person, membership, or marker.</p>
        <p class="mt-5"><a id="packet-published-map-link" class="inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white no-underline transition hover:bg-[#176f5c]" href="#{escape(team_map_path(draft))}">Open published team map</a></p>
        #{review_section_html(invite_token, "owner-review-published", "Published roster", Map.fetch!(summary, :published))}
      </section>
      </main>
      """
    )
  end

  defp publish_action_html(invite_token, summary) do
    accepted_count = summary |> Map.fetch!(:accepted) |> length()

    """
    <section id="packet-publish-panel" class="mt-6 rounded-2xl border border-[#1F8A70]/20 bg-[#1F8A70]/10 p-4">
      <h2>Publish reviewed roster</h2>
      <p>Only accepted complete entries publish. Pending, rejected, and excluded entries stay out of the map.</p>
      <form id="packet-publish-form" action="/team-invites/review/#{escape(invite_token)}/publish" method="post">
        <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
        <button id="packet-publish-submit" class="mt-3 inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white transition hover:bg-[#176f5c]" type="submit">Publish #{accepted_count} accepted entries</button>
      </form>
    </section>
    """
  end

  defp publish_error_html(nil), do: ""

  defp publish_error_html(error) do
    ~s(<p id="packet-publish-error" class="mt-4 rounded-xl border border-[#B9822E]/30 bg-[#B9822E]/10 px-3 py-2 text-sm text-[#5F3D13]">#{escape(error)}</p>)
  end

  defp review_section_html(invite_token, id, title, members) do
    """
    <section id="#{id}" class="mt-6 border-t border-[rgba(22,26,29,0.10)] pt-4">
      <h2 class="text-xl font-semibold">#{title}</h2>
      #{review_members_html(invite_token, members)}
    </section>
    """
  end

  defp review_members_html(_invite_token, []),
    do: ~s(<p class="review-empty mt-3 text-sm text-[#5F6B73]">No entries in this state.</p>)

  defp review_members_html(invite_token, members) do
    members
    |> Enum.map(&review_member_html(invite_token, &1))
    |> Enum.join("")
  end

  defp review_member_html(invite_token, %TeamDraftMember{} = member) do
    """
    <article id="review-member-#{escape(member.id)}" data-review-status="#{member.review_status}" class="mt-3 rounded-2xl border border-[rgba(22,26,29,0.10)] bg-white/80 p-4">
      <h3 class="text-lg font-semibold">#{escape(member.display_name)}</h3>
      <p class="text-sm text-[#5F6B73]">#{escape(member.role)}</p>
      <dl class="mt-3 grid gap-2 text-sm sm:grid-cols-2">
        <dt>Location</dt><dd>#{escape(member.location_label)} #{escape(member.location_country)}</dd>
        <dt>Timezone</dt><dd>#{escape(member.timezone)}</dd>
        <dt>Work hours</dt><dd>#{escape(time_value(member, :work_start))}–#{escape(time_value(member, :work_end))}</dd>
        <dt>Completion</dt><dd>#{escape(member.completion_status)}</dd>
        <dt>Review state</dt><dd>#{escape(member.review_status)}</dd>
      </dl>
      #{review_actions_html(invite_token, member)}
    </article>
    """
  end

  defp review_actions_html(invite_token, %TeamDraftMember{review_status: :pending} = member) do
    """
    <form id="review-actions-#{escape(member.id)}" class="mt-4 flex flex-wrap gap-2" action="/team-invites/review/#{escape(invite_token)}/#{escape(member.id)}" method="post">
      <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
      <button id="review-accept-#{escape(member.id)}" class="rounded-full bg-[#1F8A70] px-4 py-2 text-sm font-semibold text-white" name="review[status]" value="accepted" type="submit">Accept into roster</button>
      <button id="review-reject-#{escape(member.id)}" class="rounded-full border border-[rgba(22,26,29,0.16)] px-4 py-2 text-sm font-semibold text-[#364148]" name="review[status]" value="rejected" type="submit">Reject submission</button>
      <button id="review-pending-#{escape(member.id)}" class="rounded-full border border-[rgba(22,26,29,0.16)] px-4 py-2 text-sm font-semibold text-[#364148]" name="review[status]" value="pending" type="submit">Leave pending</button>
    </form>
    """
  end

  defp review_actions_html(invite_token, %TeamDraftMember{review_status: :accepted} = member) do
    """
    <form id="review-actions-#{escape(member.id)}" class="mt-4 flex flex-wrap gap-2" action="/team-invites/review/#{escape(invite_token)}/#{escape(member.id)}" method="post">
      <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
      <button id="review-exclude-#{escape(member.id)}" class="rounded-full border border-[rgba(22,26,29,0.16)] px-4 py-2 text-sm font-semibold text-[#364148]" name="review[status]" value="excluded" type="submit">Exclude before publish</button>
    </form>
    """
  end

  defp review_actions_html(_invite_token, _member), do: ""

  defp invite_html(%TeamDraft{} = draft, invite_token, submission) do
    page_html(
      "Team invite",
      """
      <main id="packet-invite" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-2xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team invite</p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">#{escape(draft.name)}</h1>
        <p id="packet-public-context" class="mt-3 text-[#5F6B73]">Add your own map profile as a pending submission. Owner review controls are not available from this invite.</p>
        #{own_submission_html(submission)}
        <form id="packet-submission-form" class="mt-6 grid gap-4" action="/team-invites/invite/#{escape(invite_token)}/submission" method="post">
          <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
          <label for="submission-display-name">Display name</label>
          <input id="submission-display-name" class="min-h-11 rounded-xl border border-[rgba(22,26,29,0.14)] bg-white px-3 outline-none focus:border-[#1F8A70] focus:ring-4 focus:ring-[#1F8A70]/10" name="submission[display_name]" type="text" required value="#{field_value(submission, :display_name)}" />
          <label for="submission-pronouns">Pronouns</label>
          <input id="submission-pronouns" class="min-h-11 rounded-xl border border-[rgba(22,26,29,0.14)] bg-white px-3 outline-none focus:border-[#1F8A70] focus:ring-4 focus:ring-[#1F8A70]/10" name="submission[pronouns]" type="text" value="#{field_value(submission, :pronouns)}" />
          #{country_field_html(submission)}
          <label for="submission-location-label">City, region, or place label</label>
          <input id="submission-location-label" class="min-h-11 rounded-xl border border-[rgba(22,26,29,0.14)] bg-white px-3 outline-none focus:border-[#1F8A70] focus:ring-4 focus:ring-[#1F8A70]/10" name="submission[location_label]" type="text" value="#{field_value(submission, :location_label)}" />
          #{timezone_field_html(submission)}
          #{work_window_range_html(submission)}
          <button id="packet-submission-submit" class="inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white transition hover:bg-[#176f5c]" type="submit">Save submission</button>
        </form>
      </section>
      </main>
      """
    )
  end

  defp published_invite_html(%TeamDraft{} = draft, summary) do
    page_html(
      "Published team invite",
      """
      <main id="packet-published-invite" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-2xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Published team invite</p>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">#{escape(draft.name)}</h1>
        <p id="packet-published-invite-context" class="mt-3 text-[#5F6B73]">Team invite already published. This invite is no longer accepting submissions; use the existing team map instead.</p>
        <p class="mt-5"><a id="packet-published-map-link" class="inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white no-underline transition hover:bg-[#176f5c]" href="#{escape(team_map_path(draft))}">Open published team map</a></p>
        <section id="packet-published-roster" class="mt-6 border-t border-[rgba(22,26,29,0.10)] pt-4">
          <h2 class="text-xl font-semibold">Published roster</h2>
          #{published_member_names_html(Map.fetch!(summary, :published))}
        </section>
      </section>
      </main>
      """
    )
  end

  defp published_member_names_html([]),
    do: ~s(<p class="review-empty mt-3 text-sm text-[#5F6B73]">No published entries.</p>)

  defp published_member_names_html(members) do
    members
    |> Enum.map(fn %TeamDraftMember{} = member ->
      """
      <p class="published-member-name mt-3 rounded-xl border border-[rgba(22,26,29,0.10)] bg-white/80 px-3 py-2">#{escape(member.display_name)}</p>
      """
    end)
    |> Enum.join("")
  end

  defp own_submission_html(%TeamDraftMember{} = member) do
    """
    <section id="own-pending-submission" class="mt-5 rounded-2xl border border-[rgba(22,26,29,0.10)] bg-[#EEF2EF] p-4">
      <h2 class="text-lg font-semibold">Your pending submission</h2>
      <p>#{escape(member.display_name)}</p>
    </section>
    """
  end

  defp own_submission_html(_submission), do: ""

  defp country_field_html(submission) do
    selected_code = field_value(submission, :location_country)

    """
    <label for="submission-location-country">Country</label>
    <div class="progressive-combobox" data-progressive-combobox>
      <input id="submission-location-country-value" name="submission[location_country]" type="hidden" value="#{selected_code}" data-combobox-value />
      <input id="submission-location-country" class="progressive-combobox-input min-h-11 rounded-xl border border-[rgba(22,26,29,0.14)] bg-white px-3 outline-none focus:border-[#1F8A70] focus:ring-4 focus:ring-[#1F8A70]/10" type="text" autocomplete="country-name" placeholder="Type country" required value="#{country_field_value(submission)}" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="submission-location-country-options" data-combobox-input />
      <ul id="submission-location-country-options" class="progressive-combobox-list" role="listbox" hidden data-combobox-list>
      #{country_option_html()}
      </ul>
    </div>
    """
  end

  defp country_option_html do
    Geography.country_options()
    |> Enum.map(fn %{code: code, name: name} ->
      """
      <li id="submission-location-country-option-#{escape(code)}" class="progressive-combobox-option" role="option" tabindex="-1" data-combobox-option data-value="#{escape(code)}" data-label="#{escape(name)}" data-search="#{escape(name)} #{escape(code)}">
        <span>#{escape(name)}</span>
        <small>#{escape(code)}</small>
      </li>
      """
    end)
    |> Enum.join("")
  end

  defp timezone_field_html(submission) do
    """
    <label for="submission-timezone">Timezone</label>
    <div class="progressive-combobox" data-progressive-combobox>
      <input id="submission-timezone" class="progressive-combobox-input min-h-11 rounded-xl border border-[rgba(22,26,29,0.14)] bg-white px-3 font-mono text-sm outline-none focus:border-[#1F8A70] focus:ring-4 focus:ring-[#1F8A70]/10" name="submission[timezone]" type="text" autocomplete="off" placeholder="Type timezone" required value="#{field_value(submission, :timezone)}" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="submission-timezone-options" data-combobox-input />
      <ul id="submission-timezone-options" class="progressive-combobox-list" role="listbox" hidden data-combobox-list>
      #{timezone_option_html()}
      </ul>
    </div>
    """
  end

  defp timezone_option_html do
    Geography.timezone_options()
    |> Enum.map(fn timezone ->
      """
      <li id="submission-timezone-option-#{option_id(timezone)}" class="progressive-combobox-option is-mono" role="option" tabindex="-1" data-combobox-option data-value="#{escape(timezone)}" data-label="#{escape(timezone)}" data-search="#{escape(timezone)}">
        <span>#{escape(timezone)}</span>
      </li>
      """
    end)
    |> Enum.join("")
  end

  defp option_id(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> escape()
  end

  defp work_window_range_html(submission) do
    start_minutes = work_minutes_value(submission, :work_start, 540)
    end_minutes = work_minutes_value(submission, :work_end, 1020)
    fill_left = work_window_percent(start_minutes)
    fill_right = 100 - work_window_percent(end_minutes)

    """
    <div id="submission-work-window" class="work-window-range" data-work-window-range data-min-gap="30">
      <div class="work-window-range-header">
        <label id="submission-work-window-label" for="submission-work-start-minutes">Working hours</label>
        <output id="submission-work-window-output" class="work-window-range-output" for="submission-work-start-minutes submission-work-end-minutes" data-work-window-output>
          #{minutes_label(start_minutes)}–#{minutes_label(end_minutes)}
        </output>
      </div>
      <div class="work-window-range-control" data-work-window-track>
        <span class="work-window-range-base" aria-hidden="true"></span>
        <span class="work-window-range-fill" aria-hidden="true" data-work-window-fill style="left: #{fill_left}%; right: #{fill_right}%;"></span>
        <input
          id="submission-work-start-minutes"
          class="work-window-range-input"
          name="submission[work_start_minutes]"
          type="range"
          min="0"
          max="1410"
          step="30"
          value="#{start_minutes}"
          data-work-window-handle="start"
          aria-label="Work start"
          aria-describedby="submission-work-window-label submission-work-window-output"
          aria-valuetext="#{minutes_label(start_minutes)}"
        />
        <input
          id="submission-work-end-minutes"
          class="work-window-range-input"
          name="submission[work_end_minutes]"
          type="range"
          min="0"
          max="1410"
          step="30"
          value="#{end_minutes}"
          data-work-window-handle="end"
          aria-label="Work end"
          aria-describedby="submission-work-window-label submission-work-window-output"
          aria-valuetext="#{minutes_label(end_minutes)}"
        />
      </div>
      <div class="work-window-range-scale" aria-hidden="true">
        <span>00:00</span>
        <span>12:00</span>
        <span>23:30</span>
      </div>
    </div>
    """
  end

  defp country_field_value(%TeamDraftMember{location_country: country}) do
    country
    |> Geography.country_display_value()
    |> escape()
  end

  defp country_field_value(_submission), do: ""

  defp work_minutes_value(%TeamDraftMember{} = member, field, default_minutes) do
    case Map.get(member, field) do
      %Time{} = time -> time.hour * 60 + time.minute
      _value -> default_minutes
    end
  end

  defp work_minutes_value(_submission, _field, default_minutes), do: default_minutes

  defp minutes_label(minutes) do
    hour = minutes |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    minute = minutes |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hour}:#{minute}"
  end

  defp work_window_percent(minutes) do
    minutes
    |> max(0)
    |> min(1410)
    |> Kernel./(1410)
    |> Kernel.*(100)
    |> Float.round(3)
  end

  defp packet_submission_error_html(invite_token) do
    page_html(
      "Invite submission error",
      """
      <main id="packet-submission-error" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
        <section class="mx-auto max-w-xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6 shadow-[0_22px_70px_rgba(22,26,29,0.14)]">
          <h1 class="text-3xl font-semibold tracking-tight">We could not save your invite submission</h1>
          <p class="mt-3 text-[#5F6B73]">Check required fields and try the invite again.</p>
          <a class="mt-5 inline-flex min-h-11 items-center justify-center rounded-full bg-[#1F8A70] px-5 py-2 text-sm font-semibold text-white no-underline transition hover:bg-[#176f5c]" href="/team-invites/invite/#{escape(invite_token)}">Return to team invite</a>
        </section>
      </main>
      """
    )
  end

  defp packet_invite_url(conn, invite_path) do
    packet_invite_origin(conn) <> invite_path
  end

  defp packet_invite_origin(conn) do
    configured_origin = Application.get_env(:zonely, :packet_invite_origin)

    cond do
      local_request?(conn) ->
        request_origin(conn)

      is_binary(configured_origin) and configured_origin != "" ->
        String.trim_trailing(configured_origin, "/")

      true ->
        request_origin(conn)
    end
  end

  defp local_request?(%{host: host}) when is_binary(host) do
    host in ["localhost", "127.0.0.1", "::1"] or String.ends_with?(host, ".localhost")
  end

  defp local_request?(_conn), do: false

  defp request_origin(conn) do
    scheme = conn.scheme |> to_string() |> String.trim_leading(":")
    "#{scheme}://#{conn.host}#{request_port(scheme, conn.port)}"
  end

  defp request_port("http", 80), do: ""
  defp request_port("https", 443), do: ""
  defp request_port(_scheme, nil), do: ""
  defp request_port(_scheme, port), do: ":#{port}"

  defp page_html(title, body) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="csrf-token" content="#{csrf_token()}" />
        <title>#{escape(title)} · Zonely</title>
        <link rel="icon" href="#{~p"/favicon.ico"}" sizes="any" />
        <link rel="icon" type="image/svg+xml" href="#{~p"/favicon.svg"}" />
        <link rel="stylesheet" href="#{~p"/assets/app.css"}" />
        <script defer type="text/javascript" src="#{~p"/assets/app.js"}"></script>
      </head>
      <body class="m-0 bg-[#F7F8F6] text-[#161A1D] antialiased">
        #{body}
      </body>
    </html>
    """
  end

  defp error_html(nil), do: ""

  defp error_html(error) do
    ~s(<p id="packet-create-error" class="mt-4 rounded-xl border border-[#B9822E]/30 bg-[#B9822E]/10 px-3 py-2 text-sm text-[#5F3D13]">#{escape(error)}</p>)
  end

  defp target_team_input_html(nil), do: ""

  defp target_team_input_html(team) do
    ~s(<input type="hidden" name="packet[published_team_id]" value="#{escape(team.id)}" />)
  end

  defp packet_name_value(nil), do: ""
  defp packet_name_value(team), do: escape(team.name)

  defp team_map_path(%{published_team_id: team_id}) when is_binary(team_id),
    do: ~p"/?team=#{team_id}"

  defp team_map_path(%{id: team_id}) when is_binary(team_id), do: ~p"/?team=#{team_id}"
  defp team_map_path(_value), do: ~p"/"

  defp field_value(%TeamDraftMember{} = member, field), do: member |> Map.get(field) |> escape()
  defp field_value(_member, _field), do: ""

  defp time_value(%TeamDraftMember{} = member, field) do
    case Map.get(member, field) do
      %Time{} = time -> Calendar.strftime(time, "%H:%M")
      _value -> ""
    end
  end

  defp time_value(_member, _field), do: ""

  defp escape(nil), do: ""

  defp escape(value),
    do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp csrf_token, do: Plug.CSRFProtection.get_csrf_token()

  defp review_status("pending"), do: {:ok, :pending}
  defp review_status("accepted"), do: {:ok, :accepted}
  defp review_status("rejected"), do: {:ok, :rejected}
  defp review_status("excluded"), do: {:ok, :excluded}
  defp review_status(_status), do: {:error, :invalid_review_status}

  defp review_flash(:pending), do: "Submission left pending."
  defp review_flash(:accepted), do: "Submission accepted into the draft."
  defp review_flash(:rejected), do: "Submission rejected."
  defp review_flash(:excluded), do: "Accepted draft entry excluded from publish."
end

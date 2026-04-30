defmodule ZonelyWeb.PacketController do
  use ZonelyWeb, :controller

  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}

  @created_owner_session_key "zonely_packet_created_owner_token"
  @created_invite_session_key "zonely_packet_created_invite_token"
  @owner_session_key "zonely_packet_owner_tokens_by_invite"
  @submission_session_key "zonely_packet_submission_tokens_by_invite"

  def new(conn, _params) do
    html(conn, new_packet_html())
  end

  def create(conn, %{"packet" => packet_params}) do
    case Drafts.create_team_draft(%{
           name: Map.get(packet_params, "name"),
           source_kind: "zonely_packet"
         }) do
      {:ok, %{owner_token: owner_token, invite_token: invite_token}} ->
        conn
        |> put_packet_owner_token(invite_token, owner_token)
        |> put_latest_packet_tokens(owner_token, invite_token)
        |> redirect(to: ~p"/packets/created")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> html(new_packet_html("Packet name is required."))
    end
  end

  def created(conn, _params) do
    with owner_token when is_binary(owner_token) <- get_latest_packet_owner_token(conn),
         invite_token when is_binary(invite_token) <- get_latest_packet_invite_token(conn),
         %TeamDraft{} = draft <- Drafts.get_draft_by_owner_token(owner_token),
         true <- Drafts.owner_token_matches?(draft, owner_token),
         true <- Drafts.get_draft_by_invite_token(invite_token) == draft do
      invite_path = ~p"/packets/invite/#{invite_token}"
      invite_url = packet_invite_url(invite_path)

      html(conn, created_packet_html(draft, invite_token, invite_path, invite_url))
    else
      _error -> packet_unavailable(conn)
    end
  end

  def review(conn, %{"invite_token" => invite_token}) do
    with %TeamDraft{} = draft <- Drafts.get_open_packet_by_invite_token(invite_token),
         owner_token when is_binary(owner_token) <- get_packet_owner_token(conn, invite_token),
         true <- Drafts.owner_token_matches?(draft, owner_token) do
      html(conn, owner_review_html(draft, invite_token, Drafts.packet_review_summary(draft)))
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
      |> redirect(to: ~p"/packets/review/#{invite_token}")
    else
      _error -> review_unavailable(conn)
    end
  end

  def review_member(conn, _params), do: review_unavailable(conn)

  def invite(conn, %{"invite_token" => invite_token}) do
    case Drafts.get_open_packet_by_invite_token(invite_token) do
      %TeamDraft{} = draft ->
        submission = own_submission(conn, draft, invite_token)
        html(conn, invite_html(draft, invite_token, submission))

      nil ->
        packet_unavailable(conn)
    end
  end

  def submit(conn, %{"invite_token" => invite_token, "submission" => submission_params}) do
    case get_or_create_submission(conn, invite_token, submission_params) do
      {:ok, conn, _member} ->
        conn
        |> put_flash(:info, "Your pending packet submission was saved.")
        |> redirect(to: ~p"/packets/invite/#{invite_token}")

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

  defp packet_unavailable(conn) do
    conn
    |> put_status(:not_found)
    |> html("""
    <main id="packet-unavailable">
      <h1>Packet invite unavailable</h1>
      <p>The link may be invalid, expired, or no longer accepting submissions.</p>
    </main>
    """)
  end

  defp review_unavailable(conn) do
    conn
    |> put_status(:not_found)
    |> html("""
    <main id="packet-review-unavailable">
      <h1>Packet review unavailable</h1>
      <p>The owner review link is unavailable from this browser session.</p>
    </main>
    """)
  end

  defp new_packet_html(error \\ nil) do
    """
    <main id="packet-create" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team packet</p>
        <h1>Create a packet invite</h1>
        #{error_html(error)}
        <form id="packet-create-form" action="/packets" method="post">
          <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
          <label for="packet-name">Packet name</label>
          <input id="packet-name" name="packet[name]" type="text" required />
          <button id="packet-create-submit" type="submit">Create invite</button>
        </form>
      </section>
    </main>
    """
  end

  defp created_packet_html(%TeamDraft{} = draft, invite_token, invite_path, invite_url) do
    """
    <main id="packet-created" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-2xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Invite ready</p>
        <h1>#{escape(draft.name)}</h1>
        <p>Share this append-self packet link with teammates. The link uses an opaque invite token.</p>
        <p id="packet-invite-link" data-invite-path="#{escape(invite_path)}">#{escape(invite_url)}</p>
        <p><a id="packet-owner-review-link" href="/packets/review/#{escape(invite_token)}">Review pending submissions</a></p>
      </section>
    </main>
    """
  end

  defp owner_review_html(%TeamDraft{} = draft, invite_token, summary) do
    """
    <main id="packet-owner-review" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-4xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Owner packet review</p>
        <h1>#{escape(draft.name)}</h1>
        <p id="packet-owner-review-context">Review each teammate submission before publish. Accepted entries stay in the draft roster; pending, rejected, and excluded entries are visibly separate.</p>
        #{review_section_html(invite_token, "owner-review-pending", "Pending submissions", Map.fetch!(summary, :pending))}
        #{review_section_html(invite_token, "owner-review-accepted", "Accepted draft roster", Map.fetch!(summary, :accepted))}
        #{review_section_html(invite_token, "owner-review-rejected", "Rejected submissions", Map.fetch!(summary, :rejected))}
        #{review_section_html(invite_token, "owner-review-excluded", "Excluded before publish", Map.fetch!(summary, :excluded))}
      </section>
    </main>
    """
  end

  defp review_section_html(invite_token, id, title, members) do
    """
    <section id="#{id}" class="mt-6 border-t border-[rgba(22,26,29,0.10)] pt-4">
      <h2>#{title}</h2>
      #{review_members_html(invite_token, members)}
    </section>
    """
  end

  defp review_members_html(_invite_token, []),
    do: ~s(<p class="review-empty">No entries in this state.</p>)

  defp review_members_html(invite_token, members) do
    members
    |> Enum.map(&review_member_html(invite_token, &1))
    |> Enum.join("")
  end

  defp review_member_html(invite_token, %TeamDraftMember{} = member) do
    """
    <article id="review-member-#{escape(member.id)}" data-review-status="#{member.review_status}" class="py-4">
      <h3>#{escape(member.display_name)}</h3>
      <p>#{escape(member.role)}</p>
      <dl>
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
    <form id="review-actions-#{escape(member.id)}" action="/packets/review/#{escape(invite_token)}/#{escape(member.id)}" method="post">
      <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
      <button id="review-accept-#{escape(member.id)}" name="review[status]" value="accepted" type="submit">Accept into draft</button>
      <button id="review-reject-#{escape(member.id)}" name="review[status]" value="rejected" type="submit">Reject submission</button>
      <button id="review-pending-#{escape(member.id)}" name="review[status]" value="pending" type="submit">Leave pending</button>
    </form>
    """
  end

  defp review_actions_html(invite_token, %TeamDraftMember{review_status: :accepted} = member) do
    """
    <form id="review-actions-#{escape(member.id)}" action="/packets/review/#{escape(invite_token)}/#{escape(member.id)}" method="post">
      <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
      <button id="review-exclude-#{escape(member.id)}" name="review[status]" value="excluded" type="submit">Exclude before publish</button>
    </form>
    """
  end

  defp review_actions_html(_invite_token, _member), do: ""

  defp invite_html(%TeamDraft{} = draft, invite_token, submission) do
    """
    <main id="packet-invite" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-2xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Team packet invite</p>
        <h1>#{escape(draft.name)}</h1>
        <p id="packet-public-context">Add your own profile as a pending submission. Owner review controls are not available from this invite.</p>
        #{own_submission_html(submission)}
        <form id="packet-submission-form" action="/packets/invite/#{escape(invite_token)}/submission" method="post">
          <input type="hidden" name="_csrf_token" value="#{csrf_token()}" />
          <label for="submission-display-name">Display name</label>
          <input id="submission-display-name" name="submission[display_name]" type="text" required value="#{field_value(submission, :display_name)}" />
          <label for="submission-pronouns">Pronouns</label>
          <input id="submission-pronouns" name="submission[pronouns]" type="text" value="#{field_value(submission, :pronouns)}" />
          <label for="submission-location-country">Country</label>
          <input id="submission-location-country" name="submission[location_country]" type="text" maxlength="2" value="#{field_value(submission, :location_country)}" />
          <label for="submission-location-label">City or location label</label>
          <input id="submission-location-label" name="submission[location_label]" type="text" value="#{field_value(submission, :location_label)}" />
          <label for="submission-timezone">Timezone</label>
          <input id="submission-timezone" name="submission[timezone]" type="text" value="#{field_value(submission, :timezone)}" />
          <label for="submission-work-start">Work start</label>
          <input id="submission-work-start" name="submission[work_start]" type="time" value="#{time_value(submission, :work_start)}" />
          <label for="submission-work-end">Work end</label>
          <input id="submission-work-end" name="submission[work_end]" type="time" value="#{time_value(submission, :work_end)}" />
          <button id="packet-submission-submit" type="submit">Save pending submission</button>
        </form>
      </section>
    </main>
    """
  end

  defp own_submission_html(%TeamDraftMember{} = member) do
    """
    <section id="own-pending-submission">
      <h2>Your pending submission</h2>
      <p>#{escape(member.display_name)}</p>
    </section>
    """
  end

  defp own_submission_html(_submission), do: ""

  defp packet_submission_error_html(invite_token) do
    """
    <main id="packet-submission-error">
      <h1>We could not save your packet submission</h1>
      <p>Check required fields and try the invite again.</p>
      <a href="/packets/invite/#{escape(invite_token)}">Return to packet invite</a>
    </main>
    """
  end

  defp packet_invite_url(invite_path) do
    case Application.get_env(:zonely, :packet_invite_origin) do
      origin when is_binary(origin) and origin != "" ->
        origin
        |> String.trim_trailing("/")
        |> Kernel.<>(invite_path)

      _origin ->
        ZonelyWeb.Endpoint.url() <> invite_path
    end
  end

  defp error_html(nil), do: ""
  defp error_html(error), do: ~s(<p id="packet-create-error">#{escape(error)}</p>)

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

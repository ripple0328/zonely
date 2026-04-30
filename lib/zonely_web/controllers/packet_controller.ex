defmodule ZonelyWeb.PacketController do
  use ZonelyWeb, :controller

  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}

  @owner_session_key "zonely_packet_owner_tokens_by_draft"
  @invite_session_key "zonely_packet_invite_tokens_by_draft"
  @submission_session_key "zonely_packet_submission_tokens_by_invite"

  def new(conn, _params) do
    html(conn, new_packet_html())
  end

  def create(conn, %{"packet" => packet_params}) do
    case Drafts.create_team_draft(%{
           name: Map.get(packet_params, "name"),
           source_kind: "zonely_packet"
         }) do
      {:ok, %{draft: draft, owner_token: owner_token, invite_token: invite_token}} ->
        conn
        |> put_packet_owner_token(draft, owner_token)
        |> put_packet_invite_token(draft, invite_token)
        |> redirect(to: ~p"/packets/#{draft.id}/created")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> html(new_packet_html("Packet name is required."))
    end
  end

  def created(conn, %{"id" => id}) do
    with %TeamDraft{} = draft <- Zonely.Repo.get(TeamDraft, id),
         owner_token when is_binary(owner_token) <- get_packet_owner_token(conn, draft),
         true <- Drafts.owner_token_matches?(draft, owner_token),
         invite_token when is_binary(invite_token) <- get_packet_invite_token(conn, draft) do
      invite_path = ~p"/packets/invite/#{invite_token}"
      invite_url = url(~p"/packets/invite/#{invite_token}")

      html(conn, created_packet_html(draft, invite_path, invite_url))
    else
      _error -> packet_unavailable(conn)
    end
  end

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

  defp put_packet_owner_token(conn, draft, owner_token) do
    tokens =
      conn
      |> get_session(@owner_session_key, %{})
      |> normalize_tokens()
      |> Map.put(to_string(draft.id), owner_token)

    put_session(conn, @owner_session_key, tokens)
  end

  defp put_packet_invite_token(conn, draft, invite_token) do
    tokens =
      conn
      |> get_session(@invite_session_key, %{})
      |> normalize_tokens()
      |> Map.put(to_string(draft.id), invite_token)

    put_session(conn, @invite_session_key, tokens)
  end

  defp get_packet_invite_token(conn, draft) do
    conn
    |> get_session(@invite_session_key, %{})
    |> normalize_tokens()
    |> Map.get(to_string(draft.id))
  end

  defp get_packet_owner_token(conn, draft) do
    conn
    |> get_session(@owner_session_key, %{})
    |> normalize_tokens()
    |> Map.get(to_string(draft.id))
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

  defp created_packet_html(%TeamDraft{} = draft, invite_path, invite_url) do
    """
    <main id="packet-created" class="min-h-[100dvh] bg-[#F7F8F6] px-6 py-8 text-[#161A1D]">
      <section class="mx-auto max-w-2xl rounded-[20px] border border-[rgba(22,26,29,0.10)] bg-white/90 p-6">
        <p class="text-sm font-medium uppercase tracking-[0.18em] text-[#1F8A70]">Invite ready</p>
        <h1>#{escape(draft.name)}</h1>
        <p>Share this append-self packet link with teammates. The link uses an opaque invite token.</p>
        <p id="packet-invite-link" data-invite-path="#{escape(invite_path)}">#{escape(invite_url)}</p>
      </section>
    </main>
    """
  end

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
end

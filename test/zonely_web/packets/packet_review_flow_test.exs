defmodule ZonelyWeb.Packets.PacketReviewFlowTest do
  use ZonelyWeb.ConnCase, async: true

  alias Zonely.Drafts

  describe "owner review UI" do
    test "owner reviews pending submissions and reloads distinct lifecycle states", %{conn: conn} do
      create_conn =
        post(conn, ~p"/packets", %{
          "packet" => %{"name" => "Owner review team"}
        })

      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      created_html = html_response(created_conn, 200)

      assert created_html =~ ~s(id="packet-owner-review-link")

      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      invite_token = session_invite_token(created_conn, draft)

      {:ok, %{member: pending}} =
        Drafts.create_packet_submission(invite_token, %{
          display_name: "Mina Park",
          role: "Design",
          location_country: "KR",
          location_label: "Seoul",
          timezone: "Asia/Seoul",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        })

      review_conn = get(recycle(created_conn), ~p"/packets/review/#{invite_token}")
      review_html = html_response(review_conn, 200)

      assert review_html =~ ~s(id="packet-owner-review")
      assert review_html =~ ~s(id="owner-review-pending")
      assert review_html =~ "Mina Park"
      assert review_html =~ "Design"
      assert review_html =~ "Asia/Seoul"
      assert review_html =~ ~s(id="review-accept-#{pending.id}")
      assert review_html =~ ~s(id="review-reject-#{pending.id}")
      assert review_html =~ ~s(id="review-pending-#{pending.id}")

      accepted_conn =
        post(recycle(review_conn), ~p"/packets/review/#{invite_token}/#{pending.id}", %{
          "review" => %{"status" => "accepted"}
        })

      assert redirected_to(accepted_conn) == ~p"/packets/review/#{invite_token}"

      accepted_html =
        accepted_conn
        |> recycle()
        |> get(~p"/packets/review/#{invite_token}")
        |> html_response(200)

      assert accepted_html =~ ~s(id="owner-review-accepted")
      assert accepted_html =~ ~s(data-review-status="accepted")
      assert accepted_html =~ ~s(id="review-exclude-#{pending.id}")

      excluded_conn =
        post(recycle(accepted_conn), ~p"/packets/review/#{invite_token}/#{pending.id}", %{
          "review" => %{"status" => "excluded"}
        })

      excluded_html =
        excluded_conn
        |> recycle()
        |> get(~p"/packets/review/#{invite_token}")
        |> html_response(200)

      assert excluded_html =~ ~s(id="owner-review-excluded")
      assert excluded_html =~ ~s(data-review-status="excluded")
    end

    test "owner can reject a pending submission without accepting it", %{conn: conn} do
      create_conn = post(conn, ~p"/packets", %{"packet" => %{"name" => "Reject review team"}})
      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      invite_token = session_invite_token(created_conn, draft)

      {:ok, %{member: member}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Rejected Recipient"})

      rejected_conn =
        post(recycle(created_conn), ~p"/packets/review/#{invite_token}/#{member.id}", %{
          "review" => %{"status" => "rejected"}
        })

      rejected_html =
        rejected_conn
        |> recycle()
        |> get(~p"/packets/review/#{invite_token}")
        |> html_response(200)

      assert rejected_html =~ ~s(id="owner-review-rejected")
      assert rejected_html =~ "Rejected Recipient"
      refute rejected_html =~ ~s(id="review-exclude-#{member.id}")
    end

    test "forged owner review posts cannot skip or revive lifecycle states", %{conn: conn} do
      create_conn = post(conn, ~p"/packets", %{"packet" => %{"name" => "Forged review team"}})
      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      invite_token = session_invite_token(created_conn, draft)

      {:ok, %{member: pending}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Forged Pending"})

      direct_exclude_conn =
        post(recycle(created_conn), ~p"/packets/review/#{invite_token}/#{pending.id}", %{
          "review" => %{"status" => "excluded"}
        })

      assert html_response(direct_exclude_conn, 404) =~ "Packet review unavailable"
      assert [%{review_status: :pending}] = Drafts.list_draft_members(draft)

      rejected_conn =
        post(recycle(created_conn), ~p"/packets/review/#{invite_token}/#{pending.id}", %{
          "review" => %{"status" => "rejected"}
        })

      assert redirected_to(rejected_conn) == ~p"/packets/review/#{invite_token}"

      direct_accept_conn =
        post(recycle(rejected_conn), ~p"/packets/review/#{invite_token}/#{pending.id}", %{
          "review" => %{"status" => "accepted"}
        })

      assert html_response(direct_accept_conn, 404) =~ "Packet review unavailable"
      assert [%{review_status: :rejected}] = Drafts.list_draft_members(draft)
    end

    test "non-owner cannot see or use review controls", %{conn: conn} do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Non-owner review team"})

      {:ok, %{member: member}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Protected Recipient"})

      unavailable_html =
        conn
        |> get(~p"/packets/review/#{invite_token}")
        |> html_response(404)

      assert unavailable_html =~ "Packet review unavailable"
      refute unavailable_html =~ "Protected Recipient"
      refute unavailable_html =~ "Accept into draft"

      forbidden_html =
        conn
        |> post(~p"/packets/review/#{invite_token}/#{member.id}", %{
          "review" => %{"status" => "accepted"}
        })
        |> html_response(404)

      assert forbidden_html =~ "Packet review unavailable"
      assert [%{review_status: :pending}] = Drafts.list_draft_members(draft)
    end
  end

  defp session_invite_token(conn, draft) do
    invite_token = Plug.Conn.get_session(conn, "zonely_packet_created_invite_token")

    assert Drafts.get_draft_by_invite_token(invite_token).id == draft.id

    invite_token
  end
end

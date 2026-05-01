defmodule ZonelyWeb.Packets.PacketReviewFlowTest do
  use ZonelyWeb.ConnCase, async: true

  alias Zonely.Drafts

  describe "owner review UI" do
    test "owner publishes accepted complete submissions into the normal map flow", %{conn: conn} do
      create_conn = post(conn, ~p"/packets", %{"packet" => %{"name" => "Map publish team"}})
      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      invite_token = session_invite_token(created_conn, draft)

      {:ok, %{member: accepted}} =
        Drafts.create_packet_submission(invite_token, %{
          display_name: "Mara Published",
          role: "Product Lead",
          location_country: "PT",
          location_label: "Lisbon",
          latitude: Decimal.new("38.7223"),
          longitude: Decimal.new("-9.1393"),
          timezone: "Europe/Lisbon",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        })

      {:ok, %{member: pending}} =
        Drafts.create_packet_submission(invite_token, %{
          display_name: "Pending Draft",
          location_country: "GB",
          location_label: "London",
          latitude: Decimal.new("51.5072"),
          longitude: Decimal.new("-0.1276"),
          timezone: "Europe/London",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        })

      {:ok, _accepted_member} =
        Drafts.review_packet_member(
          draft,
          Plug.Conn.get_session(created_conn, "zonely_packet_created_owner_token"),
          accepted.id,
          :accepted
        )

      review_conn = get(recycle(created_conn), ~p"/packets/review/#{invite_token}")
      review_html = html_response(review_conn, 200)

      assert review_html =~ ~s(id="packet-publish-submit")
      assert review_html =~ "Mara Published"
      assert review_html =~ "Pending Draft"

      publish_conn = post(recycle(review_conn), ~p"/packets/review/#{invite_token}/publish")
      assert redirected_to(publish_conn) == ~p"/"

      home_html =
        publish_conn
        |> recycle()
        |> get(~p"/")
        |> html_response(200)

      assert home_html =~ "Mara Published"
      assert home_html =~ "&quot;name&quot;:&quot;Mara Published&quot;"
      assert home_html =~ "&quot;latitude&quot;:38.7223"
      refute home_html =~ "Pending Draft"

      assert %{review_status: :pending, published_person_id: nil} =
               Drafts.get_draft_member!(pending.id)
    end

    test "owner review link reopens published packet state after publish without duplicate publish controls",
         %{conn: conn} do
      create_conn = post(conn, ~p"/packets", %{"packet" => %{"name" => "Replay review team"}})
      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      invite_token = session_invite_token(created_conn, draft)

      {:ok, %{member: accepted}} =
        Drafts.create_packet_submission(invite_token, %{
          display_name: "Rosa Replay",
          role: "Engineering",
          location_country: "PT",
          location_label: "Lisbon",
          timezone: "Europe/Lisbon",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        })

      {:ok, _accepted_member} =
        Drafts.review_packet_member(
          draft,
          Plug.Conn.get_session(created_conn, "zonely_packet_created_owner_token"),
          accepted.id,
          :accepted
        )

      publish_conn = post(recycle(created_conn), ~p"/packets/review/#{invite_token}/publish")
      assert redirected_to(publish_conn) == ~p"/"

      review_html =
        publish_conn
        |> recycle()
        |> get(~p"/packets/review/#{invite_token}")
        |> html_response(200)

      assert review_html =~ ~s(id="packet-published-review")
      assert review_html =~ "Packet already published"
      assert review_html =~ "Rosa Replay"
      assert review_html =~ ~s(id="owner-review-published")
      assert review_html =~ ~s(id="packet-published-map-link")
      refute review_html =~ ~s(id="packet-publish-form")
      refute review_html =~ "Accept into draft"
      refute review_html =~ "Exclude before publish"

      assert Zonely.Repo.aggregate(Zonely.Accounts.Team, :count) == 1
      assert Zonely.Repo.aggregate(Zonely.Accounts.Person, :count) == 1
      assert Zonely.Repo.aggregate(Zonely.Accounts.Membership, :count) == 1
    end

    test "published invite replay shows map continuation and cannot append duplicate submissions",
         %{conn: conn} do
      create_conn = post(conn, ~p"/packets", %{"packet" => %{"name" => "Replay invite team"}})
      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      invite_token = session_invite_token(created_conn, draft)

      recipient_conn =
        post(build_conn(), ~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{
            "display_name" => "Invite Replay",
            "location_country" => "PT",
            "location_label" => "Lisbon",
            "timezone" => "Europe/Lisbon",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        })

      assert redirected_to(recipient_conn) == ~p"/packets/invite/#{invite_token}"
      [member] = Drafts.list_draft_members(draft)

      {:ok, _accepted_member} =
        Drafts.review_packet_member(
          draft,
          Plug.Conn.get_session(created_conn, "zonely_packet_created_owner_token"),
          member.id,
          :accepted
        )

      publish_conn = post(recycle(created_conn), ~p"/packets/review/#{invite_token}/publish")
      assert redirected_to(publish_conn) == ~p"/"

      invite_html =
        recipient_conn
        |> recycle()
        |> get(~p"/packets/invite/#{invite_token}")
        |> html_response(200)

      assert invite_html =~ ~s(id="packet-published-invite")
      assert invite_html =~ "Packet already published"
      assert invite_html =~ "Invite Replay"
      assert invite_html =~ ~s(id="packet-published-map-link")
      refute invite_html =~ ~s(id="packet-submission-form")
      refute invite_html =~ "Save pending submission"
      refute invite_html =~ "Accept into draft"

      unavailable_html =
        recipient_conn
        |> recycle()
        |> post(~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Duplicate Replay"}
        })
        |> html_response(404)

      assert unavailable_html =~ "Packet invite unavailable"
      assert length(Drafts.list_draft_members(draft)) == 1
      assert Zonely.Repo.aggregate(Zonely.Accounts.Team, :count) == 1
      assert Zonely.Repo.aggregate(Zonely.Accounts.Person, :count) == 1
      assert Zonely.Repo.aggregate(Zonely.Accounts.Membership, :count) == 1
    end

    test "owner review blocks publish for incomplete accepted members", %{conn: conn} do
      create_conn = post(conn, ~p"/packets", %{"packet" => %{"name" => "Blocked publish team"}})
      draft = Zonely.Repo.one!(Zonely.Drafts.TeamDraft)
      created_conn = get(recycle(create_conn), redirected_to(create_conn))
      invite_token = session_invite_token(created_conn, draft)

      {:ok, %{member: incomplete}} =
        Drafts.create_packet_submission(invite_token, %{display_name: "Incomplete Accepted"})

      {:ok, _accepted_member} =
        Drafts.review_packet_member(
          draft,
          Plug.Conn.get_session(created_conn, "zonely_packet_created_owner_token"),
          incomplete.id,
          :accepted
        )

      publish_conn =
        post(recycle(created_conn), ~p"/packets/review/#{invite_token}/publish")

      blocked_html = html_response(publish_conn, 422)

      assert blocked_html =~ ~s(id="packet-publish-error")
      assert blocked_html =~ "Complete or exclude incomplete accepted entries before publishing."
      assert blocked_html =~ "Incomplete Accepted"
      assert Zonely.Repo.aggregate(Zonely.Accounts.Person, :count) == 0
    end

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

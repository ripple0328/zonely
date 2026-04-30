defmodule ZonelyWeb.Packets.PacketFlowTest do
  use ZonelyWeb.ConnCase, async: true

  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Repo

  describe "packet invite creation" do
    test "owner creates opaque invite link without exposing database ids", %{conn: conn} do
      conn =
        post(conn, ~p"/packets", %{
          "packet" => %{"name" => "Lisbon launch team"}
        })

      assert redirected_to(conn) == ~p"/packets/created"

      draft = Repo.one!(TeamDraft)
      refute redirected_to(conn) =~ draft.id

      created_conn = get(recycle(conn), redirected_to(conn))
      html = html_response(created_conn, 200)

      assert html =~ ~s(id="packet-created")
      assert html =~ ~s(id="packet-invite-link")
      refute html =~ draft.id
      refute html =~ draft.owner_token_hash
      refute html =~ draft.invite_token_hash
      assert html =~ "/packets/invite/"
    end

    test "raw draft id created URLs cannot expose owner packet details", %{conn: conn} do
      create_conn =
        post(conn, ~p"/packets", %{
          "packet" => %{"name" => "Hidden continuation team"}
        })

      draft = Repo.one!(TeamDraft)

      assert redirected_to(create_conn) == ~p"/packets/created"

      raw_id_conn = get(recycle(create_conn), "/packets/#{draft.id}/created")

      assert response(raw_id_conn, 404)
    end

    test "created continuation is bound to originating browser session", %{conn: conn} do
      create_conn =
        post(conn, ~p"/packets", %{
          "packet" => %{"name" => "Session-bound packet"}
        })

      assert create_conn
             |> recycle()
             |> get(~p"/packets/created")
             |> html_response(200) =~ ~s(id="packet-created")

      copied_url_conn = get(build_conn(), ~p"/packets/created")

      assert html_response(copied_url_conn, 404) =~ "Packet invite unavailable"
    end
  end

  describe "recipient append-self flow" do
    test "fresh recipient creates and then updates only their own pending submission", %{
      conn: conn
    } do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Append-self team"})

      assert get(conn, ~p"/packets/invite/#{invite_token}")
             |> html_response(200) =~ ~s(id="packet-invite")

      submitted_conn =
        post(conn, ~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{
            "display_name" => "Alice Stone",
            "location_country" => "US",
            "location_label" => "Seattle",
            "timezone" => "America/Los_Angeles",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        })

      assert redirected_to(submitted_conn) == ~p"/packets/invite/#{invite_token}"
      assert [first] = Drafts.list_draft_members(draft)
      assert first.display_name == "Alice Stone"
      assert first.review_status == :pending
      assert first.completion_status == :complete

      updated_conn =
        post(recycle(submitted_conn), ~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{
            "display_name" => "Alice Chen",
            "location_country" => "US",
            "location_label" => "San Francisco",
            "timezone" => "America/Los_Angeles",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        })

      assert redirected_to(updated_conn) == ~p"/packets/invite/#{invite_token}"
      assert [updated] = Drafts.list_draft_members(draft)
      assert updated.id == first.id
      assert updated.display_name == "Alice Chen"
      assert updated.location_label == "San Francisco"
    end

    test "different recipient sessions create separate pending submissions", %{conn: conn} do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Pass-on team"})

      first_conn =
        post(conn, ~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Alice"}
        })

      second_conn =
        conn
        |> recycle()
        |> post(~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Bob"}
        })

      assert redirected_to(first_conn) == ~p"/packets/invite/#{invite_token}"
      assert redirected_to(second_conn) == ~p"/packets/invite/#{invite_token}"

      assert draft
             |> Drafts.list_draft_members()
             |> Enum.map(& &1.display_name)
             |> Enum.sort() == ["Alice", "Bob"]
    end

    test "pass-on invite accumulates Alice, Bob, and Carol while same-session replay updates only own submission",
         %{conn: alice_conn} do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Passed teammate packet"})

      alice_submitted_conn =
        post(alice_conn, ~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Alice", "Lisbon")
        })

      bob_submitted_conn =
        build_conn()
        |> post(~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Bob", "London")
        })

      carol_submitted_conn =
        build_conn()
        |> post(~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Carol", "Toronto")
        })

      assert redirected_to(alice_submitted_conn) == ~p"/packets/invite/#{invite_token}"
      assert redirected_to(bob_submitted_conn) == ~p"/packets/invite/#{invite_token}"
      assert redirected_to(carol_submitted_conn) == ~p"/packets/invite/#{invite_token}"

      assert ["Alice", "Bob", "Carol"] =
               draft
               |> Drafts.list_draft_members()
               |> Enum.map(& &1.display_name)
               |> Enum.sort()

      alice_replayed_conn =
        alice_submitted_conn
        |> recycle()
        |> post(~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Alice Chen", "Porto")
        })

      assert redirected_to(alice_replayed_conn) == ~p"/packets/invite/#{invite_token}"

      members = Drafts.list_draft_members(draft)

      assert length(members) == 3

      assert Enum.any?(
               members,
               &(&1.display_name == "Alice Chen" and &1.location_label == "Porto")
             )

      assert Enum.any?(members, &(&1.display_name == "Bob" and &1.location_label == "London"))
      assert Enum.any?(members, &(&1.display_name == "Carol" and &1.location_label == "Toronto"))
      refute Enum.any?(members, &(&1.display_name == "Alice" and &1.location_label == "Lisbon"))
    end

    test "recipient invite page shows only own pending submission", %{conn: conn} do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Private pending team"})

      {:ok, _other} =
        Drafts.create_submission_member(draft, %{
          display_name: "Other Recipient",
          role: "Team-only role",
          timezone: "Europe/London"
        })

      own_conn =
        post(conn, ~p"/packets/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Current Recipient"}
        })

      html =
        own_conn
        |> recycle()
        |> get(~p"/packets/invite/#{invite_token}")
        |> html_response(200)

      assert html =~ "Current Recipient"
      refute html =~ "Other Recipient"
      refute html =~ "Team-only role"
      refute html =~ "Europe/London"
    end

    test "invalid invite token cannot mutate packet state", %{conn: conn} do
      assert get(conn, ~p"/packets/invite/invalid-token") |> html_response(404) =~
               "Packet invite unavailable"

      assert post(conn, ~p"/packets/invite/invalid-token/submission", %{
               "submission" => %{"display_name" => "Nope"}
             })
             |> html_response(404) =~ "Packet invite unavailable"

      assert Repo.aggregate(TeamDraftMember, :count) == 0
    end
  end

  defp packet_submission(display_name, location_label) do
    %{
      "display_name" => display_name,
      "location_country" => "PT",
      "location_label" => location_label,
      "timezone" => "Europe/Lisbon",
      "work_start" => "09:00",
      "work_end" => "17:00"
    }
  end
end

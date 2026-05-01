defmodule ZonelyWeb.Packets.PacketFlowTest do
  use ZonelyWeb.ConnCase, async: true

  alias Zonely.Accounts
  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Repo

  describe "team invite creation" do
    test "create page uses team invite language and loads app styling", %{conn: conn} do
      html =
        conn
        |> get(~p"/team-invites/new")
        |> html_response(200)

      assert html =~ ~s(href="/assets/app.css")
      assert html =~ "Create a team invite"
      assert html =~ "Team invite"
      refute html =~ "Team packet"
      refute html =~ "packet invite"
    end

    test "legacy packet URL redirects to team invite URL", %{conn: conn} do
      conn = get(conn, ~p"/packets/new?team_id=abc")

      assert redirected_to(conn) == ~p"/team-invites/new?team_id=abc"
    end

    test "owner creates opaque invite link without exposing database ids", %{conn: conn} do
      conn =
        post(conn, ~p"/team-invites", %{
          "packet" => %{"name" => "Lisbon launch team"}
        })

      assert redirected_to(conn) == ~p"/team-invites/created"

      draft = Repo.one!(TeamDraft)
      refute redirected_to(conn) =~ draft.id

      created_conn = get(recycle(conn), redirected_to(conn))
      html = html_response(created_conn, 200)

      assert html =~ ~s(href="/assets/app.css")
      assert html =~ ~s(id="packet-created")
      assert html =~ ~s(id="packet-invite-link")
      assert html =~ ~s(id="packet-invite-copy")
      assert html =~ ~s(data-clipboard-text="https://zonely.localhost/team-invites/invite/)
      assert html =~ "Share this team invite link"
      refute html =~ "packet link"
      refute html =~ draft.id
      refute html =~ draft.owner_token_hash
      refute html =~ draft.invite_token_hash
      assert html =~ "/team-invites/invite/"
      assert html =~ ~r"https://zonely\.localhost/team-invites/invite/[A-Za-z0-9_-]+"
      refute html =~ "http://localhost"
    end

    test "created invite link uses current local request origin and is clickable", %{conn: conn} do
      local_conn = %{conn | scheme: :http, host: "zonely.localhost", port: 4319}

      conn =
        post(local_conn, ~p"/team-invites", %{
          "packet" => %{"name" => "Local invite team"}
        })

      created_conn =
        conn
        |> recycle()
        |> Map.put(:scheme, :http)
        |> Map.put(:host, "zonely.localhost")
        |> Map.put(:port, 4319)
        |> get(redirected_to(conn))

      html = html_response(created_conn, 200)

      assert html =~
               ~r/href="http:\/\/zonely\.localhost:4319\/team-invites\/invite\/[A-Za-z0-9_-]+"/

      assert html =~
               ~r/data-clipboard-text="http:\/\/zonely\.localhost:4319\/team-invites\/invite\/[A-Za-z0-9_-]+"/

      assert html =~ ~s(data-invite-path="/team-invites/invite/)
      refute html =~ "https://zonely.localhost/team-invites/invite/"
    end

    test "raw draft id created URLs cannot expose owner invite details", %{conn: conn} do
      create_conn =
        post(conn, ~p"/team-invites", %{
          "packet" => %{"name" => "Hidden continuation team"}
        })

      draft = Repo.one!(TeamDraft)

      assert redirected_to(create_conn) == ~p"/team-invites/created"

      raw_id_conn = get(recycle(create_conn), "/packets/#{draft.id}/created")

      assert response(raw_id_conn, 404)
    end

    test "created continuation is bound to originating browser session", %{conn: conn} do
      create_conn =
        post(conn, ~p"/team-invites", %{
          "packet" => %{"name" => "Session-bound packet"}
        })

      assert create_conn
             |> recycle()
             |> get(~p"/team-invites/created")
             |> html_response(200) =~ ~s(id="packet-created")

      copied_url_conn = get(build_conn(), ~p"/team-invites/created")

      assert html_response(copied_url_conn, 404) =~ "Team invite unavailable"
    end

    test "creating an invite from an active team preserves the map target", %{conn: conn} do
      {:ok, team} = Accounts.create_team(%{name: "Existing Product Team"})

      new_html =
        conn
        |> get(~p"/team-invites/new?team_id=#{team.id}")
        |> html_response(200)

      assert new_html =~ ~s(href="/assets/app.css")
      assert new_html =~ ~s(id="packet-name")
      assert new_html =~ ~s(value="Existing Product Team")
      assert new_html =~ ~s(name="packet[published_team_id]" value="#{team.id}")

      create_conn =
        post(conn, ~p"/team-invites", %{
          "packet" => %{"name" => "Existing Product Team", "published_team_id" => team.id}
        })

      assert redirected_to(create_conn) == ~p"/team-invites/created"
      assert %{published_team_id: published_team_id} = Repo.one!(TeamDraft)
      assert published_team_id == team.id
    end
  end

  describe "recipient append-self flow" do
    test "fresh recipient creates and then updates only their own pending submission", %{
      conn: conn
    } do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Append-self team"})

      assert get(conn, ~p"/team-invites/invite/#{invite_token}")
             |> html_response(200) =~ ~s(id="packet-invite")

      submitted_conn =
        post(conn, ~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => %{
            "display_name" => "Alice Stone",
            "location_country" => "US",
            "location_label" => "Seattle",
            "timezone" => "America/Los_Angeles",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        })

      assert redirected_to(submitted_conn) == ~p"/team-invites/invite/#{invite_token}"
      assert [first] = Drafts.list_draft_members(draft)
      assert first.display_name == "Alice Stone"
      assert first.review_status == :pending
      assert first.completion_status == :complete

      updated_conn =
        post(recycle(submitted_conn), ~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => %{
            "display_name" => "Alice Chen",
            "location_country" => "US",
            "location_label" => "San Francisco",
            "timezone" => "America/Los_Angeles",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        })

      assert redirected_to(updated_conn) == ~p"/team-invites/invite/#{invite_token}"
      assert [updated] = Drafts.list_draft_members(draft)
      assert updated.id == first.id
      assert updated.display_name == "Alice Chen"
      assert updated.location_label == "San Francisco"
    end

    test "different recipient sessions create separate pending submissions", %{conn: conn} do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Pass-on team"})

      first_conn =
        post(conn, ~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Alice"}
        })

      second_conn =
        conn
        |> recycle()
        |> post(~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Bob"}
        })

      assert redirected_to(first_conn) == ~p"/team-invites/invite/#{invite_token}"
      assert redirected_to(second_conn) == ~p"/team-invites/invite/#{invite_token}"

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
        post(alice_conn, ~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Alice", "Lisbon")
        })

      bob_submitted_conn =
        build_conn()
        |> post(~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Bob", "London")
        })

      carol_submitted_conn =
        build_conn()
        |> post(~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Carol", "Toronto")
        })

      assert redirected_to(alice_submitted_conn) == ~p"/team-invites/invite/#{invite_token}"
      assert redirected_to(bob_submitted_conn) == ~p"/team-invites/invite/#{invite_token}"
      assert redirected_to(carol_submitted_conn) == ~p"/team-invites/invite/#{invite_token}"

      assert ["Alice", "Bob", "Carol"] =
               draft
               |> Drafts.list_draft_members()
               |> Enum.map(& &1.display_name)
               |> Enum.sort()

      alice_replayed_conn =
        alice_submitted_conn
        |> recycle()
        |> post(~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => packet_submission("Alice Chen", "Porto")
        })

      assert redirected_to(alice_replayed_conn) == ~p"/team-invites/invite/#{invite_token}"

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
        post(conn, ~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => %{"display_name" => "Current Recipient"}
        })

      html =
        own_conn
        |> recycle()
        |> get(~p"/team-invites/invite/#{invite_token}")
        |> html_response(200)

      assert html =~ "Current Recipient"
      refute html =~ "Other Recipient"
      refute html =~ "Team-only role"
      refute html =~ ~s(<option value="Europe/London" selected>)
    end

    test "invite submission form uses controlled country timezone and work hour controls", %{
      conn: conn
    } do
      {:ok, %{invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Controlled input team"})

      html =
        conn
        |> get(~p"/team-invites/invite/#{invite_token}")
        |> html_response(200)

      assert html =~ ~s(id="submission-location-country")
      assert html =~ ~s(role="combobox")
      assert html =~ ~s(aria-autocomplete="list")
      assert html =~ ~s(aria-controls="submission-location-country-options")
      assert html =~ ~s(id="submission-location-country-value")
      assert html =~ ~s(name="submission[location_country]")
      assert html =~ ~s(<ul id="submission-location-country-options")
      assert html =~ ~s(role="listbox")
      assert html =~ ~s(data-combobox-option)
      assert html =~ ~s(data-value="AF")
      assert html =~ ~s(data-label="Afghanistan")
      assert html =~ ~s(data-value="US")
      assert html =~ ~s(data-label="United States")
      refute html =~ ~s(id="submission-location-country-filter")
      refute html =~ ~r/<select[^>]+id="submission-location-country"/
      refute html =~ ~s(<datalist id="submission-location-country-options">)

      assert html =~ ~s(id="submission-timezone")
      assert html =~ ~s(name="submission[timezone]")
      assert html =~ ~s(aria-controls="submission-timezone-options")
      assert html =~ ~s(<ul id="submission-timezone-options")
      assert html =~ ~s(data-value="America/Los_Angeles")
      assert html =~ ~s(data-value="Asia/Kolkata")
      refute html =~ ~r/<select[^>]+id="submission-timezone"/
      refute html =~ ~s(<datalist id="submission-timezone-options">)

      assert html =~ ~s(id="submission-work-window")
      assert html =~ ~s(data-work-window-range)
      assert html =~ ~s(id="submission-work-window-output")
      assert html =~ "09:00–17:00"
      assert html =~ ~s(id="submission-work-start-minutes")
      assert html =~ ~s(name="submission[work_start_minutes]")
      assert html =~ ~s(type="range")
      assert html =~ ~s(data-work-window-handle="start")
      assert html =~ ~s(id="submission-work-end-minutes")
      assert html =~ ~s(name="submission[work_end_minutes]")
      assert html =~ ~s(data-work-window-handle="end")
    end

    test "range work-hour submission values are normalized to time fields", %{conn: conn} do
      {:ok, %{draft: draft, invite_token: invite_token}} =
        Drafts.create_team_draft(%{name: "Slider input team"})

      submitted_conn =
        post(conn, ~p"/team-invites/invite/#{invite_token}/submission", %{
          "submission" => %{
            "display_name" => "Slider Teammate",
            "location_country" => "United States",
            "location_label" => "Seattle, Washington",
            "timezone" => "America/Los_Angeles",
            "work_start_minutes" => "540",
            "work_end_minutes" => "1020"
          }
        })

      assert redirected_to(submitted_conn) == ~p"/team-invites/invite/#{invite_token}"
      assert [member] = Drafts.list_draft_members(draft)
      assert member.location_country == "US"
      assert member.work_start == ~T[09:00:00]
      assert member.work_end == ~T[17:00:00]
      assert member.completion_status == :complete
    end

    test "invalid invite token cannot mutate team invite state", %{conn: conn} do
      assert get(conn, ~p"/team-invites/invite/invalid-token") |> html_response(404) =~
               "Team invite unavailable"

      assert post(conn, ~p"/team-invites/invite/invalid-token/submission", %{
               "submission" => %{"display_name" => "Nope"}
             })
             |> html_response(404) =~ "Team invite unavailable"

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

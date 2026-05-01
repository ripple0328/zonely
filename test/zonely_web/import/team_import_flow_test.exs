defmodule ZonelyWeb.Import.TeamImportFlowTest do
  use ZonelyWeb.ConnCase, async: false

  alias Zonely.Accounts
  alias Zonely.Drafts
  alias Zonely.Drafts.{TeamDraft, TeamDraftMember}
  alias Zonely.Repo

  setup do
    previous_resolver = Application.get_env(:zonely, :say_my_name_list_resolver_fun)

    on_exit(fn ->
      if previous_resolver do
        Application.put_env(:zonely, :say_my_name_list_resolver_fun, previous_resolver)
      else
        Application.delete_env(:zonely, :say_my_name_list_resolver_fun)
      end
    end)

    :ok
  end

  describe "SayMyName list import entry" do
    test "creates a draft team with member-scoped completion states and no published roster",
         %{conn: conn} do
      Application.put_env(:zonely, :say_my_name_list_resolver_fun, fn
        "https://saymyname.localhost/list/team-token" -> {:ok, team_payload()}
      end)

      conn =
        get(conn, ~p"/imports/saymyname/list?url=https://saymyname.localhost/list/team-token")

      redirect_path = redirected_to(conn)
      assert redirect_path =~ "/imports/"
      refute redirect_path =~ "owner_token"
      assert Repo.aggregate(TeamDraft, :count) == 1
      assert Repo.aggregate(TeamDraftMember, :count) == 2
      assert Repo.aggregate(Accounts.Team, :count) == 0
      assert Repo.aggregate(Accounts.Person, :count) == 0
      assert Repo.aggregate(Accounts.Membership, :count) == 0

      draft = Repo.one!(TeamDraft)
      members = Drafts.list_draft_members(draft)

      assert draft.name == "Portable Product Team"
      assert draft.status == :draft
      assert Enum.map(members, & &1.display_name) == ["Avery Stone", "Rhea Patel"]
      assert Enum.map(members, & &1.completion_status) == [:complete, :incomplete]
      assert Enum.map(members, & &1.review_status) == [:pending, :pending]

      {:ok, view, html} = live(recycle(conn), ~p"/imports/#{draft.id}")

      assert html =~ "SayMyName list import"
      assert has_element?(view, "#team-import-review")
      assert has_element?(view, "#team-draft-status")
      assert has_element?(view, "#draft-member-#{Enum.at(members, 0).id}-complete")
      assert has_element?(view, "#draft-member-#{Enum.at(members, 1).id}-incomplete")

      assert has_element?(
               view,
               "#draft-member-#{Enum.at(members, 1).id}-missing-location-country"
             )

      assert has_element?(view, "#draft-member-#{Enum.at(members, 1).id}-missing-work-end")
      assert has_element?(view, "#draft-member-#{Enum.at(members, 0).id}-variant-0")
      refute has_element?(view, "#publish-team-draft")
    end

    test "fails safely for empty lists, invalid payloads, and fully invalid members", %{
      conn: conn
    } do
      Application.put_env(:zonely, :say_my_name_list_resolver_fun, fn
        "https://saymyname.localhost/list/empty" ->
          {:ok,
           %{
             "version" => "shared_profile_v1",
             "team" => %{"name" => "Empty"},
             "memberships" => []
           }}

        "https://saymyname.localhost/list/bad-version" ->
          {:ok,
           %{"version" => "legacy_list", "team" => %{"name" => "Legacy"}, "memberships" => []}}

        "https://saymyname.localhost/list/no-identities" ->
          {:ok,
           %{
             "version" => "shared_profile_v1",
             "team" => %{"name" => "No identities"},
             "memberships" => [%{"person" => %{"name_variants" => []}}]
           }}
      end)

      for token <- ["empty", "bad-version", "no-identities"] do
        conn =
          get(conn, ~p"/imports/saymyname/list?url=https://saymyname.localhost/list/#{token}")

        assert html_response(conn, 422) =~ "We could not import that SayMyName list"
      end

      assert Repo.aggregate(TeamDraft, :count) == 0
      assert Repo.aggregate(TeamDraftMember, :count) == 0
      assert Repo.aggregate(Accounts.Person, :count) == 0
    end

    test "isolates partially invalid members and duplicate conflicts without guessing people",
         %{conn: conn} do
      {:ok, person} =
        Accounts.create_person(%{
          name: "Avery Stone",
          country: "GB",
          timezone: "Europe/London",
          work_start: ~T[08:00:00],
          work_end: ~T[16:00:00]
        })

      Application.put_env(:zonely, :say_my_name_list_resolver_fun, fn
        "https://saymyname.localhost/list/partial" ->
          {:ok, partial_payload()}
      end)

      conn =
        get(conn, ~p"/imports/saymyname/list?url=https://saymyname.localhost/list/partial")

      assert redirected_to(conn) =~ "/imports/"
      assert Repo.aggregate(TeamDraft, :count) == 1
      assert Repo.aggregate(TeamDraftMember, :count) == 1
      assert Repo.get!(Accounts.Person, person.id).timezone == "Europe/London"

      draft = Repo.one!(TeamDraft)
      member = Repo.one!(TeamDraftMember)
      assert member.display_name == "Avery Stone"
      assert member.timezone == "Europe/London"

      assert [%{"index" => 1, "reason" => "missing_display_name"}] =
               draft.source_payload["invalid_memberships"]

      {:ok, view, _html} = live(recycle(conn), ~p"/imports/#{draft.id}")

      assert has_element?(view, "#draft-member-#{member.id}-conflict")
      assert has_element?(view, "#invalid-import-member-1")
      assert has_element?(view, "#invalid-import-member-1-reason")
    end
  end

  defp team_payload do
    %{
      "version" => "shared_profile_v1",
      "team" => %{"id" => "team-portable", "name" => "Portable Product Team"},
      "memberships" => [
        %{
          "role" => "Design",
          "person" => %{
            "id" => "smn-avery",
            "display_name" => "Avery Stone",
            "name_variants" => [%{"lang" => "en-US", "text" => "Avery Stone"}]
          },
          "location" => %{
            "country" => "GB",
            "label" => "London",
            "latitude" => 51.5072,
            "longitude" => -0.1276
          },
          "availability" => %{
            "timezone" => "Europe/London",
            "work_start" => "09:00",
            "work_end" => "17:00"
          }
        },
        %{
          "role" => "Product",
          "person" => %{
            "id" => "smn-rhea",
            "display_name" => "Rhea Patel",
            "pronouns" => "she/her",
            "name_variants" => [%{"lang" => "gu-IN", "text" => "રીયા પટેલ"}]
          },
          "availability" => %{
            "timezone" => "Asia/Kolkata",
            "work_start" => "10:00"
          }
        }
      ]
    }
  end

  defp partial_payload do
    %{
      "version" => "shared_profile_v1",
      "team" => %{"name" => "Partial Team"},
      "memberships" => [
        hd(team_payload()["memberships"]),
        %{"role" => "Unknown", "person" => %{"name_variants" => []}}
      ]
    }
  end
end

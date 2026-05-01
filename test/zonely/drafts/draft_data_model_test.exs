defmodule Zonely.Drafts.DraftDataModelTest do
  use Zonely.DataCase, async: true

  alias Zonely.Accounts
  alias Zonely.Drafts
  alias Zonely.Drafts.TeamDraftMember
  alias Zonely.Repo

  describe "draft data model" do
    test "stores incomplete imported profiles without creating published people" do
      {:ok, %{draft: draft}} = Drafts.create_team_draft(%{name: "Portable card"})

      assert {:ok, member} =
               Drafts.create_draft_member(draft, %{
                 display_name: "Lina Torres",
                 location_country: "PT",
                 location_label: "Lisbon",
                 source_kind: "saymyname_card",
                 source_payload: %{"version" => "shared_profile_v1"}
               })

      assert member.completion_status == :incomplete
      assert member.published_person_id == nil
      assert Repo.aggregate(Accounts.Person, :count) == 0

      assert {:error, changeset} = Accounts.create_person(%{name: "Incomplete Published Person"})
      assert "can't be blank" in errors_on(changeset).timezone
      assert "can't be blank" in errors_on(changeset).country
    end

    test "supports review lifecycle states and published references" do
      {:ok, %{draft: draft}} = Drafts.create_team_draft(%{name: "Review packet"})

      {:ok, member} =
        Drafts.create_draft_member(draft, %{
          display_name: "Avery Stone",
          location_country: "GB",
          location_label: "London",
          timezone: "Europe/London",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00],
          review_status: :accepted
        })

      assert member.completion_status == :complete

      assert TeamDraftMember.review_statuses() == [
               :pending,
               :accepted,
               :rejected,
               :excluded,
               :published
             ]

      {:ok, person} =
        Accounts.create_person(%{
          name: "Avery Stone",
          country: "GB",
          timezone: "Europe/London",
          work_start: ~T[09:00:00],
          work_end: ~T[17:00:00]
        })

      {:ok, team} = Accounts.create_team(%{name: "Published Team"})
      {:ok, membership} = Accounts.create_membership(%{team_id: team.id, person_id: person.id})

      assert {:ok, published_draft} = Drafts.put_published_references(draft, team.id)

      assert {:ok, published_member} =
               Drafts.put_published_references(member, person.id, membership.id)

      assert published_draft.status == :published
      assert published_draft.published_team_id == team.id
      assert published_member.review_status == :published
      assert published_member.published_person_id == person.id
      assert published_member.published_membership_id == membership.id
    end

    test "creates team draft members from import projections with independent completion states" do
      projection = %{
        kind: :team,
        version: "shared_profile_v1",
        team: %{"name" => "Zonely Team"},
        memberships: [
          %{
            "person" => %{"display_name" => "Avery Stone"},
            "location" => %{"country" => "GB", "label" => "London"},
            "availability" => %{
              "timezone" => "Europe/London",
              "work_start" => "09:00",
              "work_end" => "17:00"
            }
          },
          %{"person" => %{"display_name" => "Rhea Patel"}}
        ]
      }

      assert {:ok, result} = Drafts.create_draft_from_import(projection)

      assert Enum.map(result.members, & &1.display_name) == ["Avery Stone", "Rhea Patel"]
      assert Enum.map(result.members, & &1.completion_status) == [:complete, :incomplete]
      assert Enum.all?(result.members, &is_nil(&1.published_person_id))
    end
  end
end
